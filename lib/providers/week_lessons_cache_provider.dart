import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../repositories/timetable_repository.dart';
import '../utils/logger.dart';
import 'services_provider.dart';
import 'timetable_repository_provider.dart';

/// S5.5(조회를 SQLite `lessons`로 전환)에서, 동기적으로 렌더링해야 하는 그리드가
/// 비동기 SQLite 조회를 직접 기다릴 수 없다는 문제를 해소하기 위한 프리페치
/// 캐시 (S5.5.3 — 아직 어떤 화면도 이 클래스를 쓰지 않는다, 완전 비연결).
///
/// 사용 패턴은 항상 2단계다 — sync→async 오염을 피하기 위한 설계(S5.5 설계
/// 검토 Decision C):
/// 1. [ensureLoaded]를 (보통 `addPostFrameCallback` 등에서) 비동기로 호출해
///    캐시를 미리 채운다.
/// 2. 실제 렌더링·검증 경로에서는 [lessonsFor]만 **동기로** 읽는다 — 아직
///    준비되지 않았으면 null을 반환하므로, 호출자는 이 경우 기존(JSON 기반)
///    경로로 폴백해야 한다(S5.5.4에서 실제로 연결할 때의 책임).
class WeekLessonsCache {
  WeekLessonsCache({
    required Future<TimetableRepository> Function() repository,
    required Future<void> Function() flushPendingWrites,
    void Function()? onLoaded,
  }) : _repository = repository,
       _flushPendingWrites = flushPendingWrites,
       _onLoaded = onLoaded;

  final Future<TimetableRepository> Function() _repository;
  final Future<void> Function() _flushPendingWrites;

  /// [_load]가 끝날 때마다(성공·실패 무관) 호출된다 — S5.5.4에서 화면이
  /// 이 캐시를 실제로 쓰기 시작하면, "캐시가 막 준비됐으니 다시 그려라"는
  /// 신호로 [weekLessonsCacheTickerProvider]를 올리는 용도로 연결한다.
  final void Function()? _onLoaded;

  final Map<String, List<Lesson>> _cache = {};
  final Map<String, Future<void>> _inFlight = {};

  static String _cacheKey(String timetableId, DateTime weekMonday) {
    final monday = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    return '$timetableId|${monday.toIso8601String().substring(0, 10)}';
  }

  /// 캐시된 값을 동기로 읽는다. [ensureLoaded]가 아직 끝나지 않았거나 한 번도
  /// 호출되지 않았으면 null이다 — "아직 모른다"와 "조회했더니 빈 목록이었다"를
  /// 구분하기 위해 빈 목록은 그대로 `[]`로 캐시한다.
  List<Lesson>? lessonsFor(String timetableId, DateTime weekMonday) {
    return _cache[_cacheKey(timetableId, weekMonday)];
  }

  /// [timetableId]의 [weekMonday] 주 데이터를 비동기로 미리 읽어 캐시를 채운다.
  ///
  /// 같은 키에 대해 진행 중인 호출이 있으면 새로 조회하지 않고 그 Future를
  /// 그대로 기다린다(중복 조회 방지). 조회 전 [ExchangeHistoryService.flushPendingWrites]로
  /// 큐에 쌓인 쓰기(JSON 저장 → SQLite 미러 → `replayInto`)를 모두 흘려보낸다 —
  /// 그렇지 않으면 방금 실행한 교체가 SQLite에 반영되기 전 값을 캐시해 버리는
  /// 읽기-쓰기 경쟁이 생긴다.
  ///
  /// 그래도 재생이 밀려 있으면([ProjectionStatus.isStale] — 예: `loadSink`로
  /// SQLite에서 곧바로 이력을 불러온 시간표는 로드 시 `replayInto`를 타지
  /// 않는다, S5.5 설계 검토에서 발견) 한 번만 [TimetableRepository.replayInto]를
  /// 추가로 실행한다. 그래도 여전히 밀려 있으면(예: 동시에 다른 쓰기가 들어옴)
  /// 있는 그대로 조용히 진행한다 — 차단하지 않는다(Decision E).
  Future<void> ensureLoaded(String timetableId, DateTime weekMonday) {
    final key = _cacheKey(timetableId, weekMonday);
    if (_cache.containsKey(key)) return Future<void>.value();

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _load(timetableId, weekMonday, key);
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  Future<void> _load(
    String timetableId,
    DateTime weekMonday,
    String key,
  ) async {
    try {
      await _flushPendingWrites();
      final repo = await _repository();

      var status = await repo.getProjectionStatus(timetableId);
      if (status.isStale) {
        await repo.replayInto(timetableId);
        status = await repo.getProjectionStatus(timetableId);
        if (status.isStale) {
          AppLogger.error(
            '$timetableId 재생이 여전히 밀려 있습니다'
            '(projectedSeq=${status.projectedSeq}, maxActiveSeq=${status.maxActiveSeq})'
            ' — 있는 그대로 진행합니다.',
          );
        }
      }

      _cache[key] = await repo.getTouchedLessonsForWeek(timetableId, weekMonday);
    } catch (e) {
      AppLogger.error('WeekLessonsCache 로드 실패: $e', e);
      // 캐시를 채우지 않는다 — lessonsFor는 계속 null을 반환해 호출자가
      // 기존 경로로 폴백하게 한다.
    } finally {
      _onLoaded?.call();
    }
  }

  /// 시간표를 전환하거나 삭제할 때 그 시간표의 캐시 항목을 모두 지운다
  /// (S5.5 설계 검토 R9 — 캐시 무효화). 진행 중인 조회는 끝난 뒤 `_inFlight`에서
  /// 스스로 제거되므로 별도로 취소하지 않아도 안전하다(단지 그 결과를 다시
  /// 못 찾도록 `_cache`에서만 지운다 — 조회 자체가 실패하지는 않는다).
  void invalidateTimetable(String timetableId) {
    final prefix = '$timetableId|';
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// 캐시 전체를 비운다 — 시간표 전환처럼 큰 리셋이 일어나는 시점에
  /// 시간표별로 하나씩 지우는 대신 통째로 비워 메모리를 정리한다.
  void clearAll() {
    _cache.clear();
  }
}

/// S5.5의 3단계 롤백 중 1단계(즉시 토글) — true일 때만 화면이 SQLite 조회
/// 경로([WeekLessonsCache])를 실제로 쓴다. S5.5.4에서 연결하기 전까지는
/// 이 값을 읽는 코드가 없다. 기본값 false.
final lessonReadPathEnabledProvider = StateProvider<bool>((ref) => false);

/// [WeekLessonsCache]가 캐시를 채울 때마다 값을 올린다 — 이 값을
/// `ref.watch`하는 Provider·리스너는 "캐시가 방금 준비됐으니 다시 계산/재렌더
/// 하라"는 신호로 쓴다(S5.5.4에서 `resolved_timetable_provider`·
/// `exchange_view_provider`가 이 용도로 구독한다).
class WeekLessonsCacheTicker extends StateNotifier<int> {
  WeekLessonsCacheTicker() : super(0);

  void bump() => state++;
}

final weekLessonsCacheTickerProvider =
    StateNotifierProvider<WeekLessonsCacheTicker, int>(
      (ref) => WeekLessonsCacheTicker(),
    );

/// 앱 전체에서 하나만 유지하는 [WeekLessonsCache] 인스턴스.
///
/// **버그 수정 (2026-09-30, 사용자 실 앱 테스트로 발견)**: 처음 구현에서는
/// [WeekLessonsCache]가 한 번 채운 (시간표, 주) 항목을 시간표 전환(Level 3
/// 리셋) 전까지 영원히 그대로 들고 있었다 — 즉 교체를 추가·삭제·되돌려도
/// 이미 캐시된 주는 다시 조회하지 않았다. 그 결과 "여러 교체를 연속으로
/// 실행 → 전체 초기화 → 같은 칸 재선택"처럼 캐시가 먼저 채워진 뒤 교체
/// 이력이 바뀌는 순서로 조작하면, 화면 표시(`교체 뷰` OFF라 원본을 그대로
/// 그리는 그리드)는 정상인데 검증 경로(`resolvedTimetableProvider` →
/// `validationTimeSlots`)만 낡은 캐시를 계속 읽어 **선택한 칸을 빈 칸으로
/// 오판, 교체 경로 탐색 사이드바가 아예 뜨지 않는** 표시/검증 불일치가
/// 발생했다(S5.5 설계 검토 R11이 미리 경고했던 바로 그 시나리오). SQLite
/// `lessons` 테이블 자체는 항상 정상이었다 — 섀도우 비교 패널로 "불일치
/// 0칸"이 확인된 것이 그 증거다. 그래서 [exchangeListVersionProvider]
/// (교체 추가·삭제·되돌리기·전체 초기화 시 항상 증가)를 구독해, 값이
/// 바뀔 때마다 캐시 전체를 비우고 ticker를 올려 다음 조회가 무조건
/// 새로 읽도록 고쳤다. 주 단위로 세밀하게 지우는 대신 통째로 비우는
/// 이유는, 어떤 주가 영향받는지 이벤트 하나하나를 다시 분석하는 것보다
/// "교체 이력이 하나라도 바뀌면 이번 주만 다시 읽는 비용은 무시할 수
/// 있는 수준"이라 정확성을 우선한 것이다.
final weekLessonsCacheProvider = Provider<WeekLessonsCache>((ref) {
  final cache = WeekLessonsCache(
    repository: () => ref.read(timetableRepositoryProvider.future),
    flushPendingWrites:
        () => ref.read(exchangeHistoryServiceProvider).flushPendingWrites(),
    onLoaded: () => ref.read(weekLessonsCacheTickerProvider.notifier).bump(),
  );

  ref.listen<int>(exchangeListVersionProvider, (previous, next) {
    cache.clearAll();
    ref.read(weekLessonsCacheTickerProvider.notifier).bump();
  });

  return cache;
});

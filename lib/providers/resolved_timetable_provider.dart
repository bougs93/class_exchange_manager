import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exchange_history_item.dart';
import '../models/time_slot.dart';
import '../utils/logger.dart';
import '../utils/non_exchangeable_week_overlay.dart';
import '../utils/resolved_week.dart';
import 'exchange_screen_provider.dart';
import 'non_exchangeable_dated_cells_provider.dart';
import 'selected_week_provider.dart';
import 'services_provider.dart';
import 'show_week_header_provider.dart';
import 'week_lessons_cache_provider.dart';

/// 교체 가능성 **판정**에 사용할 시간표 (§10.8 4d)
///
/// 원본 시간표에 활성 교체를 합성한 결과다. 교체 탐색·검증은 이 결과를 기준으로 한다.
///
/// 날짜 반영 ON — "현재 보고 있는 주"만 합성:
/// - **다른 주의 교체는 반영되지 않는다** → P3 해소. 8/27 교체가 9/3 건의
///   판정을 방해하지 않는다
/// - **같은 주의 선행 교체는 반영된다** → 이미 그 주에 교체된 칸을 다시
///   교체 대상으로 제시하지 않는다(§10.5 "같은 주 충돌")
///
/// 날짜 반영 OFF — 모든 주 교체를 한 장에 합성(`ResolvedWeek.allWeeks`, 2026-09-30):
/// - 화면(교체 뷰)과 같은 기준 → 보이는 칸 그대로 교체를 찾는다
/// - 다른 주 교체로 옮겨진 칸도 "찬 칸"으로 본다(ON보다 엄격 — 의도된 동작)
///
/// 교체 뷰(보기 토글)의 ON/OFF와 무관하게 항상 합성 결과를 쓴다. 교체 뷰는
/// "무엇을 보여줄지"의 옵션일 뿐이고, 교체는 언제나 누적 상태 위에 쌓이기
/// 때문이다(§1-6).
///
/// **성능**(§10.9 리스크 3): Provider가 의존성(시간표·주·교체 목록 버전)이
/// 바뀔 때만 재계산하므로 렌더링마다 다시 합성하지 않는다.
final resolvedTimetableProvider = Provider<List<TimeSlot>>((ref) {
  final timetableData = ref.watch(
    exchangeScreenProvider.select((state) => state.timetableData),
  );
  if (timetableData == null) return const [];

  // 교체가 추가·삭제·되돌려지면 다시 합성
  ref.watch(exchangeListVersionProvider);
  final weekMonday = ref.watch(selectedWeekProvider);

  final events = ref.read(exchangeHistoryServiceProvider).getActiveExchangeList();
  final base = timetableData.timeSlots;

  // 날짜표시 스위치(S1.5)가 ON이면 실제 날짜 기준으로 다른 주 교체를 독립
  // 반영한다(S1.8, 2026-09-29 사용자 확정 — 검증도 화면 표시와 함께 고침).
  // OFF면 모든 주 교체를 한 장에 합친다(`allWeeks`, 2026-09-30 — 이전엔 `of`).
  // ⚠ `exchange_view_provider.dart`의 `_applyResolvedWeek`와 반드시 같은 합성을 쓴다.
  //
  // OFF 모드는 절대 SQLite를 읽지 않는다(S5.5 설계 검토 Decision D) — 날짜 키
  // 데이터로는 "요일·교시 한 장 합성"을 재현할 수 없고, "날짜표시 OFF는 날짜
  // 정보를 유출하지 않는다"는 불변 조건을 계속 지키기 위해서다. ON 모드에서만
  // 아래에서 SQLite 오버레이로 바꿔치기한다.
  final showWeekHeader = ref.watch(showWeekHeaderProvider);
  final resolved =
      showWeekHeader
          ? _resolveOnWeek(ref, base: base, events: events, weekMonday: weekMonday)
          : ResolvedWeek.allWeeks(base: base, events: events, weekMonday: weekMonday);
  final resolvedSlots = resolved.toTimeSlots(base);

  // 날짜 지정 교체불가 셀(§10.6) — 매주 반복 셀은 이미 base에 구워져 있으므로
  // 여기서는 그 주에만 적용되는 셀만 얹는다.
  final datedNonExchangeable = ref.watch(nonExchangeableDatedCellsProvider);
  if (datedNonExchangeable.isEmpty) return resolvedSlots;

  return applyDatedNonExchangeable(resolvedSlots, datedNonExchangeable, weekMonday);
});

/// 날짜표시 ON 모드의 합성 — SQLite 캐시가 이미 준비돼 있으면 그 값을 쓰고,
/// 아니면 기존 `dateAware`로 폴백한다(캐시가 준비 안 됐을 때의 자동 폴백은
/// 이 함수 자체가 항상 수행한다).
///
/// [weekLessonsCacheTickerProvider]를 watch하므로, 캐시가 비동기로 채워진
/// 직후 이 Provider가 자동으로 다시 계산되어 SQLite 값으로 갱신된다.
ResolvedWeek _resolveOnWeek(
  Ref ref, {
  required List<TimeSlot> base,
  required List<ExchangeHistoryItem> events,
  required DateTime weekMonday,
}) {
  final timetableId = ref.read(exchangeHistoryServiceProvider).timetableId;
  if (timetableId == null) {
    return ResolvedWeek.dateAware(base: base, events: events, weekMonday: weekMonday);
  }

  // 캐시가 준비되면 이 Provider를 다시 계산시키기 위한 구독.
  ref.watch(weekLessonsCacheTickerProvider);

  final cache = ref.read(weekLessonsCacheProvider);
  final touched = cache.lessonsFor(timetableId, weekMonday);
  if (touched != null) {
    return ResolvedWeek.fromLessons(
      base: base,
      touchedLessons: touched,
      weekMonday: weekMonday,
    );
  }

  // 아직 캐시가 준비되지 않았다 — 이번 프레임은 기존 경로로 폴백하고,
  // 백그라운드로 준비시킨다(끝나면 ticker가 올라 이 Provider가 다시 계산된다).
  cache.ensureLoaded(timetableId, weekMonday).catchError((Object e) {
    AppLogger.error('resolvedTimetableProvider용 SQLite 프리페치 실패: $e', e);
  });
  return ResolvedWeek.dateAware(base: base, events: events, weekMonday: weekMonday);
}

/// `교사|요일번호|교시` → 과목명 색인
///
/// 사이드바는 경로 노드마다 과목명을 보여주는데, 예전에는 노드 하나당
/// 시간표 전체(1,000칸 이상)를 선형 탐색하면서 요일 문자열까지 매번
/// 숫자로 바꿨다. 화면에 보이는 노드가 수십 개라 경로를 고를 때마다
/// 수만 번 비교가 일어나 반응이 눈에 띄게 늦었다(2026-10-01).
///
/// 시간표가 바뀔 때만 한 번 만들어 두고 O(1)로 찾는다.
/// `resolvedTimetableProvider`를 watch하므로 교체·주 변경이 자동 반영된다.
final resolvedSubjectIndexProvider = Provider<Map<String, String>>((ref) {
  final slots = ref.watch(resolvedTimetableProvider);

  final index = <String, String>{};
  for (final slot in slots) {
    final teacher = slot.teacher;
    final dayOfWeek = slot.dayOfWeek;
    final period = slot.period;
    final subject = slot.subject;
    if (teacher == null || dayOfWeek == null || period == null) continue;
    if (subject == null || subject.isEmpty) continue;
    // 선형 탐색이 먼저 찾은 값과 같도록 앞선 항목을 유지한다.
    index.putIfAbsent('$teacher|$dayOfWeek|$period', () => subject);
  }
  return index;
});

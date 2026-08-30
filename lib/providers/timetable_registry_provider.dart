import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timetable_registry.dart';
import '../services/print_profile_storage_service.dart';
import '../services/timetable_registry_service.dart';
import '../utils/logger.dart';
import 'services_provider.dart';
import 'substitution_plan_provider.dart';

/// 시간표 레지스트리 서비스 Provider
final timetableRegistryServiceProvider = Provider<TimetableRegistryService>((
  ref,
) {
  return TimetableRegistryService();
});

/// 활성 시간표 전환 버전 (전환 시 증가 → 화면 데이터 재로드 트리거)
final timetableSwitchVersionProvider = StateProvider<int>((ref) => 0);

/// 시간표 레지스트리 상태 Notifier
///
/// 앱 시작 시 레지스트리를 로드하고 활성 시간표 스코프를
/// 교체 이력·결보강 서비스에 적용합니다.
/// 시간표 전환 시 스코프 재적용 + 데이터 재로드를 오케스트레이션합니다.
class TimetableRegistryNotifier
    extends StateNotifier<AsyncValue<TimetableRegistry>> {
  TimetableRegistryNotifier(this._ref) : super(const AsyncValue.loading()) {
    unawaited(_initialize());
  }

  final Ref _ref;

  final Completer<void> _initCompleter = Completer<void>();

  /// 초기화(로드+스코프 적용) 완료 대기
  ///
  /// 데이터 로드 전 반드시 호출해야 스코프가 올바르게 적용됩니다.
  /// 실패 시에도 완료 처리되어 빈 상태로 진행됩니다.
  Future<void> ensureInitialized() => _initCompleter.future;

  TimetableRegistryService get _service =>
      _ref.read(timetableRegistryServiceProvider);

  Future<void> _initialize() async {
    try {
      // 레지스트리 로드
      final registry = await _service.loadRegistry();
      state = AsyncValue.data(registry);

      // 활성 시간표 스코프 적용 (데이터 로드는 각 화면의 기존 흐름이 수행)
      await _applyScope(registry.activeId, reload: false);
    } catch (e, st) {
      AppLogger.error('시간표 레지스트리 초기화 실패: $e', e);
      state = AsyncValue.error(e, st);
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// 활성 시간표 스코프를 서비스 계층에 적용
  ///
  /// [reload]가 true면 스코프 데이터(교체 목록·결보강)도 즉시 재로드합니다.
  Future<void> _applyScope(String? timetableId, {required bool reload}) async {
    final historyService = _ref.read(exchangeHistoryServiceProvider);
    historyService.timetableId = timetableId;

    final substitutionNotifier = _ref.read(substitutionPlanProvider.notifier);
    if (reload) {
      await substitutionNotifier.setTimetableScope(timetableId);
    } else {
      // 초기화 시: 재로드 없이 스코프만 설정 (start_screen이 로드)
      substitutionNotifier.setTimetableScopeWithoutReload(timetableId);
    }
  }

  /// 활성 시간표 전환
  ///
  /// 레지스트리 갱신 → 스코프 재적용 → 데이터 재로드 → 화면 재로드 트리거.
  Future<bool> switchActive(String id) async {
    await ensureInitialized();
    final current = state.valueOrNull;
    if (current == null || current.getById(id) == null) {
      AppLogger.warning('전환 대상 시간표를 찾을 수 없음: $id');
      return false;
    }
    if (current.activeId == id) {
      return true; // 이미 활성
    }

    final success = await _service.switchActive(id);
    if (!success) {
      return false;
    }

    state = AsyncValue.data(current.withActive(id));

    // 스코프 재적용 + 스코프 데이터 재로드
    await _applyScope(id, reload: true);
    await _ref.read(exchangeHistoryServiceProvider).loadFromLocalStorage();

    // 화면(시간표 본문·그리드) 재로드 트리거
    _ref.read(timetableSwitchVersionProvider.notifier).state++;

    AppLogger.info('활성 시간표 전환 완료: $id');
    return true;
  }

  /// 시간표 등록
  ///
  /// 첫 시간표인 경우 자동으로 활성 지정 + 스코프 적용.
  /// 반환값: 등록된 항목 (실패 시 null)
  Future<TimetableRegistryEntry?> registerTimetable({
    required String name,
    required String fileName,
    required String filePath,
    required String hash,
    required String contentHash,
    String? teacherName,
    String? schoolName,
    DateTime? semesterStart,
    DateTime? semesterEnd,
  }) async {
    await ensureInitialized();
    try {
      final entry = await _service.registerTimetable(
        name: name,
        fileName: fileName,
        filePath: filePath,
        hash: hash,
        contentHash: contentHash,
        teacherName: teacherName,
        schoolName: schoolName,
        semesterStart: semesterStart,
        semesterEnd: semesterEnd,
      );

      final current = state.valueOrNull ?? const TimetableRegistry();
      final isFirst = current.timetables.isEmpty;
      state = AsyncValue.data(current.withEntry(entry));

      // 첫 시간표면 활성 스코프 적용
      if (isFirst) {
        await _applyScope(entry.id, reload: true);
        await _ref.read(exchangeHistoryServiceProvider).loadFromLocalStorage();
        _ref.read(timetableSwitchVersionProvider.notifier).state++;
      }

      return entry;
    } catch (e) {
      AppLogger.error('시간표 등록 실패: $e', e);
      return null;
    }
  }

  /// 활성 시간표 데이터 재로드
  ///
  /// 전환 없이 현재 활성 시간표의 저장 데이터를 다시 읽어 화면을 되돌립니다.
  /// (동일 파일 재선택을 사용자가 취소했을 때, 이미 메모리에 올라온 새 파일
  ///  내용을 버리고 원래 시간표 상태로 복구하는 용도)
  Future<void> reloadActive() async {
    await ensureInitialized();
    final activeId = state.valueOrNull?.activeId;
    if (activeId == null) return;

    await _applyScope(activeId, reload: true);
    await _ref.read(exchangeHistoryServiceProvider).loadFromLocalStorage();
    _ref.read(timetableSwitchVersionProvider.notifier).state++;
    AppLogger.info('활성 시간표 재로드: $activeId');
  }

  /// 활성 시간표의 교사·학교명 갱신
  ///
  /// 교사는 엑셀 교사 목록에서 고른 값이어야 합니다(자유 입력 금지).
  /// 빈 문자열을 넘기면 미지정으로 되돌립니다.
  Future<bool> updateTeacherAndSchool(
    String id, {
    String? teacherName,
    String? schoolName,
  }) async {
    await ensureInitialized();
    final current = state.valueOrNull;
    if (current == null || current.getById(id) == null) {
      return false;
    }

    final teacher = teacherName?.trim();
    final school = schoolName?.trim();
    final clearTeacher = teacherName != null && (teacher?.isEmpty ?? true);
    final clearSchool = schoolName != null && (school?.isEmpty ?? true);

    final success = await _service.updateTeacherAndSchool(
      id,
      teacherName: clearTeacher ? null : teacher,
      schoolName: clearSchool ? null : school,
      clearTeacher: clearTeacher,
      clearSchool: clearSchool,
    );
    if (!success) {
      return false;
    }

    state = AsyncValue.data(
      current.copyWith(
        timetables:
            current.timetables
                .map(
                  (e) =>
                      e.id == id
                          ? e.copyWith(
                            teacherName: clearTeacher ? null : teacher,
                            schoolName: clearSchool ? null : school,
                            clearTeacherName: clearTeacher,
                            clearSchoolName: clearSchool,
                          )
                          : e,
                )
                .toList(),
      ),
    );
    AppLogger.info('시간표 교사·학교명 갱신: $id (교사=$teacher, 학교=$school)');
    return true;
  }

  /// 시간표 이름 변경
  Future<bool> renameTimetable(String id, String newName) async {
    await ensureInitialized();
    final success = await _service.renameTimetable(id, newName);
    if (!success) {
      return false;
    }

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          timetables:
              current.timetables
                  .map((e) => e.id == id ? e.copyWith(name: newName) : e)
                  .toList(),
        ),
      );
    }
    return true;
  }

  /// 시간표 원본 파일 갱신 (동일 파일 재선택 시)
  ///
  /// 내용 해시가 변경된 경우 해당 시간표의 교체 목록·결보강 데이터는
  /// 내용과 불일치하므로 스코프 파일을 정리합니다. 계획서는 유지됩니다.
  /// 처리 후 해당 시간표를 활성으로 전환합니다.
  Future<bool> updateTimetableSource(
    String id, {
    required String fileName,
    required String filePath,
    required String hash,
    required String contentHash,
  }) async {
    await ensureInitialized();
    final current = state.valueOrNull;
    final entry = current?.getById(id);
    if (entry == null) {
      return false;
    }

    final contentChanged =
        entry.contentHash.isNotEmpty && entry.contentHash != contentHash;

    final success = await _service.updateTimetableData(
      id,
      fileName: fileName,
      filePath: filePath,
      hash: hash,
      contentHash: contentHash,
    );
    if (!success) {
      return false;
    }

    // 내용이 바뀐 경우: 교체 목록·결보강 스코프 데이터 정리 (계획서는 유지)
    if (contentChanged) {
      await _ref
          .read(exchangeHistoryServiceProvider)
          .clearStoredDataForTimetable(id);
      await _ref
          .read(substitutionPlanProvider.notifier)
          .clearStoredDataForTimetable(id);
      AppLogger.info('시간표 내용 변경 감지 → 스코프 교체 데이터 정리: $id');
    }

    // 상태 갱신
    final next = current!.copyWith(
      timetables:
          current.timetables
              .map(
                (e) =>
                    e.id == id
                        ? e.copyWith(
                          fileName: fileName,
                          filePath: filePath,
                          hash: hash,
                          contentHash: contentHash,
                        )
                        : e,
              )
              .toList(),
    );
    state = AsyncValue.data(next);

    // 해당 시간표로 전환 (이미 활성이면 내부에서 무시됨)
    if (next.activeId != id) {
      await switchActive(id);
    } else {
      // 이미 활성인 경우에도 데이터 재로드가 필요 (내용이 바뀌었을 수 있음)
      await _applyScope(id, reload: true);
      await _ref.read(exchangeHistoryServiceProvider).loadFromLocalStorage();
      _ref.read(timetableSwitchVersionProvider.notifier).state++;
    }

    return true;
  }

  /// 시간표 제거
  ///
  /// 스코프 데이터(교체 목록·결보강·계획서)도 함께 삭제합니다.
  /// 활성 시간표를 제거하면 남은 시간표 중 첫 번째로 자동 전환합니다.
  Future<bool> removeTimetable(String id) async {
    await ensureInitialized();
    final current = state.valueOrNull;
    if (current == null || current.getById(id) == null) {
      return false;
    }

    final success = await _service.removeTimetable(id);
    if (!success) {
      return false;
    }

    // 스코프 데이터 삭제
    await _ref
        .read(exchangeHistoryServiceProvider)
        .clearStoredDataForTimetable(id);
    await _ref
        .read(substitutionPlanProvider.notifier)
        .clearStoredDataForTimetable(id);
    await PrintProfileStorageService().clearStore(id);

    final next = current.withoutEntry(id);
    state = AsyncValue.data(next);

    // 활성이 해제된 경우: 남은 시간표 중 첫 번째로 자동 전환 또는 메모리 정리
    if (next.activeId == null && next.timetables.isNotEmpty) {
      await switchActive(next.timetables.first.id);
    } else if (next.activeId == null) {
      // 마지막 시간표 삭제: 레거시 파일의 고스트 데이터가 로드되지 않도록
      // 메모리만 초기화 (재로드 금지)
      await _applyScope(null, reload: false);
      _ref.read(exchangeHistoryServiceProvider).resetInMemoryState();
      _ref.read(substitutionPlanProvider.notifier).clearInMemory();
      _ref.read(timetableSwitchVersionProvider.notifier).state++;
    }

    return true;
  }
}

/// 시간표 레지스트리 Provider
final timetableRegistryProvider = StateNotifierProvider<
  TimetableRegistryNotifier,
  AsyncValue<TimetableRegistry>
>((ref) {
  return TimetableRegistryNotifier(ref);
});

/// 현재 활성 시간표 항목 Provider (없으면 null)
final activeTimetableEntryProvider = Provider<TimetableRegistryEntry?>((ref) {
  final async = ref.watch(timetableRegistryProvider);
  return async.valueOrNull?.activeEntry;
});

/// 활성 시간표에 설정된 교사명 (미지정이면 빈 문자열)
///
/// 교체 화면 행 하이라이트·개인 시간표 기본 교사·계획서 교사명의 단일 출처입니다.
/// 전역 설정(defaultTeacherName)을 대체합니다.
final activeTeacherNameProvider = Provider<String>((ref) {
  return ref.watch(activeTimetableEntryProvider)?.teacherName?.trim() ?? '';
});

/// 활성 시간표의 학교명 (미입력이면 빈 문자열)
final activeSchoolNameProvider = Provider<String>((ref) {
  return ref.watch(activeTimetableEntryProvider)?.schoolName ?? '';
});

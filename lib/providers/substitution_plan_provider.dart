import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import '../services/substitution_plan_storage_service.dart';

/// 결보강 계획서 상태
///
/// §10.10: 결강일·교체일(`savedDates`)은 여기서 제거됐다 —
/// `ExchangeHistoryItem.absenceDate`/`substitutionDate`가 유일한 진실원본이며
/// `ExchangeHistoryService`가 직접 저장·로드한다(`exchange_list_{timetableId}.json`).
/// 이 상태는 그 진실원본으로 표현할 수 없는 값(보강 과목 선택)만 남는다.
class SubstitutionPlanState {
  // 사용자가 선택한 보강 과목 저장 (교체 항목별)
  // 키: exchangeId, 값: 과목명
  final Map<String, String> savedSupplementSubjects;

  // 현재 선택된 날짜 범위 (필요시)
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;

  const SubstitutionPlanState({
    this.savedSupplementSubjects = const {},
    this.selectedStartDate,
    this.selectedEndDate,
  });

  SubstitutionPlanState copyWith({
    Map<String, String>? savedSupplementSubjects,
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
  }) {
    return SubstitutionPlanState(
      savedSupplementSubjects:
          savedSupplementSubjects ?? this.savedSupplementSubjects,
      selectedStartDate: selectedStartDate ?? this.selectedStartDate,
      selectedEndDate: selectedEndDate ?? this.selectedEndDate,
    );
  }

  /// JSON 직렬화 (저장용)
  ///
  /// SubstitutionPlanState를 Map 형태로 변환하여 JSON 파일에 저장할 수 있도록 합니다.
  Map<String, dynamic> toJson() {
    return {
      'savedSupplementSubjects': savedSupplementSubjects,
      'selectedStartDate': selectedStartDate?.toIso8601String(),
      'selectedEndDate': selectedEndDate?.toIso8601String(),
    };
  }

  /// JSON 역직렬화 (로드용)
  ///
  /// JSON 파일에서 읽어온 Map 데이터를 SubstitutionPlanState 객체로 변환합니다.
  /// 구 형식 파일에 남아있는 `savedDates` 키는 무시한다(§10.10 — 더 이상 쓰지 않음).
  factory SubstitutionPlanState.fromJson(Map<String, dynamic> json) {
    // savedSupplementSubjects 변환 (null 안전성 처리)
    final savedSupplementSubjectsJson =
        json['savedSupplementSubjects'] as Map<String, dynamic>?;
    final savedSupplementSubjects =
        savedSupplementSubjectsJson != null
            ? Map<String, String>.from(
              savedSupplementSubjectsJson.map(
                (key, value) => MapEntry(key, value.toString()),
              ),
            )
            : <String, String>{};

    // 날짜 범위 변환 (null 안전성 처리)
    final selectedStartDateStr = json['selectedStartDate'] as String?;
    final selectedEndDateStr = json['selectedEndDate'] as String?;
    final selectedStartDate =
        selectedStartDateStr != null
            ? DateTime.tryParse(selectedStartDateStr)
            : null;
    final selectedEndDate =
        selectedEndDateStr != null
            ? DateTime.tryParse(selectedEndDateStr)
            : null;

    return SubstitutionPlanState(
      savedSupplementSubjects: savedSupplementSubjects,
      selectedStartDate: selectedStartDate,
      selectedEndDate: selectedEndDate,
    );
  }
}

/// 결보강 계획서 상태 관리 Notifier
class SubstitutionPlanNotifier extends StateNotifier<SubstitutionPlanState> {
  // 저장 서비스 인스턴스
  final SubstitutionPlanStorageService _storageService =
      SubstitutionPlanStorageService();
  Future<void> _storageQueue = Future<void>.value();

  /// 현재 스코프 시간표 ID
  ///
  /// null이면 레거시 전역 파일을 사용합니다.
  /// 활성 시간표 전환 시 레지스트리 Provider에서 설정하고 재로드합니다.
  String? _timetableId;

  SubstitutionPlanNotifier() : super(const SubstitutionPlanState());

  /// 스코프 시간표 설정 후 데이터 재로드
  Future<void> setTimetableScope(String? timetableId) async {
    _timetableId = timetableId;
    await loadFromStorage();
  }

  /// 스코프 시간표만 설정 (재로드 없음 — 앱 시작 시 화면 로드 흐름이 사용)
  void setTimetableScopeWithoutReload(String? timetableId) {
    _timetableId = timetableId;
  }

  /// 메모리 상태만 초기화 (파일은 건드리지 않음)
  ///
  /// 활성 시간표가 모두 삭제된 경우 레거시 파일의 고스트 데이터가
  /// 로드되지 않도록 스코프 해제와 함께 사용합니다.
  void clearInMemory() {
    state = const SubstitutionPlanState();
  }

  /// 예약된 자동 저장을 마친 뒤 특정 시간표의 저장 파일을 삭제합니다.
  Future<void> clearStoredDataForTimetable(String timetableId) {
    _storageQueue = _storageQueue.then((_) async {
      try {
        await _storageService.clearSubstitutionPlanData(
          timetableId: timetableId,
        );
      } catch (e) {
        AppLogger.error('결보강 계획서 저장 데이터 삭제 실패: $e', e);
      }
    });
    return _storageQueue;
  }

  /// 보강 과목 저장 (자동 저장 포함)
  void saveSupplementSubject(String exchangeId, String subject) {
    final newSaved = Map<String, String>.from(state.savedSupplementSubjects);
    newSaved[exchangeId] = subject;
    AppLogger.exchangeDebug('보강 과목 저장 (전역): $exchangeId = $subject');
    state = state.copyWith(savedSupplementSubjects: newSaved);

    // 자동 저장
    _saveToStorage();
  }

  /// 보강 과목 복원
  String getSupplementSubject(String exchangeId) {
    final subject = state.savedSupplementSubjects[exchangeId] ?? '';
    if (subject.isNotEmpty) {
      AppLogger.exchangeDebug('보강 과목 복원 (전역): $exchangeId = $subject');
    }
    return subject;
  }

  /// 특정 교체 식별자의 보강 과목 삭제 (자동 저장 포함)
  void clearSupplementSubject(String exchangeId) {
    final newSaved = Map<String, String>.from(state.savedSupplementSubjects);
    newSaved.remove(exchangeId);
    AppLogger.exchangeDebug('보강 과목 삭제 (전역): $exchangeId');
    state = state.copyWith(savedSupplementSubjects: newSaved);

    // 자동 저장
    _saveToStorage();
  }

  /// 모든 보강 과목 초기화 (자동 저장 포함)
  void clearAllSupplementSubjects() {
    AppLogger.exchangeDebug('모든 보강 과목 초기화 (전역)');
    state = state.copyWith(savedSupplementSubjects: const {});

    // 자동 저장
    _saveToStorage();
  }

  /// 결보강 전체 삭제 되돌리기 — 지워졌던 보강 과목을 다시 넣는다.
  /// 그 사이 새로 정한 과목은 덮지 않는다 (자동 저장 포함).
  void restoreSupplementSubjects(Map<String, String> subjects) {
    if (subjects.isEmpty) return;
    final newSaved = Map<String, String>.from(state.savedSupplementSubjects);
    subjects.forEach((key, value) => newSaved.putIfAbsent(key, () => value));
    state = state.copyWith(savedSupplementSubjects: newSaved);
    _saveToStorage();
  }

  /// 결보강 전체 삭제 다시 실행 — 복원했던 보강 과목을 다시 지운다 (자동 저장 포함).
  void removeSupplementSubjects(Iterable<String> exchangeIds) {
    final newSaved = Map<String, String>.from(state.savedSupplementSubjects);
    var changed = false;
    for (final id in exchangeIds) {
      changed = newSaved.remove(id) != null || changed;
    }
    if (!changed) return;
    state = state.copyWith(savedSupplementSubjects: newSaved);
    _saveToStorage();
  }

  /// 날짜 범위 설정
  void setDateRange(DateTime? startDate, DateTime? endDate) {
    state = state.copyWith(
      selectedStartDate: startDate,
      selectedEndDate: endDate,
    );
  }

  /// 상태를 JSON 파일에 자동 저장 (내부 메서드)
  ///
  /// 보강 과목이 변경될 때마다 자동으로 호출됩니다.
  /// 비동기로 실행하여 UI 블로킹을 방지합니다.
  void _saveToStorage() {
    final stateSnapshot = state;
    final timetableIdSnapshot = _timetableId;
    _storageQueue = _storageQueue.then((_) async {
      try {
        await _storageService.saveSubstitutionPlanData(
          stateSnapshot,
          timetableId: timetableIdSnapshot,
        );
      } catch (e) {
        AppLogger.error('결보강 계획서 날짜 정보 자동 저장 실패: $e', e);
      }
    });
  }

  /// 저장된 정보를 JSON 파일에서 로드
  ///
  /// 프로그램 시작 시 호출되어 저장된 보강 과목 정보를 복원합니다.
  Future<void> loadFromStorage() async {
    try {
      final requestedTimetableId = _timetableId;
      await _storageQueue;

      final loadedState = await _storageService.loadSubstitutionPlanData(
        timetableId: requestedTimetableId,
      );

      if (_timetableId != requestedTimetableId) {
        return;
      }

      state = loadedState ?? const SubstitutionPlanState();
      AppLogger.info(
        '결보강 계획서 정보 로드 완료: ${state.savedSupplementSubjects.length}개 보강 과목',
      );
    } catch (e) {
      AppLogger.error('결보강 계획서 정보 로드 실패: $e', e);
    }
  }
}

/// 결보강 계획서 Provider
final substitutionPlanProvider =
    StateNotifierProvider<SubstitutionPlanNotifier, SubstitutionPlanState>((
      ref,
    ) {
      return SubstitutionPlanNotifier();
    });

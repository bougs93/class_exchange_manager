import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import '../services/substitution_plan_storage_service.dart';

/// 결보강 계획서 날짜 관리 상태
class SubstitutionPlanState {
  // 사용자가 입력한 날짜 정보를 저장하는 맵
  // 키: "교체식별자_컬럼명" (예: "문유란_월5_absenceDate"), 값: 날짜 문자열
  final Map<String, String> savedDates;
  // 사용자가 선택한 보강 과목 저장 (교체 항목별)
  // 키: exchangeId, 값: 과목명
  final Map<String, String> savedSupplementSubjects;

  // 현재 선택된 날짜 범위 (필요시)
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;

  const SubstitutionPlanState({
    this.savedDates = const {},
    this.savedSupplementSubjects = const {},
    this.selectedStartDate,
    this.selectedEndDate,
  });

  SubstitutionPlanState copyWith({
    Map<String, String>? savedDates,
    Map<String, String>? savedSupplementSubjects,
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
  }) {
    return SubstitutionPlanState(
      savedDates: savedDates ?? this.savedDates,
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
      'savedDates': savedDates,
      'savedSupplementSubjects': savedSupplementSubjects,
      'selectedStartDate': selectedStartDate?.toIso8601String(),
      'selectedEndDate': selectedEndDate?.toIso8601String(),
    };
  }

  /// JSON 역직렬화 (로드용)
  ///
  /// JSON 파일에서 읽어온 Map 데이터를 SubstitutionPlanState 객체로 변환합니다.
  factory SubstitutionPlanState.fromJson(Map<String, dynamic> json) {
    // savedDates 변환 (null 안전성 처리)
    final savedDatesJson = json['savedDates'] as Map<String, dynamic>?;
    final savedDates =
        savedDatesJson != null
            ? Map<String, String>.from(
              savedDatesJson.map(
                (key, value) => MapEntry(key, value.toString()),
              ),
            )
            : <String, String>{};

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
      savedDates: savedDates,
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

  /// 날짜 정보 저장 (자동 저장 포함)
  void saveDate(String exchangeId, String columnName, String date) {
    final key = '${exchangeId}_$columnName';
    final newSavedDates = Map<String, String>.from(state.savedDates);
    newSavedDates[key] = date;

    AppLogger.exchangeDebug('날짜 저장 (전역): $key = $date');

    state = state.copyWith(savedDates: newSavedDates);

    // 자동 저장 (비동기로 실행하여 UI 블로킹 방지)
    _saveToStorage();
  }

  /// 저장된 날짜 정보 복원
  String getSavedDate(String exchangeId, String columnName) {
    final key = '${exchangeId}_$columnName';
    final date = state.savedDates[key] ?? '';

    if (date.isNotEmpty) {
      AppLogger.exchangeDebug('날짜 복원 (전역): $key = $date');
    }

    return date;
  }

  /// 특정 교체 식별자의 모든 날짜 정보 삭제 (자동 저장 포함)
  void clearExchangeDates(String exchangeId) {
    final newSavedDates = Map<String, String>.from(state.savedDates);
    newSavedDates.removeWhere((key, value) => key.startsWith('${exchangeId}_'));

    AppLogger.exchangeDebug('교체 식별자 날짜 삭제 (전역): $exchangeId');

    state = state.copyWith(savedDates: newSavedDates);

    // 자동 저장
    _saveToStorage();
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

  /// 모든 날짜 정보 및 보강 과목 초기화 (자동 저장 포함)
  void clearAllDates() {
    AppLogger.exchangeDebug('모든 날짜 정보 및 보강 과목 초기화 (전역)');
    state = const SubstitutionPlanState();

    // 자동 저장
    _saveToStorage();
  }

  /// 날짜 범위 설정
  void setDateRange(DateTime? startDate, DateTime? endDate) {
    state = state.copyWith(
      selectedStartDate: startDate,
      selectedEndDate: endDate,
    );
  }

  /// 저장된 날짜 개수 반환
  int get savedDatesCount => state.savedDates.length;

  /// 특정 교체 식별자의 저장된 날짜 개수 반환
  int getExchangeDatesCount(String exchangeId) {
    return state.savedDates.keys
        .where((key) => key.startsWith('${exchangeId}_'))
        .length;
  }

  /// 상태를 JSON 파일에 자동 저장 (내부 메서드)
  ///
  /// 날짜나 보강 과목이 변경될 때마다 자동으로 호출됩니다.
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

  /// 저장된 날짜 정보를 JSON 파일에서 로드
  ///
  /// 프로그램 시작 시 호출되어 저장된 날짜 정보를 복원합니다.
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
        '결보강 계획서 날짜 정보 로드 완료: ${state.savedDates.length}개 날짜, ${state.savedSupplementSubjects.length}개 보강 과목',
      );
    } catch (e) {
      AppLogger.error('결보강 계획서 날짜 정보 로드 실패: $e', e);
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

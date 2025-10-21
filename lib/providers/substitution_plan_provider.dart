import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

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
      savedSupplementSubjects: savedSupplementSubjects ?? this.savedSupplementSubjects,
      selectedStartDate: selectedStartDate ?? this.selectedStartDate,
      selectedEndDate: selectedEndDate ?? this.selectedEndDate,
    );
  }
}

/// 결보강 계획서 상태 관리 Notifier
class SubstitutionPlanNotifier extends StateNotifier<SubstitutionPlanState> {
  SubstitutionPlanNotifier() : super(const SubstitutionPlanState());

  /// 날짜 정보 저장
  void saveDate(String exchangeId, String columnName, String date) {
    final key = '${exchangeId}_$columnName';
    final newSavedDates = Map<String, String>.from(state.savedDates);
    newSavedDates[key] = date;
    
    AppLogger.exchangeDebug('날짜 저장 (전역): $key = $date');
    
    state = state.copyWith(savedDates: newSavedDates);
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

  /// 특정 교체 식별자의 모든 날짜 정보 삭제
  void clearExchangeDates(String exchangeId) {
    final newSavedDates = Map<String, String>.from(state.savedDates);
    newSavedDates.removeWhere((key, value) => key.startsWith('${exchangeId}_'));
    
    AppLogger.exchangeDebug('교체 식별자 날짜 삭제 (전역): $exchangeId');
    
    state = state.copyWith(savedDates: newSavedDates);
  }

  /// 보강 과목 저장
  void saveSupplementSubject(String exchangeId, String subject) {
    final newSaved = Map<String, String>.from(state.savedSupplementSubjects);
    newSaved[exchangeId] = subject;
    AppLogger.exchangeDebug('보강 과목 저장 (전역): $exchangeId = $subject');
    state = state.copyWith(savedSupplementSubjects: newSaved);
  }

  /// 보강 과목 복원
  String getSupplementSubject(String exchangeId) {
    final subject = state.savedSupplementSubjects[exchangeId] ?? '';
    if (subject.isNotEmpty) {
      AppLogger.exchangeDebug('보강 과목 복원 (전역): $exchangeId = $subject');
    }
    return subject;
  }

  /// 특정 교체 식별자의 보강 과목 삭제
  void clearSupplementSubject(String exchangeId) {
    final newSaved = Map<String, String>.from(state.savedSupplementSubjects);
    newSaved.remove(exchangeId);
    AppLogger.exchangeDebug('보강 과목 삭제 (전역): $exchangeId');
    state = state.copyWith(savedSupplementSubjects: newSaved);
  }

  /// 모든 날짜 정보 초기화
  void clearAllDates() {
    AppLogger.exchangeDebug('모든 날짜 정보 초기화 (전역)');
    state = const SubstitutionPlanState();
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
    return state.savedDates.keys.where((key) => key.startsWith('${exchangeId}_')).length;
  }
}

/// 결보강 계획서 Provider
final substitutionPlanProvider = StateNotifierProvider<SubstitutionPlanNotifier, SubstitutionPlanState>((ref) {
  return SubstitutionPlanNotifier();
});

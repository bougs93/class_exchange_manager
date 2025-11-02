import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/week_date_calculator.dart';
import '../providers/exchange_screen_provider.dart';
import '../services/excel_service.dart';

/// 개인 시간표 상태 클래스
class PersonalScheduleState {
  /// 현재 표시 중인 주의 월요일 날짜
  final DateTime currentWeekMonday;

  /// 로딩 상태
  final bool isLoading;

  /// 오류 메시지
  final String? errorMessage;

  /// 설정에서 저장된 교사명
  final String? teacherName;

  const PersonalScheduleState({
    required this.currentWeekMonday,
    this.isLoading = false,
    this.errorMessage,
    this.teacherName,
  });

  PersonalScheduleState copyWith({
    DateTime? currentWeekMonday,
    bool? isLoading,
    String? errorMessage,
    String? teacherName,
  }) {
    return PersonalScheduleState(
      currentWeekMonday: currentWeekMonday ?? this.currentWeekMonday,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      teacherName: teacherName ?? this.teacherName,
    );
  }

  /// 현재 주의 날짜 리스트 가져오기
  List<DateTime> get weekDates => WeekDateCalculator.getWeekDates(currentWeekMonday);
}

/// 개인 시간표 상태 관리 Notifier
class PersonalScheduleNotifier extends StateNotifier<PersonalScheduleState> {
  PersonalScheduleNotifier() : super(
    PersonalScheduleState(
      currentWeekMonday: WeekDateCalculator.getThisWeekMonday(),
    ),
  );

  /// 교사명 설정
  void setTeacherName(String? teacherName) {
    state = state.copyWith(teacherName: teacherName);
  }

  /// 이전 주로 이동
  void moveToPreviousWeek() {
    final newWeekMonday = WeekDateCalculator.moveWeek(
      state.currentWeekMonday,
      -1,
    );
    state = state.copyWith(currentWeekMonday: newWeekMonday);
  }

  /// 다음 주로 이동
  void moveToNextWeek() {
    final newWeekMonday = WeekDateCalculator.moveWeek(
      state.currentWeekMonday,
      1,
    );
    state = state.copyWith(currentWeekMonday: newWeekMonday);
  }

  /// 특정 주로 이동
  void moveToWeek(DateTime weekMonday) {
    state = state.copyWith(currentWeekMonday: weekMonday);
  }

  /// 오늘 주로 이동
  void moveToThisWeek() {
    state = state.copyWith(
      currentWeekMonday: WeekDateCalculator.getThisWeekMonday(),
    );
  }
}

/// 개인 시간표 상태 Provider
final personalScheduleProvider =
    StateNotifierProvider<PersonalScheduleNotifier, PersonalScheduleState>(
  (ref) => PersonalScheduleNotifier(),
);

/// 개인 시간표 데이터 Provider
/// 
/// ExchangeScreenProvider의 timetableData를 기반으로 특정 교사의 시간표를 제공합니다.
final personalTimetableDataProvider = Provider<TimetableData?>((ref) {
  return ref.watch(exchangeScreenProvider).timetableData;
});


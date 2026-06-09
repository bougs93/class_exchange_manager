import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/screens/personal_schedule_screen/exchange_week_collector.dart';
import '../utils/week_date_calculator.dart';
import '../providers/exchange_screen_provider.dart';
import '../providers/substitution_plan_viewmodel.dart';
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
  List<DateTime> get weekDates =>
      WeekDateCalculator.getWeekDates(currentWeekMonday);
}

/// 개인 시간표 상태 관리 Notifier
///
/// 결보강 planData의 결강일·교체일이 바뀌면 교체 주를 자동 맞춥니다.
/// - 교체 주 있음 → 첫 번째(가장 이른 주)
/// - 교체 주 없음 → 이번 주
class PersonalScheduleNotifier extends StateNotifier<PersonalScheduleState> {
  PersonalScheduleNotifier(this._ref)
    : super(
        PersonalScheduleState(
          currentWeekMonday: WeekDateCalculator.getThisWeekMonday(),
        ),
      ) {
    _ref.listen<String>(
      substitutionPlanViewModelProvider.select(
        (vm) => ExchangeWeekCollector.planDatesFingerprint(vm.planData),
      ),
      (previous, next) {
        if (previous == null || previous == next) return;
        _syncWeekFromPlanData();
      },
    );
  }

  final Ref _ref;

  /// planData 기준으로 교체 주 동기화
  void _syncWeekFromPlanData() {
    final planData = _ref.read(substitutionPlanViewModelProvider).planData;
    final target = ExchangeWeekCollector.defaultWeekMonday(
      planData,
      referenceDate: state.currentWeekMonday,
    );
    if (ExchangeWeekCollector.isSameWeek(target, state.currentWeekMonday)) {
      return;
    }
    state = state.copyWith(currentWeekMonday: target);
  }

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
      (ref) => PersonalScheduleNotifier(ref),
    );

/// 개인 시간표 데이터 Provider
///
/// ExchangeScreenProvider의 timetableData를 기반으로 특정 교사의 시간표를 제공합니다.
final personalTimetableDataProvider = Provider<TimetableData?>((ref) {
  return ref.watch(exchangeScreenProvider).timetableData;
});

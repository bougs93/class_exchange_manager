import '../models/school_semester.dart';

/// 어떤 주(월요일 기준)가 학기 범위와 어떤 관계인지 (S4.1)
///
/// 순수 판정 로직만 담당한다 — 화면에 아직 연결하지 않는다(S4.2에서 연결 예정).
enum WeekSemesterStatus {
  /// 학기 범위와 겹친다(부분 겹침 포함)
  withinRange,

  /// 학기 시작일보다 완전히 앞선 주
  beforeRange,

  /// 학기 종료일보다 완전히 뒤인 주
  afterRange,

  /// 학기 범위를 알 수 없다(예: 이 시간표에 날짜 기반 데이터가 없음)
  unknown,
}

/// [WeekSemesterStatus] 판정기
class WeekSemesterStatusChecker {
  const WeekSemesterStatusChecker._();

  /// [weekMonday]로 시작하는 한 주(월~금, 5일)가 [semester] 범위와 어떤
  /// 관계인지 판정한다.
  ///
  /// [semester]가 null이면(날짜 기반 데이터가 없는 시간표) 항상 [WeekSemesterStatus.unknown]을
  /// 반환한다 — 이 경우 범위를 알 수 없으므로 "범위 밖"이라고 단정하지 않는다.
  static WeekSemesterStatus check({
    required DateTime weekMonday,
    required SchoolSemester? semester,
  }) {
    if (semester == null) return WeekSemesterStatus.unknown;

    final monday = _dateOnly(weekMonday);
    final friday = monday.add(const Duration(days: 4));

    if (friday.isBefore(semester.startDate)) {
      return WeekSemesterStatus.beforeRange;
    }
    if (monday.isAfter(semester.endDate)) {
      return WeekSemesterStatus.afterRange;
    }
    return WeekSemesterStatus.withinRange;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

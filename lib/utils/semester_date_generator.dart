import '../models/school_semester.dart';
import 'day_utils.dart';

/// 학기 범위 안의 날짜 목록을 생성하는 순수 함수 모음 (S1)
///
/// UI·저장소와 연결되지 않은 순수 로직이다. 엑셀에서 읽은 "요일" 정보를
/// 실제 날짜별 수업으로 펼칠 때 사용할 날짜 목록 계산만 담당한다.
class SemesterDateGenerator {
  const SemesterDateGenerator._();

  /// 학기 범위 안에서 특정 요일(Dart [DateTime.weekday] 기준, 1=월 ~ 7=일)에
  /// 해당하는 날짜를 시작일→종료일 순서로 모두 반환한다.
  static List<DateTime> datesForWeekday(SchoolSemester semester, int weekday) {
    assert(weekday >= 1 && weekday <= 7, '요일 값은 1(월)~7(일)이어야 한다');

    final dates = <DateTime>[];
    // 학기 시작일 이후(포함) 첫 해당 요일까지 이동
    var offset = (weekday - semester.startDate.weekday) % 7;
    if (offset < 0) offset += 7;
    var current = semester.startDate.add(Duration(days: offset));

    while (!current.isAfter(semester.endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 7));
    }
    return dates;
  }

  /// 요일명('월'~'금')으로 [datesForWeekday]를 호출하는 편의 메서드.
  ///
  /// 이 앱의 시간표는 평일(월~금)만 다루므로 [DayUtils.getDayNumber]의
  /// 매핑 범위와 동일하다. 토·일은 지원하지 않는다.
  static List<DateTime> datesForDayName(
    SchoolSemester semester,
    String dayName,
  ) {
    return datesForWeekday(semester, DayUtils.getDayNumber(dayName));
  }

  /// 학기 범위 안의 모든 날짜를 시작일→종료일 순서로 반환한다 (요일 무관).
  ///
  /// 학기 전체 운영일 캘린더(휴업일 표시 등)를 만들 때 사용할 기반 목록이다.
  static List<DateTime> allDates(SchoolSemester semester) {
    final dates = <DateTime>[];
    var current = semester.startDate;
    while (!current.isAfter(semester.endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }
}

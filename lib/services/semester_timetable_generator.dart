import '../models/lesson.dart';
import '../models/school_semester.dart';
import '../models/time_slot.dart';
import '../utils/semester_date_generator.dart';

/// 엑셀에서 파싱한 요일 기준 시간표를, 학기 범위 안의 실제 날짜별 수업
/// ([Lesson]) 목록으로 펼치는 순수 함수 (S3).
///
/// UI·DB에 의존하지 않는다 — 호출부가 결과를 `TimetableRepository`에 저장할지
/// 말지 결정한다. 각 날짜의 [Lesson]은 독립된 새 ID를 가지며, 원본 [TimeSlot]
/// 객체는 전혀 변경하지 않는다.
class SemesterTimetableGenerator {
  const SemesterTimetableGenerator._();

  /// [timeSlots]의 각 칸을 [semester] 범위 안의 실제 날짜별 [Lesson]으로 펼친다.
  ///
  /// 요일·교시·교사 중 하나라도 없는 칸(`TimeSlot`의 필드가 null)은 날짜별
  /// 수업으로 펼칠 좌표가 없으므로 건너뛴다. 토·일(6, 7)도 건너뛴다 — 이 앱의
  /// 시간표는 평일만 다룬다.
  static List<Lesson> generate({
    required String timetableId,
    required List<TimeSlot> timeSlots,
    required SchoolSemester semester,
  }) {
    final lessons = <Lesson>[];

    for (final slot in timeSlots) {
      final day = slot.dayOfWeek;
      final period = slot.period;
      final teacher = slot.teacher;
      if (day == null || period == null || teacher == null) continue;
      if (day < DateTime.monday || day > DateTime.friday) continue;

      final dates = SemesterDateGenerator.datesForWeekday(semester, day);
      for (final date in dates) {
        lessons.add(
          Lesson(
            id: Lesson.generateId(),
            timetableId: timetableId,
            date: date,
            period: period,
            teacher: teacher,
            subject: slot.subject,
            className: slot.className,
            isExchangeable: slot.isExchangeable,
            exchangeReason: slot.exchangeReason,
          ),
        );
      }
    }

    return lessons;
  }
}

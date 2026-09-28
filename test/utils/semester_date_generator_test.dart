import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/utils/semester_date_generator.dart';

void main() {
  group('SemesterDateGenerator.datesForDayName', () {
    test('1학기 모든 월요일을 시작일부터 종료일까지 반환한다', () {
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 1);
      final mondays = SemesterDateGenerator.datesForDayName(semester, '월');

      // 2026-03-01은 일요일 → 첫 월요일은 2026-03-02
      expect(mondays.first, DateTime(2026, 3, 2));
      expect(mondays.last, DateTime(2026, 7, 27));
      // 모두 실제 월요일인지, 7일 간격으로 정렬되어 있는지 확인
      for (final date in mondays) {
        expect(date.weekday, DateTime.monday);
      }
      for (var i = 1; i < mondays.length; i++) {
        expect(mondays[i].difference(mondays[i - 1]).inDays, 7);
      }
    });

    test('2학기 연도 경계를 넘는 금요일도 정상 생성된다', () {
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);
      final fridays = SemesterDateGenerator.datesForDayName(semester, '금');

      expect(fridays, isNotEmpty);
      expect(fridays.first.isAfter(DateTime(2026, 7, 31)), isTrue);
      expect(fridays.last.isBefore(DateTime(2027, 2, 1)), isTrue);
      for (final date in fridays) {
        expect(date.weekday, DateTime.friday);
        expect(semester.contains(date), isTrue);
      }
    });

    test('학기 시작일 자체가 해당 요일이면 첫 값으로 포함된다', () {
      // 2026-03-02(월)를 시작일로 하는 커스텀 학기
      final semester = SchoolSemester(
        schoolYear: 2026,
        semester: 1,
        startDate: DateTime(2026, 3, 2),
        endDate: DateTime(2026, 3, 9),
      );

      final mondays = SemesterDateGenerator.datesForDayName(semester, '월');
      expect(mondays, [DateTime(2026, 3, 2), DateTime(2026, 3, 9)]);
    });
  });

  group('SemesterDateGenerator — 같은 요일의 다른 주는 서로 독립이다', () {
    test('생성된 날짜 목록에 중복이 없고 각기 다른 날짜다', () {
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 1);
      final mondays = SemesterDateGenerator.datesForDayName(semester, '월');

      expect(mondays.toSet().length, mondays.length);
    });
  });

  group('SemesterDateGenerator.allDates', () {
    test('시작일부터 종료일까지 하루 단위로 빠짐없이 생성한다', () {
      final semester = SchoolSemester(
        schoolYear: 2026,
        semester: 1,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 5),
      );

      final dates = SemesterDateGenerator.allDates(semester);

      expect(dates, [
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 2),
        DateTime(2026, 3, 3),
        DateTime(2026, 3, 4),
        DateTime(2026, 3, 5),
      ]);
    });

    test('학기 밖 날짜는 생성하지 않는다 (마지막 값이 종료일을 넘지 않음)', () {
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);
      final dates = SemesterDateGenerator.allDates(semester);

      expect(dates.last, DateTime(2027, 1, 31));
      expect(dates.any((d) => d.isAfter(DateTime(2027, 1, 31))), isFalse);
    });
  });
}

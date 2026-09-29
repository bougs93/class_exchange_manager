import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/utils/week_semester_status.dart';

void main() {
  group('WeekSemesterStatusChecker.check', () {
    final semester = SchoolSemester(
      schoolYear: 2026,
      semester: 2,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2027, 1, 31),
    );

    test('학기가 없으면 unknown이다', () {
      final status = WeekSemesterStatusChecker.check(
        weekMonday: DateTime(2026, 9, 7),
        semester: null,
      );
      expect(status, WeekSemesterStatus.unknown);
    });

    test('학기 범위 안의 주는 withinRange다', () {
      final status = WeekSemesterStatusChecker.check(
        weekMonday: DateTime(2026, 9, 7),
        semester: semester,
      );
      expect(status, WeekSemesterStatus.withinRange);
    });

    test('학기 시작일이 속한 주는 withinRange다(월~금이 시작일과 겹침)', () {
      // 2026-08-01은 토요일 — 그 주의 월요일(07-27)은 금요일(07-31)까지도
      // 시작일(08-01) 이전이라 beforeRange여야 한다.
      final status = WeekSemesterStatusChecker.check(
        weekMonday: DateTime(2026, 7, 27),
        semester: semester,
      );
      expect(status, WeekSemesterStatus.beforeRange);
    });

    test('학기 시작 전 주는 beforeRange다', () {
      final status = WeekSemesterStatusChecker.check(
        weekMonday: DateTime(2026, 7, 20),
        semester: semester,
      );
      expect(status, WeekSemesterStatus.beforeRange);
    });

    test('학기 종료 후 주는 afterRange다', () {
      final status = WeekSemesterStatusChecker.check(
        weekMonday: DateTime(2027, 2, 2),
        semester: semester,
      );
      expect(status, WeekSemesterStatus.afterRange);
    });

    test('종료일(01-31, 토요일)이 속한 주는 withinRange다 — 월요일이 종료일 이전', () {
      final status = WeekSemesterStatusChecker.check(
        weekMonday: DateTime(2027, 1, 25),
        semester: semester,
      );
      expect(status, WeekSemesterStatus.withinRange);
    });

    test('경계 바로 다음 주(월요일이 종료일 다음날)는 afterRange다', () {
      final status = WeekSemesterStatusChecker.check(
        weekMonday: DateTime(2027, 2, 1),
        semester: semester,
      );
      expect(status, WeekSemesterStatus.afterRange);
    });
  });
}

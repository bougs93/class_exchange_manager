import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/school_semester.dart';

void main() {
  group('SchoolSemester.defaultFor', () {
    test('1학기 기본값은 3/1 ~ 7/31이다', () {
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 1);

      expect(semester.startDate, DateTime(2026, 3, 1));
      expect(semester.endDate, DateTime(2026, 7, 31));
    });

    test('2학기 기본값은 8/1 ~ 다음 연도 1/31이다 (연도 경계)', () {
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);

      expect(semester.startDate, DateTime(2026, 8, 1));
      expect(semester.endDate, DateTime(2027, 1, 31));
    });

    test('학년도는 시작 연도로 표시한다', () {
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);

      expect(semester.schoolYear, 2026);
    });
  });

  group('SchoolSemester 생성자', () {
    test('시각이 있는 DateTime을 넣어도 날짜만 남긴다 (타임존 변환으로 하루가 바뀌지 않음)', () {
      final semester = SchoolSemester(
        schoolYear: 2026,
        semester: 1,
        startDate: DateTime(2026, 3, 1, 23, 59, 59),
        endDate: DateTime(2026, 7, 31, 0, 0, 1),
      );

      expect(semester.startDate, DateTime(2026, 3, 1));
      expect(semester.endDate, DateTime(2026, 7, 31));
    });

    test('semester가 1도 2도 아니면 assert에 걸린다', () {
      expect(
        () => SchoolSemester(
          schoolYear: 2026,
          semester: 3,
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 7, 31),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('종료일이 시작일보다 앞서면 assert에 걸린다', () {
      expect(
        () => SchoolSemester(
          schoolYear: 2026,
          semester: 1,
          startDate: DateTime(2026, 7, 31),
          endDate: DateTime(2026, 3, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('SchoolSemester.contains', () {
    final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 1);

    test('시작일·종료일을 포함한다 (양 끝 포함)', () {
      expect(semester.contains(DateTime(2026, 3, 1)), isTrue);
      expect(semester.contains(DateTime(2026, 7, 31)), isTrue);
    });

    test('범위 밖 날짜는 false다', () {
      expect(semester.contains(DateTime(2026, 2, 28)), isFalse);
      expect(semester.contains(DateTime(2026, 8, 1)), isFalse);
    });
  });

  group('SchoolSemester 동일성', () {
    test('같은 값이면 ==가 true다', () {
      final a = SchoolSemester.defaultFor(schoolYear: 2026, semester: 1);
      final b = SchoolSemester.defaultFor(schoolYear: 2026, semester: 1);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('학기가 다르면 ==가 false다', () {
      final a = SchoolSemester.defaultFor(schoolYear: 2026, semester: 1);
      final b = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);

      expect(a, isNot(equals(b)));
    });
  });
}

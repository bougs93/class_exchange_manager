import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/utils/date_format_utils.dart';

void main() {
  group('DateFormatUtils.resolveMonthDayInRange (§10.6)', () {
    test('범위 안에 들어맞는 연도를 찾아 반환한다', () {
      final resolved = DateFormatUtils.resolveMonthDayInRange(
        '9.10',
        rangeStart: DateTime(2026, 9, 1),
        rangeEnd: DateTime(2027, 2, 28),
      );

      expect(resolved, DateTime(2026, 9, 10));
    });

    test('학기가 연말을 넘기면 종료 연도 쪽 해석도 시도한다', () {
      // 2학기: 2026-09-01 ~ 2027-02-28. "2.10"은 시작 연도(2026)로는 범위 밖,
      // 종료 연도(2027)로 해석해야 범위 안에 들어온다.
      final resolved = DateFormatUtils.resolveMonthDayInRange(
        '2.10',
        rangeStart: DateTime(2026, 9, 1),
        rangeEnd: DateTime(2027, 2, 28),
      );

      expect(resolved, DateTime(2027, 2, 10));
    });

    test('어느 연도로도 범위에 들어맞지 않으면 null을 반환한다', () {
      final resolved = DateFormatUtils.resolveMonthDayInRange(
        '7.15', // 학기 밖(여름방학)
        rangeStart: DateTime(2026, 9, 1),
        rangeEnd: DateTime(2027, 2, 28),
      );

      expect(resolved, isNull);
    });

    test('"월.일" 형식이 아니면 null을 반환한다 (이미 연.월.일이거나 형식 오류)', () {
      expect(
        DateFormatUtils.resolveMonthDayInRange(
          '2026.9.10',
          rangeStart: DateTime(2026, 9, 1),
          rangeEnd: DateTime(2027, 2, 28),
        ),
        isNull,
      );
    });
  });

  group('DateFormatUtils.normalizePlanDate — 학기 범위 우선 사용 (§10.6)', () {
    test('학기 범위가 주어지면 그 범위 안의 연도로 확정한다 (오늘 연도와 달라도)', () {
      // referenceDate(오늘)가 2030년이어도 학기 범위가 있으면 그쪽을 따른다
      final result = DateFormatUtils.normalizePlanDate(
        '9.10',
        referenceDate: DateTime(2030, 12, 25),
        semesterStart: DateTime(2026, 9, 1),
        semesterEnd: DateTime(2027, 2, 28),
      );

      expect(result, '2026.09.10');
    });

    test('학기 범위를 넘기지 않으면 기존처럼 referenceDate 연도를 사용한다', () {
      final result = DateFormatUtils.normalizePlanDate(
        '9.10',
        referenceDate: DateTime(2026, 1, 1),
      );

      expect(result, '2026.09.10');
    });

    test('학기 범위가 있어도 그 범위 밖 날짜면 referenceDate 방식으로 폴백한다', () {
      final result = DateFormatUtils.normalizePlanDate(
        '7.15', // 학기 범위 밖
        referenceDate: DateTime(2026, 1, 1),
        semesterStart: DateTime(2026, 9, 1),
        semesterEnd: DateTime(2027, 2, 28),
      );

      expect(result, '2026.07.15');
    });
  });
}

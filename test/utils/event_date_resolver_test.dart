import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/event_date_resolver.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/utils/week_date_calculator.dart';

OneToOneExchangePath _oneToOnePath({
  required String sourceDay,
  required int sourcePeriod,
  required String targetDay,
  required int targetPeriod,
}) {
  final targetSlot = TimeSlot(
    teacher: '박은선',
    subject: '기술가정',
    className: '3-8',
    dayOfWeek: 1,
    period: targetPeriod,
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: '정원길',
      day: sourceDay,
      period: sourcePeriod,
      className: '3-8',
      subjectName: '기술가정',
    ),
    targetNode: ExchangeNode(
      teacherName: '박은선',
      day: targetDay,
      period: targetPeriod,
      className: '3-8',
      subjectName: '기술가정',
    ),
    option: ExchangeOption(
      timeSlot: targetSlot,
      teacherName: '박은선',
      type: ExchangeType.sameClass,
      priority: 1,
      reason: 'test',
    ),
  );
}

CircularExchangePath _circularPath() {
  final a = ExchangeNode(
    teacherName: 'A',
    day: '월',
    period: 1,
    className: '1-1',
    subjectName: '수학',
  );
  final b = ExchangeNode(
    teacherName: 'B',
    day: '화',
    period: 2,
    className: '1-1',
    subjectName: '영어',
  );
  final c = ExchangeNode(
    teacherName: 'C',
    day: '수',
    period: 3,
    className: '1-1',
    subjectName: '과학',
  );
  return CircularExchangePath.fromNodes([a, b, c, a]);
}

void main() {
  group('resolveEventDates — 1:1(확정 쌍)', () {
    test('요일·교시가 일치하면 confirmedPair를 반환한다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _oneToOnePath(sourceDay: '수', sourcePeriod: 1, targetDay: '월', targetPeriod: 1),
        absenceDate: DateTime(2026, 10, 14), // 수
        substitutionDate: DateTime(2026, 10, 12), // 월
      );

      final r = resolveEventDates(item);

      final wed = r.forSlot(3, 1);
      expect(wed!.date, DateTime(2026, 10, 14));
      expect(wed.source, CellDateSource.confirmedPair);
      expect(wed.isConfirmed, isTrue);

      final mon = r.forSlot(1, 1);
      expect(mon!.date, DateTime(2026, 10, 12));
      expect(mon.source, CellDateSource.confirmedPair);

      // 교시는 무시하지 않는다 — 같은 요일이 다른 주에 걸칠 수 있기 때문이다
      // (same_weekday_cross_week_test.dart). 교체가 건드리지 않는 슬롯은 추정이다.
      expect(r.forSlot(3, 99)!.source, CellDateSource.estimated);
    });

    test('1:1 항목에 nodeDates를 억지로 넣어도(게이팅) 영향이 없다', () {
      final base = ExchangeHistoryItem.fromExchangePath(
        _oneToOnePath(sourceDay: '수', sourcePeriod: 1, targetDay: '월', targetPeriod: 1),
        absenceDate: DateTime(2026, 10, 14),
        substitutionDate: DateTime(2026, 10, 12),
      );
      // supportsNodeDates가 false이므로 copyWithNodeDate는 아무것도 안 바꾼다.
      final item = base.copyWithNodeDate('목', 5, DateTime(2026, 10, 15));

      final r = resolveEventDates(item);

      // 목요일(4)은 confirmedPair에도 nodeDates에도 없으므로 추정으로 폴백한다.
      final result = r.forSlot(4, 5);
      expect(result!.source, CellDateSource.estimated);
    });

    test('요일 불일치면 unsupported → 추정으로 폴백한다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _oneToOnePath(sourceDay: '수', sourcePeriod: 1, targetDay: '월', targetPeriod: 1),
        absenceDate: DateTime(2026, 10, 12), // 월요일 — sourceDay('수')와 불일치
        substitutionDate: DateTime(2026, 10, 14),
      );

      final r = resolveEventDates(item);
      final result = r.forSlot(3, 1); // 수요일 슬롯
      expect(result!.source, CellDateSource.estimated);
      expect(
        result.date,
        WeekDateCalculator.getWeekMonday(item.absenceDate).add(const Duration(days: 2)),
      );
    });
  });

  group('resolveEventDates — 순환(확정 노드 없음, OQ-1 추정)', () {
    test('모든 슬롯이 결강일이 속한 주로 추정된다 — 기존 _resolveDateByDay 수식과 동일', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _circularPath(),
        absenceDate: DateTime(2026, 8, 24), // 월요일
        substitutionDate: DateTime(2026, 8, 25),
      );

      final r = resolveEventDates(item);
      final weekMonday = DateTime(2026, 8, 24);

      for (var day = 1; day <= 5; day++) {
        final result = r.forSlot(day, 1);
        expect(result!.source, CellDateSource.estimated);
        expect(result.date, weekMonday.add(Duration(days: day - 1)));
      }
    });

    test('day가 1~5 밖이면 null이다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _circularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );

      final r = resolveEventDates(item);
      expect(r.forSlot(0, 1), isNull);
      expect(r.forSlot(6, 1), isNull);
      expect(r.forSlot(7, 1), isNull);
    });
  });

  group('resolveEventDates — 순환(부분 확정 노드)', () {
    test('확정된 슬롯만 confirmedNode, 나머지는 여전히 estimated다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _circularPath(),
        absenceDate: DateTime(2026, 8, 24), // 월요일
        substitutionDate: DateTime(2026, 8, 25),
      ).copyWithNodeDate('화', 2, DateTime(2026, 9, 15)); // B노드만 확정, 다른 주로

      final r = resolveEventDates(item);

      final tuesday = r.forSlot(2, 2); // 화, B노드 슬롯
      expect(tuesday!.source, CellDateSource.confirmedNode);
      expect(tuesday.date, DateTime(2026, 9, 15));
      expect(tuesday.isConfirmed, isTrue);

      final monday = r.forSlot(1, 1); // 월, 확정 안 됨
      expect(monday!.source, CellDateSource.estimated);
      expect(monday.date, DateTime(2026, 8, 24));

      final wednesday = r.forSlot(3, 3); // 수, 확정 안 됨
      expect(wednesday!.source, CellDateSource.estimated);
    });

    test('확정 노드라도 period가 다르면 매칭되지 않고 추정으로 폴백한다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _circularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      ).copyWithNodeDate('화', 2, DateTime(2026, 9, 15));

      final r = resolveEventDates(item);
      final result = r.forSlot(2, 99); // 같은 요일, 다른 교시
      expect(result!.source, CellDateSource.estimated);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/dual_exchange_path.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/supplement_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/utils/exchange_cell_dates.dart';

OneToOneExchangePath _oneToOnePath({
  required String sourceTeacher,
  required String sourceDay,
  required int sourcePeriod,
  required String targetTeacher,
  required String targetDay,
  required int targetPeriod,
}) {
  final targetSlot = TimeSlot(
    teacher: targetTeacher,
    subject: '기술가정',
    className: '3-8',
    dayOfWeek: 1,
    period: targetPeriod,
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: sourceTeacher,
      day: sourceDay,
      period: sourcePeriod,
      className: '3-8',
      subjectName: '기술가정',
    ),
    targetNode: ExchangeNode(
      teacherName: targetTeacher,
      day: targetDay,
      period: targetPeriod,
      className: '3-8',
      subjectName: '기술가정',
    ),
    option: ExchangeOption(
      timeSlot: targetSlot,
      teacherName: targetTeacher,
      type: ExchangeType.sameClass,
      priority: 1,
      reason: 'test',
    ),
  );
}

ExchangeNode _node(String teacher, String day, int period, [String subject = '수학']) {
  return ExchangeNode(
    teacherName: teacher,
    day: day,
    period: period,
    className: '1-1',
    subjectName: subject,
  );
}

void main() {
  group('ExchangeCellDates.forItem — 1:1 교체', () {
    test('결강일·교체일이 각 노드의 요일에 맞게 4개 칸 모두에 매핑된다', () {
      final path = _oneToOnePath(
        sourceTeacher: '정원길',
        sourceDay: '수',
        sourcePeriod: 1,
        targetTeacher: '박은선',
        targetDay: '월',
        targetPeriod: 1,
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 10, 7), // 수요일
        substitutionDate: DateTime(2026, 10, 5), // 월요일
      );

      final result = ExchangeCellDates.forItem(item);

      expect(result.supported, isTrue);
      expect(result.cells.length, 4);

      final byKey = {for (final c in result.cells) c.coordinateKey: c};
      expect(byKey['정원길_수_1']!.date, DateTime(2026, 10, 7));
      expect(byKey['정원길_수_1']!.isVacateSide, isTrue);
      expect(byKey['박은선_수_1']!.date, DateTime(2026, 10, 7));
      expect(byKey['박은선_수_1']!.isVacateSide, isFalse);
      expect(byKey['박은선_월_1']!.date, DateTime(2026, 10, 5));
      expect(byKey['박은선_월_1']!.isVacateSide, isTrue);
      expect(byKey['정원길_월_1']!.date, DateTime(2026, 10, 5));
      expect(byKey['정원길_월_1']!.isVacateSide, isFalse);
    });

    test('요일과 실제 날짜의 요일이 어긋나면 unsupported로 안전 폴백한다', () {
      // sourceDay는 '수'인데 absenceDate는 실제로 월요일(2026-10-05) — 계획서에서
      // 요일과 안 맞는 날짜로 직접 고친 경우를 재현한다.
      final path = _oneToOnePath(
        sourceTeacher: 'A',
        sourceDay: '수',
        sourcePeriod: 1,
        targetTeacher: 'B',
        targetDay: '월',
        targetPeriod: 1,
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 10, 5), // 월요일 — sourceDay('수')와 불일치
        substitutionDate: DateTime(2026, 10, 7),
      );

      final result = ExchangeCellDates.forItem(item);

      expect(result.supported, isFalse);
      expect(result.cells, isEmpty);
    });
  });

  group('ExchangeCellDates.forItem — 보강(단방향)', () {
    test('소스는 결강일(빠진 수업), 타겟은 교체일(맡은 수업)로 매핑된다', () {
      final path = SupplementExchangePath.simple(
        id: 'test-supplement',
        sourceTeacher: '정원길',
        sourceDay: '수',
        sourcePeriod: 1,
        targetTeacher: '박은선',
        targetDay: '월',
        targetPeriod: 2,
        className: '3-8',
        subject: '기술가정',
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 10, 7),
        substitutionDate: DateTime(2026, 10, 5),
      );

      final result = ExchangeCellDates.forItem(item);

      expect(result.supported, isTrue);
      expect(result.cells.length, 2);
      final byKey = {for (final c in result.cells) c.coordinateKey: c};
      expect(byKey['정원길_수_1']!.date, DateTime(2026, 10, 7));
      expect(byKey['정원길_수_1']!.isVacateSide, isTrue);
      expect(byKey['박은선_월_2']!.date, DateTime(2026, 10, 5));
      expect(byKey['박은선_월_2']!.isVacateSide, isFalse);
    });
  });

  group('ExchangeCellDates.forItem — 순환·2중 교체는 의도적으로 unsupported', () {
    test('순환 교체는 노드가 3개 이상이라 날짜를 매핑하지 않는다', () {
      final a = _node('A', '월', 1);
      final b = _node('B', '화', 2);
      final c = _node('C', '수', 3);
      final path = CircularExchangePath.fromNodes([a, b, c, a]);
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 8, 24), // 월요일
        substitutionDate: DateTime(2026, 8, 25), // 화요일
      );

      final result = ExchangeCellDates.forItem(item);

      expect(result.supported, isFalse);
      expect(result.cells, isEmpty);
    });

    test('2중 교체는 노드가 4개라 날짜를 매핑하지 않는다', () {
      final nodeA = _node('박지혜', '월', 1);
      final nodeB = _node('이숙희', '화', 4);
      final node1 = _node('이숙희', '월', 4);
      final node2 = _node('손혜옥', '화', 5);
      final path = DualExchangePath.build(
        nodeA: nodeA,
        nodeB: nodeB,
        node1: node1,
        node2: node2,
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );

      final result = ExchangeCellDates.forItem(item);

      expect(result.supported, isFalse);
    });
  });

  group('ExchangeCellDates.forWeek — 다른 주로 넘어가는 교체를 각자 실제 주에만 반영', () {
    test('결강 10.14(수)/10월2주, 교체 10.26(월)/10월4주 — 각 주는 자기 쪽 칸만 갖는다', () {
      final path = _oneToOnePath(
        sourceTeacher: '정원길',
        sourceDay: '수',
        sourcePeriod: 1,
        targetTeacher: '박은선',
        targetDay: '월',
        targetPeriod: 1,
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 10, 14), // 수요일, 10월2주(월요일 10.12)
        substitutionDate: DateTime(2026, 10, 26), // 월요일, 10월4주
      );

      final week2 = ExchangeCellDates.forWeek([item], DateTime(2026, 10, 12));
      final week4 = ExchangeCellDates.forWeek([item], DateTime(2026, 10, 26));
      final week3 = ExchangeCellDates.forWeek([item], DateTime(2026, 10, 19));

      // 10월2주(결강일 주, 10.14 수)에는 정원길 본인 자리(X)와 박은선이 대신
      // 들어간 자리(○)가 있다 — 둘 다 같은 실제 날짜(10.14)에 속한다.
      expect(week2.sourceKeys, {'정원길_수_1'});
      expect(week2.destinationKeys, {'박은선_수_1'});

      // 10월4주(교체일 주, 10.26 월)에는 박은선 본인 자리(X)와 정원길이 대신
      // 들어간 자리(○)가 있다 — 둘 다 같은 실제 날짜(10.26)에 속한다.
      expect(week4.sourceKeys, {'박은선_월_1'});
      expect(week4.destinationKeys, {'정원길_월_1'});

      // 관계없는 주(10월3주)는 아무 칸도 없다
      expect(week3.sourceKeys, isEmpty);
      expect(week3.destinationKeys, isEmpty);
    });

    test('순환 교체는 날짜 미확정이라 어느 주를 보든 항상 표시되고 undatedKeys에 잡힌다', () {
      final a = _node('A', '월', 1);
      final b = _node('B', '화', 2);
      final c = _node('C', '수', 3);
      final path = CircularExchangePath.fromNodes([a, b, c, a]);
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );

      final anyWeek = ExchangeCellDates.forWeek([item], DateTime(2026, 1, 5));

      expect(anyWeek.sourceKeys, isNotEmpty);
      expect(anyWeek.undatedKeys, isNotEmpty);
    });
  });

  group('ExchangeCellDates.forWeek — 순환·2중 노드별 확정 날짜 (S5.6)', () {
    test('노드 하나가 확정되면 그 칸만 실제 주에 스코프되고 undatedKeys에서 빠진다', () {
      final a = _node('A', '월', 1);
      final b = _node('B', '화', 2);
      final c = _node('C', '수', 3);
      final path = CircularExchangePath.fromNodes([a, b, c, a]);
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 8, 24), // 월, 8월4주
        substitutionDate: DateTime(2026, 8, 25),
      ).copyWithNodeDate('화', 2, DateTime(2026, 9, 8)); // B(화,2)만 9월2주로 확정

      final absenceWeek = ExchangeCellDates.forWeek([item], DateTime(2026, 8, 24));
      final confirmedWeek = ExchangeCellDates.forWeek([item], DateTime(2026, 9, 7));

      // 확정된 화(B) 칸은 결강일 주에는 더 이상 나타나지 않는다(다른 주로 확정됐으므로).
      expect(absenceWeek.sourceKeys.contains('B_화_2'), isFalse);
      expect(absenceWeek.undatedKeys.contains('B_화_2'), isFalse);
      // 확정 안 된 A·C의 칸은 여전히 결강일 주에 추정으로 나타난다.
      expect(absenceWeek.sourceKeys, containsAll(['A_월_1', 'C_수_3']));
      expect(absenceWeek.undatedKeys, containsAll(['A_월_1', 'C_수_3']));

      // 확정된 주에는 B의 소스 칸이 나타나고, 더 이상 "?"가 아니다(undatedKeys에 없음).
      expect(confirmedWeek.sourceKeys.contains('B_화_2'), isTrue);
      expect(confirmedWeek.undatedKeys.contains('B_화_2'), isFalse);
    });

    test('확정 노드가 이 주에도 저 주에도 아니면(관계없는 주) 아무 데도 나타나지 않는다', () {
      final a = _node('A', '월', 1);
      final b = _node('B', '화', 2);
      final c = _node('C', '수', 3);
      final path = CircularExchangePath.fromNodes([a, b, c, a]);
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      ).copyWithNodeDate('화', 2, DateTime(2026, 9, 8));

      final unrelatedWeek = ExchangeCellDates.forWeek([item], DateTime(2026, 9, 21));

      expect(unrelatedWeek.sourceKeys.contains('B_화_2'), isFalse);
      expect(unrelatedWeek.destinationKeys.contains('B_화_2'), isFalse);
      expect(unrelatedWeek.undatedKeys.contains('B_화_2'), isFalse);
    });
  });

  group('ExchangeCellDates.legacySourceKeys/legacyDestinationKeys — forWeek와 같은 키 집합 (S5.6)', () {
    test('순환 교체 — 확정 노드가 없으면 forWeek의 결과가 legacy 키 집합과 정확히 같다', () {
      final a = _node('A', '월', 1);
      final b = _node('B', '화', 2);
      final c = _node('C', '수', 3);
      final path = CircularExchangePath.fromNodes([a, b, c, a]);
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );

      final result = ExchangeCellDates.forWeek([item], DateTime(2026, 1, 5)); // 아무 주

      expect(result.sourceKeys, ExchangeCellDates.legacySourceKeys(path).toSet());
      expect(result.destinationKeys, ExchangeCellDates.legacyDestinationKeys(path).toSet());
    });

    test('2중 교체 — 확정 노드가 없으면 forWeek의 결과가 legacy 키 집합과 정확히 같다', () {
      final nodeA = _node('박지혜', '월', 1);
      final nodeB = _node('이숙희', '화', 4);
      final node1 = _node('이숙희', '월', 4);
      final node2 = _node('손혜옥', '화', 5);
      final path = DualExchangePath.build(
        nodeA: nodeA,
        nodeB: nodeB,
        node1: node1,
        node2: node2,
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );

      final result = ExchangeCellDates.forWeek([item], DateTime(2026, 1, 5));

      expect(result.sourceKeys, ExchangeCellDates.legacySourceKeys(path).toSet());
      expect(result.destinationKeys, ExchangeCellDates.legacyDestinationKeys(path).toSet());
    });
  });

  group('ExchangeCellDates.legacySourceKeys/legacyDestinationKeys — 기존 규칙 그대로', () {
    test('1:1 교체의 소스·목적지 키가 기존 규칙과 동일하다', () {
      final path = _oneToOnePath(
        sourceTeacher: 'A',
        sourceDay: '월',
        sourcePeriod: 1,
        targetTeacher: 'B',
        targetDay: '화',
        targetPeriod: 2,
      );

      expect(ExchangeCellDates.legacySourceKeys(path), [
        'A_월_1',
        'B_화_2',
      ]);
      expect(ExchangeCellDates.legacyDestinationKeys(path), [
        'B_월_1',
        'A_화_2',
      ]);
    });
  });

  group('ExchangeCellDates.forWeek — 실행 시점에 전부 시드된 순환 교체 (S5.6.7)', () {
    test('결강일 주에서는 undatedKeys가 비고, 나머지 주에서는 모든 키가 사라진다', () {
      final a = _node('A', '월', 1);
      final b = _node('B', '화', 2);
      final c = _node('C', '수', 3);
      final path = CircularExchangePath.fromNodes([a, b, c, a]);
      final weekMonday = DateTime(2026, 8, 24); // 월요일
      var item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: weekMonday,
        substitutionDate: weekMonday.add(const Duration(days: 1)),
      );
      // 실행 시점 시드를 그대로 재현 — 모든 노드가 확정된다.
      for (final node in [a, b, c]) {
        item = item.copyWithNodeDate(
          node.day,
          node.period,
          weekMonday.add(Duration(days: {'월': 0, '화': 1, '수': 2}[node.day]!)),
        );
      }

      final absenceWeek = ExchangeCellDates.forWeek([item], weekMonday);
      final otherWeek = ExchangeCellDates.forWeek([item], DateTime(2026, 1, 5));

      expect(absenceWeek.undatedKeys, isEmpty);
      expect(absenceWeek.sourceKeys, isNotEmpty);
      expect(otherWeek.sourceKeys, isEmpty);
      expect(otherWeek.destinationKeys, isEmpty);
      expect(otherWeek.undatedKeys, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/dual_exchange_path.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/event_date_resolver.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/utils/node_date_seed.dart';

ExchangeNode _node(String teacher, String day, int period, [String subject = '수학']) {
  return ExchangeNode(
    teacherName: teacher,
    day: day,
    period: period,
    className: '1-1',
    subjectName: subject,
  );
}

CircularExchangePath _circularPath() {
  final a = _node('A', '월', 1);
  final b = _node('B', '화', 2);
  final c = _node('C', '수', 3);
  return CircularExchangePath.fromNodes([a, b, c, a]);
}

OneToOneExchangePath _oneToOnePath() {
  final targetSlot = TimeSlot(
    teacher: '박은선',
    subject: '기술가정',
    className: '3-8',
    dayOfWeek: 1,
    period: 1,
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: '정원길',
      day: '수',
      period: 1,
      className: '3-8',
      subjectName: '기술가정',
    ),
    targetNode: ExchangeNode(
      teacherName: '박은선',
      day: '월',
      period: 1,
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

void main() {
  group('seedNodeDatesForWeek', () {
    test('순환 교체 — 각 노드가 그 요일에 맞는 날짜로 시드된다(중복 노드는 키를 늘리지 않는다)', () {
      final path = _circularPath(); // [A월1, B화2, C수3, A월1]
      final weekMonday = DateTime(2026, 8, 24); // 월요일

      final seeded = seedNodeDatesForWeek(path, weekMonday);

      expect(seeded, {
        '월|1': DateTime(2026, 8, 24),
        '화|2': DateTime(2026, 8, 25),
        '수|3': DateTime(2026, 8, 26),
      });
    });

    test('2중 교체 — (요일,교시)가 같고 교사만 다른 두 노드는 키가 하나로 합쳐진다 (OQ-11 한계 고정)', () {
      // node2와 nodeB가 둘 다 (금,4)인 실제 사용자 사례를 재현한다.
      final nodeA = _node('박선영', '목', 6);
      final nodeB = _node('정원길', '금', 4);
      final node1 = _node('정원길', '수', 4);
      final node2 = _node('정수정', '금', 4); // nodeB와 같은 슬롯
      final path = DualExchangePath.build(
        nodeA: nodeA,
        nodeB: nodeB,
        node1: node1,
        node2: node2,
      );
      final weekMonday = DateTime(2026, 8, 24);

      final seeded = seedNodeDatesForWeek(path, weekMonday);

      // 슬롯 3개뿐 — 금|4 하나로 합쳐짐(교사 다른 두 노드가 공유)
      expect(seeded.length, 3);
      expect(seeded['목|6'], DateTime(2026, 8, 27));
      expect(seeded['수|4'], DateTime(2026, 8, 26));
      expect(seeded['금|4'], DateTime(2026, 8, 28));
    });

    test('1:1·보강은 빈 맵을 반환한다', () {
      final seeded = seedNodeDatesForWeek(_oneToOnePath(), DateTime(2026, 8, 24));
      expect(seeded, isEmpty);
    });

    test('월요일이 아닌 날짜를 넘겨도 그 주 월요일 기준으로 정규화된다', () {
      final path = _circularPath();
      final wednesday = DateTime(2026, 8, 26); // 같은 주 수요일

      final seeded = seedNodeDatesForWeek(path, wednesday);

      expect(seeded['월|1'], DateTime(2026, 8, 24));
    });

    test('시드 값은 resolveEventDates의 OQ-1 추정값과 모든 노드에서 동일하다 (값 불변 증명)', () {
      final path = _circularPath();
      final weekMonday = DateTime(2026, 8, 24);
      final seeded = seedNodeDatesForWeek(path, weekMonday);

      // 시드하지 않은(빈 nodeDates) 항목의 추정값과 비교
      final unseededItem = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: weekMonday,
        substitutionDate: weekMonday.add(const Duration(days: 1)),
      );
      final resolution = resolveEventDates(unseededItem);

      for (final entry in seeded.entries) {
        final parts = entry.key.split('|');
        final dayName = parts[0];
        final period = int.parse(parts[1]);
        final dayNumber = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5}[dayName]!;
        final estimated = resolution.forSlot(dayNumber, period)!;
        expect(estimated.source, CellDateSource.estimated);
        expect(entry.value, estimated.date, reason: '슬롯 $entry.key');
      }
    });
  });
}

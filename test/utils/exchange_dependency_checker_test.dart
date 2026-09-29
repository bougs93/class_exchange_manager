import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/supplement_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/utils/exchange_dependency_checker.dart';

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

ExchangeHistoryItem _item(String id, OneToOneExchangePath path) {
  return ExchangeHistoryItem.fromExchangePath(
    path,
    absenceDate: DateTime(2026, 9, 3),
    substitutionDate: DateTime(2026, 9, 5),
    customId: id,
  );
}

void main() {
  group('findDependentExchanges', () {
    test('나중 이벤트가 없으면 빈 목록이다', () {
      final target = _item(
        'evt_1',
        _oneToOnePath(
          sourceTeacher: 'A',
          sourceDay: '월',
          sourcePeriod: 1,
          targetTeacher: 'B',
          targetDay: '화',
          targetPeriod: 2,
        ),
      );

      final result = findDependentExchanges(
        target: target,
        allEventsInOrder: [target],
      );

      expect(result, isEmpty);
    });

    test('나중 이벤트가 target이 만든 칸을 source로 쓰면 의존으로 판정한다', () {
      // evt_1(A월1↔B화2) 실행 후 B의 월1 자리(evt_1이 만든 칸)를
      // evt_2(B↔C)가 source로 사용한다.
      final evt1 = _item(
        'evt_1',
        _oneToOnePath(
          sourceTeacher: 'A',
          sourceDay: '월',
          sourcePeriod: 1,
          targetTeacher: 'B',
          targetDay: '화',
          targetPeriod: 2,
        ),
      );
      final evt2 = _item(
        'evt_2',
        _oneToOnePath(
          sourceTeacher: 'B',
          sourceDay: '월',
          sourcePeriod: 1,
          targetTeacher: 'C',
          targetDay: '수',
          targetPeriod: 3,
        ),
      );

      final result = findDependentExchanges(
        target: evt1,
        allEventsInOrder: [evt1, evt2],
      );

      expect(result.map((e) => e.id), ['evt_2']);
    });

    test('되돌린(isReverted) 이후 이벤트는 의존 목록에서 제외된다', () {
      final evt1 = _item(
        'evt_1',
        _oneToOnePath(
          sourceTeacher: 'A',
          sourceDay: '월',
          sourcePeriod: 1,
          targetTeacher: 'B',
          targetDay: '화',
          targetPeriod: 2,
        ),
      );
      final evt2 = _item(
        'evt_2',
        _oneToOnePath(
          sourceTeacher: 'B',
          sourceDay: '월',
          sourcePeriod: 1,
          targetTeacher: 'C',
          targetDay: '수',
          targetPeriod: 3,
        ),
      ).copyWithReverted(true);

      final result = findDependentExchanges(
        target: evt1,
        allEventsInOrder: [evt1, evt2],
      );

      expect(result, isEmpty);
    });

    test('겹치는 칸이 없는 나중 이벤트는 의존이 아니다', () {
      final evt1 = _item(
        'evt_1',
        _oneToOnePath(
          sourceTeacher: 'A',
          sourceDay: '월',
          sourcePeriod: 1,
          targetTeacher: 'B',
          targetDay: '화',
          targetPeriod: 2,
        ),
      );
      final evt2 = _item(
        'evt_2',
        _oneToOnePath(
          sourceTeacher: 'X',
          sourceDay: '목',
          sourcePeriod: 4,
          targetTeacher: 'Y',
          targetDay: '금',
          targetPeriod: 5,
        ),
      );

      final result = findDependentExchanges(
        target: evt1,
        allEventsInOrder: [evt1, evt2],
      );

      expect(result, isEmpty);
    });

    test('target보다 먼저 실행된 이벤트는 검사 대상이 아니다', () {
      final evt0 = _item(
        'evt_0',
        _oneToOnePath(
          sourceTeacher: 'B',
          sourceDay: '월',
          sourcePeriod: 1,
          targetTeacher: 'Z',
          targetDay: '금',
          targetPeriod: 5,
        ),
      );
      final evt1 = _item(
        'evt_1',
        _oneToOnePath(
          sourceTeacher: 'A',
          sourceDay: '월',
          sourcePeriod: 1,
          targetTeacher: 'B',
          targetDay: '화',
          targetPeriod: 2,
        ),
      );

      final result = findDependentExchanges(
        target: evt1,
        allEventsInOrder: [evt0, evt1],
      );

      expect(result, isEmpty);
    });

    test('보강(supplement) 경로도 목적지 칸 기준으로 의존을 판정한다', () {
      final supplement = ExchangeHistoryItem.fromExchangePath(
        SupplementExchangePath.simple(
          id: 'supp',
          sourceTeacher: 'A',
          sourceDay: '월',
          sourcePeriod: 1,
          targetTeacher: 'B',
          targetDay: '월',
          targetPeriod: 1,
          className: '1-1',
          subject: '수학',
        ),
        absenceDate: DateTime(2026, 9, 3),
        substitutionDate: DateTime(2026, 9, 3),
        customId: 'evt_supp',
      );
      final evt2 = _item(
        'evt_2',
        _oneToOnePath(
          sourceTeacher: 'B',
          sourceDay: '월',
          sourcePeriod: 1,
          targetTeacher: 'C',
          targetDay: '수',
          targetPeriod: 3,
        ),
      );

      final result = findDependentExchanges(
        target: supplement,
        allEventsInOrder: [supplement, evt2],
      );

      expect(result.map((e) => e.id), ['evt_2']);
    });
  });
}

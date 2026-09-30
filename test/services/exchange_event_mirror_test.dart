import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/supplement_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/exchange_event_mirror.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

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

OneToOneExchangePath _oneToOnePath(String label) {
  final targetSlot = TimeSlot(
    teacher: '교사B-$label',
    subject: '국어',
    className: '1-2',
    dayOfWeek: 2,
    period: 2,
  );
  final option = ExchangeOption(
    timeSlot: targetSlot,
    teacherName: '교사B-$label',
    type: ExchangeType.sameClass,
    priority: 1,
    reason: 'test',
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: '교사A-$label',
      day: '월',
      period: 1,
      className: '1-1',
      subjectName: '수학',
    ),
    targetNode: ExchangeNode(
      teacherName: '교사B-$label',
      day: '화',
      period: 2,
      className: '1-2',
      subjectName: '국어',
    ),
    option: option,
  );
}

void main() {
  group('toExchangeEventRecords', () {
    test('빈 목록은 빈 목록을 반환한다', () {
      expect(toExchangeEventRecords(const [], 'tt_1'), isEmpty);
    });

    test('목록 순서를 seq(0부터)로 그대로 반영한다', () {
      final items = [
        ExchangeHistoryItem.fromExchangePath(
          _oneToOnePath('1'),
          absenceDate: DateTime(2026, 9, 3),
          substitutionDate: DateTime(2026, 9, 5),
          customId: 'evt_1',
        ),
        ExchangeHistoryItem.fromExchangePath(
          _oneToOnePath('2'),
          absenceDate: DateTime(2026, 9, 4),
          substitutionDate: DateTime(2026, 9, 6),
          customId: 'evt_2',
        ),
      ];

      final records = toExchangeEventRecords(items, 'tt_1');

      expect(records.map((r) => r.id).toList(), ['evt_1', 'evt_2']);
      expect(records.map((r) => r.seq).toList(), [0, 1]);
      expect(records.every((r) => r.timetableId == 'tt_1'), isTrue);
    });

    test('pathJson은 ExchangePath.toJson()과 동일한 내용을 담는다', () {
      final path = _oneToOnePath('1');
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 9, 3),
        substitutionDate: DateTime(2026, 9, 5),
        customId: 'evt_1',
      );

      final record = toExchangeEventRecords([item], 'tt_1').single;

      expect(jsonDecode(record.pathJson), path.toJson());
    });

    test('필드가 1:1 매핑된다 (type/날짜/태그/메모/프로파일/되돌리기 상태)', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _oneToOnePath('1'),
        absenceDate: DateTime(2026, 9, 3),
        substitutionDate: DateTime(2026, 9, 5),
        customId: 'evt_1',
        notes: '메모',
        tags: const ['긴급'],
      ).copyWithProfileId('profile_1').copyWithReverted(true);

      final record = toExchangeEventRecords([item], 'tt_1').single;

      expect(record.type, 'oneToOne');
      expect(record.absenceDate, DateTime(2026, 9, 3));
      expect(record.substitutionDate, DateTime(2026, 9, 5));
      expect(record.notes, '메모');
      expect(record.tags, ['긴급']);
      expect(record.profileId, 'profile_1');
      expect(record.isReverted, isTrue);
      expect(record.description, item.description);
      expect(record.nodeDatesJson, isNull); // 1:1은 노드 날짜를 쓰지 않는다 (S5.6)
    });

    test('nodeDates가 비어 있는 순환 교체도 nodeDatesJson이 null이다 (S5.6)', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _circularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
        customId: 'evt_circular',
      );

      final record = toExchangeEventRecords([item], 'tt_1').single;

      expect(record.nodeDatesJson, isNull);
    });

    test('노드 날짜가 지정된 순환 교체는 nodeDatesJson에 그대로 직렬화된다 (S5.6)', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _circularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
        customId: 'evt_circular',
      ).copyWithNodeDate('화', 2, DateTime(2026, 9, 1));

      final record = toExchangeEventRecords([item], 'tt_1').single;

      expect(record.nodeDatesJson, isNotNull);
      expect(jsonDecode(record.nodeDatesJson!), {
        '화|2': DateTime(2026, 9, 1).toIso8601String(),
      });
    });

    test('supplement(보강) 타입도 정확히 매핑된다', () {
      final path = SupplementExchangePath.simple(
        id: 'supp_1',
        sourceTeacher: '교사A',
        sourceDay: '월',
        sourcePeriod: 1,
        targetTeacher: '교사B',
        targetDay: '월',
        targetPeriod: 1,
        className: '1-1',
        subject: '수학',
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 9, 3),
        substitutionDate: DateTime(2026, 9, 3),
        customId: 'evt_supp',
      );

      final record = toExchangeEventRecords([item], 'tt_1').single;

      expect(record.type, 'supplement');
    });
  });

  group('toExchangeHistoryItem — nodeDates 왕복 (S5.6)', () {
    test('nodeDatesJson이 null이면 되돌린 항목의 nodeDates는 빈 맵이다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _circularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
        customId: 'evt_circular',
      );
      final record = toExchangeEventRecords([item], 'tt_1').single;

      final restored = toExchangeHistoryItem(record);

      expect(restored.nodeDates, isEmpty);
    });

    test('nodeDatesJson이 있으면 그대로 복원된다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _circularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
        customId: 'evt_circular',
      ).copyWithNodeDate('화', 2, DateTime(2026, 9, 1));
      final record = toExchangeEventRecords([item], 'tt_1').single;

      final restored = toExchangeHistoryItem(record);

      expect(restored.nodeDateFor('화', 2), DateTime(2026, 9, 1));
    });
  });
}

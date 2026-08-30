import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

OneToOneExchangePath _testPath() {
  final targetSlot = TimeSlot(
    teacher: '교사B',
    subject: '국어',
    className: '1-2',
    dayOfWeek: 2,
    period: 2,
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: '교사A',
      day: '월',
      period: 1,
      className: '1-1',
      subjectName: '수학',
    ),
    targetNode: ExchangeNode(
      teacherName: '교사B',
      day: '화',
      period: 2,
      className: '1-2',
      subjectName: '국어',
    ),
    option: ExchangeOption(
      timeSlot: targetSlot,
      teacherName: '교사B',
      type: ExchangeType.sameClass,
      priority: 1,
      reason: 'test',
    ),
  );
}

void main() {
  group('ExchangeHistoryItem 날짜 필드 (§10.6)', () {
    test('toJson → fromJson 왕복 시 absenceDate/substitutionDate가 보존된다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
        customDescription: '왕복 테스트',
      );

      final restored = ExchangeHistoryItem.fromJson(item.toJson());

      expect(restored.absenceDate, item.absenceDate);
      expect(restored.substitutionDate, item.substitutionDate);
      expect(restored.id, item.id);
    });

    test('weekMonday는 absenceDate가 속한 주의 월요일이다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27), // 목요일
        substitutionDate: DateTime(2026, 8, 28),
      );

      expect(item.weekMonday, DateTime(2026, 8, 24));
    });

    test('absenceDate/substitutionDate가 없는 구 형식 JSON은 fromJson이 예외를 던진다', () {
      // §10.6: 마이그레이션하지 않는다 — 구 데이터는 조용히 통과시키지 않고
      // 명시적으로 실패해야, 이를 잡아 건너뛰는 저장 계층(§10.6)이 동작한다.
      final legacyJson = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      ).toJson()..remove('absenceDate');

      expect(() => ExchangeHistoryItem.fromJson(legacyJson), throwsA(anything));
    });

    test('copyWith* 계열 메서드는 absenceDate/substitutionDate를 보존한다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );

      final reverted = item.copyWithReverted(true);
      final withNotes = item.copyWithNotes('메모');
      final withTags = item.copyWithTags(['태그']);
      final withMetadata = item.copyWithMetadata({'k': 'v'});
      final withProfile = item.copyWithProfileId('pp_1');

      for (final copy in [reverted, withNotes, withTags, withMetadata, withProfile]) {
        expect(copy.absenceDate, item.absenceDate);
        expect(copy.substitutionDate, item.substitutionDate);
      }
    });
  });
}

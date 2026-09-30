import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

CircularExchangePath _testCircularPath() {
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

  group('ExchangeHistoryItem.copyWithDates (§10.10)', () {
    test('absenceDate만 지정하면 substitutionDate는 그대로 유지된다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );

      final updated = item.copyWithDates(absenceDate: DateTime(2026, 9, 3));

      expect(updated.absenceDate, DateTime(2026, 9, 3));
      expect(updated.substitutionDate, item.substitutionDate);
      expect(updated.id, item.id);
    });

    test('substitutionDate만 지정하면 absenceDate는 그대로 유지된다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );

      final updated = item.copyWithDates(
        substitutionDate: DateTime(2026, 9, 4),
      );

      expect(updated.absenceDate, item.absenceDate);
      expect(updated.substitutionDate, DateTime(2026, 9, 4));
    });

    test('둘 다 지정하지 않으면 아무 것도 바뀌지 않는다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );

      final updated = item.copyWithDates();

      expect(updated.absenceDate, item.absenceDate);
      expect(updated.substitutionDate, item.substitutionDate);
    });

    test('시간 정보가 포함된 날짜를 넘겨도 자정 기준으로 정규화된다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );

      final updated = item.copyWithDates(
        absenceDate: DateTime(2026, 9, 3, 15, 30),
      );

      expect(updated.absenceDate, DateTime(2026, 9, 3));
    });
  });

  group('ExchangeHistoryItem.nodeDates (S5.6)', () {
    test('기본값은 빈 맵이고 supportsNodeDates는 1:1에서 false다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );

      expect(item.nodeDates, isEmpty);
      expect(item.supportsNodeDates, isFalse);
    });

    test('순환 교체는 supportsNodeDates가 true다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testCircularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );

      expect(item.supportsNodeDates, isTrue);
    });

    test('copyWithNodeDate는 순환 교체에서 해당 슬롯에 날짜를 추가한다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testCircularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );

      final updated = item.copyWithNodeDate('화', 2, DateTime(2026, 9, 1, 10, 0));

      expect(updated.nodeDateFor('화', 2), DateTime(2026, 9, 1)); // 시각 제거됨
      expect(updated.nodeDateFor('수', 3), isNull); // 다른 슬롯은 그대로 비어있음
      expect(item.nodeDates, isEmpty); // 원본은 불변
    });

    test('copyWithNodeDate는 1:1(supportsNodeDates=false)에서 아무것도 바꾸지 않는다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );

      final result = item.copyWithNodeDate('월', 1, DateTime(2026, 9, 1));

      expect(identical(result, item), isTrue);
      expect(result.nodeDates, isEmpty);
    });

    test('toJson → fromJson 왕복 시 nodeDates가 보존된다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testCircularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      ).copyWithNodeDate('화', 2, DateTime(2026, 9, 1));

      final restored = ExchangeHistoryItem.fromJson(item.toJson());

      expect(restored.nodeDateFor('화', 2), DateTime(2026, 9, 1));
    });

    test('nodeDates가 비어 있으면 toJson 결과에 nodeDates 키 자체가 없다 (구 파일과 바이트 동일 보장)', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );

      expect(item.toJson().containsKey('nodeDates'), isFalse);
    });

    test('nodeDates 키가 없는 구 JSON을 로드하면 빈 맵이 된다', () {
      final legacyJson = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      ).toJson();

      expect(legacyJson.containsKey('nodeDates'), isFalse);
      final restored = ExchangeHistoryItem.fromJson(legacyJson);
      expect(restored.nodeDates, isEmpty);
    });

    test('copyWith* 6개 전부 nodeDates를 보존한다 (특히 copyWithReverted)', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testCircularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      ).copyWithNodeDate('화', 2, DateTime(2026, 9, 1));

      final copies = [
        item.copyWithReverted(true),
        item.copyWithNotes('메모'),
        item.copyWithDates(absenceDate: DateTime(2026, 9, 7)),
        item.copyWithTags(['태그']),
        item.copyWithMetadata({'k': 'v'}),
        item.copyWithProfileId('pp_1'),
      ];

      for (final copy in copies) {
        expect(copy.nodeDateFor('화', 2), DateTime(2026, 9, 1));
      }
    });
  });

  group('ExchangeHistoryItem.fromExchangePath(nodeDates:) (S5.6.7)', () {
    test('인자를 넘기지 않으면 순환 교체도 여전히 nodeDates가 빈 맵이다 (기존 동작 보장)', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testCircularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );

      expect(item.nodeDates, isEmpty);
    });

    test('순환 교체에 nodeDates를 넘기면 저장되고 시각이 제거된다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testCircularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
        nodeDates: {'화|2': DateTime(2026, 9, 1, 15, 30)},
      );

      expect(item.nodeDateFor('화', 2), DateTime(2026, 9, 1)); // 시각 제거됨
    });

    test('1:1 교체에 nodeDates를 넘겨도 무시되어 빈 맵이다 (오염 방지 가드)', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testPath(),
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
        nodeDates: {'월|1': DateTime(2026, 9, 1)},
      );

      expect(item.nodeDates, isEmpty);
    });

    test('nodeDates를 넘긴 뒤 toJson → fromJson 왕복해도 보존된다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        _testCircularPath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
        nodeDates: {'화|2': DateTime(2026, 9, 1)},
      );

      final restored = ExchangeHistoryItem.fromJson(item.toJson());

      expect(restored.nodeDateFor('화', 2), DateTime(2026, 9, 1));
    });
  });
}

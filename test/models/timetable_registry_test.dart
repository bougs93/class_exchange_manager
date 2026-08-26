import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/timetable_registry.dart';

void main() {
  group('TimetableRegistryEntry', () {
    test('generateId는 tt_ 접두사와 타임스탬프 형식을 가진다', () {
      final id = TimetableRegistryEntry.generateId(
        now: DateTime(2026, 8, 26, 14, 30, 0),
      );

      expect(id, startsWith('tt_20260826_143000_'));
    });

    test('generateId는 연속 호출 시 서로 다른 값을 반환한다', () {
      final ids = List.generate(50, (_) => TimetableRegistryEntry.generateId());
      expect(ids.toSet().length, ids.length);
    });

    test('JSON 직렬화/역직렬화 왕복', () {
      final entry = TimetableRegistryEntry(
        id: 'tt_20260826_143000_100',
        name: '월계중1학기',
        fileName: '2학기_전체시간표.xlsx',
        filePath: 'D:/schedules/2학기_전체시간표.xlsx',
        hash: '월계중_abc123',
        contentHash: 'abc123',
        registeredAt: DateTime(2026, 8, 26, 14, 30),
      );

      final restored = TimetableRegistryEntry.fromJson(entry.toJson());

      expect(restored.id, entry.id);
      expect(restored.name, entry.name);
      expect(restored.fileName, entry.fileName);
      expect(restored.filePath, entry.filePath);
      expect(restored.hash, entry.hash);
      expect(restored.contentHash, entry.contentHash);
      expect(restored.registeredAt, entry.registeredAt);
    });

    test('fromJson은 name이 없으면 fileName으로 대체한다', () {
      final entry = TimetableRegistryEntry.fromJson({
        'id': 'tt_1',
        'fileName': '시간표.xlsx',
      });

      expect(entry.name, '시간표.xlsx');
    });

    test('fromJson은 누락 필드를 기본값으로 채운다', () {
      final entry = TimetableRegistryEntry.fromJson({'id': 'tt_1'});

      expect(entry.fileName, '');
      expect(entry.filePath, '');
      expect(entry.hash, '');
      expect(entry.contentHash, '');
    });

    test('copyWith는 지정한 필드만 변경한다', () {
      final entry = TimetableRegistryEntry(
        id: 'tt_1',
        name: '원본이름',
        fileName: 'a.xlsx',
        filePath: '/a.xlsx',
        hash: 'h1',
        contentHash: 'c1',
        registeredAt: DateTime(2026, 1, 1),
      );

      final renamed = entry.copyWith(name: '새이름');

      expect(renamed.name, '새이름');
      expect(renamed.id, entry.id);
      expect(renamed.hash, entry.hash);
      expect(renamed.registeredAt, entry.registeredAt);
    });
  });

  group('TimetableRegistry', () {
    TimetableRegistryEntry entry(String id) => TimetableRegistryEntry(
      id: id,
      name: '이름$id',
      fileName: '$id.xlsx',
      filePath: '/$id.xlsx',
      hash: 'hash$id',
      contentHash: 'content$id',
      registeredAt: DateTime(2026, 1, 1),
    );

    test('빈 레지스트리에 항목 추가 시 자동으로 활성 지정된다', () {
      const registry = TimetableRegistry();
      final next = registry.withEntry(entry('tt_1'));

      expect(next.activeId, 'tt_1');
      expect(next.hasValidActive, isTrue);
    });

    test('기존 활성이 있으면 항목 추가 시 활성이 유지된다', () {
      final registry = TimetableRegistry(activeId: 'tt_1', timetables: [entry('tt_1')]);
      final next = registry.withEntry(entry('tt_2'));

      expect(next.activeId, 'tt_1');
      expect(next.timetables.length, 2);
    });

    test('활성 항목 제거 시 activeId가 해제된다', () {
      final registry = TimetableRegistry(activeId: 'tt_1', timetables: [entry('tt_1')]);
      final next = registry.withoutEntry('tt_1');

      expect(next.activeId, isNull);
      expect(next.timetables, isEmpty);
    });

    test('비활성 항목 제거 시 activeId가 유지된다', () {
      final registry = TimetableRegistry(
        activeId: 'tt_1',
        timetables: [entry('tt_1'), entry('tt_2')],
      );
      final next = registry.withoutEntry('tt_2');

      expect(next.activeId, 'tt_1');
      expect(next.timetables.length, 1);
    });

    test('withActive는 활성을 전환한다', () {
      final registry = TimetableRegistry(
        activeId: 'tt_1',
        timetables: [entry('tt_1'), entry('tt_2')],
      );
      final next = registry.withActive('tt_2');

      expect(next.activeId, 'tt_2');
    });

    test('withActive는 존재하지 않는 ID에 대해 assert한다', () {
      final registry = TimetableRegistry(activeId: 'tt_1', timetables: [entry('tt_1')]);

      expect(() => registry.withActive('없는id'), throwsA(isA<AssertionError>()));
    });

    test('getById는 없는 ID에 null을 반환한다', () {
      final registry = TimetableRegistry(activeId: 'tt_1', timetables: [entry('tt_1')]);

      expect(registry.getById('없는id'), isNull);
      expect(registry.activeEntry, isNotNull);
    });

    test('JSON 직렬화/역직렬화 왕복', () {
      final registry = TimetableRegistry(
        activeId: 'tt_1',
        timetables: [entry('tt_1'), entry('tt_2')],
      );

      final restored = TimetableRegistry.fromJson(registry.toJson());

      expect(restored.activeId, 'tt_1');
      expect(restored.timetables.length, 2);
      expect(restored.timetables[0].name, '이름tt_1');
      expect(restored.timetables[1].hash, 'hashtt_2');
    });
  });
}

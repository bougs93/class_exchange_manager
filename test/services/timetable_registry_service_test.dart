import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/services/timetable_registry_service.dart';
import '../helpers/in_memory_json_storage.dart';

void main() {
  late InMemoryJsonStorage storage;
  late TimetableRegistryService service;

  setUp(() {
    storage = InMemoryJsonStorage();
    service = TimetableRegistryService(storage: storage);
  });

  group('TimetableRegistryService', () {
    test('저장소가 비어 있으면 빈 레지스트리를 반환한다', () async {
      final registry = await service.loadRegistry();

      expect(registry.activeId, isNull);
      expect(registry.timetables, isEmpty);
    });

    test('registerTimetable은 첫 항목을 활성으로 지정하고 저장한다', () async {
      final entry = await service.registerTimetable(
        name: '월계중1학기',
        fileName: '시간표.xlsx',
        filePath: '/시간표.xlsx',
        hash: 'hash1',
        contentHash: 'content1',
      );

      final registry = await service.loadRegistry();

      expect(registry.activeId, entry.id);
      expect(registry.timetables.single.name, '월계중1학기');
      expect(storage.fileExists('timetable_registry.json'), completes);
      expect(await storage.fileExists('timetable_registry.json'), isTrue);
    });

    test('registerTimetable은 기존 활성을 유지한다', () async {
      final first = await service.registerTimetable(
        name: 'A',
        fileName: 'a.xlsx',
        filePath: '/a.xlsx',
        hash: 'h1',
        contentHash: 'c1',
      );
      await service.registerTimetable(
        name: 'B',
        fileName: 'b.xlsx',
        filePath: '/b.xlsx',
        hash: 'h2',
        contentHash: 'c2',
      );

      final registry = await service.loadRegistry();

      expect(registry.activeId, first.id);
      expect(registry.timetables.length, 2);
    });

    test('switchActive는 활성을 전환하고 저장한다', () async {
      final first = await service.registerTimetable(
        name: 'A',
        fileName: 'a.xlsx',
        filePath: '/a.xlsx',
        hash: 'h1',
        contentHash: 'c1',
      );
      final second = await service.registerTimetable(
        name: 'B',
        fileName: 'b.xlsx',
        filePath: '/b.xlsx',
        hash: 'h2',
        contentHash: 'c2',
      );

      final success = await service.switchActive(second.id);
      final registry = await service.loadRegistry();

      expect(success, isTrue);
      expect(registry.activeId, second.id);
      expect(registry.activeId, isNot(first.id));
    });

    test('renameTimetable은 이름만 변경한다', () async {
      final entry = await service.registerTimetable(
        name: '옛이름',
        fileName: 'a.xlsx',
        filePath: '/a.xlsx',
        hash: 'h1',
        contentHash: 'c1',
      );

      final success = await service.renameTimetable(entry.id, '새이름');
      final registry = await service.loadRegistry();

      expect(success, isTrue);
      expect(registry.timetables.single.name, '새이름');
      expect(registry.timetables.single.hash, 'h1');
    });

    test('removeTimetable은 활성 제거 시 activeId를 해제한다', () async {
      final entry = await service.registerTimetable(
        name: 'A',
        fileName: 'a.xlsx',
        filePath: '/a.xlsx',
        hash: 'h1',
        contentHash: 'c1',
      );

      await service.removeTimetable(entry.id);
      final registry = await service.loadRegistry();

      expect(registry.timetables, isEmpty);
      expect(registry.activeId, isNull);
    });

    test('removeTimetable은 비활성 제거 시 활성을 유지한다', () async {
      final first = await service.registerTimetable(
        name: 'A',
        fileName: 'a.xlsx',
        filePath: '/a.xlsx',
        hash: 'h1',
        contentHash: 'c1',
      );
      final second = await service.registerTimetable(
        name: 'B',
        fileName: 'b.xlsx',
        filePath: '/b.xlsx',
        hash: 'h2',
        contentHash: 'c2',
      );

      await service.removeTimetable(second.id);
      final registry = await service.loadRegistry();

      expect(registry.activeId, first.id);
      expect(registry.timetables.single.id, first.id);
    });

    test('다른 서비스 인스턴스도 같은 저장소 데이터를 조회한다', () async {
      final entry = await service.registerTimetable(
        name: 'A',
        fileName: 'a.xlsx',
        filePath: '/a.xlsx',
        hash: 'h1',
        contentHash: 'c1',
      );

      final other = TimetableRegistryService(storage: storage);
      final active = await other.getActiveEntry();

      expect(active?.id, entry.id);
    });
  });
}

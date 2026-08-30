import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/exchange_list_storage_service.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

import '../helpers/in_memory_json_storage.dart';

/// 테스트용 교체 항목 1건 생성
ExchangeHistoryItem _testItem(String label) {
  final targetSlot = TimeSlot(
    teacher: '교사B',
    subject: '국어',
    className: '1-2',
    dayOfWeek: 2,
    period: 2,
  );
  final path = OneToOneExchangePath(
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
    option: ExchangeOption(
      timeSlot: targetSlot,
      teacherName: '교사B',
      type: ExchangeType.sameClass,
      priority: 1,
      reason: 'test',
    ),
  );

  return ExchangeHistoryItem.fromExchangePath(
    path,
    absenceDate: DateTime(2026, 8, 24),
    substitutionDate: DateTime(2026, 8, 25),
    customDescription: '테스트 교체 $label',
  );
}

void main() {
  const timetableId = 'tt_test';
  final filename = ExchangeListStorageService.fileNameFor(timetableId);
  final backupName = '$filename${ExchangeListStorageService.legacyBackupSuffix}';

  late InMemoryJsonStorage storage;
  late ExchangeListStorageService service;

  setUp(() {
    storage = InMemoryJsonStorage();
    service = ExchangeListStorageService(storage: storage);
  });

  group('ExchangeListStorageService §10.6 스키마 버전', () {
    test('저장 후 로드하면 동일한 항목을 그대로 복원한다 (날짜 필드 포함)', () async {
      final items = [_testItem('1'), _testItem('2')];

      final saved = await service.saveExchangeList(
        items,
        timetableId: timetableId,
      );
      expect(saved, isTrue);

      final result = await service.loadExchangeList(timetableId: timetableId);

      expect(result.legacyBackupPerformed, isFalse);
      expect(result.items.length, 2);
      expect(result.items[0].absenceDate, DateTime(2026, 8, 24));
      expect(result.items[0].substitutionDate, DateTime(2026, 8, 25));
    });

    test('저장된 파일은 schemaVersion과 items를 담은 객체다', () async {
      await service.saveExchangeList([_testItem('1')], timetableId: timetableId);

      final raw = storage.files[filename] as Map;
      expect(raw['schemaVersion'], ExchangeListStorageService.currentSchemaVersion);
      expect(raw['items'], isA<List>());
    });

    test('파일이 없으면 빈 목록 + 백업 없음 (정상 첫 실행)', () async {
      final result = await service.loadExchangeList(timetableId: timetableId);

      expect(result.items, isEmpty);
      expect(result.legacyBackupPerformed, isFalse);
      expect(storage.files.containsKey(backupName), isFalse);
    });

    test('구 스키마(최상위 배열) 파일이 있으면 백업 후 빈 목록으로 시작한다 (마이그레이션 없음)', () async {
      // §1~§9 시절 저장 형식: 최상위가 배열이고 날짜 필드가 없음
      storage.seedJson(filename, [
        {
          'id': 'legacy_1',
          'timestamp': DateTime(2026, 1, 1).toIso8601String(),
          'type': 'oneToOne',
          'description': '구 버전 교체',
          'metadata': {},
          'notes': null,
          'tags': <String>[],
          'profileId': null,
          'isReverted': false,
          'originalPath': _testItem('legacy').originalPath.toJson(),
        },
      ]);

      final result = await service.loadExchangeList(timetableId: timetableId);

      expect(result.items, isEmpty);
      expect(result.legacyBackupPerformed, isTrue);
      // 원본은 사라지고 백업 이름으로 보존됨
      expect(storage.files.containsKey(filename), isFalse);
      expect(storage.files.containsKey(backupName), isTrue);
    });

    test('schemaVersion이 낮은 객체 파일도 구 데이터로 취급해 백업한다', () async {
      storage.seedJson(filename, {'schemaVersion': 1, 'items': <dynamic>[]});

      final result = await service.loadExchangeList(timetableId: timetableId);

      expect(result.legacyBackupPerformed, isTrue);
      expect(storage.files.containsKey(backupName), isTrue);
    });

    test('timetableId가 없으면 저장·로드 모두 건너뛴다 (스코프 필수 정책)', () async {
      final saved = await service.saveExchangeList(
        [_testItem('1')],
        timetableId: null,
      );
      expect(saved, isFalse);

      final result = await service.loadExchangeList(timetableId: null);
      expect(result.items, isEmpty);
      expect(result.legacyBackupPerformed, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/services/storage_migration_service.dart';
import '../helpers/in_memory_json_storage.dart';

void main() {
  late InMemoryJsonStorage storage;
  late StorageMigrationService service;

  /// 구 버전 단일 시간표 메타데이터 시드
  void seedOldMetadata({String hash = '월계중_hash1', String contentHash = 'content1'}) {
    storage.seedJson('timetable_file_metadata.json', {
      'filePath': 'D:/시간표/2학기_전체시간표.xlsx',
      'fileName': '2학기_전체시간표.xlsx',
      'lastModified': '2026-08-20T09:00:00.000',
      'hash': hash,
      'contentHash': contentHash,
    });
  }

  setUp(() {
    storage = InMemoryJsonStorage();
    service = StorageMigrationService(
      storage: storage,
      generateTimetableId: () => 'tt_fixed_001',
      generateProfileId: () => 'pp_fixed_001',
    );
  });

  group('StorageMigrationService', () {
    test('신규 설치(파일 없음) → 빈 레지스트리 생성', () async {
      final result = await service.migrateIfNeeded();

      expect(result.migrated, isTrue);
      expect(result.initialTimetableId, isNull);

      final registryJson = await storage.loadJson('timetable_registry.json');
      expect(registryJson, isNotNull);
      expect(registryJson!['timetables'], isEmpty);
      expect(registryJson['activeId'], isNull);
    });

    test('구 메타데이터 존재 → 레지스트리 1건 생성 + 활성 지정', () async {
      seedOldMetadata();

      final result = await service.migrateIfNeeded();

      expect(result.migrated, isTrue);
      expect(result.initialTimetableId, 'tt_fixed_001');

      final registryJson = await storage.loadJson('timetable_registry.json');
      final timetables = registryJson!['timetables'] as List;
      expect(timetables.single['id'], 'tt_fixed_001');
      expect(timetables.single['name'], '2학기_전체시간표.xlsx');
      expect(timetables.single['hash'], '월계중_hash1');
      expect(registryJson['activeId'], 'tt_fixed_001');
    });

    test('구 교체 목록 → 시간표 스코프 파일로 복사, 원본 보존', () async {
      seedOldMetadata();
      storage.seedJson('exchange_list.json', [
        {'id': 'one_to_one_exchange_1', 'type': 'oneToOne'},
        {'id': 'circular_exchange_2', 'type': 'circular'},
      ]);

      await service.migrateIfNeeded();

      final scoped = await storage.loadJsonArray(
        'exchange_list_tt_fixed_001.json',
      );
      expect(scoped, isNotNull);
      expect(scoped!.length, 2);
      // 원본 보존
      expect(await storage.fileExists('exchange_list.json'), isTrue);
    });

    test('구 결보강 데이터 → 시간표 스코프 파일로 복사, 원본 보존', () async {
      seedOldMetadata();
      storage.seedJson('substitution_plan_data.json', {
        'savedDates': {'key1': '2026-08-27'},
      });

      await service.migrateIfNeeded();

      final scoped = await storage.loadJson(
        'substitution_plan_data_tt_fixed_001.json',
      );
      expect(scoped, isNotNull);
      expect(await storage.fileExists('substitution_plan_data.json'), isTrue);
    });

    test('구 PDF 양식 설정 2개 → 계획서 2개로 이전', () async {
      seedOldMetadata();
      storage.seedJson('pdf_export_settings_template_0.json', {
        'fontSize': 12.0,
        'remarksFontSize': 8.0,
        'selectedFont': 'gulim.ttc',
        'includeRemarks': true,
        'additionalFields': {'notes': '안내문'},
      });
      storage.seedJson('pdf_export_settings_template_1.json', {
        'fontSize': 11.0,
        'remarksFontSize': 7.0,
        'selectedFont': 'hanbatang.ttf',
        'includeRemarks': false,
        'additionalFields': {},
      });

      await service.migrateIfNeeded();

      final store = await storage.loadJson('print_profiles_tt_fixed_001.json');
      expect(store, isNotNull);
      final profiles = store!['profiles'] as List;
      expect(profiles.length, 2);
      expect(profiles[0]['name'], '양식 1');
      expect(profiles[0]['fontSize'], 12.0);
      expect(profiles[0]['additionalFields']['notes'], '안내문');
      expect(profiles[1]['name'], '양식 2');
    });

    test('PDF 설정 파일이 없어도 기본값 계획서 2개를 생성한다', () async {
      seedOldMetadata();

      await service.migrateIfNeeded();

      final store = await storage.loadJson('print_profiles_tt_fixed_001.json');
      final profiles = store!['profiles'] as List;
      expect(profiles.length, 2);
      expect(profiles[0]['fontSize'], 10.0); // 양식 1 기본값
    });

    test('이미 마이그레이션된 경우(레지스트리 존재) 아무 작업도 하지 않는다', () async {
      storage.seedJson('timetable_registry.json', {
        'activeId': 'tt_existing',
        'timetables': [
          {'id': 'tt_existing', 'name': '기존'},
        ],
      });
      seedOldMetadata();
      storage.seedJson('exchange_list.json', [
        {'id': 'legacy'},
      ]);
      final saveCountBefore = storage.saveCount;

      final result = await service.migrateIfNeeded();

      expect(result.migrated, isFalse);
      expect(result.initialTimetableId, isNull);
      expect(storage.saveCount, saveCountBefore);
      // 구 파일도 건드리지 않음
      expect(await storage.fileExists('exchange_list_tt_existing.json'), isFalse);
    });

    test('스코프 파일이 이미 있으면 덮어쓰지 않는다', () async {
      seedOldMetadata();
      storage.seedJson('exchange_list.json', [
        {'id': 'legacy'},
      ]);
      storage.seedJson('exchange_list_tt_fixed_001.json', [
        {'id': 'already_scoped'},
      ]);

      await service.migrateIfNeeded();

      final scoped = await storage.loadJsonArray(
        'exchange_list_tt_fixed_001.json',
      );
      expect(scoped!.single['id'], 'already_scoped');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/print_profile.dart';
import 'package:class_exchange_manager/services/print_profile_storage_service.dart';
import '../helpers/in_memory_json_storage.dart';

void main() {
  late InMemoryJsonStorage storage;
  late PrintProfileStorageService service;
  const timetableId = 'tt_20260826_143000_100';

  PrintProfile profile(String id, {String teacher = '홍길동', String name = '계획서1'}) {
    return PrintProfile(
      id: id,
      name: name,
      teacherName: teacher,
      templateIndex: 0,
      fontSize: 10.0,
      remarksFontSize: 7.0,
      selectedFont: 'hanbatang.ttf',
      includeRemarks: false,
    );
  }

  setUp(() {
    storage = InMemoryJsonStorage();
    service = PrintProfileStorageService(storage: storage);
  });

  group('PrintProfileStorageService', () {
    test('저장된 스토어가 없으면 빈 스토어를 반환한다', () async {
      final store = await service.loadStore(timetableId);

      expect(store.profiles, isEmpty);
      expect(store.lastUsedProfileId, isNull);
      expect(store.lastSelectedTeacher, isNull);
    });

    test('saveStore는 시간표별 스코프 파일명으로 저장한다', () async {
      await service.saveStore(
        timetableId,
        PrintProfileStore(profiles: [profile('pp_1')]),
      );

      expect(
        storage.files.containsKey('print_profiles_$timetableId.json'),
        isTrue,
      );
    });

    test('saveStore/loadStore 왕복', () async {
      final store = PrintProfileStore(
        profiles: [profile('pp_1'), profile('pp_2', teacher: '김철수')],
        lastUsedProfileId: 'pp_1',
        lastSelectedTeacher: '홍길동',
      );

      await service.saveStore(timetableId, store);
      final loaded = await service.loadStore(timetableId);

      expect(loaded.profiles.length, 2);
      expect(loaded.lastUsedProfileId, 'pp_1');
      expect(loaded.lastSelectedTeacher, '홍길동');
    });

    test('시간표가 다르면 별도 파일로 분리된다', () async {
      await service.saveStore(
        'tt_aaa',
        PrintProfileStore(profiles: [profile('pp_1')]),
      );
      await service.saveStore(
        'tt_bbb',
        PrintProfileStore(profiles: [profile('pp_2', teacher: '김철수')]),
      );

      final a = await service.loadStore('tt_aaa');
      final b = await service.loadStore('tt_bbb');

      expect(a.profiles.single.id, 'pp_1');
      expect(b.profiles.single.id, 'pp_2');
    });

    test('saveProfile은 새 계획서를 추가한다', () async {
      await service.saveProfile(timetableId, profile('pp_1'));
      await service.saveProfile(
        timetableId,
        profile('pp_2', name: '계획서2'),
      );

      final store = await service.loadStore(timetableId);
      expect(store.profiles.map((p) => p.id), ['pp_1', 'pp_2']);
    });

    test('saveProfile은 같은 ID면 갱신한다', () async {
      await service.saveProfile(timetableId, profile('pp_1'));
      await service.saveProfile(
        timetableId,
        profile('pp_1', name: '수정된이름'),
      );

      final store = await service.loadStore(timetableId);
      expect(store.profiles.length, 1);
      expect(store.profiles.single.name, '수정된이름');
    });

    test('deleteProfile은 계획서를 제거하고 lastUsedProfileId를 정리한다', () async {
      await service.saveStore(
        timetableId,
        PrintProfileStore(
          profiles: [profile('pp_1'), profile('pp_2')],
          lastUsedProfileId: 'pp_1',
        ),
      );

      await service.deleteProfile(timetableId, 'pp_1');
      final store = await service.loadStore(timetableId);

      expect(store.profiles.map((p) => p.id), ['pp_2']);
      expect(store.lastUsedProfileId, isNull);
    });

    test('deleteProfile은 다른 계획서를 가리키는 lastUsedProfileId를 유지한다', () async {
      await service.saveStore(
        timetableId,
        PrintProfileStore(
          profiles: [profile('pp_1'), profile('pp_2')],
          lastUsedProfileId: 'pp_2',
        ),
      );

      await service.deleteProfile(timetableId, 'pp_1');
      final store = await service.loadStore(timetableId);

      expect(store.lastUsedProfileId, 'pp_2');
    });

    test('renameProfile은 이름만 변경한다', () async {
      await service.saveProfile(timetableId, profile('pp_1'));

      await service.renameProfile(timetableId, 'pp_1', '새계획서');
      final store = await service.loadStore(timetableId);

      expect(store.profiles.single.name, '새계획서');
    });

    test('setLastSelectedTeacher를 저장한다', () async {
      await service.setLastSelectedTeacher(timetableId, '홍길동');
      await service.setLastSelectedTeacher(timetableId, '김철수');

      final store = await service.loadStore(timetableId);
      expect(store.lastSelectedTeacher, '김철수');
    });

    test('clearStore는 스코프 파일을 삭제한다', () async {
      await service.saveStore(
        timetableId,
        PrintProfileStore(profiles: [profile('pp_1')]),
      );

      await service.clearStore(timetableId);

      expect(await storage.fileExists('print_profiles_$timetableId.json'), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/print_profile.dart';

void main() {
  PrintProfile profile({String id = 'pp_1', String teacher = '홍길동'}) {
    return PrintProfile(
      id: id,
      name: '계획서1',
      teacherName: teacher,
      templateIndex: 1,
      fontSize: 11.0,
      remarksFontSize: 7.5,
      selectedFont: 'gulim.ttc',
      includeRemarks: true,
      additionalFields: {'notes': '비고 내용', 'teacherName': '홍길동'},
      selectedTemplateFilePath: 'D:/templates/a.pdf',
    );
  }

  group('PrintProfile', () {
    test('generateId는 pp_ 접두사와 타임스탬프 형식을 가진다', () {
      final id = PrintProfile.generateId(now: DateTime(2026, 8, 26, 15, 0, 0));

      expect(id, startsWith('pp_20260826_150000_'));
    });

    test('generateId는 연속 호출 시 서로 다른 값을 반환한다', () {
      final ids = List.generate(50, (_) => PrintProfile.generateId());
      expect(ids.toSet().length, ids.length);
    });

    test('JSON 직렬화/역직렬화 왕복', () {
      final original = profile().copyWith(
        deselectedGroupIds: const ['ex_1', 'ex_2'],
      );
      final restored = PrintProfile.fromJson(original.toJson());

      expect(restored.id, 'pp_1');
      expect(restored.name, '계획서1');
      expect(restored.teacherName, '홍길동');
      expect(restored.templateIndex, 1);
      expect(restored.fontSize, 11.0);
      expect(restored.remarksFontSize, 7.5);
      expect(restored.selectedFont, 'gulim.ttc');
      expect(restored.includeRemarks, isTrue);
      expect(restored.additionalFields, {'notes': '비고 내용', 'teacherName': '홍길동'});
      expect(restored.selectedTemplateFilePath, 'D:/templates/a.pdf');
      expect(restored.deselectedGroupIds, ['ex_1', 'ex_2']);
    });

    test('fromJson은 additionalFields의 동적 값을 문자열로 강제한다', () {
      final restored = PrintProfile.fromJson({
        'id': 'pp_1',
        'additionalFields': {'notes': 123, 'flag': true},
      });

      expect(restored.additionalFields['notes'], '123');
      expect(restored.additionalFields['flag'], 'true');
    });

    test('fromJson은 누락 필드를 기본값으로 채운다', () {
      final restored = PrintProfile.fromJson({'id': 'pp_1'});

      expect(restored.name, '');
      expect(restored.teacherName, '');
      expect(restored.templateIndex, 0);
      expect(restored.fontSize, 10.0);
      expect(restored.selectedFont, 'hanbatang.ttf');
      expect(restored.includeRemarks, isFalse);
      expect(restored.selectedTemplateFilePath, isNull);
      expect(restored.deselectedGroupIds, isEmpty);
    });

    test('isGroupSelected는 제외 목록에 없으면 true', () {
      final p = profile().copyWith(deselectedGroupIds: const ['a']);
      expect(p.isGroupSelected('a'), isFalse);
      expect(p.isGroupSelected('b'), isTrue);
    });

    test('copyWith clearTemplateFilePath는 경로를 제거한다', () {
      final cleared = profile().copyWith(clearTemplateFilePath: true);

      expect(cleared.selectedTemplateFilePath, isNull);
    });

    test('copyWith는 ID를 변경하지 않는다', () {
      final updated = profile().copyWith(name: '계획서2');

      expect(updated.id, 'pp_1');
      expect(updated.name, '계획서2');
    });
  });

  group('PrintProfileStore', () {
    test('byTeacher는 해당 교사의 계획서만 반환한다', () {
      final store = PrintProfileStore(profiles: [
        profile(id: 'pp_1', teacher: '홍길동'),
        profile(id: 'pp_2', teacher: '김철수'),
        profile(id: 'pp_3', teacher: '홍길동'),
      ]);

      final hong = store.byTeacher('홍길동');

      expect(hong.map((p) => p.id), ['pp_1', 'pp_3']);
    });

    test('teacherNames는 등장 순으로 중복 없이 반환한다', () {
      final store = PrintProfileStore(profiles: [
        profile(id: 'pp_1', teacher: '홍길동'),
        profile(id: 'pp_2', teacher: '김철수'),
        profile(id: 'pp_3', teacher: '홍길동'),
      ]);

      expect(store.teacherNames, ['홍길동', '김철수']);
    });

    test('getById는 없는 ID에 null을 반환한다', () {
      final store = PrintProfileStore(profiles: [profile(id: 'pp_1')]);

      expect(store.getById('pp_1'), isNotNull);
      expect(store.getById('없는id'), isNull);
      expect(store.getById(null), isNull);
    });

    test('JSON 직렬화/역직렬화 왕복', () {
      final store = PrintProfileStore(
        profiles: [profile()],
        lastUsedProfileId: 'pp_1',
        lastSelectedTeacher: '홍길동',
      );

      final restored = PrintProfileStore.fromJson(store.toJson());

      expect(restored.profiles.length, 1);
      expect(restored.profiles.first.id, 'pp_1');
      expect(restored.lastUsedProfileId, 'pp_1');
      expect(restored.lastSelectedTeacher, '홍길동');
    });

    test('copyWith clearLastUsedProfileId는 값을 해제한다', () {
      final store = PrintProfileStore(
        profiles: [profile()],
        lastUsedProfileId: 'pp_1',
      );

      final cleared = store.copyWith(clearLastUsedProfileId: true);

      expect(cleared.lastUsedProfileId, isNull);
    });
  });
}

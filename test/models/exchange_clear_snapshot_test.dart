import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/exchange_clear_snapshot.dart';
import 'package:class_exchange_manager/models/print_profile.dart';

PrintProfile _profile(String id, {String name = '계획서'}) => PrintProfile(
  id: id,
  name: name,
  teacherName: '김교사',
  templateIndex: 0,
  fontSize: 10,
  remarksFontSize: 8,
  selectedFont: 'Malgun',
  includeRemarks: true,
);

List<String> _ids(PrintProfileStore s) => s.profiles.map((p) => p.id).toList();

void main() {
  group('PrintProfileStore.mergeRestored', () {
    test('그 사이 만든 계획서를 유지하고 복원분을 덧붙인다', () {
      final store = PrintProfileStore(profiles: [_profile('new')]);
      final merged = store.mergeRestored([_profile('old')]);
      expect(_ids(merged), ['new', 'old']);
    });

    test('같은 id가 있으면 덮어쓰지 않는다', () {
      final store = PrintProfileStore(profiles: [_profile('a', name: '현재')]);
      final merged = store.mergeRestored([_profile('a', name: '복원')]);
      expect(merged.profiles, hasLength(1));
      expect(merged.profiles.single.name, '현재');
    });

    test('lastUsedProfileId는 현재 값이 null일 때만 채운다', () {
      final empty = const PrintProfileStore().mergeRestored(
        [],
        lastUsedProfileId: 'old',
        lastSelectedTeacher: '박교사',
      );
      expect(empty.lastUsedProfileId, 'old');
      expect(empty.lastSelectedTeacher, '박교사');

      final set = const PrintProfileStore(
        lastUsedProfileId: 'cur',
        lastSelectedTeacher: '이교사',
      ).mergeRestored([], lastUsedProfileId: 'old', lastSelectedTeacher: '박교사');
      expect(set.lastUsedProfileId, 'cur');
      expect(set.lastSelectedTeacher, '이교사');
    });
  });

  group('PrintProfileStore.withoutProfiles', () {
    test('마지막 사용 계획서가 빠지면 lastUsedProfileId를 비운다', () {
      final store = PrintProfileStore(
        profiles: [_profile('a'), _profile('b')],
        lastUsedProfileId: 'a',
      );
      final out = store.withoutProfiles({'a'});
      expect(_ids(out), ['b']);
      expect(out.lastUsedProfileId, isNull);
    });

    test('다른 계획서가 빠지면 lastUsedProfileId를 유지한다', () {
      final store = PrintProfileStore(
        profiles: [_profile('a'), _profile('b')],
        lastUsedProfileId: 'a',
      );
      expect(store.withoutProfiles({'b'}).lastUsedProfileId, 'a');
    });
  });

  group('ExchangeClearSnapshot.recapture', () {
    test('자기 id·키만 현재 값으로 다시 뜨고 사용자가 지운 것은 뺀다', () {
      final snap = ExchangeClearSnapshot(
        profiles: [_profile('a', name: '옛A'), _profile('b', name: '옛B')],
        lastUsedProfileId: 'a',
        lastSelectedTeacher: '박교사',
        supplementSubjects: const {'k1': '수학', 'k2': '영어'},
      );
      final store = PrintProfileStore(
        profiles: [_profile('a', name: '새A'), _profile('other')],
        lastUsedProfileId: 'a',
      );
      final re = snap.recapture(
        store: store,
        supplementSubjects: const {'k1': '과학', 'k3': '음악'},
      );
      expect(_ids(PrintProfileStore(profiles: re.profiles)), ['a']);
      expect(re.profiles.single.name, '새A');
      expect(re.lastUsedProfileId, 'a');
      expect(re.lastSelectedTeacher, '박교사');
      expect(re.supplementSubjects, {'k1': '과학'});
    });

    test('현재 lastUsedProfileId가 자기 것이 아니면 null', () {
      final snap = ExchangeClearSnapshot(profiles: [_profile('a')]);
      final re = snap.recapture(
        store: PrintProfileStore(
          profiles: [_profile('a'), _profile('z')],
          lastUsedProfileId: 'z',
        ),
        supplementSubjects: const {},
      );
      expect(re.lastUsedProfileId, isNull);
    });
  });
}

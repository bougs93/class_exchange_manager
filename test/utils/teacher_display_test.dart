import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/teacher.dart';
import 'package:class_exchange_manager/utils/teacher_display.dart';

void main() {
  group('plainTeacherName', () {
    test('끝의 원숫자를 제거한다', () {
      expect(plainTeacherName('김철수①'), '김철수');
      expect(plainTeacherName('김철수②'), '김철수');
      expect(plainTeacherName('김철수⑳'), '김철수');
    });

    test('번호가 없는 이름은 그대로 둔다', () {
      expect(plainTeacherName('김철수'), '김철수');
      expect(plainTeacherName(''), '');
    });

    test('중간의 원숫자는 유지한다', () {
      expect(plainTeacherName('김①철수'), '김①철수');
    });

    test('원숫자만 있는 문자열은 이름을 지우지 않는다', () {
      expect(plainTeacherName('①'), '①');
    });

    test('20명을 넘는 동명이인의 (n) 형태도 제거한다', () {
      expect(plainTeacherName('김철수(21)'), '김철수');
    });
  });

  group('uniqueTeacherNames', () {
    test('동명이인이 없으면 이름을 그대로 돌려준다', () {
      expect(uniqueTeacherNames(['가', '나', '다']), ['가', '나', '다']);
    });

    test('동명이인 모두에게 등장 순서대로 번호를 붙인다', () {
      expect(uniqueTeacherNames(['김철수', '이영희', '김철수']), [
        '김철수①',
        '이영희',
        '김철수②',
      ]);
    });

    test('세 명 이상도 순서대로 붙인다', () {
      expect(uniqueTeacherNames(['김철수', '김철수', '김철수']), [
        '김철수①',
        '김철수②',
        '김철수③',
      ]);
    });

    test('20명을 넘으면 (n) 형태로 이어 붙인다', () {
      final names = uniqueTeacherNames(List.filled(21, '김철수'));
      expect(names[19], '김철수⑳');
      expect(names[20], '김철수(21)');
    });
  });

  group('duplicateTeacherNotice', () {
    test('동명이인이 있으면 행 번호가 든 안내 문구를 만든다', () {
      final teachers = [
        Teacher(name: '김철수①', subject: '', sourceRow: 12),
        Teacher(name: '이영희', subject: '', sourceRow: 20),
        Teacher(name: '김철수②', subject: '', sourceRow: 40),
      ];
      expect(
        duplicateTeacherNotice(teachers),
        '동명이인 1건을 구분해서 불러왔습니다: 김철수①(12행), 김철수②(40행)',
      );
    });

    test('동명이인이 여러 쌍이면 건수를 센다', () {
      final teachers = [
        Teacher(name: '김철수①', subject: '', sourceRow: 4),
        Teacher(name: '김철수②', subject: '', sourceRow: 5),
        Teacher(name: '이영희①', subject: '', sourceRow: 6),
        Teacher(name: '이영희②', subject: '', sourceRow: 7),
      ];
      expect(duplicateTeacherNotice(teachers), startsWith('동명이인 2건을'));
    });

    test('동명이인이 없으면 null이다', () {
      final teachers = [Teacher(name: '가', subject: '', sourceRow: 4)];
      expect(duplicateTeacherNotice(teachers), isNull);
    });
  });

  group('findDuplicateTeacherGroups', () {
    test('동명이인만 plain 이름별로 묶는다', () {
      final teachers = [
        Teacher(name: '김철수①', subject: ''),
        Teacher(name: '이영희', subject: ''),
        Teacher(name: '김철수②', subject: ''),
      ];
      expect(findDuplicateTeacherGroups(teachers), {
        '김철수': ['김철수①', '김철수②'],
      });
    });

    test('동명이인이 없으면 비어 있다', () {
      final teachers = [Teacher(name: '가', subject: '')];
      expect(findDuplicateTeacherGroups(teachers), isEmpty);
    });
  });
}

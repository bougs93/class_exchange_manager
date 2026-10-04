import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/notice_message.dart';
import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/utils/notice_message_generator.dart';
import 'package:class_exchange_manager/utils/substitution_plan_field_accessor.dart';

/// 동명이인 교사(`김철수①`, `김철수②`)는 앱 안에서는 구분되지만, 사람에게 나가는
/// 문서(안내 문구·PDF)에는 원숫자 없이 실제 이름만 나와야 한다.
void main() {
  /// 김철수①(수학) ↔ 김철수②(영어) 1:1 교체
  SubstitutionPlanData sameNameExchange() => SubstitutionPlanData(
    exchangeId: 'e1',
    absenceDate: '2026.10.07',
    absenceDay: '수',
    period: '2',
    grade: '3',
    className: '7',
    subject: '수학',
    teacher: '김철수①',
    supplementSubject: '',
    supplementTeacher: '',
    substitutionDate: '2026.10.06',
    substitutionDay: '화',
    substitutionPeriod: '6',
    substitutionSubject: '영어',
    substitutionTeacher: '김철수②',
    remarks: '',
    groupId: 'one_to_one_exchange_e1',
  );

  SubstitutionPlanData supplement() => SubstitutionPlanData(
    exchangeId: 'e2',
    absenceDate: '2026.10.07',
    absenceDay: '수',
    period: '3',
    grade: '3',
    className: '7',
    subject: '수학',
    teacher: '김철수①',
    supplementSubject: '영어',
    supplementTeacher: '김철수②',
    substitutionDate: '',
    substitutionDay: '',
    substitutionPeriod: '',
    substitutionSubject: '',
    substitutionTeacher: '',
    remarks: '',
  );

  group('SubstitutionPlanData plain getter', () {
    test('원숫자를 뗀 이름을 돌려주고 원본 키는 그대로 둔다', () {
      final data = sameNameExchange();

      expect(data.plainTeacher, '김철수');
      expect(data.plainSubstitutionTeacher, '김철수');
      expect(data.teacher, '김철수①');
      expect(data.substitutionTeacher, '김철수②');
    });
  });

  group('교사 안내 문구', () {
    for (final option in MessageOption.values) {
      test('${option.name}: 호칭과 본문에 원숫자가 없고 그룹은 두 사람으로 나뉜다', () {
        final groups = NoticeMessageGenerator.generateTeacherMessages([
          sameNameExchange(),
        ], option);

        // 그룹핑은 키 그대로 → 서로 다른 두 교사
        expect(groups.map((g) => g.groupIdentifier).toSet(), {'김철수①', '김철수②'});
        for (final group in groups) {
          final content = group.messages.single.content;
          expect(content, startsWith('김철수 선생님'));
          expect(content, isNot(contains('①')));
          expect(content, isNot(contains('②')));
        }
      });
    }

    test('보강 안내에도 원숫자가 없다', () {
      final groups = NoticeMessageGenerator.generateTeacherMessages([
        supplement(),
      ], MessageOption.option3);

      expect(groups, hasLength(2));
      for (final group in groups) {
        expect(group.messages.single.content, isNot(contains('①')));
        expect(group.messages.single.content, isNot(contains('②')));
      }
    });
  });

  group('학급 안내 문구', () {
    for (final option in MessageOption.values) {
      test('${option.name}: 원숫자 없이 실제 이름만 나온다', () {
        final groups = NoticeMessageGenerator.generateClassMessages([
          sameNameExchange(),
        ], option);

        expect(groups, isNotEmpty);
        for (final group in groups) {
          for (final message in group.messages) {
            expect(message.content, contains('김철수'));
            expect(message.content, isNot(contains('①')));
            expect(message.content, isNot(contains('②')));
          }
        }
      });
    }
  });

  group('PDF 필드 접근자', () {
    test('교사 필드 3종에서 원숫자를 뗀다', () {
      final data = SubstitutionPlanData(
        exchangeId: 'e3',
        absenceDate: '2026.10.07',
        absenceDay: '수',
        period: '2',
        grade: '3',
        className: '7',
        subject: '수학',
        teacher: '김철수①',
        supplementSubject: '영어',
        supplementTeacher: '김철수②',
        substitutionDate: '2026.10.06',
        substitutionDay: '화',
        substitutionPeriod: '6',
        substitutionSubject: '영어',
        substitutionTeacher: '김철수②',
        remarks: '',
      );

      expect(SubstitutionPlanFieldAccessor.getValue(data, 'teacher'), '김철수');
      expect(
        SubstitutionPlanFieldAccessor.getValue(data, 'supplementTeacher'),
        '김철수',
      );
      expect(
        SubstitutionPlanFieldAccessor.getValue(data, 'substitutionTeacher'),
        '김철수',
      );
    });

    test('동명이인이 아닌 교사 이름은 그대로 나온다', () {
      final data = sameNameExchange().copyWith(
        teacher: '이영희',
        substitutionTeacher: '박민수',
      );

      expect(SubstitutionPlanFieldAccessor.getValue(data, 'teacher'), '이영희');
      expect(
        SubstitutionPlanFieldAccessor.getValue(data, 'substitutionTeacher'),
        '박민수',
      );
    });
  });
}

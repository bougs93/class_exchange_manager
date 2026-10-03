import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/utils/notice_message_generator.dart';
import 'package:class_exchange_manager/models/notice_message.dart';

/// 리팩토링(파일 분리) 전 현재 동작을 고정하는 특성화(characterization) 테스트.
///
/// NoticeMessageGenerator가 lib/utils/notice/ 하위 파일들로 쪼개지더라도
/// generateClassMessages / generateTeacherMessages의 출력 문자열이
/// 전혀 바뀌지 않았음을 보장하기 위한 안전망이다.
void main() {
  SubstitutionPlanData basic({
    required String exchangeId,
    required String absenceDate,
    required String absenceDay,
    required String period,
    required String subject,
    required String teacher,
    required String substitutionDate,
    required String substitutionDay,
    required String substitutionPeriod,
    required String substitutionSubject,
    required String substitutionTeacher,
    String grade = '3',
    String className = '7',
    String groupId = '',
  }) {
    return SubstitutionPlanData(
      exchangeId: exchangeId,
      absenceDate: absenceDate,
      absenceDay: absenceDay,
      period: period,
      grade: grade,
      className: className,
      subject: subject,
      teacher: teacher,
      supplementSubject: '',
      supplementTeacher: '',
      substitutionDate: substitutionDate,
      substitutionDay: substitutionDay,
      substitutionPeriod: substitutionPeriod,
      substitutionSubject: substitutionSubject,
      substitutionTeacher: substitutionTeacher,
      remarks: '',
      groupId: groupId.isEmpty ? 'one_to_one_exchange_$exchangeId' : groupId,
    );
  }

  SubstitutionPlanData supplement({
    required String exchangeId,
    required String absenceDate,
    required String absenceDay,
    required String period,
    required String subject,
    required String teacher,
    required String supplementSubject,
    required String supplementTeacher,
    String grade = '2',
    String className = '3',
  }) {
    return SubstitutionPlanData(
      exchangeId: exchangeId,
      absenceDate: absenceDate,
      absenceDay: absenceDay,
      period: period,
      grade: grade,
      className: className,
      subject: subject,
      teacher: teacher,
      supplementSubject: supplementSubject,
      supplementTeacher: supplementTeacher,
      substitutionDate: '',
      substitutionDay: '',
      substitutionPeriod: '',
      substitutionSubject: '',
      substitutionTeacher: '',
      remarks: '',
      groupId: 'supplement_exchange_$exchangeId',
    );
  }

  final basicData = basic(
    exchangeId: 'e1',
    absenceDate: '2026.10.07',
    absenceDay: '수',
    period: '2',
    subject: '기술가정',
    teacher: '정원길',
    substitutionDate: '2026.10.06',
    substitutionDay: '화',
    substitutionPeriod: '6',
    substitutionSubject: '수학',
    substitutionTeacher: '정호성',
  );

  final supplementData = supplement(
    exchangeId: 's1',
    absenceDate: '2026.10.08',
    absenceDay: '목',
    period: '3',
    subject: '국어',
    teacher: '김국어',
    supplementSubject: '도덕',
    supplementTeacher: '이도덕',
  );

  // 순환교체 4단계 그룹: A -> B -> C -> A (각자 자기 과목을 들고 이동)
  final circularA = basic(
    exchangeId: 'c1',
    absenceDate: '2026.10.01',
    absenceDay: '목',
    period: '1',
    subject: '물리',
    teacher: '순환A',
    substitutionDate: '2026.10.01',
    substitutionDay: '목',
    substitutionPeriod: '1',
    substitutionSubject: '화학',
    substitutionTeacher: '순환B',
    grade: '1',
    className: '1',
    groupId: 'circular_exchange_4_g1',
  );
  final circularB = basic(
    exchangeId: 'c2',
    absenceDate: '2026.10.02',
    absenceDay: '금',
    period: '2',
    subject: '화학',
    teacher: '순환B',
    substitutionDate: '2026.10.02',
    substitutionDay: '금',
    substitutionPeriod: '2',
    substitutionSubject: '생물',
    substitutionTeacher: '순환C',
    grade: '1',
    className: '1',
    groupId: 'circular_exchange_4_g1',
  );
  final circularC = basic(
    exchangeId: 'c3',
    absenceDate: '2026.10.03',
    absenceDay: '토',
    period: '3',
    subject: '생물',
    teacher: '순환C',
    substitutionDate: '2026.10.03',
    substitutionDay: '토',
    substitutionPeriod: '3',
    substitutionSubject: '물리',
    substitutionTeacher: '순환A',
    grade: '1',
    className: '1',
    groupId: 'circular_exchange_4_g1',
  );
  final circularGroup = [circularA, circularB, circularC];

  // 2중교체 그룹: 중간 단계(Ta<->Tb), 최종 단계(Tc<->Td)
  final dualIntermediate = SubstitutionPlanData(
    exchangeId: 'd1',
    absenceDate: '2026.10.10',
    absenceDay: '토',
    period: '1',
    grade: '4',
    className: '2',
    subject: '과학',
    teacher: 'Ta',
    supplementSubject: '',
    supplementTeacher: '',
    substitutionDate: '2026.10.11',
    substitutionDay: '일',
    substitutionPeriod: '2',
    substitutionSubject: '영어',
    substitutionTeacher: 'Tb',
    remarks: '2중교체(중간)',
    groupId: 'dual_exchange_g2',
  );
  final dualFinal = SubstitutionPlanData(
    exchangeId: 'd2',
    absenceDate: '2026.10.12',
    absenceDay: '월',
    period: '3',
    grade: '4',
    className: '2',
    subject: '수학',
    teacher: 'Tc',
    supplementSubject: '',
    supplementTeacher: '',
    substitutionDate: '2026.10.13',
    substitutionDay: '화',
    substitutionPeriod: '4',
    substitutionSubject: '미술',
    substitutionTeacher: 'Td',
    remarks: '2중교체(최종)',
    groupId: 'dual_exchange_g2',
  );

  group('generateClassMessages', () {
    test('1:1 교체 - option1(질문)', () {
      final groups = NoticeMessageGenerator.generateClassMessages([
        basicData,
      ], MessageOption.option1);
      expect(groups, hasLength(1));
      expect(groups.first.groupIdentifier, '3-7');
      expect(
        groups.first.messages.single.content,
        "3-7 수업변경 안내\n10.07 수 2교시 3-7 기술가정 정원길 <-> 10.06 화 6교시 3-7 수학 정호성 교체 가능하신지요?",
      );
    });

    test('1:1 교체 - option2(교체 안내)', () {
      final groups = NoticeMessageGenerator.generateClassMessages([
        basicData,
      ], MessageOption.option2);
      expect(
        groups.first.messages.single.content,
        "3-7 수업변경 안내\n10.07 수 2교시 3-7 기술가정 정원길 <-> 10.06 화 6교시 3-7 수학 정호성",
      );
    });

    test('1:1 교체 - option3(수업 안내)', () {
      final groups = NoticeMessageGenerator.generateClassMessages([
        basicData,
      ], MessageOption.option3);
      expect(
        groups.first.messages.single.content,
        "3-7 수업변경 안내\n10.07 수 2교시 3-7 수학 정호성\n10.06 화 6교시 3-7 기술가정 정원길",
      );
    });

    test('보강 - option3(수업 안내)', () {
      final groups = NoticeMessageGenerator.generateClassMessages([
        supplementData,
      ], MessageOption.option3);
      expect(groups.first.groupIdentifier, '2-3');
      expect(
        groups.first.messages.single.content,
        "2-3 수업변경 안내\n'10.08 목 3교시 2-3 도덕 이도덕' 수업입니다.",
      );
    });

    test('순환교체 4단계 - option2(교체 안내)', () {
      final groups = NoticeMessageGenerator.generateClassMessages(
        circularGroup,
        MessageOption.option2,
      );
      expect(groups, hasLength(1));
      expect(groups.first.groupIdentifier, '1-1');
      final content = groups.first.messages.single.content;
      expect(content, startsWith('1-1 수업변경 안내\n'));
      expect(
        content,
        "1-1 수업변경 안내\n"
        "'10.01 목 1교시 1-1 화학 순환B' -> '10.01 목 1교시 1-1 물리 순환A'\n"
        "'10.02 금 2교시 1-1 생물 순환C' -> '10.02 금 2교시 1-1 화학 순환B'\n"
        "'10.03 토 3교시 1-1 물리 순환A' -> '10.03 토 3교시 1-1 생물 순환C'",
      );
    });
  });

  group('generateTeacherMessages', () {
    test('1:1 교체 - option1(질문)', () {
      final group = NoticeMessageGenerator.generateTeacherMessages([
        basicData,
      ], MessageOption.option1).firstWhere((g) => g.groupIdentifier == '정원길');
      expect(
        group.messages.single.content,
        "정원길 선생님\n10.07 수 2교시 3-7 기술가정 정원길 <-> 10.06 화 6교시 3-7 수학 정호성 수업 교체 가능할까요?",
      );
    });

    test('1:1 교체 - option2(교체 안내)', () {
      final group = NoticeMessageGenerator.generateTeacherMessages([
        basicData,
      ], MessageOption.option2).firstWhere((g) => g.groupIdentifier == '정원길');
      expect(
        group.messages.single.content,
        "정원길 선생님\n10.07 수 2교시 3-7 기술가정 정원길 <-> 10.06 화 6교시 3-7 수학 정호성 수업 교체되었습니다.",
      );
    });

    test('보강 - option1(질문), 결강 교사', () {
      final group = NoticeMessageGenerator.generateTeacherMessages([
        supplementData,
      ], MessageOption.option1).firstWhere((g) => g.groupIdentifier == '김국어');
      expect(
        group.messages.single.content,
        "김국어 선생님\n10.08 목 3교시 2-3 국어 결강 - 대체 가능하신지요?",
      );
    });

    test('보강 - option1(질문), 보강 교사', () {
      final group = NoticeMessageGenerator.generateTeacherMessages([
        supplementData,
      ], MessageOption.option1).firstWhere((g) => g.groupIdentifier == '이도덕');
      expect(
        group.messages.single.content,
        "이도덕 선생님\n10.08 목 3교시 2-3 도덕 보강 수업 가능하신지요?",
      );
    });

    test('보강 - option3(수업 안내)', () {
      final teacherGroup = NoticeMessageGenerator.generateTeacherMessages([
        supplementData,
      ], MessageOption.option3).firstWhere((g) => g.groupIdentifier == '김국어');
      expect(
        teacherGroup.messages.single.content,
        "김국어 선생님\n10.08 목 3교시 2-3 국어 결강 되었습니다.",
      );

      final supplementGroup = NoticeMessageGenerator.generateTeacherMessages([
        supplementData,
      ], MessageOption.option3).firstWhere((g) => g.groupIdentifier == '이도덕');
      expect(
        supplementGroup.messages.single.content,
        "이도덕 선생님\n10.08 목 3교시 2-3 도덕 보강 수업입니다.",
      );
    });

    test('순환교체 4단계 - option2(교체 안내)', () {
      final group = NoticeMessageGenerator.generateTeacherMessages(
        circularGroup,
        MessageOption.option2,
      ).firstWhere((g) => g.groupIdentifier == '순환A');
      expect(
        group.messages.single.content,
        "순환A 선생님\n10.01 목 1교시 -> 10.03 토 3교시 물리 1-1 이동 되었습니다.",
      );
    });

    test('순환교체 4단계 - option3(수업 안내)', () {
      final group = NoticeMessageGenerator.generateTeacherMessages(
        circularGroup,
        MessageOption.option3,
      ).firstWhere((g) => g.groupIdentifier == '순환B');
      expect(
        group.messages.single.content,
        "순환B 선생님\n10.02 금 2교시 -> 10.01 목 1교시 화학 1-1 이동 되었습니다.",
      );
    });

    test('2중교체 - option3(수업 안내), 중간 단계 원래 교사', () {
      final group = NoticeMessageGenerator.generateTeacherMessages([
        dualIntermediate,
        dualFinal,
      ], MessageOption.option3).firstWhere((g) => g.groupIdentifier == 'Ta');
      expect(
        group.messages.single.content,
        "Ta 선생님\n10.11 일 2교시 과학 4-2 수업입니다.",
      );
    });

    test('2중교체 - option3(수업 안내), 중간 단계 교체 교사', () {
      final group = NoticeMessageGenerator.generateTeacherMessages([
        dualIntermediate,
        dualFinal,
      ], MessageOption.option3).firstWhere((g) => g.groupIdentifier == 'Tb');
      expect(
        group.messages.single.content,
        "Tb 선생님\n10.10 토 1교시 영어 4-2 수업입니다.\n10.11 일 2교시 영어 4-2 결강입니다.",
      );
    });

    test('2중교체 - option3(수업 안내), 최종 단계 원래 교사', () {
      final group = NoticeMessageGenerator.generateTeacherMessages([
        dualIntermediate,
        dualFinal,
      ], MessageOption.option3).firstWhere((g) => g.groupIdentifier == 'Tc');
      expect(
        group.messages.single.content,
        "Tc 선생님\n10.12 월 3교시 수학 4-2 결강입니다.\n10.13 화 4교시 수학 4-2 수업입니다.",
      );
    });

    test('2중교체 - option3(수업 안내), 최종 단계 교체 교사', () {
      final group = NoticeMessageGenerator.generateTeacherMessages([
        dualIntermediate,
        dualFinal,
      ], MessageOption.option3).firstWhere((g) => g.groupIdentifier == 'Td');
      expect(
        group.messages.single.content,
        "Td 선생님\n10.12 월 3교시 미술 4-2 수업입니다.\n10.13 화 4교시 미술 4-2 결강입니다.",
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/utils/notice_message_generator.dart';
import 'package:class_exchange_manager/models/notice_message.dart';

/// 2026-09-30 버그 리포트 재현 테스트: "교사안내 > 수업안내"에서
/// (1) 결강/수업 줄이 행 단위가 아니라 실제 날짜·교시 순으로 뒤섞여 정렬되는지,
/// (2) "수업입니다" 줄이 그 시간에 실제로 수업하는 교사 자신의 과목을 쓰는지
/// (상대방 과목이 아니라)를 검증한다.
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
      groupId: 'one_to_one_exchange_$exchangeId',
    );
  }

  test('수업입니다 줄은 상대방 과목이 아니라 실제 수업하는 교사 자신의 과목을 쓴다', () {
    // 정원길(기술가정)이 정호성(수학) 자리로 이동한 1:1 교체.
    final data = basic(
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

    final wonGil = NoticeMessageGenerator.generateTeacherMessages(
      [data],
      MessageOption.option3,
    ).firstWhere((g) => g.groupIdentifier == '정원길');
    final content = wonGil.messages.single.content;

    expect(content, contains('기술가정 3-7 수업입니다'));
    expect(content, isNot(contains('수학 3-7 수업입니다')));

    final hoSeong = NoticeMessageGenerator.generateTeacherMessages(
      [data],
      MessageOption.option3,
    ).firstWhere((g) => g.groupIdentifier == '정호성');
    final hoSeongContent = hoSeong.messages.single.content;

    expect(hoSeongContent, contains('수학 3-7 수업입니다'));
    expect(hoSeongContent, isNot(contains('기술가정 3-7 수업입니다')));
  });

  test('한 교사의 여러 교체 건은 결강/수업 구분 없이 실제 날짜·교시 순으로 정렬된다', () {
    // 정원길 기준: 정호성 건의 "수업" 날짜(10.06)가 박은선 건의 "결강" 날짜(10.07)보다 빠르다.
    final withHoSeong = basic(
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
      className: '7',
    );
    final withEunSun = basic(
      exchangeId: 'e2',
      absenceDate: '2026.10.07',
      absenceDay: '수',
      period: '1',
      subject: '기술가정',
      teacher: '정원길',
      substitutionDate: '2026.10.12',
      substitutionDay: '월',
      substitutionPeriod: '1',
      substitutionSubject: '기술가정',
      substitutionTeacher: '박은선',
      className: '8',
    );

    final group = NoticeMessageGenerator.generateTeacherMessages(
      [withHoSeong, withEunSun],
      MessageOption.option3,
    ).firstWhere((g) => g.groupIdentifier == '정원길');
    final lines = group.messages.single.content.split('\n');

    // 첫 데이터줄(선생님 인사말 다음)이 10.06(가장 이른 날짜)이어야 한다.
    expect(lines[1], contains('10.06'));
    expect(lines[1], contains('수업입니다'));
  });
}

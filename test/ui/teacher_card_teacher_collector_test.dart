import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/ui/screens/personal_schedule_screen/teacher_card_teacher_collector.dart';
import 'package:class_exchange_manager/ui/screens/personal_schedule_screen/exchange_week_collector.dart';
import 'package:class_exchange_manager/utils/personal_exchange_info_extractor.dart';

void main() {
  group('TeacherCardTeacherCollector', () {
    test('호출측이 넘긴 planData의 교사를 모두 카드로 만든다', () {
      final plans = [_plan(teacher: '김철수', substitutionTeacher: '이영희')];

      final targets = TeacherCardTeacherCollector.collect(
        savedTeacherName: '김철수',
        planData: plans,
      );

      expect(targets.map((t) => t.name).toList(), ['김철수', '이영희']);
      expect(targets[0].isSaved, isTrue);
      expect(targets[1].isSubstitution, isTrue);
    });

    test('선택 교사가 교체 상대이면 결강 교사 카드도 포함한다', () {
      final plans = [_plan(teacher: '김철수', substitutionTeacher: '이영희')];

      final targets = TeacherCardTeacherCollector.collect(
        savedTeacherName: '이영희',
        planData: plans,
      );

      expect(targets.map((t) => t.name).toList(), ['이영희', '김철수']);
      expect(targets[0].isSaved, isTrue);
      expect(targets[1].isAbsence, isTrue);
      expect(targets[1].roleLabel, '결강');
    });

    test('보강 교사만 있는 건도 포함한다', () {
      final plans = [
        _plan(
          teacher: '김철수',
          substitutionTeacher: '',
          supplementTeacher: '박보강',
        ),
      ];

      final targets = TeacherCardTeacherCollector.collect(
        savedTeacherName: '김철수',
        planData: plans,
      );

      expect(targets.map((t) => t.name).toList(), ['김철수', '박보강']);
      expect(targets[1].isSupplement, isTrue);
      expect(targets[1].roleLabel, '보강');
    });

    test('planData가 비면 선택 교사 카드만 남는다', () {
      final targets = TeacherCardTeacherCollector.collect(
        savedTeacherName: '김철수',
        planData: const [],
      );

      expect(targets, hasLength(1));
      expect(targets.first.name, '김철수');
      expect(targets.first.isSaved, isTrue);
    });

    test('헤더 계획서 체크 행의 교체 당사자도 카드에 넣는다', () {
      final plans = [
        _plan(teacher: '박은선', substitutionTeacher: '변아영', groupId: 'ex1'),
      ];

      final targets = TeacherCardTeacherCollector.collect(
        savedTeacherName: '정원길',
        planData: plans,
      );

      expect(targets.map((t) => t.name).toList(), ['정원길', '박은선', '변아영']);
      expect(targets[0].isSaved, isTrue);
      expect(targets[1].isAbsence, isTrue);
      expect(targets[2].isSubstitution, isTrue);
    });

    test('교사별 버튼은 계획서에 등장한 교사만 중복 없이 표시한다', () {
      final targets = TeacherCardTeacherCollector.collect(
        savedTeacherName: null,
        planData: [
          _plan(teacher: '김철수', substitutionTeacher: '이영희'),
          _plan(
            teacher: '김철수',
            substitutionTeacher: '',
            supplementTeacher: '박보강',
          ),
        ],
      );

      expect(targets.map((target) => target.name).toList(), [
        '김철수',
        '이영희',
        '박보강',
      ]);
    });
  });

  group('PersonalExchangeInfoExtractor.plansForPersonalSchedule', () {
    test('헤더 계획서에 체크된 행을 포함한다 (profileId 없어도)', () {
      final plans = [
        _plan(teacher: '박은선', substitutionTeacher: '변아영', groupId: 'ex1'),
        _plan(teacher: '다른결강', substitutionTeacher: '다른교체', groupId: 'ex2'),
      ];

      // ex2만 체크 해제 → ex1만 계획서에 포함
      final filtered = PersonalExchangeInfoExtractor.plansForPersonalSchedule(
        planData: plans,
        teacherName: '정원길',
        selectedProfileId: 'pp_jeong',
        deselectedGroupIds: const ['ex2'],
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.groupId, 'ex1');
    });

    test('체크가 모두 켜져 있으면 전체 행을 포함한다', () {
      final plans = [
        _plan(teacher: '박은선', substitutionTeacher: '변아영', groupId: 'ex1'),
      ];

      final filtered = PersonalExchangeInfoExtractor.plansForPersonalSchedule(
        planData: plans,
        teacherName: '정원길',
        selectedProfileId: 'pp_jeong',
        deselectedGroupIds: const [],
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.teacher, '박은선');
    });

    test('계획서 미선택이면 선택 교사 관련 행만 남긴다', () {
      final plans = [
        _plan(teacher: '정원길', substitutionTeacher: '이영희', groupId: 'ex1'),
        _plan(teacher: '박은선', substitutionTeacher: '변아영', groupId: 'ex2'),
      ];

      final filtered = PersonalExchangeInfoExtractor.plansForPersonalSchedule(
        planData: plans,
        teacherName: '정원길',
        selectedProfileId: null,
        deselectedGroupIds: const [],
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.groupId, 'ex1');
    });
  });

  test('교사별 보기는 선택 교사의 모든 결보강 주차를 날짜순으로 모은다', () {
    final plans = [
      _plan(
        teacher: '김철수',
        substitutionTeacher: '이영희',
        absenceDate: '2026.09.14',
        substitutionDate: '2026.09.15',
      ),
      _plan(
        teacher: '박은선',
        substitutionTeacher: '김철수',
        absenceDate: '2026.08.31',
        substitutionDate: '2026.09.01',
      ),
      _plan(
        teacher: '다른교사',
        substitutionTeacher: '다른교체',
        absenceDate: '2026.09.21',
        substitutionDate: '2026.09.22',
      ),
    ];

    final related = PersonalExchangeInfoExtractor.plansRelatedToTeacher(
      plans,
      '김철수',
    );
    final weeks = ExchangeWeekCollector.collectWeekMondays(related);

    expect(weeks, [DateTime(2026, 8, 31), DateTime(2026, 9, 14)]);
  });
}

SubstitutionPlanData _plan({
  required String teacher,
  required String substitutionTeacher,
  String supplementTeacher = '',
  String? groupId,
  String absenceDate = '2026.08.31',
  String substitutionDate = '2026.09.01',
}) {
  return SubstitutionPlanData(
    exchangeId: '$teacher-$substitutionTeacher-$supplementTeacher',
    absenceDate: absenceDate,
    absenceDay: '월',
    period: '1',
    grade: '1',
    className: '1',
    subject: '수학',
    teacher: teacher,
    supplementSubject: '',
    supplementTeacher: supplementTeacher,
    substitutionDate: substitutionDate,
    substitutionDay: '화',
    substitutionPeriod: '2',
    substitutionSubject: '수학',
    substitutionTeacher: substitutionTeacher,
    remarks: '',
    groupId: groupId,
  );
}

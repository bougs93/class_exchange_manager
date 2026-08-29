import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/ui/screens/personal_schedule_screen/teacher_card_teacher_collector.dart';

void main() {
  group('TeacherCardTeacherCollector', () {
    test('선택 교사와 무관한 계획서 교사는 카드에 넣지 않는다', () {
      final plans = [
        _plan(
          teacher: '김철수',
          substitutionTeacher: '이영희',
        ),
        _plan(
          teacher: '박민수',
          substitutionTeacher: '최지훈',
        ),
      ];

      final targets = TeacherCardTeacherCollector.collect(
        savedTeacherName: '김철수',
        planData: plans,
      );

      expect(targets.map((t) => t.name).toList(), ['김철수', '이영희']);
      expect(targets[0].isSaved, isTrue);
      expect(targets[1].isSubstitution, isTrue);
    });

    test('선택 교사가 교체 상대이면 결강 교사 카드도 포함한다', () {
      final plans = [
        _plan(
          teacher: '김철수',
          substitutionTeacher: '이영희',
        ),
      ];

      final targets = TeacherCardTeacherCollector.collect(
        savedTeacherName: '이영희',
        planData: plans,
      );

      expect(targets.map((t) => t.name).toList(), ['이영희', '김철수']);
      expect(targets[0].isSaved, isTrue);
      expect(targets[1].isAbsence, isTrue);
      expect(targets[1].roleLabel, '결강');
    });

    test('보강 교사만 있는 건도 선택 교사와 연결되면 포함한다', () {
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

    test('선택 교사만 있고 관련 계획서가 없으면 카드는 1장이다', () {
      final targets = TeacherCardTeacherCollector.collect(
        savedTeacherName: '김철수',
        planData: [
          _plan(teacher: '박민수', substitutionTeacher: '최지훈'),
        ],
      );

      expect(targets, hasLength(1));
      expect(targets.first.name, '김철수');
      expect(targets.first.isSaved, isTrue);
    });
  });
}

SubstitutionPlanData _plan({
  required String teacher,
  required String substitutionTeacher,
  String supplementTeacher = '',
}) {
  return SubstitutionPlanData(
    exchangeId: '$teacher-$substitutionTeacher-$supplementTeacher',
    absenceDate: '2026.08.31',
    absenceDay: '월',
    period: '1',
    grade: '1',
    className: '1',
    subject: '수학',
    teacher: teacher,
    supplementSubject: '',
    supplementTeacher: supplementTeacher,
    substitutionDate: '2026.09.01',
    substitutionDay: '화',
    substitutionPeriod: '2',
    substitutionSubject: '수학',
    substitutionTeacher: substitutionTeacher,
    remarks: '',
  );
}

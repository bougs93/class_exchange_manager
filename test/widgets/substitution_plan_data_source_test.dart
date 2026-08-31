import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/ui/screens/plan_output/widgets/content_input_grid.dart';

SubstitutionPlanData _row({required String groupId, String teacher = '홍길동'}) {
  return SubstitutionPlanData(
    exchangeId: '${groupId}_absenceDate',
    absenceDate: '2026.08.27',
    absenceDay: '목',
    period: '3',
    grade: '1',
    className: '1',
    subject: '수학',
    teacher: teacher,
    supplementSubject: '',
    supplementTeacher: '',
    substitutionDate: '2026.08.28',
    substitutionDay: '금',
    substitutionPeriod: '2',
    substitutionSubject: '',
    substitutionTeacher: '',
    remarks: '',
    groupId: groupId,
  );
}

/// row의 `_weekKey` 숨김 컬럼 값을 꺼낸다.
String _weekKeyOf(SubstitutionPlanDataSource source, int rowIndex) {
  final cell = source.rows[rowIndex].getCells().firstWhere(
    (c) => c.columnName == '_weekKey',
  );
  return cell.value as String;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubstitutionPlanDataSource — 주차 그룹핑 키 (§10.8 6단계)', () {
    test('groupWeeks에 있는 groupId는 결강일이 속한 주의 ISO 날짜 키를 가진다', () {
      final planData = [_row(groupId: 'g1')];
      final source = SubstitutionPlanDataSource(
        planData,
        groupWeeks: {'g1': DateTime(2026, 8, 24)}, // 8월4주 월요일
      );

      expect(_weekKeyOf(source, 0), '2026-08-24');
    });

    test('groupWeeks에 없는 groupId는 미지정 키(항상 맨 뒤 정렬)를 가진다', () {
      final planData = [_row(groupId: 'g_unknown')];
      final source = SubstitutionPlanDataSource(planData, groupWeeks: const {});

      final key = _weekKeyOf(source, 0);
      expect(key, '9999-99-99');
      // 사전식 정렬에서 실제 날짜보다 항상 뒤에 온다
      expect(key.compareTo('2026-08-24') > 0, isTrue);
    });

    test('groupId가 빈 문자열이면 미지정 키를 가진다', () {
      final planData = [_row(groupId: '')];
      final source = SubstitutionPlanDataSource(
        planData,
        groupWeeks: {'g1': DateTime(2026, 8, 24)},
      );

      expect(_weekKeyOf(source, 0), '9999-99-99');
    });

    test('서로 다른 주의 두 건은 서로 다른 키를 가져 별도 그룹으로 묶인다', () {
      final planData = [_row(groupId: 'g1'), _row(groupId: 'g2')];
      final source = SubstitutionPlanDataSource(
        planData,
        groupWeeks: {
          'g1': DateTime(2026, 8, 24), // 8월4주
          'g2': DateTime(2026, 8, 31), // 9월1주
        },
      );

      expect(_weekKeyOf(source, 0), isNot(_weekKeyOf(source, 1)));
    });

    test('ISO 날짜 키는 사전식 정렬이 곧 날짜순 정렬이다', () {
      // sortGroupRows: true가 문자열 정렬에 의존하므로, 형식이 항상
      // 'yyyy-MM-dd'(0-패딩)여야 한다 — 그렇지 않으면 "2026-9-1"이
      // "2026-08-31"보다 앞서는 등 순서가 깨진다.
      final planData = [_row(groupId: 'g1')];
      final source = SubstitutionPlanDataSource(
        planData,
        groupWeeks: {'g1': DateTime(2026, 9, 1)},
      );

      expect(_weekKeyOf(source, 0), '2026-09-01');
    });
  });
}

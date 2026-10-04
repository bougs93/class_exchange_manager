import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/utils/plan_sort.dart';
import 'package:flutter_test/flutter_test.dart';

SubstitutionPlanData _row(String id, String date, String period) {
  return SubstitutionPlanData(
    exchangeId: id,
    absenceDate: date,
    absenceDay: '',
    period: period,
    grade: '1',
    className: '1',
    subject: '',
    teacher: '',
    supplementSubject: '',
    supplementTeacher: '',
    substitutionDate: '',
    substitutionDay: '',
    substitutionPeriod: '',
    substitutionSubject: '',
    substitutionTeacher: '',
    remarks: '',
  );
}

List<String> _ids(List<SubstitutionPlanData> list) =>
    list.map((e) => e.exchangeId).toList();

void main() {
  group('sortPlanData', () {
    test('날짜순: 결강일 → 교시 순으로 정렬한다', () {
      final input = [
        _row('a', '2026.09.02', '1'),
        _row('b', '2026.09.01', '5'),
        _row('c', '2026.09.01', '2'),
      ];
      final out = sortPlanData(input, PlanSortMode.byDate);
      expect(_ids(out), ['c', 'b', 'a']);
    });

    test('등록순: 원래 순서를 그대로 유지한다', () {
      final input = [
        _row('a', '2026.09.02', '1'),
        _row('b', '2026.09.01', '5'),
        _row('c', '2026.09.01', '2'),
      ];
      final out = sortPlanData(input, PlanSortMode.byRegistration);
      expect(_ids(out), ['a', 'b', 'c']);
    });

    test('입력 리스트는 변경하지 않는다', () {
      final input = [
        _row('a', '2026.09.02', '1'),
        _row('b', '2026.09.01', '1'),
      ];
      sortPlanData(input, PlanSortMode.byDate);
      expect(_ids(input), ['a', 'b']);
    });

    test('날짜·교시가 같으면 입력 순서를 유지한다(안정 정렬)', () {
      final input = [
        for (var i = 0; i < 40; i++) _row('r$i', '2026.09.01', '3'),
      ];
      final out = sortPlanData(input, PlanSortMode.byDate);
      expect(_ids(out), _ids(input));
    });

    test('날짜 파싱 실패 행은 뒤로 보내고 그들끼리는 교시 → 입력 순서', () {
      final input = [
        _row('bad2', '선택', '1'),
        _row('ok', '2026.09.01', '9'),
        _row('bad1', '', '1'),
      ];
      final out = sortPlanData(input, PlanSortMode.byDate);
      expect(_ids(out), ['ok', 'bad2', 'bad1']);
    });

    test('교시 파싱 실패는 9999로 취급해 같은 날 맨 뒤', () {
      final input = [
        _row('x', '2026.09.01', ''),
        _row('y', '2026.09.01', '7'),
      ];
      final out = sortPlanData(input, PlanSortMode.byDate);
      expect(_ids(out), ['y', 'x']);
    });

    test('groupKeyOf가 있으면 그룹 키가 최우선이다', () {
      final input = [
        _row('late', '2026.09.01', '1'),
        _row('early', '2026.09.10', '1'),
      ];
      final out = sortPlanData(
        input,
        PlanSortMode.byDate,
        groupKeyOf: (d) => d.exchangeId == 'early' ? 'A' : 'B',
      );
      expect(_ids(out), ['early', 'late']);
    });
  });
}

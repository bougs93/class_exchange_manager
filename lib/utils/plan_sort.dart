import '../providers/substitution_plan_viewmodel.dart';
import 'date_format_utils.dart';

/// 결보강 일정·출력의 정렬 방식
enum PlanSortMode {
  /// 결강일 → 결강교시 순
  byDate,

  /// 등록(입력 리스트) 순서 그대로
  byRegistration,
}

/// 결보강 계획 데이터 정렬 (순수 함수 — 입력 리스트는 바꾸지 않는다)
///
/// - [PlanSortMode.byRegistration]: 입력 순서 그대로 복사해 돌려준다.
/// - [PlanSortMode.byDate]: [groupKeyOf]가 있으면 그 키(사전식) → 결강일 → 교시 순.
///   날짜 파싱 실패 행은 뒤로, 교시 파싱 실패는 9999로 본다. 모두 같으면 입력
///   인덱스로 비교해 안정 정렬을 보장한다(Dart `List.sort`는 불안정).
///
/// 안내문용 `DataSorter.sortByDateAndPeriod`와는 별개다(안내문은 항상 날짜순).
List<SubstitutionPlanData> sortPlanData(
  List<SubstitutionPlanData> planData,
  PlanSortMode mode, {
  String Function(SubstitutionPlanData data)? groupKeyOf,
}) {
  if (mode == PlanSortMode.byRegistration) {
    return List<SubstitutionPlanData>.from(planData);
  }

  final indexed = [
    for (var i = 0; i < planData.length; i++) (index: i, data: planData[i]),
  ];
  indexed.sort((x, y) {
    final a = x.data;
    final b = y.data;

    if (groupKeyOf != null) {
      final groupCompare = groupKeyOf(a).compareTo(groupKeyOf(b));
      if (groupCompare != 0) return groupCompare;
    }

    final aDate = DateFormatUtils.parseYearMonthDay(a.absenceDate);
    final bDate = DateFormatUtils.parseYearMonthDay(b.absenceDate);
    if (aDate != null && bDate != null) {
      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) return dateCompare;
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }

    final aPeriod = int.tryParse(a.period) ?? 9999;
    final bPeriod = int.tryParse(b.period) ?? 9999;
    final periodCompare = aPeriod.compareTo(bPeriod);
    if (periodCompare != 0) return periodCompare;

    return x.index.compareTo(y.index);
  });
  return [for (final e in indexed) e.data];
}

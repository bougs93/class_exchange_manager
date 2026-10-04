import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../models/print_profile.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../personal_schedule_screen/exchange_week_collector.dart';
import '../../../../utils/plan_sort.dart';
import 'content_input_grid_helpers.dart';

/// 주(週) 정보를 알 수 없는 행의 그룹 정렬 키 — 항상 맨 뒤로 정렬되도록
/// 실제 날짜보다 큰 값을 쓴다.
const String _unresolvedWeekKey = '9999-99-99';

/// DateTime → 그룹 정렬용 ISO 날짜 키 ('yyyy-MM-dd', 사전식 정렬 = 날짜순)
String _weekSortKey(DateTime weekMonday) {
  final y = weekMonday.year.toString().padLeft(4, '0');
  final m = weekMonday.month.toString().padLeft(2, '0');
  final d = weekMonday.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime? _parseWeekSortKey(String key) {
  if (key == _unresolvedWeekKey) return null;
  return DateTime.tryParse(key);
}

/// 보강계획서 데이터 소스
class SubstitutionPlanDataSource extends DataGridSource {
  final List<SubstitutionPlanData> planData;
  final Function(String, String)? onDateCellTap;
  final Function(String)? onSupplementSubjectTap;

  /// 그룹(교체 건) 선택 상태 조회
  final bool Function(String groupId)? isSelected;

  /// 그룹 선택 토글
  final ValueChanged<String>? onToggleSelect;

  /// 행 교사의 계획서 목록 조회
  final List<PrintProfile> Function(String teacher)? profileOptions;

  /// 행 드롭다운의 '＋ 새 계획서…' 선택 콜백
  final void Function(String groupId, String teacher)? onCreateProfile;

  /// 그룹의 지정 계획서 ID 조회
  final String? Function(String groupId)? selectedProfileId;

  /// 계획서 지정 변경
  final Function(String groupId, String? profileId)? onProfileChanged;

  /// 그룹(교체 건) ID → 소속 주(週)의 월요일 (§10.8 6단계)
  ///
  /// `ExchangeHistoryItem.weekMonday`(결강일 기준)에서 만든다. 여기 없는
  /// groupId는 "주 미지정"으로 묶인다.
  final Map<String, DateTime> groupWeeks;

  /// 그룹 안 정렬 방식 (기본: 날짜순)
  final PlanSortMode sortMode;

  SubstitutionPlanDataSource(
    this.planData, {
    this.onDateCellTap,
    this.onSupplementSubjectTap,
    this.isSelected,
    this.onToggleSelect,
    this.profileOptions,
    this.onCreateProfile,
    this.selectedProfileId,
    this.onProfileChanged,
    this.groupWeeks = const {},
    this.sortMode = PlanSortMode.byRegistration,
  }) {
    // 결강일이 속한 주(週) 기준으로 그룹핑 — sortGroupRows로 주 순서 정렬
    addColumnGroup(ColumnGroup(name: '_weekKey', sortGroupRows: true));
  }

  /// 행의 주차 정렬 키 (groupId로 [groupWeeks] 조회, 없으면 미지정 키)
  String _weekKeyFor(SubstitutionPlanData data) {
    final groupId = data.groupId;
    if (groupId == null || groupId.isEmpty) return _unresolvedWeekKey;
    final week = groupWeeks[groupId];
    if (week == null) return _unresolvedWeekKey;
    return _weekSortKey(week);
  }

  /// 화면 표시용 정렬 — 주 그룹 → (날짜순이면) 결강일 → 결강교시 순
  ///
  /// 주 그룹핑(`_weekKey`)은 유지한 채 그룹 안의 순서만 [sortMode]에 따른다.
  /// 등록순이면 그룹 안은 입력 순서 그대로다(그룹 간 순서는 그리드가 정렬).
  List<SubstitutionPlanData> get _sortedPlanData =>
      sortPlanData(planData, sortMode, groupKeyOf: _weekKeyFor);

  @override
  List<DataGridRow> get rows =>
      _sortedPlanData.map<DataGridRow>((data) {
        return DataGridRow(
          cells: [
            // exchangeId를 첫 번째 숨김 컬럼으로 추가
            DataGridCell<String>(
              columnName: '_exchangeId',
              value: data.exchangeId,
            ),
            // groupId (교체 건 ID) 숨김 컬럼 — 선택·계획서 지정은 그룹 단위
            DataGridCell<String>(
              columnName: '_groupId',
              value: data.groupId ?? '',
            ),
            // 주차 그룹핑용 숨김 컬럼 (§10.8 6단계)
            DataGridCell<String>(
              columnName: '_weekKey',
              value: _weekKeyFor(data),
            ),
            DataGridCell<String>(
              columnName: 'absenceDate',
              value: data.absenceDate,
            ),
            DataGridCell<String>(
              columnName: 'absenceDay',
              value: data.absenceDay,
            ),
            DataGridCell<String>(columnName: 'period', value: data.period),
            DataGridCell<String>(columnName: 'grade', value: data.grade),
            DataGridCell<String>(
              columnName: 'className',
              value: data.className,
            ),
            DataGridCell<String>(columnName: 'subject', value: data.subject),
            DataGridCell<String>(columnName: 'teacher', value: data.teacher),
            DataGridCell<String>(
              columnName: 'supplementSubject',
              value: data.supplementSubject,
            ),
            DataGridCell<String>(
              columnName: 'supplementTeacher',
              value: data.supplementTeacher,
            ),
            DataGridCell<String>(
              columnName: 'substitutionDate',
              value: data.substitutionDate,
            ),
            DataGridCell<String>(
              columnName: 'substitutionDay',
              value: data.substitutionDay,
            ),
            DataGridCell<String>(
              columnName: 'substitutionPeriod',
              value: data.substitutionPeriod,
            ),
            DataGridCell<String>(
              columnName: 'substitutionSubject',
              value: data.substitutionSubject,
            ),
            DataGridCell<String>(
              columnName: 'substitutionTeacher',
              value: data.substitutionTeacher,
            ),
            DataGridCell<String>(columnName: 'remarks', value: data.remarks),
          ],
        );
      }).toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final selectCell = CellRendererFactory.build(
      row.getCells().firstWhere(
        (c) => c.columnName == 'select',
        orElse:
            () => const DataGridCell<String>(columnName: 'select', value: ''),
      ),
      row,
      isSelected: isSelected,
      onToggleSelect: onToggleSelect,
      profileOptions: profileOptions,
      onCreateProfile: onCreateProfile,
      selectedProfileId: selectedProfileId,
      onProfileChanged: onProfileChanged,
    );

    // exchangeId·groupId 컬럼을 제외한 나머지 셀들만 렌더링
    final cells =
        row
            .getCells()
            .where(
              (cell) =>
                  cell.columnName != '_exchangeId' &&
                  cell.columnName != '_groupId' &&
                  cell.columnName != '_weekKey' &&
                  cell.columnName != 'select' &&
                  cell.columnName != 'profile',
            )
            .map<Widget>((cell) {
              return CellRendererFactory.build(
                cell,
                row,
                onDateCellTap: onDateCellTap,
                onSupplementSubjectTap: onSupplementSubjectTap,
              );
            })
            .toList();

    return DataGridRowAdapter(cells: [selectCell, ...cells]);
  }

  /// 주차 캡션 행 — `SfDataGrid.groupCaptionTitleFormat: '{Key}'`로
  /// [summaryValue]에 `_weekKey`(ISO 날짜 문자열)가 그대로 전달된다.
  ///
  /// 체크된 건은 결보강 출력(미리보기)에서 PDF에 반영된다.
  @override
  Widget? buildGroupCaptionCellWidget(
    RowColumnIndex rowColumnIndex,
    String summaryValue,
  ) {
    final weekMonday = _parseWeekSortKey(summaryValue);
    final label =
        weekMonday == null
            ? '주 미지정'
            : ExchangeWeekCollector.monthWeekLabel(weekMonday);

    final weekCount =
        planData.where((d) => _weekKeyFor(d) == summaryValue).length;

    return Container(
      color: const Color(0x14000000),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: Text(
        '$label · 교체 $weekCount건',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../../models/print_profile.dart';
import '../../../../../providers/services_provider.dart';
import '../../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../../theme/design_tokens.dart';
import '../content_input_grid_dialogs.dart';
import '../content_input_grid_helpers.dart';
import '../substitution_plan_data_source.dart';

/// 결보강 일정 그리드(`ContentInputGrid`)의 실제 데이터 표(`SfDataGrid`) 부분.
///
/// 날짜/과목 선택 다이얼로그를 띄우는 것 외의 모든 동작(체크 토글, 계획서
/// 생성/지정, 결강일 선택 후 계획서 이름 변경 등)은 생성자로 전달받은
/// 콜백에 그대로 위임한다 — `_ContentInputGridState`의 상태(`setState`)는
/// 이 위젯이 직접 건드리지 않는다.
class PlanGridDataTable extends ConsumerWidget {
  const PlanGridDataTable({
    super.key,
    required this.planData,
    required this.viewModel,
    required this.isGroupSelected,
    required this.onToggleGroupSelection,
    required this.profileOptionsForTeacher,
    required this.onCreateProfile,
    required this.selectedProfileIdForGroup,
    required this.onProfileChanged,
    required this.onAbsenceDateSelected,
    required this.horizontalScrollController,
    required this.verticalScrollController,
    required this.wrapWithDragScroll,
  });

  final List<SubstitutionPlanData> planData;
  final SubstitutionPlanViewModel viewModel;

  /// 그룹(교체 건) 체크 여부 조회
  final bool Function(String groupId) isGroupSelected;
  final ValueChanged<String> onToggleGroupSelection;
  final List<PrintProfile> Function(String teacher) profileOptionsForTeacher;
  final void Function(String groupId, String teacher) onCreateProfile;
  final String? Function(String groupId) selectedProfileIdForGroup;
  final void Function(String groupId, String? profileId) onProfileChanged;

  /// 결강일/교체일 선택 완료 콜백. 결강일(`absenceDate`)이 선택된 경우에만
  /// 호출된다(계획서 이름을 "결보강 YY.MM.DD"로 바꾸는 등 후속 처리용).
  final Future<void> Function(
    DateTime selectedDate,
    List<SubstitutionPlanData> planData,
  )
  onAbsenceDateSelected;

  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;

  /// 교체 관리 시간표와 동일한 드래그 스크롤 적용 (공통 믹신 메서드 참조)
  final Widget Function(Widget child) wrapWithDragScroll;

  /// 교체 건(groupId) → 소속 주(週)의 월요일. 그 주 안에서 반복 조회하지
  /// 않도록 그리드 빌드 시점에 한 번만 만든다.
  Map<String, DateTime> _buildGroupWeeks(WidgetRef ref) {
    final history = ref.read(exchangeHistoryServiceProvider).getExchangeList();
    return {for (final item in history) item.id: item.weekMonday};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataSource = SubstitutionPlanDataSource(
      planData,
      onDateCellTap:
          (exchangeId, columnName) => showSubstitutionDatePickerDialog(
            context,
            ref,
            exchangeId,
            columnName,
            planData,
            onAbsenceDateSelected: onAbsenceDateSelected,
          ),
      onSupplementSubjectTap:
          (exchangeId) => showSubjectPickerDialog(
            context,
            ref,
            viewModel,
            exchangeId,
            planData,
          ),
      isSelected: isGroupSelected,
      onToggleSelect: onToggleGroupSelection,
      profileOptions: profileOptionsForTeacher,
      onCreateProfile: onCreateProfile,
      selectedProfileId: selectedProfileIdForGroup,
      onProfileChanged: onProfileChanged,
      groupWeeks: _buildGroupWeeks(ref),
    );

    return Expanded(
      child: wrapWithDragScroll(
        SfDataGrid(
          source: dataSource,
          columns: ContentInputGridConfig.getColumns(context.tokens),
          stackedHeaderRows: ContentInputGridConfig.getStackedHeaders(
            context.tokens,
          ),
          allowColumnsResizing: true,
          columnResizeMode: ColumnResizeMode.onResize,
          gridLinesVisibility: GridLinesVisibility.both,
          // 헤더 가로선은 컬럼 Container 테두리로만 표시 (비고 1·2행 사이 선 제거)
          headerGridLinesVisibility: GridLinesVisibility.vertical,
          selectionMode: SelectionMode.single,
          headerRowHeight: ContentInputGridConfig.headerRowHeight,
          rowHeight: 28,
          allowEditing: false,
          // 주차 그룹핑 (§10.8 6단계) — 캡션에는 _weekKey 값(원본 문자열)만 전달
          allowExpandCollapseGroup: true,
          groupCaptionTitleFormat: '{Key}',
          // 교체 관리 시간표와 동일한 스크롤 컨트롤러 적용 (공통 믹신 사용)
          horizontalScrollController: horizontalScrollController,
          verticalScrollController: verticalScrollController,
        ),
      ),
    );
  }
}

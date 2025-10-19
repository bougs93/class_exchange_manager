import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../utils/logger.dart';

/// 여백 및 스타일 상수
class _Spacing {
  static const EdgeInsets headerPadding = EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0);
  static const EdgeInsets cellPadding = EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0);
  static const double smallSpacing = 2.0;
  static const double mediumSpacing = 2.0;
  static const double headerFontSize = 12.0;
  static const double cellFontSize = 12.0;
}

/// 보강계획서 데이터 소스
class SubstitutionPlanDataSource extends DataGridSource {
  final List<SubstitutionPlanData> planData;
  final Function(String, String)? onDateCellTap;

  SubstitutionPlanDataSource(this.planData, {this.onDateCellTap});

  @override
  List<DataGridRow> get rows => planData.map<DataGridRow>((data) {
    return DataGridRow(cells: [
      // exchangeId를 첫 번째 숨김 컬럼으로 추가
      DataGridCell<String>(columnName: '_exchangeId', value: data.exchangeId),
      DataGridCell<String>(columnName: 'absenceDate', value: data.absenceDate),
      DataGridCell<String>(columnName: 'absenceDay', value: data.absenceDay),
      DataGridCell<String>(columnName: 'period', value: data.period),
      DataGridCell<String>(columnName: 'grade', value: data.grade),
      DataGridCell<String>(columnName: 'className', value: data.className),
      DataGridCell<String>(columnName: 'subject', value: data.subject),
      DataGridCell<String>(columnName: 'teacher', value: data.teacher),
      DataGridCell<String>(columnName: 'supplementSubject', value: data.supplementSubject),
      DataGridCell<String>(columnName: 'supplementTeacher', value: data.supplementTeacher),
      DataGridCell<String>(columnName: 'substitutionDate', value: data.substitutionDate),
      DataGridCell<String>(columnName: 'substitutionDay', value: data.substitutionDay),
      DataGridCell<String>(columnName: 'substitutionPeriod', value: data.substitutionPeriod),
      DataGridCell<String>(columnName: 'substitutionSubject', value: data.substitutionSubject),
      DataGridCell<String>(columnName: 'substitutionTeacher', value: data.substitutionTeacher),
      DataGridCell<String>(columnName: 'remarks', value: data.remarks),
    ]);
  }).toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    // exchangeId 컬럼을 제외한 나머지 셀들만 렌더링
    final cells = row.getCells().where((cell) => cell.columnName != '_exchangeId').map<Widget>((cell) {
      if (cell.columnName == 'absenceDate' || cell.columnName == 'substitutionDate') {
        return _buildDateCell(cell, row);
      }
      return _buildNormalCell(cell);
    }).toList();

    return DataGridRowAdapter(cells: cells);
  }

  Widget _buildDateCell(DataGridCell cell, DataGridRow row) {
    final isSelectable = cell.value == '선택';
    final displayText = isSelectable ? '선택' : (cell.value?.toString() ?? '');

    return GestureDetector(
      onTap: () {
        AppLogger.exchangeDebug('셀 클릭 - 컬럼: ${cell.columnName}, 값: ${cell.value}');
        if (onDateCellTap != null) {
          // exchangeId를 row의 첫 번째 셀에서 추출
          final exchangeIdCell = row.getCells().firstWhere(
            (c) => c.columnName == '_exchangeId',
            orElse: () => DataGridCell<String>(columnName: '_exchangeId', value: ''),
          );
          final exchangeId = exchangeIdCell.value?.toString() ?? '';

          AppLogger.exchangeDebug('exchangeId: $exchangeId, 콜백 호출');

          if (exchangeId.isNotEmpty) {
            onDateCellTap!(exchangeId, cell.columnName);
          } else {
            AppLogger.warning('exchangeId가 비어있습니다');
          }
        } else {
          AppLogger.warning('onDateCellTap이 null입니다');
        }
      },
      child: Container(
        alignment: Alignment.center,
        padding: _Spacing.cellPadding,
        decoration: BoxDecoration(
          color: isSelectable ? Colors.blue.shade50 : Colors.transparent,
          border: isSelectable ? Border.all(color: Colors.blue.shade200) : null,
          borderRadius: isSelectable ? BorderRadius.circular(4) : null,
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: _Spacing.cellFontSize,
            height: 1.0,
            color: isSelectable ? Colors.blue.shade700 : Colors.black87,
            fontWeight: isSelectable ? FontWeight.w500 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildNormalCell(DataGridCell cell) {
    return Container(
      alignment: Alignment.center,
      padding: _Spacing.cellPadding,
      child: Text(
        cell.value?.toString() ?? '',
        style: const TextStyle(
          fontSize: _Spacing.cellFontSize,
          height: 1.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 보강계획서 그리드 위젯 (리팩토링 버전)
class SubstitutionPlanGrid extends ConsumerWidget {
  const SubstitutionPlanGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModelState = ref.watch(substitutionPlanViewModelProvider);
    final viewModel = ref.read(substitutionPlanViewModelProvider.notifier);

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActionButtons(context, ref, viewModel),
            const SizedBox(height: _Spacing.mediumSpacing),
            _buildDataGrid(context, ref, viewModelState, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, SubstitutionPlanViewModel viewModel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => viewModel.loadPlanData(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('새로고침'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: _Spacing.smallSpacing),
          ElevatedButton.icon(
            onPressed: () => _clearAllDates(context, viewModel),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('날짜 지우기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: _Spacing.smallSpacing),
          ElevatedButton.icon(
            onPressed: () => _exportToPDF(context),
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('PDF 출력'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataGrid(
    BuildContext context,
    WidgetRef ref,
    SubstitutionPlanViewModelState state,
    SubstitutionPlanViewModel viewModel,
  ) {
    if (state.isLoading) {
      return _buildLoadingIndicator();
    }

    if (state.planData.isEmpty) {
      return _buildEmptyState();
    }

    final dataSource = SubstitutionPlanDataSource(
      state.planData,
      onDateCellTap: (exchangeId, columnName) => _showDatePicker(context, ref, viewModel, exchangeId, columnName, state.planData),
    );

    return SizedBox(
      height: 500,
      child: SfDataGrid(
        source: dataSource,
        columns: _buildColumns(),
        stackedHeaderRows: _buildStackedHeaders(),
        allowColumnsResizing: true,
        columnResizeMode: ColumnResizeMode.onResize,
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        selectionMode: SelectionMode.single,
        headerRowHeight: 35,
        rowHeight: 28,
        allowEditing: false,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      height: 500,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('교체 기록이 없습니다', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('교체를 실행하면 여기에 기록이 표시됩니다', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  List<GridColumn> _buildColumns() {
    return [
      GridColumn(columnName: 'absenceDate', label: _buildHeaderLabel('결강일'), width: 70),
      GridColumn(columnName: 'absenceDay', label: _buildHeaderLabel('요일'), width: 45),
      GridColumn(columnName: 'period', label: _buildHeaderLabel('교시'), width: 45),
      GridColumn(columnName: 'grade', label: _buildHeaderLabel('학년'), width: 45),
      GridColumn(columnName: 'className', label: _buildHeaderLabel('반'), width: 55),
      GridColumn(columnName: 'subject', label: _buildHeaderLabel('과목'), width: 70),
      GridColumn(columnName: 'teacher', label: _buildHeaderLabel('교사'), width: 70),
      GridColumn(columnName: 'supplementSubject', label: _buildHeaderLabel('과목'), width: 70),
      GridColumn(columnName: 'supplementTeacher', label: _buildHeaderLabel('성명'), width: 90),
      GridColumn(columnName: 'substitutionDate', label: _buildHeaderLabel('교체일'), width: 70),
      GridColumn(columnName: 'substitutionDay', label: _buildHeaderLabel('요일'), width: 45),
      GridColumn(columnName: 'substitutionPeriod', label: _buildHeaderLabel('교시'), width: 45),
      GridColumn(columnName: 'substitutionSubject', label: _buildHeaderLabel('과목'), width: 70),
      GridColumn(columnName: 'substitutionTeacher', label: _buildHeaderLabel('교사'), width: 90),
      GridColumn(columnName: 'remarks', label: _buildHeaderLabel('비고'), width: 100),
    ];
  }

  List<StackedHeaderRow> _buildStackedHeaders() {
    return [
      StackedHeaderRow(
        cells: [
          _buildStackedHeaderCell(['absenceDate', 'absenceDay', 'period', 'grade', 'className', 'subject', 'teacher'], '결강'),
          _buildStackedHeaderCell(['supplementSubject', 'supplementTeacher'], '보강/수업변경'),
          _buildStackedHeaderCell(['substitutionDate', 'substitutionDay', 'substitutionPeriod', 'substitutionSubject', 'substitutionTeacher'], '수업 교체'),
          _buildStackedHeaderCell(['remarks'], '비고'),
        ],
      ),
    ];
  }

  Widget _buildHeaderLabel(String text) {
    return Container(
      padding: _Spacing.headerPadding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: _Spacing.cellFontSize,
          height: 1.0,
        ),
      ),
    );
  }

  StackedHeaderCell _buildStackedHeaderCell(List<String> columnNames, String text) {
    return StackedHeaderCell(
      columnNames: columnNames,
      child: Container(
        padding: _Spacing.headerPadding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: _Spacing.headerFontSize,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Future<void> _showDatePicker(
    BuildContext context,
    WidgetRef ref,
    SubstitutionPlanViewModel viewModel,
    String exchangeId,
    String columnName,
    List<SubstitutionPlanData> planData,
  ) async {
    AppLogger.exchangeDebug('날짜 선택 시작 - exchangeId: $exchangeId, columnName: $columnName');

    // 해당 데이터 찾기
    try {
      final data = planData.firstWhere((d) => d.exchangeId == exchangeId);
      AppLogger.exchangeDebug('데이터 찾기 성공');

      // 요일 정보 추출
      final targetWeekday = columnName == 'absenceDate' ? data.absenceDay : data.substitutionDay;
      AppLogger.exchangeDebug('대상 요일: $targetWeekday');

      // 날짜 선택기 표시
      final selectedDates = await showCalendarDatePicker2Dialog(
        context: context,
        config: CalendarDatePicker2WithActionButtonsConfig(
          calendarType: CalendarDatePicker2Type.single,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          weekdayLabels: ['일', '월', '화', '수', '목', '금', '토'],
          selectableDayPredicate: targetWeekday.isNotEmpty
              ? (date) => _isTargetWeekday(date, targetWeekday)
              : null,
          selectedDayHighlightColor: Colors.blue.shade600,
          okButton: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('확인', style: TextStyle(color: Colors.white)),
          ),
          cancelButton: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('취소', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
        dialogSize: const Size(350, 360),
        borderRadius: BorderRadius.circular(5),
        value: [DateTime.now()],
      );

      AppLogger.exchangeDebug('선택 결과: $selectedDates');

      final selectedDate = selectedDates?.isNotEmpty == true ? selectedDates!.first : null;

      if (selectedDate != null) {
        if (targetWeekday.isNotEmpty && !_isTargetWeekday(selectedDate, targetWeekday)) {
          AppLogger.warning('요일 불일치 - 선택: ${selectedDate.weekday}, 대상: $targetWeekday');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$targetWeekday요일이 아닌 날짜는 선택할 수 없습니다.'),
                backgroundColor: Colors.red.shade600,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        final formattedDate = '${selectedDate.month}.${selectedDate.day}';
        AppLogger.exchangeInfo('날짜 업데이트: $formattedDate');
        viewModel.updateDate(exchangeId, columnName, formattedDate);
      } else {
        AppLogger.exchangeDebug('날짜 선택 취소됨');
      }
    } catch (e) {
      AppLogger.error('날짜 선택 중 오류 발생', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('날짜 선택 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  bool _isTargetWeekday(DateTime date, String targetWeekday) {
    const weekdayMap = {'일': 0, '월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6};
    final targetWeekdayNumber = weekdayMap[targetWeekday];
    if (targetWeekdayNumber == null) return true;

    final dateWeekday = date.weekday == 7 ? 0 : date.weekday;
    return dateWeekday == targetWeekdayNumber;
  }

  void _clearAllDates(BuildContext context, SubstitutionPlanViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('날짜 지우기'),
        content: const Text('입력한 모든 날짜 정보를 지우시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              viewModel.clearAllDates();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('모든 날짜 정보가 지워졌습니다.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text('지우기', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }

  void _exportToPDF(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF 출력 기능은 추후 구현 예정입니다.'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

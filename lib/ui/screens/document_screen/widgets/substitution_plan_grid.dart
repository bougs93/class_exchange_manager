import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../providers/exchange_screen_provider.dart';
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
  final Function(String)? onSupplementSubjectTap;

  SubstitutionPlanDataSource(this.planData, {this.onDateCellTap, this.onSupplementSubjectTap});

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
      if (cell.columnName == 'supplementSubject') {
        return _buildSupplementSubjectCell(cell, row);
      }
      return _buildNormalCell(cell);
    }).toList();

    return DataGridRowAdapter(cells: cells);
  }

  /// 보강 과목 셀 렌더링: 보강 교사명이 있으면 과목 선택 버튼을 제공 (과목이 있어도 재선택 가능)
  Widget _buildSupplementSubjectCell(DataGridCell cell, DataGridRow row) {
    final value = (cell.value?.toString() ?? '').trim();
    final isEmpty = value.isEmpty;

    // exchangeId 추출
    final exchangeIdCell = row.getCells().firstWhere(
      (c) => c.columnName == '_exchangeId',
      orElse: () => const DataGridCell<String>(columnName: '_exchangeId', value: ''),
    );
    final exchangeId = exchangeIdCell.value?.toString() ?? '';

    // 보강 교사명(성명) 셀 찾기
    final supplementTeacherCell = row.getCells().firstWhere(
      (c) => c.columnName == 'supplementTeacher',
      orElse: () => const DataGridCell<String>(columnName: 'supplementTeacher', value: ''),
    );
    final supplementTeacher = (supplementTeacherCell.value?.toString() ?? '').trim();
    final hasTeacher = supplementTeacher.isNotEmpty;

    // 보강 교사명이 있으면 항상 활성화 (과목이 있어도 재선택 가능)
    final isSelectable = hasTeacher;

    return GestureDetector(
      onTap: () async {
        if (exchangeId.isEmpty || !isSelectable) return;
        if (onSupplementSubjectTap != null) {
          onSupplementSubjectTap!(exchangeId);
        }
      },
      child: Container(
        alignment: Alignment.center,
        padding: _Spacing.cellPadding,
        decoration: BoxDecoration(
          // 과목이 비어있을 때만 버튼 스타일 적용
          color: isSelectable && isEmpty ? Colors.blue.shade50 : Colors.transparent,
          border: isSelectable && isEmpty ? Border.all(color: Colors.blue.shade200) : null,
          borderRadius: isSelectable && isEmpty ? BorderRadius.circular(4) : null,
        ),
        child: Text(
          isEmpty ? (hasTeacher ? '과목선택' : '') : value,
          style: TextStyle(
            fontSize: _Spacing.cellFontSize,
            height: 1.0,
            // 과목이 비어있을 때만 파란색 적용, 있을 때는 일반 텍스트 색상
            color: isSelectable && isEmpty ? Colors.blue.shade700 : Colors.black87,
            fontWeight: isSelectable && isEmpty ? FontWeight.w500 : FontWeight.normal,
            decoration: TextDecoration.none, // 밑줄 제거
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDateCell(DataGridCell cell, DataGridRow row) {
    // 교체일(substitutionDate) 컬럼인 경우 교사 이름 확인
    bool isSelectable = false;
    String displayText = '';
    
    if (cell.columnName == 'substitutionDate') {
      // 교체일 컬럼의 경우: 교체 교사가 있으면 항상 선택 가능 (날짜가 설정되어 있어도 재선택 가능)
      final substitutionTeacherCell = row.getCells().firstWhere(
        (c) => c.columnName == 'substitutionTeacher',
        orElse: () => const DataGridCell<String>(columnName: 'substitutionTeacher', value: ''),
      );
      final substitutionTeacher = (substitutionTeacherCell.value?.toString() ?? '').trim();
      final hasSubstitutionTeacher = substitutionTeacher.isNotEmpty;
      
      // 교체 교사가 있으면 항상 활성화 (날짜가 설정되어 있어도 재선택 가능)
      isSelectable = hasSubstitutionTeacher;
      displayText = cell.value?.toString() ?? '';
    } else {
      // 다른 날짜 컬럼(결강일 등)의 경우: 항상 선택 가능 (날짜가 설정되어 있어도 재선택 가능)
      isSelectable = true;
      displayText = cell.value?.toString() ?? '';
    }

    return GestureDetector(
      onTap: () {
        AppLogger.exchangeDebug('셀 클릭 - 컬럼: ${cell.columnName}, 값: ${cell.value}, 선택가능: $isSelectable');
        
        // 선택 불가능한 경우 클릭 무시
        if (!isSelectable) {
          AppLogger.exchangeDebug('교체일 선택 불가: 교체 교사가 없거나 이미 날짜가 설정됨');
          return;
        }
        
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
          // 날짜가 비어있거나 '선택'일 때만 버튼 스타일 적용
          color: isSelectable && (displayText.isEmpty || displayText == '선택') ? Colors.blue.shade50 : Colors.transparent,
          border: isSelectable && (displayText.isEmpty || displayText == '선택') ? Border.all(color: Colors.blue.shade200) : null,
          borderRadius: isSelectable && (displayText.isEmpty || displayText == '선택') ? BorderRadius.circular(4) : null,
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: _Spacing.cellFontSize,
            height: 1.0,
            // 날짜가 비어있거나 '선택'일 때만 파란색 적용, 있을 때는 일반 텍스트 색상
            color: isSelectable && (displayText.isEmpty || displayText == '선택') ? Colors.blue.shade700 : Colors.black87,
            fontWeight: isSelectable && (displayText.isEmpty || displayText == '선택') ? FontWeight.w500 : FontWeight.normal,
            decoration: TextDecoration.none, // 밑줄 제거
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
            onPressed: () async {
              // 새로고침 실행
              await viewModel.loadPlanData();
              // 새로고침 완료 후 planData 디버그 출력
              // ref를 통해 현재 상태를 가져와서 디버그 출력
              final currentState = ref.read(substitutionPlanViewModelProvider);
              _debugPrintPlanDataTable(currentState.planData);
            },
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
            label: const Text('지우기'),
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
      onSupplementSubjectTap: (exchangeId) => _showSubjectPickerDialog(context, ref, viewModel, exchangeId, state.planData),
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

  /// 과목 선택 다이얼로그 표시
  Future<void> _showSubjectPickerDialog(
    BuildContext context,
    WidgetRef ref,
    SubstitutionPlanViewModel viewModel,
    String exchangeId,
    List<SubstitutionPlanData> planData,
  ) async {
    // 1) 행 데이터에서 교사명 결정 (보강교사 우선, 없으면 원래 교사)
    final SubstitutionPlanData rowData = planData.firstWhere(
      (d) => d.exchangeId == exchangeId,
      orElse: () => SubstitutionPlanData(
        exchangeId: '',
        absenceDate: '',
        absenceDay: '',
        period: '',
        grade: '',
        className: '',
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
      ),
    );

    if (rowData.exchangeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('행 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    final String teacherName = (rowData.supplementTeacher.isNotEmpty)
        ? rowData.supplementTeacher
        : rowData.teacher;

    if (teacherName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('교사 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    // 2) 전역 시간표에서 해당 교사가 실제로 가르친 과목 목록 추출
    final timetableData = ref.read(exchangeScreenProvider).timetableData;
    if (timetableData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시간표 데이터가 없어 과목을 불러올 수 없습니다.')),
      );
      return;
    }

    final Set<String> subjectSet = <String>{};
    for (final slot in timetableData.timeSlots) {
      if (slot.teacher == teacherName && (slot.subject != null) && slot.subject!.trim().isNotEmpty) {
        subjectSet.add(slot.subject!.trim());
      }
    }

    final List<String> subjects = subjectSet.toList()..sort();

    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('교사 "$teacherName"의 과목 정보를 찾지 못했습니다.')),
      );
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String customInput = '';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('보강 과목 선택 - $teacherName'),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...subjects
                          .map((s) => ListTile(
                                title: Text(s),
                                onTap: () => Navigator.of(ctx).pop(s),
                              )),
                      const Divider(),
                      const Text('직접 입력'),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: '과목명을 입력하세요',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => customInput = v),
                        onSubmitted: (v) {
                          final t = v.trim();
                          if (t.isNotEmpty) Navigator.of(ctx).pop(t);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: customInput.trim().isEmpty
                      ? null
                      : () => Navigator.of(ctx).pop(customInput.trim()),
                  child: const Text('입력 적용'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null && selected.isNotEmpty) {
      // 비동기 갭 이후 BuildContext 사용을 안전하게 보장
      if (!context.mounted) return;
      viewModel.updateSupplementSubject(exchangeId, selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('보강 과목이 "$selected"(으)로 설정되었습니다.')),
      );
    }
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
        title: const Text('지우기'),
        content: const Text('입력한 모든 날짜 정보와 과목 선택을 지우시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
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
                  content: Text('모든 날짜 정보와 과목 선택이 지워졌습니다.'),
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

  /// planData 테이블을 디버그 콘솔에 표 형태로 출력하는 함수
  /// 
  /// 새로고침 시 호출되어 현재 planData의 내용을 콘솔에 표 형태로 출력합니다.
  /// 각 컬럼의 너비를 맞춰서 가독성 있게 표시합니다.
  void _debugPrintPlanDataTable(List<SubstitutionPlanData> planData) {
    if (planData.isEmpty) {
      AppLogger.exchangeDebug('=== PlanData 테이블 (빈 데이터) ===');
      return;
    }

    // 컬럼 헤더 정의 (한글명과 영문명 매핑)
    final Map<String, String> columnHeaders = {
      'exchangeId': '교체ID',
      'absenceDate': '결강일',
      'absenceDay': '결강요일',
      'period': '교시',
      'grade': '학년',
      'className': '반',
      'subject': '과목',
      'teacher': '교사',
      'supplementSubject': '보강과목',
      'supplementTeacher': '보강교사',
      'substitutionDate': '교체일',
      'substitutionDay': '교체요일',
      'substitutionPeriod': '교체교시',
      'substitutionSubject': '교체과목',
      'substitutionTeacher': '교체교사',
      'remarks': '비고',
    };

    // 출력할 컬럼 순서 정의 (exchangeId는 제외)
    final List<String> displayColumns = [
      'absenceDate', 'absenceDay', 'period', 'grade', 'className', 'subject', 'teacher',
      'supplementSubject', 'supplementTeacher', 'substitutionDate', 'substitutionDay',
      'substitutionPeriod', 'substitutionSubject', 'substitutionTeacher', 'remarks'
    ];

    // 각 컬럼의 최대 너비 계산
    Map<String, int> columnWidths = {};
    for (String column in displayColumns) {
      int maxWidth = columnHeaders[column]!.length; // 헤더 길이로 초기화
      for (SubstitutionPlanData data in planData) {
        String value = _getColumnValue(data, column);
        maxWidth = maxWidth > value.length ? maxWidth : value.length;
      }
      columnWidths[column] = maxWidth;
    }

    // 테이블 출력 시작
    AppLogger.exchangeDebug('=== PlanData 테이블 (총 ${planData.length}개 항목) ===');
    
    // 헤더 출력
    String headerLine = '';
    for (String column in displayColumns) {
      String header = columnHeaders[column]!;
      headerLine += header.padRight(columnWidths[column]! + 2);
    }
    AppLogger.exchangeDebug(headerLine);
    
    // 구분선 출력
    String separatorLine = '';
    for (String column in displayColumns) {
      separatorLine += '-'.padRight(columnWidths[column]! + 2, '-');
    }
    AppLogger.exchangeDebug(separatorLine);

    // 데이터 행 출력
    for (int i = 0; i < planData.length; i++) {
      SubstitutionPlanData data = planData[i];
      String dataLine = '';
      for (String column in displayColumns) {
        String value = _getColumnValue(data, column);
        dataLine += value.padRight(columnWidths[column]! + 2);
      }
      AppLogger.exchangeDebug('${(i + 1).toString().padLeft(3)}: $dataLine');
    }
    
    AppLogger.exchangeDebug('=== 테이블 출력 완료 ===');
  }

  /// SubstitutionPlanData 객체에서 특정 컬럼의 값을 문자열로 반환하는 헬퍼 함수
  /// 
  /// [data]: SubstitutionPlanData 객체
  /// [columnName]: 컬럼명 (영문)
  /// 반환: 해당 컬럼의 값 (문자열)
  String _getColumnValue(SubstitutionPlanData data, String columnName) {
    switch (columnName) {
      case 'absenceDate':
        return data.absenceDate;
      case 'absenceDay':
        return data.absenceDay;
      case 'period':
        return data.period;
      case 'grade':
        return data.grade;
      case 'className':
        return data.className;
      case 'subject':
        return data.subject;
      case 'teacher':
        return data.teacher;
      case 'supplementSubject':
        return data.supplementSubject;
      case 'supplementTeacher':
        return data.supplementTeacher;
      case 'substitutionDate':
        return data.substitutionDate;
      case 'substitutionDay':
        return data.substitutionDay;
      case 'substitutionPeriod':
        return data.substitutionPeriod;
      case 'substitutionSubject':
        return data.substitutionSubject;
      case 'substitutionTeacher':
        return data.substitutionTeacher;
      case 'remarks':
        return data.remarks;
      default:
        return '';
    }
  }
}

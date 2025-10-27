import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/services.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../../utils/logger.dart';
import '../../../mixins/scroll_management_mixin.dart';
import 'substitution_plan_grid_helpers.dart';

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
      return CellRendererFactory.build(
        cell,
        row,
        onDateCellTap: onDateCellTap,
        onSupplementSubjectTap: onSupplementSubjectTap,
      );
    }).toList();

    return DataGridRowAdapter(cells: cells);
  }
}

/// 보강계획서 그리드 위젯 (리팩토링 버전)
class SubstitutionPlanGrid extends ConsumerStatefulWidget {
  const SubstitutionPlanGrid({super.key});

  @override
  ConsumerState<SubstitutionPlanGrid> createState() => _SubstitutionPlanGridState();
}

class _SubstitutionPlanGridState extends ConsumerState<SubstitutionPlanGrid>
    with ScrollManagementMixin {
  
  @override
  void initState() {
    super.initState();
    // 공통 스크롤 관리 믹신 초기화
    initializeScrollControllers();
  }

  @override
  void dispose() {
    // 공통 스크롤 관리 믹신 해제
    disposeScrollControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Riverpod select 패턴 사용 - 필요한 상태만 구독
    final planData = ref.watch(
      substitutionPlanViewModelProvider.select((state) => state.planData)
    );
    final isLoading = ref.watch(
      substitutionPlanViewModelProvider.select((state) => state.isLoading)
    );
    final viewModel = ref.read(substitutionPlanViewModelProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButtons(context, ref, viewModel),
          const SizedBox(height: 10),
          _buildDataGrid(context, ref, planData, isLoading, viewModel),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, SubstitutionPlanViewModel viewModel) {
    return Row(
      children: [
        // 스크롤 가능한 버튼 영역
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await viewModel.loadPlanData();
                    final currentPlanData = ref.read(
                      substitutionPlanViewModelProvider.select((state) => state.planData)
                    );
                    SubstitutionPlanDebugger.printTable(currentPlanData);
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('새로고침'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: SubstitutionPlanGridConfig.mediumSpacing),
                ElevatedButton.icon(
                  onPressed: () => _clearAllDates(context, viewModel),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('지우기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: SubstitutionPlanGridConfig.mediumSpacing),
                // 테이블 복사 버튼 (지우기 버튼 오른쪽)
                IconButton(
                  onPressed: () => _copyTableToClipboard(context, ref),
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: '테이블 복사',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataGrid(
    BuildContext context,
    WidgetRef ref,
    List<SubstitutionPlanData> planData,
    bool isLoading,
    SubstitutionPlanViewModel viewModel,
  ) {
    if (isLoading) {
      return _buildLoadingIndicator();
    }

    if (planData.isEmpty) {
      return _buildEmptyState();
    }

    final dataSource = SubstitutionPlanDataSource(
      planData,
      onDateCellTap: (exchangeId, columnName) => _showDatePicker(context, ref, viewModel, exchangeId, columnName, planData),
      onSupplementSubjectTap: (exchangeId) => _showSubjectPickerDialog(context, ref, viewModel, exchangeId, planData),
    );

    return Expanded(
      child: wrapWithDragScroll(
        SfDataGrid(
          source: dataSource,
          columns: SubstitutionPlanGridConfig.getColumns(),
          stackedHeaderRows: SubstitutionPlanGridConfig.getStackedHeaders(),
          allowColumnsResizing: true,
          columnResizeMode: ColumnResizeMode.onResize,
          gridLinesVisibility: GridLinesVisibility.both,
          headerGridLinesVisibility: GridLinesVisibility.both,
          selectionMode: SelectionMode.single,
          headerRowHeight: 35,
          rowHeight: 28,
          allowEditing: false,
          // 교체 관리 시간표와 동일한 스크롤 컨트롤러 적용 (공통 믹신 사용)
          horizontalScrollController: horizontalScrollController,
          verticalScrollController: verticalScrollController,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined, size: 50, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('교체 기록이 없습니다', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('교체를 실행하면 여기에 기록이 표시됩니다', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
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
      if (!context.mounted) return;
      viewModel.updateSupplementSubject(exchangeId, selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('보강 과목이 "$selected"(으)로 설정되었습니다.')),
      );
    }
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

  /// 테이블 데이터를 엑셀 형식으로 클립보드에 복사
  /// 
  /// 탭(\t)으로 구분하여 엑셀에서 붙여넣기 시 각 셀에 데이터가 자동으로 분리됩니다.
  Future<void> _copyTableToClipboard(BuildContext context, WidgetRef ref) async {
    try {
      final planData = ref.read(
        substitutionPlanViewModelProvider.select((state) => state.planData)
      );

      if (planData.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('복사할 데이터가 없습니다.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 테이블 내용을 텍스트로 변환
      final tableText = _generateTableText(planData);

      // 클립보드에 복사
      await Clipboard.setData(ClipboardData(text: tableText));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${planData.length}개 행의 데이터가 클립보드에 복사되었습니다.'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('복사 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 테이블 내용을 탭 구분 텍스트로 변환
  /// 
  /// 엑셀에서 붙여넣기 시 각 셀에 자동으로 데이터가 분리됩니다.
  String _generateTableText(List<SubstitutionPlanData> data) {
    final buffer = StringBuffer();

    // 헤더 행 (탭으로 구분)
    const headers = [
      '결강일',
      '교시',
      '학년',
      '반',
      '과목',
      '교사',
      '보강/수업변경 과목',
      '보강/수업변경 성명',
      '교체일',
      '교체 교시',
      '교체 과목',
      '교체 교사',
      '비고',
    ];
    buffer.writeln(headers.join('\t'));

    // 데이터 행
    for (final row in data) {
      final cells = [
        '${row.absenceDate}(${row.absenceDay})',  // 결강일(요일)
        row.period,                 // 교시
        row.grade,                  // 학년
        row.className,              // 반
        row.subject,                // 과목 (결강)
        row.teacher,                // 교사 (결강)
        row.supplementSubject,      // 보강/수업변경 과목
        row.supplementTeacher,      // 보강/수업변경 성명
        '${row.substitutionDate}(${row.substitutionDay})',  // 교체일(교체 요일)
        row.substitutionPeriod,     // 교체 교시
        row.substitutionSubject,    // 교체 과목
        row.substitutionTeacher,    // 교체 교사
        row.remarks,                // 비고
      ];
      buffer.writeln(cells.join('\t'));
    }

    return buffer.toString();
  }

}

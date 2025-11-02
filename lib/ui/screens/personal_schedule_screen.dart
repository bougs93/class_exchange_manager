import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/pdf_export_settings_storage_service.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/personal_schedule_provider.dart';
import '../../utils/personal_timetable_helper.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../../utils/cell_style_config.dart';
import '../../utils/week_date_calculator.dart';
import '../../utils/logger.dart';
import '../../models/time_slot.dart';
import '../../ui/widgets/timetable_grid/grid_header_widgets.dart';
import '../../providers/substitution_plan_provider.dart';
import '../../providers/services_provider.dart';
import '../../services/excel_service.dart';
import '../../utils/personal_exchange_filter.dart';
import '../../utils/personal_exchange_view_manager.dart';

/// 개인 시간표 화면
/// 
/// 설정에서 저장한 교사명에 해당하는 개인 시간표를 표시합니다.
/// - 세로행: 교시
/// - 가로행: 요일 (날짜 포함)
/// - 교체 뷰 스위치로 교체관리와 동일한 기능 제공
class PersonalScheduleScreen extends ConsumerStatefulWidget {
  const PersonalScheduleScreen({super.key});

  @override
  ConsumerState<PersonalScheduleScreen> createState() => _PersonalScheduleScreenState();
}

class _PersonalScheduleScreenState extends ConsumerState<PersonalScheduleScreen> {
  bool _isLoadingTeacherName = true;
  PersonalTimetableDataSource? _dataSource;
  bool _isExchangeViewEnabled = false;
  List<TimeSlot>? _originalTimeSlots; // 원본 데이터 백업용

  @override
  void initState() {
    super.initState();
    _loadTeacherName();
  }

  /// 설정에서 교사명 로드
  /// 
  /// 설정 화면에서 저장한 교사명을 기본값으로 설정합니다.
  Future<void> _loadTeacherName() async {
    try {
      final pdfSettings = PdfExportSettingsStorageService();
      final defaults = await pdfSettings.loadDefaultTeacherAndSchoolName();
      final teacherName = defaults['defaultTeacherName'] ?? '';
      
      setState(() {
        _isLoadingTeacherName = false;
      });
      
      // Provider에 교사명 설정 (비어있지 않은 경우에만)
      if (teacherName.isNotEmpty) {
        ref.read(personalScheduleProvider.notifier).setTeacherName(teacherName);
      }
    } catch (e) {
      AppLogger.error('교사명 로드 중 오류: $e', e);
      setState(() {
        _isLoadingTeacherName = false;
      });
    }
  }

  /// 교사 선택 팝업 표시
  /// 
  /// 전체 교사 목록을 표시하고 선택할 수 있는 다이얼로그를 보여줍니다.
  Future<void> _showTeacherSelectionDialog() async {
    final timetableData = ref.read(exchangeScreenProvider).timetableData;
    if (timetableData == null || timetableData.teachers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('시간표 데이터가 없거나 교사 목록이 비어있습니다.'),
          ),
        );
      }
      return;
    }

    // 교사명 목록 생성 (중복 제거 후 정렬)
    final teacherNames = timetableData.teachers
        .map((teacher) => teacher.name)
        .toSet()
        .toList()
      ..sort();

    // 현재 선택된 교사명 가져오기
    final currentTeacherName = ref.read(personalScheduleProvider).teacherName;

    // 다이얼로그 표시
    final selectedTeacherName = await showDialog<String>(
      context: context,
      builder: (context) => _TeacherSelectionDialog(
        teacherNames: teacherNames,
        currentTeacherName: currentTeacherName,
      ),
    );

    // 교사 선택 시 Provider 업데이트
    if (selectedTeacherName != null && selectedTeacherName.isNotEmpty) {
      ref.read(personalScheduleProvider.notifier).setTeacherName(selectedTeacherName);
      
      // 교체 뷰가 활성화되어 있으면 비활성화 (새 교사 선택 시 원본 데이터로 초기화)
      if (_isExchangeViewEnabled) {
        setState(() {
          _isExchangeViewEnabled = false;
        });
        // 원본 데이터로 복원
        await _disablePersonalExchangeView(timetableData);
      }
      
      // DataSource 초기화 (새 교사로 시간표 재생성)
      setState(() {
        _dataSource = null;
        _originalTimeSlots = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(personalScheduleProvider);
    final timetableData = ref.watch(exchangeScreenProvider).timetableData;
    final teacherName = scheduleState.teacherName;

    // 로딩 중인 경우 처리
    if (_isLoadingTeacherName) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 교사명이 없거나 시간표 데이터가 없는 경우 처리
    if (teacherName == null || teacherName.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('개인 시간표'),
          actions: [
            // 교사 선택 버튼
            IconButton(
              icon: const Icon(Icons.person_search),
              onPressed: _showTeacherSelectionDialog,
              tooltip: '교사 선택',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                '교사명이 설정되지 않았습니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '우측 상단 버튼을 눌러 교사를 선택하거나,\n설정 화면에서 교사명을 입력해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (timetableData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('개인 시간표'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.table_chart_outlined,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                '시간표 데이터가 없습니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '홈 화면에서 시간표 파일을 먼저 선택해주세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 원본 데이터 백업 (교체 뷰 비활성화 시 복원용)
    // 교사명이 변경되었을 때도 원본 데이터 재백업
    if (_originalTimeSlots == null || 
        (ref.read(personalScheduleProvider).teacherName != teacherName)) {
      _originalTimeSlots = List<TimeSlot>.from(timetableData.timeSlots);
    }

    // 교체 뷰가 활성화되어 있지 않으면 원본 데이터 사용, 활성화되어 있으면 현재 시간표 데이터 사용
    final timeSlotsToUse = _isExchangeViewEnabled
        ? timetableData.timeSlots
        : List<TimeSlot>.from(_originalTimeSlots!);

    // 개인 시간표 데이터 생성
    final weekDates = scheduleState.weekDates;
    final result = PersonalTimetableHelper.convertToPersonalTimetableData(
      timeSlotsToUse,
      teacherName,
      weekDates,
    );

    // DataSource 생성 또는 업데이트
    if (_dataSource == null || _dataSource!._rows.length != result.rows.length) {
      _dataSource = PersonalTimetableDataSource(
        rows: result.rows,
      );
    } else {
      _dataSource!.updateRows(result.rows);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // 교사 선택 버튼 (아이콘 + 텍스트)
            InkWell(
              onTap: _showTeacherSelectionDialog,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_search,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '교사 선택',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 현재 교사명
            Expanded(
              child: Text(
                '$teacherName 선생님 시간표',
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 주 이동 및 교체 뷰 스위치 컨트롤 패널
          _buildControlPanel(scheduleState, weekDates),
          
          // 시간표 그리드
          Expanded(
            child: SfDataGrid(
              source: _dataSource!,
              columns: result.columns,
              stackedHeaderRows: result.stackedHeaders,
              gridLinesVisibility: GridLinesVisibility.both,
              headerGridLinesVisibility: GridLinesVisibility.both,
              allowSorting: false,
              allowTriStateSorting: false,
              columnWidthMode: ColumnWidthMode.fill,
            ),
          ),
        ],
      ),
    );
  }

  /// 컨트롤 패널 위젯 (주 이동 버튼 + 교체 뷰 스위치)
  Widget _buildControlPanel(PersonalScheduleState scheduleState, List<DateTime> weekDates) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // 이전 주 버튼
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(personalScheduleProvider.notifier).moveToPreviousWeek();
            },
            tooltip: '이전 주',
          ),
          
          // 현재 주 정보
          Expanded(
            child: Center(
              child: Text(
                WeekDateCalculator.formatWeekRange(scheduleState.currentWeekMonday),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          // 다음 주 버튼
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ref.read(personalScheduleProvider.notifier).moveToNextWeek();
            },
            tooltip: '다음 주',
          ),
          
          const SizedBox(width: 16),
          
          // 교체 뷰 스위치
          ExchangeViewCheckbox(
            isEnabled: _isExchangeViewEnabled,
            onChanged: (enabled) {
              if (enabled != null) {
                _handleExchangeViewToggle(enabled, scheduleState.weekDates);
              }
            },
          ),
        ],
      ),
    );
  }

  /// 교체 뷰 스위치 토글 처리
  Future<void> _handleExchangeViewToggle(bool enabled, List<DateTime> weekDates) async {
    final timetableData = ref.read(exchangeScreenProvider).timetableData;
    final teacherName = ref.read(personalScheduleProvider).teacherName;
    if (timetableData == null || teacherName == null) return;

    setState(() {
      _isExchangeViewEnabled = enabled;
    });

    if (enabled) {
      // 교체 뷰 활성화: 필터링된 교체 리스트 사용
      await _enablePersonalExchangeView(weekDates, timetableData);
    } else {
      // 교체 뷰 비활성화: 원본 데이터로 복원
      await _disablePersonalExchangeView(timetableData);
    }
  }

  /// 개인 시간표 교체 뷰 활성화
  Future<void> _enablePersonalExchangeView(
    List<DateTime> weekDates,
    TimetableData timetableData,
  ) async {
    try {
      final historyService = ref.read(exchangeHistoryServiceProvider);
      final substitutionPlanState = ref.read(substitutionPlanProvider);

      // 필터링된 교체 리스트 가져오기
      final teacherName = ref.read(personalScheduleProvider).teacherName;
      if (teacherName == null) return;
      
      final filteredExchanges = PersonalExchangeFilter.filterExchangesForPersonalSchedule(
        teacherName: teacherName,
        weekDates: weekDates,
        substitutionPlanState: substitutionPlanState,
        historyService: historyService,
      );

      // 필터링된 교체 리스트로 교체 뷰 활성화
      await PersonalExchangeViewManager.enableExchangeView(
        filteredExchanges: filteredExchanges,
        timeSlots: timetableData.timeSlots,
        teachers: timetableData.teachers,
        dataSource: _dataSource!,
      );

      // UI 업데이트를 위해 상태 갱신
      setState(() {});
    } catch (e) {
      AppLogger.error('개인 시간표 교체 뷰 활성화 중 오류: $e', e);
    }
  }

  /// 개인 시간표 교체 뷰 비활성화
  Future<void> _disablePersonalExchangeView(TimetableData timetableData) async {
    try {
      // 원본 데이터로 복원
      await PersonalExchangeViewManager.disableExchangeView(
        originalTimetableData: TimetableData(
          timeSlots: List<TimeSlot>.from(_originalTimeSlots!),
          teachers: timetableData.teachers,
          config: timetableData.config,
          totalParsedCells: timetableData.totalParsedCells,
          successCount: timetableData.successCount,
          errorCount: timetableData.errorCount,
        ),
        timeSlots: timetableData.timeSlots,
        teachers: timetableData.teachers,
        dataSource: _dataSource!,
      );

      // UI 업데이트를 위해 상태 갱신
      setState(() {});
    } catch (e) {
      AppLogger.error('개인 시간표 교체 뷰 비활성화 중 오류: $e', e);
    }
  }
}

/// 개인 시간표용 DataSource
/// 
/// 교시가 행이고 요일이 열인 구조를 위한 DataSource
class PersonalTimetableDataSource extends DataGridSource {
  PersonalTimetableDataSource({
    required List<DataGridRow> rows,
  })  : _rows = rows;

  List<DataGridRow> _rows;

  void updateRows(List<DataGridRow> newRows) {
    _rows = newRows;
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().asMap().entries.map<Widget>((entry) {
        final dataGridCell = entry.value;
        final isPeriodColumn = dataGridCell.columnName == 'period';

        // 교시 헤더 열인 경우
        if (isPeriodColumn) {
          return Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SimplifiedTimetableTheme.teacherHeaderColor,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              dataGridCell.value.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        // 시간표 셀인 경우
        final timeSlot = dataGridCell.value as TimeSlot?;
        final content = timeSlot?.displayText ?? '';

        // 셀 스타일 결정 (개인 시간표는 교체 관련 상태가 없으므로 기본값 사용)
        final style = SimplifiedTimetableTheme.getCellStyleFromConfig(
          CellStyleConfig(
            isTeacherColumn: false,
            isSelected: false,
            isExchangeable: false,
            isLastColumnOfDay: false,
            isFirstColumnOfDay: false,
            isHeader: false,
            isInCircularPath: false,
            circularPathStep: null,
            isInSelectedPath: false,
            isInChainPath: false,
            chainPathStep: null,
            isTargetCell: false,
            isNonExchangeable: false,
            isExchangedSourceCell: false,
            isExchangedDestinationCell: false,
            isTeacherNameSelected: false,
            isHighlightedTeacher: false,
          ),
        );

        return Container(
          padding: const EdgeInsets.all(4.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.backgroundColor,
            border: style.border,
          ),
          child: Text(
            content,
            style: style.textStyle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}

/// 교사 선택 다이얼로그 위젯
/// 
/// 전체 교사 목록을 리스트 형태로 표시하고 선택할 수 있는 다이얼로그입니다.
class _TeacherSelectionDialog extends StatefulWidget {
  /// 선택 가능한 교사명 목록
  final List<String> teacherNames;
  
  /// 현재 선택된 교사명 (없으면 null)
  final String? currentTeacherName;

  const _TeacherSelectionDialog({
    required this.teacherNames,
    this.currentTeacherName,
  });

  @override
  State<_TeacherSelectionDialog> createState() => _TeacherSelectionDialogState();
}

class _TeacherSelectionDialogState extends State<_TeacherSelectionDialog> {
  /// 검색어 필터링용
  String _searchQuery = '';

  /// 검색어로 필터링된 교사명 목록
  List<String> get _filteredTeacherNames {
    if (_searchQuery.isEmpty) {
      return widget.teacherNames;
    }
    
    // 검색어가 포함된 교사명만 필터링 (대소문자 구분 없음)
    return widget.teacherNames
        .where((name) => name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        height: 600,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 헤더
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '교사 선택',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '닫기',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 검색 필드
            TextField(
              decoration: InputDecoration(
                hintText: '교사명 검색...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // 교사 목록
            Expanded(
              child: _filteredTeacherNames.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? '교사 목록이 비어있습니다'
                                : '검색 결과가 없습니다',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredTeacherNames.length,
                      itemBuilder: (context, index) {
                        final teacherName = _filteredTeacherNames[index];
                        final isSelected = teacherName == widget.currentTeacherName;
                        
                        return ListTile(
                          // 현재 선택된 교사는 체크 아이콘 표시
                          leading: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).primaryColor,
                                )
                              : const Icon(Icons.person_outline),
                          title: Text(teacherName),
                          // 현재 선택된 교사는 배경색 변경
                          tileColor: isSelected
                              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                              : null,
                          onTap: () {
                            // 선택한 교사명 반환하고 다이얼로그 닫기
                            Navigator.of(context).pop(teacherName);
                          },
                        );
                      },
                    ),
            ),
            
            // 하단 정보
            if (widget.teacherNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '총 ${widget.teacherNames.length}명의 교사',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

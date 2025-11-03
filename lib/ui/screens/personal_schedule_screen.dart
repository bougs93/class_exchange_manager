import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/pdf_export_settings_storage_service.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/personal_schedule_provider.dart';
import '../../utils/personal_timetable_helper.dart';
import '../../utils/week_date_calculator.dart';
import '../../utils/logger.dart';
import '../../models/time_slot.dart';
import '../../ui/widgets/timetable_grid/grid_header_widgets.dart';
import '../../ui/widgets/simplified_timetable_cell.dart';
import '../../models/exchange_history_item.dart';
import '../../models/exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/supplement_exchange_path.dart';
import '../../providers/substitution_plan_provider.dart';
import '../../providers/services_provider.dart';
import '../../services/excel_service.dart';
import '../../utils/personal_exchange_filter.dart';
import '../../utils/personal_exchange_view_manager.dart';
import '../../providers/zoom_provider.dart';
import '../../ui/widgets/timetable_grid/grid_scaling_helper.dart';
import '../../ui/widgets/timetable_grid/timetable_grid_constants.dart';

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

    // 개인 시간표 데이터 생성 (줌 팩터는 Consumer 내부에서 동적으로 처리)
    final weekDates = scheduleState.weekDates;
    // 주의: 헤더 폰트 사이즈는 Consumer 내부에서 줌 팩터를 반영하여 재생성됨
    final result = PersonalTimetableHelper.convertToPersonalTimetableData(
      timeSlotsToUse,
      teacherName,
      weekDates,
    );

    // 교체 리스트 정보 가져오기 (셀 테마 적용용)
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final substitutionPlanState = ref.read(substitutionPlanProvider);
    final filteredExchanges = PersonalExchangeFilter.filterExchangesForPersonalSchedule(
      teacherName: teacherName,
      weekDates: weekDates,
      substitutionPlanState: substitutionPlanState,
      historyService: historyService,
    );

    // DataSource 생성 또는 업데이트
    if (_dataSource == null || _dataSource!._rows.length != result.rows.length) {
      _dataSource = PersonalTimetableDataSource(
        rows: result.rows,
        teacherName: teacherName,
        filteredExchanges: filteredExchanges,
      );
    } else {
      _dataSource!.updateRows(
        result.rows,
        teacherName: teacherName,
        filteredExchanges: filteredExchanges,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // 교사 선택 버튼 (아이콘 + 교사명, 검색 기능 유지)
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
                    Text(
                      teacherName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 기간선택 (이전에 "선생님 시간표" 위치였던 부분)
            SizedBox(
              width: 200, // 고정폭 설정 (날짜 범위 텍스트가 잘리지 않도록 넓게 설정)
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 이전 주 버튼
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      ref.read(personalScheduleProvider.notifier).moveToPreviousWeek();
                    },
                    tooltip: '이전 주',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  // 현재 주 정보 (왼쪽 정렬)
                  Expanded(
                    child: Text(
                      WeekDateCalculator.formatWeekRange(scheduleState.currentWeekMonday),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.visible, // 텍스트가 잘리지 않도록 설정
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 다음 주 버튼
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      ref.read(personalScheduleProvider.notifier).moveToNextWeek();
                    },
                    tooltip: '다음 주',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 줌 컨트롤 및 교체 뷰 스위치 컨트롤 패널
          _buildControlPanel(scheduleState, weekDates),
          
          // 시간표 그리드 (줌 팩터 적용)
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final zoomFactor = ref.watch(zoomProvider.select((s) => s.zoomFactor));
                
                // 줌 팩터에 따라 헤더 재생성 (폰트 사이즈 반영)
                final resultWithZoom = PersonalTimetableHelper.convertToPersonalTimetableData(
                  timeSlotsToUse,
                  teacherName,
                  weekDates,
                  zoomFactor: zoomFactor,
                );
                
                // 줌 팩터에 따라 컬럼과 헤더 스케일링
                final scaledColumns = GridScalingHelper.scaleColumns(resultWithZoom.columns, zoomFactor);
                final scaledStackedHeaders = GridScalingHelper.scaleStackedHeaders(resultWithZoom.stackedHeaders, zoomFactor);
                
                // DataSource 업데이트 (줌 팩터에 따라 행 데이터도 업데이트)
                _dataSource?.updateRows(
                  resultWithZoom.rows,
                  teacherName: teacherName,
                  filteredExchanges: filteredExchanges,
                );
                
                // 테이블 주변 여백 추가를 위해 Padding으로 감싸기
                return Padding(
                  padding: const EdgeInsets.all(16.0), // 상하좌우 16px 여백 추가
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textTheme: Theme.of(context).textTheme.copyWith(
                        bodyMedium: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                        bodySmall: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                        titleMedium: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                        labelMedium: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                        labelLarge: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                        labelSmall: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                      ),
                    ),
                    child: SfDataGrid(
                      source: _dataSource!,
                      columns: scaledColumns,
                      stackedHeaderRows: scaledStackedHeaders,
                      gridLinesVisibility: GridLinesVisibility.both,
                      headerGridLinesVisibility: GridLinesVisibility.both,
                      allowSorting: false,
                      allowTriStateSorting: false,
                      columnWidthMode: ColumnWidthMode.fill,
                      // 개인 시간표 테이블 크기 20% 증가 적용 (세로 높이)
                      headerRowHeight: GridScalingHelper.scaleHeaderHeight(zoomFactor) * 1.2,
                      rowHeight: GridScalingHelper.scaleRowHeight(zoomFactor) * 1.2,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 컨트롤 패널 위젯 (줌 컨트롤 + 교체 뷰 스위치)
  /// 
  /// 레이아웃 순서: 줌 컨트롤 → 교체 뷰 스위치
  /// 기간선택은 AppBar로 이동됨
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
          // 확대/축소 컨트롤
          Consumer(
            builder: (context, ref, child) {
              final zoomState = ref.watch(zoomProvider);
              final zoomNotifier = ref.read(zoomProvider.notifier);
              
              return ZoomControlWidget(
                zoomPercentage: zoomState.zoomPercentage,
                zoomFactor: zoomState.zoomFactor,
                minZoom: zoomState.minZoom,
                maxZoom: zoomState.maxZoom,
                onZoomIn: zoomNotifier.zoomIn,
                onZoomOut: zoomNotifier.zoomOut,
                onResetZoom: zoomNotifier.resetZoom,
              );
            },
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
      await _enablePersonalExchangeView(weekDates, timetableData, context);
    } else {
      // 교체 뷰 비활성화: 원본 데이터로 복원
      await _disablePersonalExchangeView(timetableData);
    }
  }

  /// 개인 시간표 교체 뷰 활성화
  Future<void> _enablePersonalExchangeView(
    List<DateTime> weekDates,
    TimetableData timetableData,
    BuildContext context,
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

      // 날짜가 없는 교체 항목 확인
      final exchangesWithoutDate = <ExchangeHistoryItem>[];
      for (final exchange in filteredExchanges) {
        final exchangeId = exchange.id;
        final absenceDateStr = substitutionPlanState.savedDates['${exchangeId}_absenceDate'] ?? '';
        final substitutionDateStr = substitutionPlanState.savedDates['${exchangeId}_substitutionDate'] ?? '';
        
        // 날짜가 하나도 지정되지 않은 경우
        if (absenceDateStr.isEmpty && substitutionDateStr.isEmpty) {
          exchangesWithoutDate.add(exchange);
        }
      }

      // 날짜가 없는 교체가 있는 경우 경고 메시지 표시
      if (exchangesWithoutDate.isNotEmpty) {
        final count = exchangesWithoutDate.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '경고: 날짜가 지정되지 않은 교체 항목 $count개가 포함되어 있습니다. 결보강 계획서에서 날짜를 지정해주세요.',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '확인',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }

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
    required String teacherName,
    required List<ExchangeHistoryItem> filteredExchanges,
  })  : _rows = rows,
        _teacherName = teacherName,
        _filteredExchanges = filteredExchanges;

  List<DataGridRow> _rows;
  String _teacherName;
  List<ExchangeHistoryItem> _filteredExchanges;

  void updateRows(
    List<DataGridRow> newRows, {
    required String teacherName,
    required List<ExchangeHistoryItem> filteredExchanges,
  }) {
    _rows = newRows;
    _teacherName = teacherName;
    _filteredExchanges = filteredExchanges;
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
          // 교체 관리 화면과 동일한 SimplifiedTimetableCell 사용
          return SimplifiedTimetableCell(
            content: dataGridCell.value.toString(),
            isTeacherColumn: true, // 교시 헤더는 교사명 열과 동일한 스타일 적용
            isSelected: false,
            isExchangeable: false,
            isLastColumnOfDay: false,
            isFirstColumnOfDay: false,
            isHeader: true, // 헤더로 표시
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
          );
        }

        // 시간표 셀인 경우
        final timeSlot = dataGridCell.value as TimeSlot?;
        final content = timeSlot?.displayText ?? '';

        // 교체 정보 확인 (교체 리스트에서 셀 상태 확인)
        final columnName = dataGridCell.columnName;
        final cellState = _getCellStateFromExchangeList(columnName);

        // 교체 관리 화면과 동일한 SimplifiedTimetableCell 사용
        // 교체 리스트 정보를 기반으로 셀 테마 적용
        return SimplifiedTimetableCell(
          content: content,
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
          isExchangedSourceCell: cellState.isExchangedSourceCell,
          isExchangedDestinationCell: cellState.isExchangedDestinationCell,
            isTeacherNameSelected: false,
            isHighlightedTeacher: false,
        );
      }).toList(),
    );
  }

  /// 교체 리스트에서 셀 상태 확인
  /// 
  /// columnName에서 요일과 교시를 추출하여 교체 정보를 확인합니다.
  /// 반환값: 교체된 소스 셀과 목적지 셀 여부
  ({bool isExchangedSourceCell, bool isExchangedDestinationCell}) _getCellStateFromExchangeList(String columnName) {
    // columnName 형식: '${day}_$period' (예: '월_1', '화_2')
    final parts = columnName.split('_');
    if (parts.length != 2) {
      return (isExchangedSourceCell: false, isExchangedDestinationCell: false);
    }

    final day = parts[0];
    final period = int.tryParse(parts[1]) ?? 0;

    // 교체 리스트에서 해당 셀이 교체된 소스 셀인지 목적지 셀인지 확인
    bool isSourceCell = false;
    bool isDestinationCell = false;

    for (final exchange in _filteredExchanges) {
      final path = exchange.originalPath;
      
      // 소스 셀 확인 (교체 전 원본 위치)
      if (_isSourceCell(path, _teacherName, day, period)) {
        isSourceCell = true;
      }
      
      // 목적지 셀 확인 (교체 후 새 교사가 배정된 위치)
      if (_isDestinationCell(path, _teacherName, day, period)) {
        isDestinationCell = true;
      }
      
      // 둘 다 확인되면 더 이상 확인 불필요
      if (isSourceCell && isDestinationCell) break;
    }

    return (
      isExchangedSourceCell: isSourceCell,
      isExchangedDestinationCell: isDestinationCell,
    );
  }

  /// 교체 경로에서 소스 셀인지 확인 (교체 전 원본 위치)
  bool _isSourceCell(ExchangePath path, String teacherName, String day, int period) {
    try {
      if (path is OneToOneExchangePath) {
        // 1:1 교체: sourceNode와 targetNode 모두 소스 셀
        return (path.sourceNode.teacherName == teacherName && 
                path.sourceNode.day == day && 
                path.sourceNode.period == period) ||
               (path.targetNode.teacherName == teacherName && 
                path.targetNode.day == day && 
                path.targetNode.period == period);
      } else if (path is CircularExchangePath) {
        // 순환 교체: 마지막 노드를 제외한 모든 노드가 소스 셀
        return path.nodes.take(path.nodes.length - 1).any((node) =>
          node.teacherName == teacherName && 
          node.day == day && 
          node.period == period
        );
      } else if (path is ChainExchangePath) {
        // 연쇄 교체: 모든 노드가 소스 셀
        return [path.nodeA, path.nodeB, path.node1, path.node2].any((node) =>
          node.teacherName == teacherName && 
          node.day == day && 
          node.period == period
        );
      } else if (path is SupplementExchangePath) {
        // 보강 교체: 소스 셀만 교체된 소스 셀로 표시
        return path.sourceNode.teacherName == teacherName && 
               path.sourceNode.day == day && 
               path.sourceNode.period == period;
      }
    } catch (e) {
      AppLogger.error('소스 셀 확인 중 오류: $e', e);
    }
    return false;
  }

  /// 교체 경로에서 목적지 셀인지 확인 (교체 후 새 교사가 배정된 위치)
  bool _isDestinationCell(ExchangePath path, String teacherName, String day, int period) {
    try {
      if (path is OneToOneExchangePath) {
        // 1:1 교체: 각 노드가 상대 노드의 위치로 이동
        return (path.targetNode.teacherName == teacherName && 
                path.sourceNode.day == day && 
                path.sourceNode.period == period) ||
               (path.sourceNode.teacherName == teacherName && 
                path.targetNode.day == day && 
                path.targetNode.period == period);
      } else if (path is CircularExchangePath) {
        // 순환 교체: 각 노드가 다음 노드의 위치로 이동
        for (int i = 0; i < path.nodes.length - 1; i++) {
          final currentNode = path.nodes[i];
          final nextNode = path.nodes[i + 1];
          if (currentNode.teacherName == teacherName && 
              nextNode.day == day && 
              nextNode.period == period) {
            return true;
          }
        }
      } else if (path is ChainExchangePath) {
        // 연쇄 교체: 각 단계별 목적지 셀 확인
        // 1단계: node1이 node2 위치로, node2가 node1 위치로
        if ((path.node1.teacherName == teacherName && 
             path.node2.day == day && 
             path.node2.period == period) ||
            (path.node2.teacherName == teacherName && 
             path.node1.day == day && 
             path.node1.period == period)) {
          return true;
        }
        // 2단계: nodeA가 nodeB 위치로, nodeB가 nodeA 위치로
        if ((path.nodeA.teacherName == teacherName && 
             path.nodeB.day == day && 
             path.nodeB.period == period) ||
            (path.nodeB.teacherName == teacherName && 
             path.nodeA.day == day && 
             path.nodeA.period == period)) {
          return true;
        }
      } else if (path is SupplementExchangePath) {
        // 보강 교체: 타겟 노드의 위치가 목적지 셀
        return path.targetNode.teacherName == teacherName && 
               path.targetNode.day == day && 
               path.targetNode.period == period;
      }
    } catch (e) {
      AppLogger.error('목적지 셀 확인 중 오류: $e', e);
    }
    return false;
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

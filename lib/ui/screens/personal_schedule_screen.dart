import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/pdf_export_settings_storage_service.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/personal_schedule_provider.dart';
import '../../utils/personal_timetable_helper.dart';
import '../../utils/week_date_calculator.dart';
import '../../utils/logger.dart';
import '../../utils/personal_schedule_debug_helper.dart';
import '../../models/time_slot.dart';
import '../../ui/widgets/timetable_grid/grid_header_widgets.dart';
import '../../ui/widgets/simplified_timetable_cell.dart';
import '../../providers/services_provider.dart';
import '../../providers/substitution_plan_provider.dart';
import '../../models/exchange_history_item.dart';
import '../../services/excel_service.dart';
import '../../utils/personal_exchange_filter.dart';
import '../../utils/personal_exchange_view_manager.dart';
import '../../providers/zoom_provider.dart';
import '../../ui/widgets/timetable_grid/grid_scaling_helper.dart';
import '../../ui/widgets/timetable_grid/timetable_grid_constants.dart';
import '../../utils/simplified_timetable_theme.dart';

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
  DateTime? _lastCheckTime; // 마지막 확인 시간 (중복 호출 방지)
  bool _isCheckingTeacherName = false; // 교사명 확인 중 플래그 (중복 실행 방지)

  @override
  void initState() {
    super.initState();
    _checkAndLoadTeacherName(isInitialLoad: true);
  }

  /// 시간표 데이터 초기화 헬퍼 메서드
  void _clearTimetableData() {
    setState(() {
      _dataSource = null;
      _originalTimeSlots = null;
      _isExchangeViewEnabled = false;
    });
  }

  /// 설정에서 교사명 확인 및 로드
  ///
  /// 설정 화면에서 저장한 교사명을 확인하고, 없으면 시간표 데이터를 지웁니다.
  ///
  /// 매개변수:
  /// - `isInitialLoad`: 초기 로드인지 여부 (로딩 상태 관리용)
  Future<void> _checkAndLoadTeacherName({required bool isInitialLoad}) async {
    // 중복 실행 방지
    if (_isCheckingTeacherName) return;

    _isCheckingTeacherName = true;

    try {
      final pdfSettings = PdfExportSettingsStorageService();
      final defaults = await pdfSettings.loadDefaultTeacherAndSchoolName();
      final teacherName = defaults['defaultTeacherName'] ?? '';

      if (isInitialLoad) {
        setState(() {
          _isLoadingTeacherName = false;
        });
      }

      final currentTeacherName = ref.read(personalScheduleProvider).teacherName;

      // 교사명이 설정에 없는 경우
      if (teacherName.isEmpty) {
        _handleEmptyTeacherName(currentTeacherName);
        return;
      }

      // 교사명이 변경되지 않은 경우
      if (teacherName == currentTeacherName) {
        return;
      }

      // 교사명 업데이트
      ref.read(personalScheduleProvider.notifier).setTeacherName(teacherName);

      // 기존 교사명이 있었다면 시간표 초기화 (새 교사로 변경됨)
      if (currentTeacherName != null && currentTeacherName.isNotEmpty) {
        _clearTimetableData();
      }
    } catch (e) {
      AppLogger.error('교사명 확인 중 오류: $e', e);
      if (isInitialLoad) {
        setState(() {
          _isLoadingTeacherName = false;
        });
      }
    } finally {
      _isCheckingTeacherName = false;
      // 마지막 확인 시간 업데이트 (성공/실패 관계없이)
      if (!isInitialLoad) {
        _lastCheckTime = DateTime.now();
      }
    }
  }

  /// 교사명이 비어있을 때 처리
  void _handleEmptyTeacherName(String? currentTeacherName) {
    if (currentTeacherName == null || currentTeacherName.isEmpty) {
      return; // 이미 비어있으면 아무것도 하지 않음
    }

    // 교사명 제거 및 시간표 초기화
    ref.read(personalScheduleProvider.notifier).setTeacherName('');
    _clearTimetableData();
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

    // 화면이 표시될 때마다 교사명 확인 (중복 호출 방지: 0.3초 이내 재호출 방지)
    final now = DateTime.now();
    if (_lastCheckTime == null || now.difference(_lastCheckTime!).inMilliseconds > 300) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndLoadTeacherName(isInitialLoad: false);
        }
      });
    }

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

    // DataSource 생성 또는 업데이트
    if (_dataSource == null || _dataSource!._rows.length != result.rows.length) {
      _dataSource = PersonalTimetableDataSource(
        rows: result.rows,
      );
    } else {
      _dataSource!.updateRows(
        result.rows,
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          // 디버그 버튼
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _showDebugInfo(scheduleState, timetableData, teacherName),
            tooltip: '디버그 정보',
          ),
        ],
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
            const SizedBox(width: 8),
            // 현재 주차로 이동 버튼
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: _isCurrentWeek(scheduleState.currentWeekMonday)
                  ? null
                  : () {
                      ref.read(personalScheduleProvider.notifier).moveToThisWeek();
                    },
              tooltip: '현재 주차로 이동',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: _isCurrentWeek(scheduleState.currentWeekMonday)
                  ? Colors.grey
                  : null,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더 (줌 컨트롤 및 교체 뷰 스위치)
                _buildControlPanel(scheduleState, weekDates),
                
                const SizedBox(height: 2),
                
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
                      );
                      
                      return Theme(
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
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 범례 표시 (비워진 수업, 채워진 수업)
                _buildLegend(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 범례 위젯 생성 (비워진 수업, 채워진 수업)
  /// 교체 관리 페이지와 동일한 방식으로 좌측 정렬
  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 비워진 수업 범례
          _buildLegendItem(
            backgroundColor: SimplifiedTimetableTheme.defaultColor,
            borderColor: SimplifiedTimetableTheme.exchangedSourceCellBorderColor,
            borderWidth: SimplifiedTimetableTheme.exchangedSourceCellBorderWidth,
            label: '비워진 수업',
          ),
          const SizedBox(width: 8),
          
          // 채워진 수업 범례
          _buildLegendItem(
            backgroundColor: SimplifiedTimetableTheme.exchangedDestinationCellBackgroundColor,
            borderColor: Colors.transparent,
            borderWidth: 0,
            label: '채워진 수업',
          ),
        ],
      ),
    );
  }

  /// 개별 범례 아이템 생성
  Widget _buildLegendItem({
    required Color backgroundColor,
    required Color borderColor,
    required double borderWidth,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: borderWidth > 0 
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  /// 현재 주차인지 확인
  /// 
  /// 현재 표시 중인 주가 오늘 날짜가 속한 주인지 확인합니다.
  bool _isCurrentWeek(DateTime currentWeekMonday) {
    final thisWeekMonday = WeekDateCalculator.getThisWeekMonday();
    // 날짜만 비교 (시간 제외)
    return currentWeekMonday.year == thisWeekMonday.year &&
           currentWeekMonday.month == thisWeekMonday.month &&
           currentWeekMonday.day == thisWeekMonday.day;
  }

  /// 디버그 정보 출력
  ///
  /// 교체 리스트를 콘솔에 출력합니다.
  void _showDebugInfo(
    PersonalScheduleState scheduleState,
    TimetableData? timetableData,
    String? teacherName,
  ) {
    PersonalScheduleDebugHelper.showDebugInfo(ref, scheduleState, timetableData, teacherName);
  }

  /// 컨트롤 패널 위젯 (줌 컨트롤 + 교체 뷰 스위치)
  /// 
  /// 교체 관리 페이지와 동일한 헤더 스타일로 표시
  /// 레이아웃 순서: 줌 컨트롤 → 교체 뷰 스위치
  /// 기간선택은 AppBar로 이동됨
  Widget _buildControlPanel(PersonalScheduleState scheduleState, List<DateTime> weekDates) {
    return Row(
      children: [
        const SizedBox(width: 8),
        
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
        
        const SizedBox(width: 8),
        
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
          return SimplifiedTimetableCell(
            content: dataGridCell.value.toString(),
            isTeacherColumn: true,
            isSelected: false,
            isExchangeable: false,
            isLastColumnOfDay: false,
            isFirstColumnOfDay: false,
            isHeader: true,
          );
        }

        // 시간표 셀
        final timeSlot = dataGridCell.value as TimeSlot?;
        final content = timeSlot?.displayText ?? '';

        return SimplifiedTimetableCell(
          content: content,
            isTeacherColumn: false,
            isSelected: false,
            isExchangeable: false,
            isLastColumnOfDay: false,
            isFirstColumnOfDay: false,
            isHeader: false,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/app_settings_storage_service.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/personal_schedule_provider.dart';
import '../../utils/personal_timetable_helper.dart';
import '../../utils/week_date_calculator.dart';
import '../../utils/logger.dart';
import '../../utils/personal_schedule_debug_helper.dart';
import '../../utils/day_utils.dart';
import '../../models/time_slot.dart';
import '../../ui/widgets/timetable_grid/grid_header_widgets.dart';
import '../../providers/services_provider.dart';
import '../../providers/substitution_plan_provider.dart';
import '../../models/exchange_history_item.dart';
import '../../services/excel_service.dart';
import '../../utils/personal_exchange_info_extractor.dart';
import '../../providers/zoom_provider.dart';
import '../../ui/widgets/timetable_grid/grid_scaling_helper.dart';
import '../../ui/widgets/timetable_grid/timetable_grid_constants.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../../config/debug_config.dart';
import 'personal_schedule_screen/personal_timetable_datasource.dart';
import 'personal_schedule_screen/teacher_selection_dialog.dart';
import 'personal_schedule_screen/personal_schedule_constants.dart';

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
      final appSettings = AppSettingsStorageService();
      final defaults = await appSettings.loadTeacherAndSchoolName();
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
      builder: (context) => TeacherSelectionDialog(
        teacherNames: teacherNames,
        currentTeacherName: currentTeacherName,
      ),
    );

    // 교사 선택 시 Provider 업데이트 및 설정 파일에 저장
    if (selectedTeacherName != null && selectedTeacherName.isNotEmpty) {
      // 설정 파일에 저장
      final appSettings = AppSettingsStorageService();
      final defaults = await appSettings.loadTeacherAndSchoolName();
      final currentSchoolName = defaults['defaultSchoolName'] ?? '';

      await appSettings.saveTeacherAndSchoolName(
        teacherName: selectedTeacherName,
        schoolName: currentSchoolName,
      );
      
      // Provider 업데이트
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

    // 화면이 표시될 때마다 교사명 확인 (중복 호출 방지)
    final now = DateTime.now();
    if (_lastCheckTime == null ||
        now.difference(_lastCheckTime!).inMilliseconds > PersonalScheduleConstants.teacherNameCheckThrottleMs) {
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

    // 전체 시간표 데이터에서 실제 존재하는 요일만 포함한 날짜 리스트 계산
    // 전체 시간표 데이터를 사용하여 실제 존재하는 요일 확인
    final weekDates = WeekDateCalculator.getWeekDatesWithAvailableDays(
      scheduleState.currentWeekMonday,
      timetableData.timeSlots,
    );
    // 주의: 헤더 폰트 사이즈는 Consumer 내부에서 줌 팩터를 반영하여 재생성됨
    final result = PersonalTimetableHelper.convertToPersonalTimetableData(
      timeSlotsToUse,
      teacherName,
      weekDates,
    );

    // 교체 정보 추출
    final exchangeList = ref.read(exchangeHistoryServiceProvider).getExchangeList();
    final substitutionPlanState = ref.read(substitutionPlanProvider);
    final exchangeInfoList = PersonalExchangeInfoExtractor.extractExchangeInfo(
      exchangeList: exchangeList,
      teacherName: teacherName,
      weekDates: weekDates,
      substitutionPlanState: substitutionPlanState,
      scheduleState: scheduleState,
    );

    // 교체 정보 추출 결과 디버그 로그 (조건부)
    if (DebugConfig.enableExchangeInfoDebugLogs) {
      AppLogger.info('\n=== [개인시간표] 교체 정보 추출 결과 ===');
      AppLogger.info('교사명: $teacherName');

      // 현재 주 표시: "11.10(월), 11.11(화), ..." 형식
      final weekDisplay = weekDates.map((d) {
        final dayOfWeek = d.weekday; // 1=월요일, 7=일요일
        final dayName = DayUtils.getDayName(dayOfWeek); // DayUtils 사용
        return '${d.month}.${d.day}($dayName)';
      }).join(', ');
      AppLogger.info('현재 주: $weekDisplay');
      AppLogger.info('추출된 교체 정보: ${exchangeInfoList.length}개');

      if (exchangeInfoList.isNotEmpty) {
        // 현재 주의 날짜 문자열 리스트 생성 (YYYY.MM.DD 형식)
        final weekDateStrings = weekDates.map((d) =>
          '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}'
        ).toList();

        // 시간표에 실제로 존재하는 셀 정보 수집 (columnName 기준)
        final existingCells = <String>{};
        for (final row in result.rows) {
          for (final cell in row.getCells()) {
            final columnName = cell.columnName;
            if (columnName != 'period' && columnName.contains('_')) {
              existingCells.add(columnName);
            }
          }
        }

        for (int i = 0; i < exchangeInfoList.length; i++) {
          final info = exchangeInfoList[i];
          final absenceOrClass = info.isAbsence ? '결강' : '수업';

          // 적용 여부 확인
          final applyStatus = _getExchangeApplyStatus(info, weekDateStrings, existingCells);

          AppLogger.info('  [$i] $absenceOrClass - ${info.date} ${info.day} ${info.period}교시 ${info.subject ?? ''} ${info.className ?? ''}$applyStatus');
        }
      } else {
        AppLogger.info('  (교체 정보 없음)');
      }
      AppLogger.info('교체 뷰 상태: ${_isExchangeViewEnabled ? "활성화" : "비활성화"}');
      AppLogger.info('=== 교체 정보 추출 완료 ===\n');
    }

    // DataSource 생성 또는 업데이트
    if (_dataSource == null || _dataSource!.rows.length != result.rows.length) {
      _dataSource = PersonalTimetableDataSource(
        rows: result.rows,
        exchangeInfoList: exchangeInfoList,
        isExchangeViewEnabled: _isExchangeViewEnabled,
      );
    } else {
      _dataSource!.updateRows(
        result.rows,
        exchangeInfoList: exchangeInfoList,
        isExchangeViewEnabled: _isExchangeViewEnabled,
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
      
      // PersonalExchangeInfoExtractor를 사용하여 날짜가 있는 교체만 확인
      final exchangeList = historyService.getExchangeList();
      final scheduleState = ref.read(personalScheduleProvider);
      final exchangeInfoList = PersonalExchangeInfoExtractor.extractExchangeInfo(
        exchangeList: exchangeList,
        teacherName: teacherName,
        weekDates: weekDates,
        substitutionPlanState: substitutionPlanState,
        scheduleState: scheduleState,
      );

      // 원본 교체 리스트에서 날짜가 없는 항목 확인 (교사와 관련된 교체만)
      final allExchanges = historyService.getExchangeList();
      final exchangesWithoutDate = <ExchangeHistoryItem>[];
      for (final exchange in allExchanges) {
        final path = exchange.originalPath;
        final nodes = path.nodes;
        
        // 해당 교사와 관련된 교체인지 확인
        bool isRelated = nodes.any((node) => node.teacherName == teacherName);
        if (!isRelated) continue;
        
        // 날짜 확인 (exchangeId 기반)
        final exchangeId = exchange.id;
        final absenceDateStr = substitutionPlanState.savedDates['${exchangeId}_absenceDate'] ?? '';
        final substitutionDateStr = substitutionPlanState.savedDates['${exchangeId}_substitutionDate'] ?? '';
        
        // 날짜가 하나도 지정되지 않은 경우
        if (absenceDateStr.isEmpty && substitutionDateStr.isEmpty) {
          exchangesWithoutDate.add(exchange);
        }
      }

      // 날짜가 없는 교체가 있고, 실제로 표시될 교체 정보가 있는 경우에만 경고 표시
      // (날짜가 없으면 PersonalExchangeInfoExtractor에서 필터링되어 표시되지 않음)
      if (exchangesWithoutDate.isNotEmpty && exchangeInfoList.isEmpty) {
        final count = exchangesWithoutDate.length;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '경고: 날짜가 지정되지 않은 교체 항목 $count개가 있어 표시되지 않습니다. 결보강 계획서에서 날짜를 지정해주세요.',
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
      }

      // 교체 뷰 활성화 플래그 설정
      // (실제 셀 변경은 DataSource의 buildRow에서 처리)
      AppLogger.info('\n=== [개인시간표] 교체 뷰 활성화 ===');
      AppLogger.info('표시될 교체 정보: ${exchangeInfoList.length}개');
      AppLogger.info('날짜 없는 교체: ${exchangesWithoutDate.length}개');
      setState(() {
        _isExchangeViewEnabled = true;
      });
      AppLogger.info('상태: 활성화 완료');
      AppLogger.info('=== 교체 뷰 활성화 완료 ===\n');
    } catch (e) {
      AppLogger.error('개인 시간표 교체 뷰 활성화 중 오류: $e', e);
    }
  }

  /// 개인 시간표 교체 뷰 비활성화
  Future<void> _disablePersonalExchangeView(TimetableData timetableData) async {
    try {
      // 교체 뷰 비활성화 플래그 설정
      // (실제 셀 변경은 DataSource의 buildRow에서 처리)
      AppLogger.info('\n=== [개인시간표] 교체 뷰 비활성화 ===');
      setState(() {
        _isExchangeViewEnabled = false;
      });
      AppLogger.info('상태: 비활성화 완료');
      AppLogger.info('=== 교체 뷰 비활성화 완료 ===\n');
    } catch (e) {
      AppLogger.error('개인 시간표 교체 뷰 비활성화 중 오류: $e', e);
    }
  }

  /// 교체 정보 적용 여부 확인 (디버그용)
  ///
  /// 매개변수:
  /// - [info]: 교체 정보
  /// - [weekDateStrings]: 현재 주의 날짜 문자열 리스트 (YYYY.MM.DD)
  /// - [existingCells]: 시간표에 실제로 존재하는 셀 정보
  ///
  /// 반환값: 적용 상태 문자열 (' [적용됨]', ' [다른 주]', ' [셀 없음]', '')
  static String _getExchangeApplyStatus(
    ExchangeCellInfo info,
    List<String> weekDateStrings,
    Set<String> existingCells,
  ) {
    final isInCurrentWeek = weekDateStrings.contains(info.date);
    final expectedColumnName = '${info.day}_${info.period}_${info.date}';
    final hasCell = existingCells.contains(expectedColumnName);

    if (isInCurrentWeek && hasCell) return ' [적용됨]';
    if (!isInCurrentWeek) return ' [다른 주]';
    if (!hasCell) return ' [셀 없음]';
    return '';
  }
}

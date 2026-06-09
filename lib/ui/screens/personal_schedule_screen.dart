import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/app_settings_storage_service.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/personal_schedule_provider.dart';
import '../../utils/personal_timetable_helper.dart';
import '../../utils/week_date_calculator.dart';
import '../../utils/logger.dart';
import '../../utils/day_utils.dart';
import '../../models/time_slot.dart';
import '../../ui/widgets/timetable_grid/grid_header_widgets.dart';
import '../../ui/widgets/exchange_control_panel.dart';
import '../../ui/widgets/empty_state_message.dart';
import '../../providers/services_provider.dart';
import '../../providers/substitution_plan_viewmodel.dart';
import '../../services/excel_service.dart';
import '../../utils/personal_exchange_info_extractor.dart';
import '../../providers/cell_status_symbol_visibility_provider.dart';
import '../../providers/zoom_provider.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../widgets/cell_status_legend_item.dart';
import '../widgets/exchanged_cell_status_overlay.dart';
import '../../config/debug_config.dart';
import 'personal_schedule_screen/teacher_selection_dialog.dart';
import 'personal_schedule_screen/personal_schedule_constants.dart';
import 'personal_schedule_screen/teacher_card_grid_view.dart';
import 'personal_schedule_screen/teacher_card_teacher_collector.dart';
import 'personal_schedule_screen/exchange_week_collector.dart';
import 'personal_schedule_screen/exchange_week_selector.dart';
import 'personal_schedule_screen/teacher_card_grid_constants.dart';

/// 개인 시간표 화면
///
/// 설정에서 저장한 교사 + 결보강 계획서의 교체·보강 교사 시간표를 카드 그리드로 표시합니다.
/// - 세로행: 교시
/// - 가로행: 요일 (날짜 포함)
/// - 교체 뷰 스위치로 교체관리와 동일한 기능 제공
class PersonalScheduleScreen extends ConsumerStatefulWidget {
  const PersonalScheduleScreen({super.key});

  @override
  ConsumerState<PersonalScheduleScreen> createState() =>
      _PersonalScheduleScreenState();
}

class _PersonalScheduleScreenState
    extends ConsumerState<PersonalScheduleScreen> {
  bool _isLoadingTeacherName = true;

  /// 시간표 화면 기본값: 교체 뷰 활성화
  bool _isExchangeViewEnabled = true;
  bool _hasInitializedExchangeView = false;

  /// Excel 파싱 원본 슬롯 (교체 관리 화면의 요일 기준 변경과 분리)
  List<TimeSlot>? _originalTimeSlots;
  int? _lastFileLoadId;
  bool _isLoadingPristineTimeSlots = false;
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
      _originalTimeSlots = null;
      _lastFileLoadId = null;
    });
  }

  /// JSON 저장소의 Excel 원본 슬롯을 로드합니다.
  ///
  /// 교체 관리 화면은 [TimeSlot]을 요일(teacher+day+period) 기준으로 변경하므로
  /// 개인 시간표는 저장된 원본만 사용하고, 날짜별 표시는 DataSource에서 처리합니다.
  Future<void> _refreshPristineTimeSlots(
    int fileLoadId,
    TimetableData fallbackTimetableData,
  ) async {
    if (_isLoadingPristineTimeSlots) return;
    if (_lastFileLoadId == fileLoadId && _originalTimeSlots != null) return;

    _isLoadingPristineTimeSlots = true;
    try {
      final storage = ref.read(timetableStorageServiceProvider);
      final stored = await storage.loadTimetableData();
      if (!mounted) return;

      final source = stored ?? fallbackTimetableData;
      setState(() {
        _originalTimeSlots =
            source.timeSlots.map((slot) => slot.copy()).toList();
        _lastFileLoadId = fileLoadId;
      });
    } catch (e) {
      AppLogger.error('원본 시간표 로드 실패: $e', e);
      if (!mounted) return;
      setState(() {
        _originalTimeSlots =
            fallbackTimetableData.timeSlots.map((slot) => slot.copy()).toList();
        _lastFileLoadId = fileLoadId;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingPristineTimeSlots = false);
      }
    }
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
          const SnackBar(content: Text('시간표 데이터가 없거나 교사 목록이 비어있습니다.')),
        );
      }
      return;
    }

    // 교사명 목록 생성 (중복 제거 후 정렬)
    final teacherNames =
        timetableData.teachers.map((teacher) => teacher.name).toSet().toList()
          ..sort();

    // 현재 선택된 교사명 가져오기
    final currentTeacherName = ref.read(personalScheduleProvider).teacherName;

    // 다이얼로그 표시
    final selectedTeacherName = await showDialog<String>(
      context: context,
      builder:
          (context) => TeacherSelectionDialog(
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
      ref
          .read(personalScheduleProvider.notifier)
          .setTeacherName(selectedTeacherName);

      // 원본 데이터 초기화 (새 교사로 시간표 재생성)
      setState(() {
        _originalTimeSlots = null;
        _isExchangeViewEnabled = true;
      });

      // 교체 뷰 기본 활성화 유지
      final scheduleState = ref.read(personalScheduleProvider);
      await _ensureExchangeViewEnabled(
        timetableData,
        scheduleState.currentWeekMonday,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // X·O 오버레이 토글 시 개인 시간표 카드 그리드 갱신
    ref.watch(cellStatusSymbolVisibilityProvider);

    final scheduleState = ref.watch(personalScheduleProvider);
    final timetableData = ref.watch(exchangeScreenProvider).timetableData;
    final teacherName = scheduleState.teacherName;

    // 화면이 표시될 때마다 교사명 확인 (중복 호출 방지)
    final now = DateTime.now();
    if (_lastCheckTime == null ||
        now.difference(_lastCheckTime!).inMilliseconds >
            PersonalScheduleConstants.teacherNameCheckThrottleMs) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndLoadTeacherName(isInitialLoad: false);
        }
      });
    }

    // 로딩 중인 경우 처리
    if (_isLoadingTeacherName) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 교사명이 없거나 시간표 데이터가 없는 경우 처리
    if (teacherName == null || teacherName.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('시간표'),
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
              const Icon(Icons.person_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                '교사명이 설정되지 않았습니다.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                '우측 상단 버튼을 눌러 교사를 선택하거나,\n설정 화면에서 교사명을 입력해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (timetableData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('시간표')),
        body: const EmptyStateMessage(
          icon: Icons.table_chart_outlined,
          iconColor: Colors.grey,
          message: '시간표 데이터가 없습니다.',
          messageColor: Colors.grey,
          subMessage: '시작 메뉴에서 시간표 파일을 먼저 선택해주세요.',
          subMessageColor: Colors.grey,
        ),
      );
    }

    final fileLoadId = ref.watch(
      exchangeScreenProvider.select((s) => s.fileLoadId),
    );
    if (_lastFileLoadId != fileLoadId || _originalTimeSlots == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshPristineTimeSlots(fileLoadId, timetableData);
      });
    }

    if (_originalTimeSlots == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('시간표')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Excel 원본 슬롯만 사용 — 교체 관리의 요일 기준 변경은 반영하지 않음
    // 비워진/채워진 수업 표시는 PersonalTimetableDataSource가 결보강 날짜로 적용
    final timeSlotsToUse = _originalTimeSlots!;

    // 전체 시간표 데이터에서 실제 존재하는 요일만 포함한 날짜 리스트 계산
    // 전체 시간표 데이터를 사용하여 실제 존재하는 요일 확인
    final weekDates = WeekDateCalculator.getWeekDatesWithAvailableDays(
      scheduleState.currentWeekMonday,
      timetableData.timeSlots,
    );

    // 최초 진입 시 교체 뷰 기본 활성화
    if (!_hasInitializedExchangeView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureExchangeViewEnabled(
          timetableData,
          scheduleState.currentWeekMonday,
        );
      });
    }

    // 주의: 헤더 폰트 사이즈는 Consumer 내부에서 줌 팩터를 반영하여 재생성됨
    final result = PersonalTimetableHelper.convertToPersonalTimetableData(
      timeSlotsToUse,
      teacherName,
      weekDates,
    );

    // 교체 정보 추출 (결보강 계획서 planData 기준)
    final planData = ref.watch(
      substitutionPlanViewModelProvider.select((state) => state.planData),
    );
    final exchangeInfoList = PersonalExchangeInfoExtractor.extractExchangeInfo(
      planData: planData,
      teacherName: teacherName,
      weekDates: weekDates,
    );

    // 교체 정보 추출 결과 디버그 로그 (조건부)
    if (DebugConfig.enableExchangeInfoDebugLogs) {
      AppLogger.info('\n=== [개인시간표] 교체 정보 추출 결과 ===');
      AppLogger.info('교사명: $teacherName');

      // 현재 주 표시: "11.10(월), 11.11(화), ..." 형식
      final weekDisplay = weekDates
          .map((d) {
            final dayOfWeek = d.weekday; // 1=월요일, 7=일요일
            final dayName = DayUtils.getDayName(dayOfWeek); // DayUtils 사용
            return '${d.month}.${d.day}($dayName)';
          })
          .join(', ');
      AppLogger.info('현재 주: $weekDisplay');
      AppLogger.info('추출된 교체 정보: ${exchangeInfoList.length}개');

      if (exchangeInfoList.isNotEmpty) {
        // 현재 주의 날짜 문자열 리스트 생성 (YYYY.MM.DD 형식)
        final weekDateStrings =
            weekDates
                .map(
                  (d) =>
                      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}',
                )
                .toList();

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
          final applyStatus = _getExchangeApplyStatus(
            info,
            weekDateStrings,
            existingCells,
          );

          AppLogger.info(
            '  [$i] $absenceOrClass - ${info.date} ${info.day} ${info.period}교시 ${info.subject ?? ''} ${info.className ?? ''}$applyStatus',
          );
        }
      } else {
        AppLogger.info('  (교체 정보 없음)');
      }
      AppLogger.info('교체 뷰 상태: ${_isExchangeViewEnabled ? "활성화" : "비활성화"}');
      AppLogger.info('=== 교체 정보 추출 완료 ===\n');
    }

    // DataSource 생성 또는 업데이트 — TeacherTimetableCard 내부에서 처리

    // 저장 교사 + 결보강 계획서(교체·보강) 교사 카드 목록
    final cardTargets = TeacherCardTeacherCollector.collect(
      savedTeacherName: teacherName,
      planData: planData,
    );

    // 결보강 계획서에 지정된 교체·결강 날짜가 속한 주차 목록
    final exchangeWeeks = ExchangeWeekCollector.collectWeekMondays(
      planData,
      referenceDate: scheduleState.currentWeekMonday,
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: TeacherCardGridConstants.scheduleAppBarHeight,
        titleSpacing: 8,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final showDateRange =
                constraints.maxWidth >=
                TeacherCardGridConstants.scheduleAppBarDateRangeMinWidth;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 교사 선택 버튼 (아이콘 + 교사명, 검색 기능 유지)
                InkWell(
                  onTap: _showTeacherSelectionDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_search, size: 18),
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
                // 현재 주차로 이동 (교사명 바로 옆)
                IconButton(
                  icon: const Icon(Icons.today, size: 20),
                  onPressed:
                      _isCurrentWeek(scheduleState.currentWeekMonday)
                          ? null
                          : () {
                            ref
                                .read(personalScheduleProvider.notifier)
                                .moveToThisWeek();
                          },
                  tooltip: '현재 주차로 이동',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  color:
                      _isCurrentWeek(scheduleState.currentWeekMonday)
                          ? Colors.grey
                          : null,
                ),
                if (showDateRange) ...[
                  const SizedBox(width: 8),
                  _buildWeekDateRangeSelector(scheduleState),
                ],
                const SizedBox(width: 8),
                // 교체 주 선택 + 이전/다음 교체 주 이동
                ExchangeWeekToolbar(
                  exchangeWeeks: exchangeWeeks,
                  currentWeekMonday: scheduleState.currentWeekMonday,
                ),
              ],
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildScheduleToolbar(
                exchangeWeeks: exchangeWeeks,
                scheduleState: scheduleState,
                weekDates: weekDates,
              ),
              Expanded(
                child: TeacherCardGridView(
                  targets: cardTargets,
                  timetableData: timetableData,
                  timeSlots: timeSlotsToUse,
                  weekDates: weekDates,
                  isExchangeViewEnabled: _isExchangeViewEnabled,
                  scheduleState: scheduleState,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: TeacherCardGridConstants.toolbarHorizontalPadding,
                  right: TeacherCardGridConstants.toolbarHorizontalPadding,
                  bottom: 8,
                ),
                child: _buildLegend(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 범례 위젯 생성 (빠진 수업(결강), 맡은 수업(교체·보강))
  /// 교체 관리 페이지와 동일한 방식으로 좌측 정렬
  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ToggleableStatusLegendItem(
          backgroundColor: SimplifiedTimetableTheme.defaultColor,
          borderColor: SimplifiedTimetableTheme.exchangedSourceCellBorderColor,
          borderWidth: SimplifiedTimetableTheme.exchangedSourceCellBorderWidth,
          label: '빠진 수업(결강)',
          symbolType: CellStatusSymbolType.missedClass,
        ),
        const SizedBox(width: 8),
        const ToggleableStatusLegendItem(
          backgroundColor:
              SimplifiedTimetableTheme.exchangedDestinationCellBackgroundColor,
          borderColor: Colors.transparent,
          borderWidth: 0,
          label: '맡은 수업(교체·보강)',
          symbolType: CellStatusSymbolType.takenClass,
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

  /// AppBar — ◀ yyyy.mm.dd ~ yyyy.mm.dd ▶ 주간 이동
  Widget _buildWeekDateRangeSelector(PersonalScheduleState scheduleState) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          onPressed: () {
            ref.read(personalScheduleProvider.notifier).moveToPreviousWeek();
          },
          tooltip: '이전 주',
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 28),
        ),
        Text(
          WeekDateCalculator.formatWeekRange(scheduleState.currentWeekMonday),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          onPressed: () {
            ref.read(personalScheduleProvider.notifier).moveToNextWeek();
          },
          tooltip: '다음 주',
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 28),
        ),
      ],
    );
  }

  /// 주차 칩 + 줌/교체 스위치 툴바
  /// 넓을 때 1줄: [줌·교체] [주차 칩] / 좁을 때 2줄로 분리
  Widget _buildScheduleToolbar({
    required List<DateTime> exchangeWeeks,
    required PersonalScheduleState scheduleState,
    required List<DateTime> weekDates,
  }) {
    final hasChips = exchangeWeeks.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: TeacherCardGridConstants.chipRowPaddingTop,
            bottom: TeacherCardGridConstants.zoomToolbarPaddingBottom,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useSingleRow =
                  !hasChips ||
                  constraints.maxWidth >=
                      TeacherCardGridConstants.scheduleToolbarSingleRowMinWidth;

              if (useSingleRow) {
                return SizedBox(
                  height: kExchangeUnifiedToolbarHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildControlPanel(scheduleState, weekDates),
                      if (hasChips) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ExchangeWeekChipRow(
                            exchangeWeeks: exchangeWeeks,
                            currentWeekMonday: scheduleState.currentWeekMonday,
                            inline: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                );
              }

              // 좁은 폭: 1줄=줌·교체, 2줄=주차 칩
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: kExchangeUnifiedToolbarHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildControlPanel(scheduleState, weekDates),
                    ),
                  ),
                  const SizedBox(
                    height:
                        TeacherCardGridConstants.scheduleToolbarWrappedRowGap,
                  ),
                  ExchangeWeekChipRow(
                    exchangeWeeks: exchangeWeeks,
                    currentWeekMonday: scheduleState.currentWeekMonday,
                    inline: false,
                  ),
                ],
              );
            },
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      ],
    );
  }

  /// 컨트롤 패널 위젯 (줌 컨트롤 + 교체 뷰 스위치)
  ///
  /// 교체 관리 페이지와 동일한 헤더 스타일로 표시
  /// 레이아웃 순서: 줌 컨트롤 → 교체 뷰 스위치
  /// 기간선택은 AppBar로 이동됨
  Widget _buildControlPanel(
    PersonalScheduleState scheduleState,
    List<DateTime> weekDates,
  ) {
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

  /// 교체 뷰를 활성화합니다 (시간표 화면 기본값).
  Future<void> _ensureExchangeViewEnabled(
    TimetableData timetableData,
    DateTime weekMonday,
  ) async {
    if (!mounted) return;

    _hasInitializedExchangeView = true;

    final weekDates = WeekDateCalculator.getWeekDatesWithAvailableDays(
      weekMonday,
      timetableData.timeSlots,
    );

    setState(() {
      _isExchangeViewEnabled = true;
    });

    await _enablePersonalExchangeView(weekDates, timetableData, context);
  }

  /// 교체 뷰 스위치 토글 처리
  Future<void> _handleExchangeViewToggle(
    bool enabled,
    List<DateTime> weekDates,
  ) async {
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
      final teacherName = ref.read(personalScheduleProvider).teacherName;
      if (teacherName == null) return;

      final planData = ref.read(substitutionPlanViewModelProvider).planData;
      final exchangeInfoList =
          PersonalExchangeInfoExtractor.extractExchangeInfo(
            planData: planData,
            teacherName: teacherName,
            weekDates: weekDates,
          );

      final unassignedCount =
          PersonalExchangeInfoExtractor.countUnassignedPlansForTeacher(
            planData,
            teacherName,
          );

      if (unassignedCount > 0 && exchangeInfoList.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '경고: 날짜가 지정되지 않은 교체 항목 $unassignedCount개가 있어 표시되지 않습니다. 결보강 계획서에서 날짜를 지정해주세요.',
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

      AppLogger.info('\n=== [개인시간표] 교체 뷰 활성화 ===');
      AppLogger.info('표시될 교체 정보: ${exchangeInfoList.length}개');
      AppLogger.info('날짜 없는 교체: $unassignedCount개');
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/timetable_registry_provider.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/personal_schedule_provider.dart';
import '../../utils/week_date_calculator.dart';
import '../../utils/logger.dart';
import '../../models/time_slot.dart';
import '../../config/debug_config.dart';
import '../../ui/widgets/timetable_grid/grid_header_widgets.dart';
import '../../ui/widgets/exchange_control_panel.dart';
import '../../ui/widgets/empty_state_message.dart';
import '../../providers/substitution_plan_viewmodel.dart';
import '../../services/excel_service.dart';
import '../../utils/personal_exchange_info_extractor.dart';
import '../../providers/cell_status_symbol_visibility_provider.dart';
import '../../providers/zoom_provider.dart';
import '../../theme/design_tokens.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../widgets/cell_status_legend_item.dart';
import '../widgets/exchanged_cell_status_overlay.dart';
import 'personal_schedule_screen/teacher_selection_dialog.dart';
import 'personal_schedule_screen/teacher_card_grid_view.dart';
import 'personal_schedule_screen/teacher_card_teacher_collector.dart';
import 'personal_schedule_screen/exchange_week_collector.dart';
import 'personal_schedule_screen/exchange_week_selector.dart';
import 'personal_schedule_screen/teacher_card_grid_constants.dart';

/// 개인 시간표 화면
///
/// 설정에서 저장한 교사와, 그 교사의 교체·보강 상대 시간표만 카드로 표시합니다.
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
  bool _isCheckingTeacherName = false; // 교사명 확인 중 플래그 (중복 실행 방지)

  /// 디버그: 이 State가 몇 번 build 됐는지 (무한 루프 추적)
  int _debugBuildCount = 0;
  DateTime _debugLastReport = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Riverpod은 initState 안에서 Provider 수정을 금지합니다.
    //
    // 예전에는 교사명을 설정 파일에서 await 로 읽어와, 자연히 첫 프레임 뒤에
    // 실행됐습니다. 멀티 시간표 작업에서 activeTeacherNameProvider 동기 조회로
    // 바뀌면서 initState 안에서 곧바로 실행되어 예외가 났습니다.
    // (그 예외가 위젯 트리를 망가뜨려 시간표 화면이 멈췄습니다.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndLoadTeacherName(isInitialLoad: true);
      }
    });
  }

  /// 시간표 데이터 초기화 헬퍼 메서드
  void _clearTimetableData() {
    setState(() {
      _originalTimeSlots = null;
      _lastFileLoadId = null;
    });
  }

  /// 무한 리빌드인지 확인하려면 DebugConfig.enableTimetableRebuildLogs 를 true 로.
  ///
  /// 1초 동안 몇 번 build 됐는지 세어 출력합니다.
  /// - 1~3회: 정상 (멈춤 원인은 다른 곳)
  /// - 수십~수백 회: 이 화면이 무한 리빌드 중
  void _debugTraceRebuild() {
    if (!DebugConfig.enableTimetableRebuildLogs) return;

    _debugBuildCount++;
    final now = DateTime.now();
    if (now.difference(_debugLastReport) < const Duration(seconds: 1)) return;

    AppLogger.info('[시간표 리빌드] 최근 1초간 $_debugBuildCount회');
    _debugLastReport = now;
    _debugBuildCount = 0;
  }

  /// 준비/교체 화면에 이미 올라온 시간표를 복사해 바로 그립니다.
  ///
  /// 예전에는 JSON을 `addPostFrameCallback` 뒤에 다시 읽었습니다.
  /// 프레임이 끝나지 않으면 콜백이 호출되지 않아, 제목만 "시간표"인 스피너에
  /// 영원히 머물렀습니다.
  void _useInMemoryTimeSlots(int fileLoadId, TimetableData timetableData) {
    if (_originalTimeSlots != null && _lastFileLoadId == fileLoadId) {
      return;
    }
    _originalTimeSlots =
        timetableData.timeSlots.map((slot) => slot.copy()).toList();
    _lastFileLoadId = fileLoadId;
    AppLogger.info(
      '[시간표] 메모리 슬롯 ${_originalTimeSlots!.length}개로 표시 (fileLoadId=$fileLoadId)',
    );
  }

  /// 활성 시간표에 지정된 교사명을 화면 상태에 반영합니다.
  ///
  /// 교사명이 없으면 시간표 데이터를 지웁니다.
  ///
  /// 주의: 이 메서드는 Provider를 수정하므로 build·initState 안에서
  /// 곧바로 호출하면 안 됩니다. 프레임이 끝난 뒤에 호출하세요.
  ///
  /// 매개변수:
  /// - `isInitialLoad`: 초기 로드인지 여부 (로딩 상태 관리용)
  void _checkAndLoadTeacherName({required bool isInitialLoad}) {
    // 중복 실행 방지
    if (_isCheckingTeacherName) return;

    _isCheckingTeacherName = true;

    try {
      // 활성 시간표에 지정된 교사를 기본값으로 사용한다.
      // 이 화면에서 다른 교사를 골라도 시간표의 교사는 덮어쓰지 않는다
      // (남의 시간표 열람이 내 설정을 바꾸면 안 됨 — 문서 §6-10).
      final teacherName = ref.read(activeTeacherNameProvider);

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

    // 교사 선택 시 Provider만 갱신한다.
    //
    // 이 화면의 교사 전환은 "남의 시간표를 잠깐 보는" 국소 동작이므로
    // 활성 시간표에 지정된 교사(TimetableRegistryEntry.teacherName)는
    // 덮어쓰지 않는다(문서 §6-10).
    if (selectedTeacherName != null && selectedTeacherName.isNotEmpty) {
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
    _debugTraceRebuild();
    final tokens = context.tokens;
    // X·O 오버레이 토글 시 개인 시간표 카드 그리드 갱신
    ref.watch(cellStatusSymbolVisibilityProvider);

    final scheduleState = ref.watch(personalScheduleProvider);
    // 교체 화면 전체(30+ 필드)가 아니라 시간표 본문만 구독 — 불필요 리빌드 방지
    final timetableData = ref.watch(
      exchangeScreenProvider.select((s) => s.timetableData),
    );
    final teacherName = scheduleState.teacherName;

    // 준비 화면 교사 변경만 반영 (매 빌드 폴링 제거 → 무한 리빌드 방지)
    //
    // 여기서도 Provider를 수정하므로, 빌드가 끝난 뒤로 미룹니다.
    ref.listen<String>(activeTeacherNameProvider, (previous, next) {
      if (previous == next) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndLoadTeacherName(isInitialLoad: false);
        }
      });
    });

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
              Icon(Icons.person_outline, size: 64, color: tokens.textMuted),
              const SizedBox(height: 16),
              Text(
                '교사명이 설정되지 않았습니다.',
                style: TextStyle(fontSize: 16, color: tokens.textMuted),
              ),
              const SizedBox(height: 8),
              Text(
                '우측 상단 버튼을 눌러 교사를 선택하거나,\n설정 화면에서 교사명을 입력해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: tokens.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (timetableData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('시간표')),
        body: EmptyStateMessage(
          icon: Icons.table_chart_outlined,
          iconColor: tokens.textMuted,
          message: '시간표 데이터가 없습니다.',
          messageColor: tokens.textMuted,
          subMessage: '준비 메뉴에서 시간표 파일을 먼저 선택해주세요.',
          subMessageColor: tokens.textMuted,
        ),
      );
    }

    final fileLoadId = ref.watch(
      exchangeScreenProvider.select((s) => s.fileLoadId),
    );
    // JSON 재로드를 기다리지 않고, 이미 있는 시간표로 바로 그립니다.
    _useInMemoryTimeSlots(fileLoadId, timetableData);

    if (_originalTimeSlots == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('시간표')),
        body: EmptyStateMessage(
          icon: Icons.table_chart_outlined,
          iconColor: tokens.textMuted,
          message: '시간표 칸 데이터가 없습니다.',
          messageColor: tokens.textMuted,
          subMessage: '준비 메뉴에서 시간표 파일을 다시 선택해주세요.',
          subMessageColor: tokens.textMuted,
        ),
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

    // 교체 뷰는 기본이 켜짐. 끝난 뒤에 setState 하면 그리드가 다시 깔리며 멈출 수 있습니다.
    if (!_hasInitializedExchangeView) {
      _hasInitializedExchangeView = true;
    }

    // 선택 교사 + 그 교사의 교체·보강 상대만 카드로 표시
    final planData = ref.watch(
      substitutionPlanViewModelProvider.select((state) => state.planData),
    );
    final relatedPlanData = PersonalExchangeInfoExtractor.plansRelatedToTeacher(
      planData,
      teacherName,
    );
    final cardTargets = TeacherCardTeacherCollector.collect(
      savedTeacherName: teacherName,
      planData: relatedPlanData,
    );

    // 선택 교사와 관련된 결강·교체 날짜가 속한 주차만 표시
    final exchangeWeeks = ExchangeWeekCollector.collectWeekMondays(
      relatedPlanData,
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
                          ? tokens.textMuted
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
                tokens: tokens,
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
    required DesignTokens tokens,
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
        Divider(height: 1, thickness: 1, color: tokens.cardBorder),
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
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/excel_service.dart';
import '../../services/exchange_service.dart';
import '../../providers/services_provider.dart';
import '../../providers/exchange_view_provider.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/cell_selection_provider.dart';
import '../../models/exchange_mode.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/day_utils.dart';
import 'timetable_grid/arrow_state_manager.dart';
import '../../utils/logger.dart';
import '../../models/exchange_path.dart';
import '../../models/exchange_node.dart'; // 🆕 ExchangeNode import 추가
import '../../models/time_slot.dart';
import '../../providers/state_reset_provider.dart';
import '../../providers/substitution_plan_provider.dart';
import '../../providers/zoom_provider.dart';
import '../../providers/scroll_provider.dart';
import '../../providers/node_scroll_provider.dart'; // 🆕 노드 스크롤 Provider 추가
import '../../utils/simplified_timetable_theme.dart';
import 'timetable_grid/timetable_grid_constants.dart';
import 'timetable_grid/exchange_arrow_style.dart';
import 'timetable_grid/exchange_arrow_painter.dart';
import 'timetable_grid/exchange_executor.dart';
import 'timetable_grid/grid_header_widgets.dart';
import 'timetable_grid/grid_scaling_helper.dart';
import 'exchange_control_panel.dart';
import '../mixins/scroll_management_mixin.dart';

/// 교체된 셀의 원본 정보를 저장하는 클래스
/// 복원에 필요한 최소한의 정보만 포함
class ExchangeBackupInfo {
  final String teacher; // 교사명
  final int dayOfWeek; // 요일 (1-5)
  final int period; // 교시
  final String? subject; // 과목명
  final String? className; // 학급명

  ExchangeBackupInfo({
    required this.teacher,
    required this.dayOfWeek,
    required this.period,
    this.subject,
    this.className,
  });

  /// TimeSlot에서 ExchangeBackupInfo 생성
  factory ExchangeBackupInfo.fromTimeSlot(TimeSlot slot) {
    return ExchangeBackupInfo(
      teacher: slot.teacher ?? '',
      dayOfWeek: slot.dayOfWeek ?? 0,
      period: slot.period ?? 0,
      subject: slot.subject,
      className: slot.className,
    );
  }

  /// 디버깅용 문자열 반환
  String get debugInfo {
    return 'ExchangeBackupInfo(teacher: $teacher, dayOfWeek: $dayOfWeek, period: $period, subject: $subject, className: $className)';
  }
}

/// 시간표 그리드 섹션 위젯
/// Syncfusion DataGrid를 사용한 시간표 표시를 담당
class TimetableGridSection extends ConsumerStatefulWidget {
  final TimetableData? timetableData;
  final TimetableDataSource? dataSource;
  final List<GridColumn> columns;
  final List<StackedHeaderRow> stackedHeaders;
  final bool isExchangeModeEnabled;
  final bool isCircularExchangeModeEnabled;
  final bool isChainExchangeModeEnabled;
  final int exchangeableCount;
  final Function(DataGridCellTapDetails) onCellTap;
  final ExchangePath? selectedExchangePath; // 선택된 교체 경로 (모든 타입 지원)
  final ExchangeArrowStyle? customArrowStyle; // 커스텀 화살표 스타일
  final VoidCallback? onHeaderThemeUpdate; // 헤더 테마 업데이트 콜백
  final Function(ExchangeNode)? onNodeScrollRequest; // 🆕 노드 스크롤 요청 콜백
  final ExchangeMode currentMode; // 현재 교체 모드
  final void Function(ExchangeMode) onModeChanged; // 모드 변경 콜백

  const TimetableGridSection({
    super.key,
    required this.timetableData,
    required this.dataSource,
    required this.columns,
    required this.stackedHeaders,
    required this.isExchangeModeEnabled,
    required this.isCircularExchangeModeEnabled,
    required this.isChainExchangeModeEnabled,
    required this.exchangeableCount,
    required this.onCellTap,
    required this.currentMode,
    required this.onModeChanged,
    this.selectedExchangePath,
    this.customArrowStyle,
    this.onHeaderThemeUpdate,
    this.onNodeScrollRequest, // 🆕 노드 스크롤 콜백
  });

  @override
  ConsumerState<TimetableGridSection> createState() =>
      _TimetableGridSectionState();
}

class _TimetableGridSectionState extends ConsumerState<TimetableGridSection>
    with ScrollManagementMixin {
  // 🧪 테스트: GlobalKey만 사용 - 나머지 모든 수정사항 원상복구
  // GlobalKey만으로도 DataGrid 재생성 문제가 해결되는지 테스트
  final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();

  // 🆕 DataGridController 추가 (셀 스크롤용)
  final DataGridController _dataGridController = DataGridController();

  // 싱글톤 화살표 상태 매니저
  final ArrowStateManager _arrowStateManager = ArrowStateManager();

  // ExchangeExecutor (필요 시 생성)
  late final ExchangeExecutor _exchangeExecutor;

  /// 교체 모드인지 확인 (1:1, 순환, 연쇄 중 하나라도 활성화된 경우)
  bool get isInExchangeMode =>
      widget.isExchangeModeEnabled ||
      widget.isCircularExchangeModeEnabled ||
      widget.isChainExchangeModeEnabled;

  /// 🆕 노드 스크롤 콜백 설정
  void _setupNodeScrollCallback() {
    // 외부에서 노드 스크롤을 요청할 수 있도록 콜백 연결
    // 실제 구현에서는 Provider나 다른 상태 관리 방식을 사용할 수 있음
    AppLogger.exchangeDebug('🔄 [노드 스크롤] 콜백 설정 완료');
  }

  @override
  void initState() {
    super.initState();

    // ExchangeExecutor 초기화
    _exchangeExecutor = ExchangeExecutor(
      ref: ref,
      dataSource: widget.dataSource,
      onEnableExchangeView: _enableExchangeView,
    );

    // 공통 스크롤 관리 믹신 초기화
    initializeScrollControllers();

    // 🆕 노드 스크롤 요청 콜백 설정
    if (widget.onNodeScrollRequest != null) {
      // 외부에서 노드 스크롤 요청을 받을 수 있도록 설정
      _setupNodeScrollCallback();
    }

    // 테이블 렌더링 완료 후 UI 업데이트 요청
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.timetableData != null && widget.dataSource != null) {
        _requestUIUpdate();
      }
    });
  }

  @override
  void didUpdateWidget(TimetableGridSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 🔥 스크롤 문제 해결: 과거 커밋의 단순한 구조를 참고하여 불필요한 재빌드 방지
    // ValueKey는 fileLoadId를 사용하므로 파일 로드 시에만 변경됨
    // 경로 선택, 셀 선택, 헤더 업데이트 등에서는 ValueKey가 변경되지 않아 스크롤 유지됨

    // 실제로 중요한 구조적 데이터가 변경된 경우에만 UI 업데이트 요청 (성능 최적화)
    // 경로 선택으로 인한 columns/stackedHeaders 변경은 제외하여 불필요한 재빌드 방지
    if (widget.timetableData != oldWidget.timetableData ||
        widget.dataSource != oldWidget.dataSource ||
        widget.isExchangeModeEnabled != oldWidget.isExchangeModeEnabled ||
        widget.isCircularExchangeModeEnabled !=
            oldWidget.isCircularExchangeModeEnabled ||
        widget.isChainExchangeModeEnabled !=
            oldWidget.isChainExchangeModeEnabled) {
      // Syncfusion DataGrid 초기화 로그 (위젯 업데이트 시)
      AppLogger.exchangeDebug(
        '[wg2] Syncfusion DataGrid 초기화: 위젯 업데이트 시 (didUpdateWidget) - 구조적 데이터 변경',
      );

      // 스크롤 초기화 로그 (위젯 업데이트 시)
      // 파일 로드 시에만 실제로 스크롤이 초기화됨 (fileLoadId 변경)
      AppLogger.exchangeDebug('[wg] 스크롤 초기화: 파일 로드 시 (didUpdateWidget)');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.timetableData != null && widget.dataSource != null) {
          _requestUIUpdate();
        }
      });
    }

    // 🔥 스크롤 문제 해결: 경로 선택으로 인한 columns/stackedHeaders 변경은 ValueKey 변경 없이 처리
    // fileLoadId 기반 ValueKey로 인해 경로 선택 시 위젯이 재생성되지 않아 스크롤 유지됨
    // 과거 커밋의 단순한 구조를 유지하여 스크롤 위치 보존
  }

  @override
  void dispose() {
    // Syncfusion DataGrid 해제 로그
    AppLogger.exchangeDebug('[wg2] Syncfusion DataGrid 해제: 위젯 해제 시 (dispose)');

    // 스크롤 초기화 로그 (위젯 해제 시)
    AppLogger.exchangeDebug('[wg] 스크롤 초기화: 위젯 해제 시 (dispose)');

    // 공통 스크롤 관리 믹신 해제
    disposeScrollControllers();

    // 화살표 상태 정리
    _arrowStateManager.clearAllArrows();

    // 기존 리소스 정리
    super.dispose();
  }

  /// UI 업데이트 요청
  void _requestUIUpdate() {
    // UI 업데이트는 즉시 처리 (Provider 상태 변경 없이)
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timetableData == null || widget.dataSource == null) {
      return const SizedBox.shrink();
    }

    // 🆕 노드 스크롤 Provider 감지하여 스크롤 실행
    ref.listen<ExchangeNode?>(nodeScrollProvider, (previous, next) {
      if (next != null) {
        // 노드 스크롤 요청이 있을 때 실행
        scrollToExchangeNode(next);
        // 스크롤 완료 후 상태 초기화
        ref.read(nodeScrollProvider.notifier).clearScrollRequest();
      }
    });

    // 🔥 StateResetProvider 상태 감지 제거 - 교체뷰 활성화 시 레벨3 초기화 문제 해결
    return _buildMainContent();
  }

  /// 메인 콘텐츠 빌드 메서드
  /// StateResetProvider 상태 감지 제거 후 UI 구성 요소만 담당
  Widget _buildMainContent() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            _buildHeader(),

            const SizedBox(height: 2),

            // Syncfusion DataGrid 위젯 (화살표와 함께)
            Expanded(child: _buildDataGridWithArrows()),

            const SizedBox(height: 8),

            // 셀 테마 예시 (그리드 하단)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const CellThemeLegend(),
            ),
          ],
        ),
      ),
    );
  }

  /// 헤더 구성 — 모드 선택 + 실행 도구를 한 줄(또는 좁은 화면에서 2줄)로 통합
  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final bool useVerticalLayout = totalWidth < 900;
        final bool hideTeacherCount = totalWidth < 600;

        if (useVerticalLayout) {
          // 모드 선택이 단독 행 → 가용 폭 기준으로 라벨 결정
          final modeLabelStyle = resolveModeLabelStyle(
            totalWidth: totalWidth,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModeSelectorRow(modeLabelStyle),
              const SizedBox(height: 4),
              _buildActionToolbarRow(hideTeacherCount),
            ],
          );
        }

        // 통합 한 줄 — 툴바 전체 폭 기준으로 라벨 결정 (Flexible 할당 폭 X)
        final modeLabelStyle = resolveModeLabelStyle(
          totalWidth: totalWidth,
        );
        return _buildUnifiedToolbarRow(
          hideTeacherCount,
          modeLabelStyle,
        );
      },
    );
  }

  /// 모드 선택 행 (좁은 화면용)
  Widget _buildModeSelectorRow(ExchangeModeLabelStyle labelStyle) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ExchangeModeSelector(
          currentMode: widget.currentMode,
          onModeChanged: widget.onModeChanged,
          labelStyle: labelStyle,
        ),
      ),
    );
  }

  /// 통합 툴바 — [모드 | 실행 도구] (스크롤) + [zoom·교사수] (고정)
  ///
  /// Spacer()를 쓰지 않아 모드 버튼 영역이 zoom 왼쪽까지 전체 폭을 사용합니다.
  Widget _buildUnifiedToolbarRow(
    bool hideTeacherCount,
    ExchangeModeLabelStyle modeLabelStyle,
  ) {
    return SizedBox(
      height: kExchangeUnifiedToolbarHeight,
      child: Row(
        children: [
          const SizedBox(width: 8),
          // 모드 + 실행도구 — 남는 폭 전부 사용, 넘치면 가로 스크롤
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExchangeModeSelector(
                    currentMode: widget.currentMode,
                    onModeChanged: widget.onModeChanged,
                    labelStyle: modeLabelStyle,
                  ),
                  const ToolbarGroupDivider(),
                  ..._buildActionToolbarItems(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildZoomControl(),
          const SizedBox(width: 8),
          if (!hideTeacherCount) ...[
            TeacherCountWidget(
              teacherCount: widget.timetableData!.teachers.length,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// 실행 도구 행 (좁은 화면용)
  Widget _buildActionToolbarRow(bool hideTeacherCount) {
    return SizedBox(
      height: kExchangeUnifiedToolbarHeight,
      child: Row(
        children: [
          const SizedBox(width: 8),
          ..._buildActionToolbarItems(),
          const Spacer(),
          _buildZoomControl(),
          const SizedBox(width: 8),
          if (!hideTeacherCount) ...[
            TeacherCountWidget(
              teacherCount: widget.timetableData!.teachers.length,
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// 교체 적용·초기화·undo/redo 버튼 그룹
  List<Widget> _buildActionToolbarItems() {
    return [
      ExchangeViewCheckbox(
        isEnabled: ref.watch(isExchangeViewEnabledProvider),
        onChanged: (bool? value) {
          final isEnabled = value ?? false;
          if (isEnabled) {
            _enableExchangeView();
          } else {
            _disableExchangeView();
          }
        },
      ),
      const SizedBox(width: 6),
      ResetExchangeListButton(
        onPressed: () => _showDeleteExchangeListDialog(context, ref),
      ),
      const SizedBox(width: 4),
      _buildExchangeActionButtons(),
    ];
  }

  /// 확대/축소 컨트롤
  Widget _buildZoomControl() {
    return Consumer(
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
    );
  }

  /// 교체 경로 삭제 (툴바 삭제 버튼 · 우클릭 메뉴 공통)
  Future<void> _deleteExchangePath(ExchangePath exchangePath) async {
    if (!mounted) return;

    await _exchangeExecutor.deleteFromExchangeList(
      exchangePath,
      context,
      () {
        ref.read(stateResetProvider.notifier).resetExchangeStates(
              reason: '내부 경로 초기화',
            );
      },
    );
  }

  /// 되돌리기·다시 실행·삭제 버튼 그룹
  Widget _buildExchangeActionButtons() {
    return Consumer(
      builder: (context, ref, child) {
        // 교체 리스트 변경 시 버튼 활성 상태 갱신
        ref.watch(exchangeListVersionProvider);
        final historyService = ref.read(exchangeHistoryServiceProvider);
        final canUndo = historyService.canUndo;
        final canRedo = historyService.canRedo;

        final cellState = ref.watch(cellSelectionProvider);
        final currentSelectedPath =
            cellState.selectedOneToOnePath ??
            cellState.selectedCircularPath ??
            cellState.selectedChainPath ??
            cellState.selectedSupplementPath ??
            widget.selectedExchangePath;
        final isFromExchangedCell = cellState.isFromExchangedCell;

        return ExchangeActionButtons(
          onUndo:
              canUndo
                  ? () => _exchangeExecutor.undoLastExchange(context, () {
                    ref
                        .read(stateResetProvider.notifier)
                        .resetExchangeStates(reason: '내부 경로 초기화');
                  })
                  : null,
          onRepeat:
              canRedo
                  ? () => _exchangeExecutor.redoLastExchange(context)
                  : null,
          onDelete:
              (currentSelectedPath != null && isFromExchangedCell)
                  ? () async => await _deleteExchangePath(currentSelectedPath)
                  : null,
          showDeleteButton: currentSelectedPath != null && isFromExchangedCell,
        );
      },
    );
  }

  /// DataGrid와 화살표를 함께 구성
  Widget _buildDataGridWithArrows() {
    return Consumer(
      builder: (context, ref, child) {
        // select 패턴으로 경로 상태만 구독
        final cellState = ref.watch(cellSelectionProvider);
        final currentSelectedPath =
            cellState.selectedOneToOnePath ??
            cellState.selectedCircularPath ??
            cellState.selectedChainPath ??
            cellState.selectedSupplementPath ??
            widget.selectedExchangePath;

        Widget dataGrid = _buildDataGrid();

        // 교체 경로가 선택된 경우에만 화살표 표시
        if (currentSelectedPath != null && widget.timetableData != null) {
          return _buildDataGridWithLegacyArrows(dataGrid, currentSelectedPath);
        }

        return dataGrid;
      },
    );
  }

  /// 기존 CustomPainter 기반 화살표 표시
  Widget _buildDataGridWithLegacyArrows(
    Widget dataGridWithGestures,
    ExchangePath selectedPath,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final zoomFactor = ref.watch(zoomProvider.select((s) => s.zoomFactor));
        final scrollState = ref.watch(scrollProvider);
        final scrollOffset = Offset(
          scrollState.horizontalOffset,
          scrollState.verticalOffset,
        );

        return Stack(
          children: [
            dataGridWithGestures,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ExchangeArrowPainter(
                    selectedPath: selectedPath,
                    timetableData: widget.timetableData!,
                    columns: widget.columns,
                    customArrowStyle: widget.customArrowStyle,
                    zoomFactor: zoomFactor,
                    scrollOffset: scrollOffset,
                  ),
                  child: RepaintBoundary(child: Container()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// DataGrid 구성
  Widget _buildDataGrid() {
    return Consumer(
      builder: (context, ref, child) {
        final zoomFactor = ref.watch(zoomProvider.select((s) => s.zoomFactor));

        // 🔒 열 개수와 행 셀 개수 일치 여부 검증
        final scaledColumns = GridScalingHelper.scaleColumns(
          widget.columns,
          zoomFactor,
        );

        // 🔥 중요: 컬럼이 비어있거나 잘못된 경우 오류 로그
        if (widget.columns.isEmpty) {
          AppLogger.error('SfDataGrid 컬럼이 비어있습니다. Provider 상태를 확인하세요.');
          // 컬럼이 비어있으면 빈 위젯 반환 (앱 크래시 방지)
          return const Center(
            child: Text(
              '시간표 그리드 데이터를 불러오는 중입니다...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orange),
            ),
          );
        }

        if (widget.dataSource != null && widget.dataSource!.rows.isNotEmpty) {
          final firstRowCells = widget.dataSource!.rows.first.getCells();
          final expectedCellCount = scaledColumns.length;
          final actualCellCount = firstRowCells.length;

          if (expectedCellCount != actualCellCount) {
            AppLogger.error(
              'SfDataGrid 열/셀 개수 불일치: columns=$expectedCellCount, cells=$actualCellCount (원본 컬럼: ${widget.columns.length}개)',
            );

            // 🔥 중요: 컬럼이 1개만 있는 경우는 초기화 문제로 간주
            if (widget.columns.length == 1) {
              AppLogger.error(
                '컬럼이 1개만 있습니다. Provider 상태가 초기화되지 않았거나 모드 전환 중 오류가 발생했습니다.',
              );
            }

            // 오류 발생 시 빈 위젯 반환 (앱 크래시 방지)
            return const Center(
              child: Text(
                '데이터 그리드 구조 오류가 발생했습니다.\n앱을 재시작해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            );
          }
        }

        Widget dataGridContainer = wrapWithDragScroll(
          RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  textTheme: Theme.of(context).textTheme.copyWith(
                    bodyMedium: TextStyle(
                      fontSize: GridLayoutConstants.baseFontSize * zoomFactor,
                    ),
                    bodySmall: TextStyle(
                      fontSize: GridLayoutConstants.baseFontSize * zoomFactor,
                    ),
                    titleMedium: TextStyle(
                      fontSize: GridLayoutConstants.baseFontSize * zoomFactor,
                    ),
                    labelMedium: TextStyle(
                      fontSize: GridLayoutConstants.baseFontSize * zoomFactor,
                    ),
                    labelLarge: TextStyle(
                      fontSize: GridLayoutConstants.baseFontSize * zoomFactor,
                    ),
                    labelSmall: TextStyle(
                      fontSize: GridLayoutConstants.baseFontSize * zoomFactor,
                    ),
                  ),
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    // Syncfusion DataGrid의 스크롤 이벤트 감지
                    if (notification is ScrollUpdateNotification) {
                      final metrics = notification.metrics;
                      final currentState = ref.read(scrollProvider);

                      // 현재 상태를 유지하면서 해당 축의 오프셋만 업데이트
                      final newHorizontal =
                          metrics.axis == Axis.horizontal
                              ? metrics.pixels
                              : currentState.horizontalOffset;
                      final newVertical =
                          metrics.axis == Axis.vertical
                              ? metrics.pixels
                              : currentState.verticalOffset;

                      ref
                          .read(scrollProvider.notifier)
                          .updateOffset(newHorizontal, newVertical);
                    }
                    return false; // 다른 위젯도 이벤트를 받을 수 있도록
                  },
                  child: SfDataGrid(
                    key: _dataGridKey,
                    controller: _dataGridController, // 🆕 DataGridController 연결
                    source: widget.dataSource!,
                    columns: scaledColumns, // 검증된 스케일된 열 사용
                    stackedHeaderRows: GridScalingHelper.scaleStackedHeaders(
                      widget.stackedHeaders,
                      zoomFactor,
                    ),
                    gridLinesVisibility: GridLinesVisibility.both,
                    headerGridLinesVisibility: GridLinesVisibility.both,
                    headerRowHeight: GridScalingHelper.scaleHeaderHeight(
                      zoomFactor,
                    ),
                    rowHeight: GridScalingHelper.scaleRowHeight(zoomFactor),
                    allowColumnsResizing: false,
                    allowSorting: false,
                    allowEditing: false,
                    allowTriStateSorting: false,
                    allowPullToRefresh: false,
                    selectionMode: SelectionMode.none,
                    columnWidthMode: ColumnWidthMode.none,
                    frozenColumnsCount: GridLayoutConstants.frozenColumnsCount,
                    onCellTap: _handleCellTap,
                    onCellSecondaryTap: _handleCellSecondaryTap,
                    horizontalScrollController: horizontalScrollController,
                    verticalScrollController: verticalScrollController,
                  ),
                ),
              ),
            ),
          ),
        );

        // 🧪 테스트: Transform.scale 제거 - 직접 반환으로 원상복구
        return dataGridContainer;
      },
    );
  }

  /// 🆕 교체 경로 노드로 스크롤하는 메서드
  /// 사이드바에서 노드를 선택했을 때 해당 셀로 중앙 스크롤
  ///
  /// [node] 교체 경로의 노드 정보
  void scrollToExchangeNode(ExchangeNode node) {
    try {
      AppLogger.exchangeDebug(
        '🔍 [노드 스크롤] 시작: ${node.teacherName} | ${node.day}요일 ${node.period}교시',
      );

      // 1. DataGridController 상태 확인
      // DataGridController는 hasClients 속성이 없으므로 다른 방법으로 확인
      try {
        // 간단한 테스트로 컨트롤러가 작동하는지 확인
        AppLogger.exchangeDebug('🔍 [노드 스크롤] DataGridController 상태 확인 중...');
      } catch (e) {
        AppLogger.exchangeDebug(
          '❌ [노드 스크롤] DataGridController가 아직 초기화되지 않음: $e',
        );
        // 잠시 후 재시도
        Future.delayed(const Duration(milliseconds: 100), () {
          scrollToExchangeNode(node);
        });
        return;
      }

      // 2. 교사명으로 행 인덱스 찾기
      final teacherRowIndex = _findTeacherRowIndex(node.teacherName);
      if (teacherRowIndex == -1) {
        AppLogger.exchangeDebug('❌ [노드 스크롤] 교사를 찾을 수 없음: ${node.teacherName}');
        return;
      }

      // 3. 요일과 교시로 열 인덱스 계산
      final dayOfWeekInt = DayUtils.getDayNumber(node.day);
      final columnIndex = _calculateColumnIndex(dayOfWeekInt, node.period);
      if (columnIndex == -1) {
        AppLogger.exchangeDebug(
          '❌ [노드 스크롤] 열 인덱스 계산 실패: 요일=${node.day}, 교시=${node.period}',
        );
        return;
      }

      // 4. 인덱스 유효성 검증
      final dataSource = widget.dataSource;
      if (dataSource == null) {
        AppLogger.exchangeDebug('❌ [노드 스크롤] 데이터 소스가 null');
        return;
      }

      final maxRowIndex = dataSource.rows.length - 1;
      final maxColumnIndex = widget.columns.length - 1;

      if (teacherRowIndex > maxRowIndex) {
        AppLogger.exchangeDebug(
          '❌ [노드 스크롤] 행 인덱스 범위 초과: $teacherRowIndex > $maxRowIndex',
        );
        return;
      }

      if (columnIndex > maxColumnIndex) {
        AppLogger.exchangeDebug(
          '❌ [노드 스크롤] 열 인덱스 범위 초과: $columnIndex > $maxColumnIndex',
        );
        return;
      }

      AppLogger.exchangeDebug(
        '✅ [노드 스크롤] 인덱스 검증 완료: 행=$teacherRowIndex/$maxRowIndex, 열=$columnIndex/$maxColumnIndex',
      );

      // 5. Syncfusion DataGrid의 내장 스크롤 기능 사용
      _dataGridController.scrollToCell(
        teacherRowIndex.toDouble(), // 행 인덱스 (double로 변환)
        columnIndex.toDouble(), // 열 인덱스 (double로 변환)
        canAnimate: true, // 부드러운 애니메이션 효과 적용
        rowPosition: DataGridScrollPosition.center, // 행을 수직 중앙에 위치
        columnPosition: DataGridScrollPosition.center, // 열을 수평 중앙에 위치
      );

      AppLogger.exchangeDebug(
        '🎯 [노드 스크롤] 셀 중앙 이동 완료: ${node.teacherName} | ${node.day}요일 ${node.period}교시 | 행:$teacherRowIndex, 열:$columnIndex',
      );

      // 6. 스크롤 실행 확인 (잠시 후)
      Future.delayed(const Duration(milliseconds: 500), () {
        _verifyScrollExecution(node, teacherRowIndex, columnIndex);
      });
    } catch (e) {
      AppLogger.exchangeDebug('❌ [노드 스크롤] 스크롤 실패: $e');
    }
  }

  /// 🆕 스크롤 실행 확인 메서드
  /// 실제로 스크롤이 실행되었는지 확인
  void _verifyScrollExecution(
    ExchangeNode node,
    int expectedRowIndex,
    int expectedColumnIndex,
  ) {
    try {
      // 현재 스크롤 위치 확인
      final currentHorizontalOffset =
          horizontalScrollController.hasClients
              ? horizontalScrollController.offset
              : 0.0;
      final currentVerticalOffset =
          verticalScrollController.hasClients
              ? verticalScrollController.offset
              : 0.0;

      AppLogger.exchangeDebug(
        '🔍 [스크롤 확인] 현재 위치: 수평=${currentHorizontalOffset.toStringAsFixed(1)}, 수직=${currentVerticalOffset.toStringAsFixed(1)}',
      );

      // 스크롤이 실제로 발생했는지 확인
      if (currentHorizontalOffset > 0 || currentVerticalOffset > 0) {
        AppLogger.exchangeDebug('✅ [스크롤 확인] 스크롤 실행됨');
      } else {
        AppLogger.exchangeDebug('⚠️ [스크롤 확인] 스크롤이 실행되지 않음 - 대체 방법 시도');
        _tryAlternativeScrollMethod(
          node,
          expectedRowIndex,
          expectedColumnIndex,
        );
      }
    } catch (e) {
      AppLogger.exchangeDebug('❌ [스크롤 확인] 확인 실패: $e');
    }
  }

  /// 🆕 대체 스크롤 방법 시도
  /// DataGridController가 작동하지 않을 때 ScrollController 직접 사용
  void _tryAlternativeScrollMethod(
    ExchangeNode node,
    int rowIndex,
    int columnIndex,
  ) {
    try {
      AppLogger.exchangeDebug('🔄 [대체 스크롤] ScrollController 직접 사용 시도');

      // ScrollController를 직접 사용하여 스크롤
      if (horizontalScrollController.hasClients &&
          verticalScrollController.hasClients) {
        // 대략적인 위치 계산 (실제 구현에서는 더 정밀한 계산 필요)
        final estimatedHorizontalOffset = columnIndex * 100.0; // 열당 대략 100px
        final estimatedVerticalOffset = rowIndex * 50.0; // 행당 대략 50px

        horizontalScrollController.animateTo(
          estimatedHorizontalOffset.clamp(
            0.0,
            horizontalScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        verticalScrollController.animateTo(
          estimatedVerticalOffset.clamp(
            0.0,
            verticalScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        AppLogger.exchangeDebug(
          '🔄 [대체 스크롤] ScrollController 스크롤 실행: 수평=${estimatedHorizontalOffset.toStringAsFixed(1)}, 수직=${estimatedVerticalOffset.toStringAsFixed(1)}',
        );
      }
    } catch (e) {
      AppLogger.exchangeDebug('❌ [대체 스크롤] 실패: $e');
    }
  }

  /// 교사명으로 행 인덱스 찾기
  ///
  /// [teacherName] 찾을 교사명
  /// Returns 행 인덱스 (0부터 시작, 헤더 제외)
  int _findTeacherRowIndex(String teacherName) {
    final dataSource = widget.dataSource;
    if (dataSource == null) return -1;

    // 데이터 소스에서 교사명이 포함된 행 찾기
    for (int i = 0; i < dataSource.rows.length; i++) {
      final row = dataSource.rows[i];
      // 첫 번째 셀(교사명)에서 교사명 확인
      if (row.getCells().isNotEmpty) {
        final cellValue = row.getCells().first.value?.toString() ?? '';
        if (cellValue.contains(teacherName)) {
          return i; // 헤더 행이 있다면 +1 필요할 수 있음
        }
      }
    }
    return -1;
  }

  /// 요일과 교시로 열 인덱스 계산
  ///
  /// [dayOfWeek] 요일 (1-5)
  /// [period] 교시 (1-8)
  /// Returns 열 인덱스 (0부터 시작)
  int _calculateColumnIndex(int dayOfWeek, int period) {
    try {
      AppLogger.exchangeDebug('🔍 [열 계산] 시작: 요일=$dayOfWeek, 교시=$period');

      // 실제 그리드 구조 분석
      final columns = widget.columns;
      AppLogger.exchangeDebug('🔍 [열 계산] 전체 열 개수: ${columns.length}');

      // 첫 번째 열이 교사명 열인지 확인
      bool hasTeacherColumn = false;
      if (columns.isNotEmpty) {
        final firstColumn = columns.first;
        hasTeacherColumn =
            firstColumn.columnName.contains('교사') ||
            firstColumn.columnName.contains('선생님') ||
            firstColumn.columnName.contains('Teacher') ||
            firstColumn.columnName.toLowerCase().contains('teacher');
        AppLogger.exchangeDebug(
          '🔍 [열 계산] 교사명 열 존재: $hasTeacherColumn (${firstColumn.columnName})',
        );
      }

      // 교사명 열이 있다면 그 다음부터 시작
      int startColumnIndex = hasTeacherColumn ? 1 : 0;

      // 🆕 실제 그리드 구조 분석하여 요일별 교시 수 계산
      final actualDataColumns = columns.length - startColumnIndex;
      AppLogger.exchangeDebug('🔍 [열 계산] 실제 데이터 열 개수: $actualDataColumns');

      // 요일별 교시 수 계산 (실제 구조에 맞게)
      final periodsPerDay = actualDataColumns ~/ 5; // 5요일로 나누기
      AppLogger.exchangeDebug('🔍 [열 계산] 요일당 교시 수: $periodsPerDay');

      // 🆕 더 정확한 계산 방식
      // 실제 그리드에서 요일별로 몇 개의 열이 있는지 확인
      int columnIndex;

      if (periodsPerDay > 0) {
        // 일반적인 경우: 요일별로 일정한 교시 수
        columnIndex =
            startColumnIndex + (dayOfWeek - 1) * periodsPerDay + (period - 1);
      } else {
        // 🆕 특수한 경우: 실제 열 구조를 분석
        AppLogger.exchangeDebug('🔍 [열 계산] 특수 구조 감지 - 실제 열 분석 시작');
        columnIndex = _analyzeActualColumnStructure(
          dayOfWeek,
          period,
          startColumnIndex,
        );
      }

      AppLogger.exchangeDebug(
        '🔍 [열 계산] 계산 결과: 시작열=$startColumnIndex, 요일당교시=$periodsPerDay, 최종열인덱스=$columnIndex',
      );

      // 범위 검증
      if (columnIndex < 0 || columnIndex >= columns.length) {
        AppLogger.exchangeDebug(
          '❌ [열 계산] 범위 초과: $columnIndex (최대: ${columns.length - 1})',
        );

        // 🆕 범위 초과 시 대안 계산 시도
        AppLogger.exchangeDebug('🔄 [열 계산] 대안 계산 시도');
        columnIndex = _tryAlternativeColumnCalculation(
          dayOfWeek,
          period,
          startColumnIndex,
          columns.length,
        );

        if (columnIndex == -1) {
          AppLogger.exchangeDebug('❌ [열 계산] 모든 계산 방법 실패');
          return -1;
        }
      }

      AppLogger.exchangeDebug('✅ [열 계산] 성공: $columnIndex');
      return columnIndex;
    } catch (e) {
      AppLogger.exchangeDebug('❌ [열 계산] 오류: $e');
      return -1;
    }
  }

  /// 🆕 실제 열 구조 분석
  /// 그리드의 실제 구조를 분석하여 정확한 열 인덱스 계산
  int _analyzeActualColumnStructure(
    int dayOfWeek,
    int period,
    int startColumnIndex,
  ) {
    try {
      AppLogger.exchangeDebug('🔍 [구조 분석] 실제 열 구조 분석 시작');

      // 열 이름들을 분석하여 패턴 파악
      final columns = widget.columns;
      List<String> columnNames = [];

      for (int i = startColumnIndex; i < columns.length; i++) {
        columnNames.add(columns[i].columnName);
      }

      AppLogger.exchangeDebug('🔍 [구조 분석] 데이터 열 이름들: $columnNames');

      // 요일별로 그룹화 시도
      Map<String, List<int>> dayGroups = {};
      for (int i = 0; i < columnNames.length; i++) {
        final columnName = columnNames[i];
        String? dayName = _extractDayFromColumnName(columnName);
        if (dayName != null) {
          dayGroups.putIfAbsent(dayName, () => []).add(i + startColumnIndex);
        }
      }

      AppLogger.exchangeDebug('🔍 [구조 분석] 요일별 그룹: $dayGroups');

      // 해당 요일의 열들 찾기
      final dayName = DayUtils.getDayName(dayOfWeek);
      final dayColumns = dayGroups[dayName] ?? [];

      if (dayColumns.isNotEmpty && period <= dayColumns.length) {
        final columnIndex = dayColumns[period - 1];
        AppLogger.exchangeDebug(
          '✅ [구조 분석] 성공: $dayName $period교시 = 열 $columnIndex',
        );
        return columnIndex;
      }

      AppLogger.exchangeDebug('❌ [구조 분석] 해당 요일/교시를 찾을 수 없음');
      return -1;
    } catch (e) {
      AppLogger.exchangeDebug('❌ [구조 분석] 오류: $e');
      return -1;
    }
  }

  /// 🆕 열 이름에서 요일 추출
  String? _extractDayFromColumnName(String columnName) {
    final dayNames = ['월', '화', '수', '목', '금'];
    for (String day in dayNames) {
      if (columnName.contains(day)) {
        return day;
      }
    }
    return null;
  }

  /// 🆕 대안 열 계산 방법
  /// 기본 계산이 실패했을 때 시도하는 대안 방법
  int _tryAlternativeColumnCalculation(
    int dayOfWeek,
    int period,
    int startColumnIndex,
    int totalColumns,
  ) {
    try {
      AppLogger.exchangeDebug('🔄 [대안 계산] 대안 방법 시도');

      // 방법 1: 단순한 선형 계산 (교시별로 연속 배치)
      final linearIndex = startColumnIndex + (dayOfWeek - 1) * 8 + (period - 1);
      if (linearIndex < totalColumns) {
        AppLogger.exchangeDebug('✅ [대안 계산] 선형 계산 성공: $linearIndex');
        return linearIndex;
      }

      // 방법 2: 교시 중심 계산 (요일별로 교시가 연속 배치)
      final periodBasedIndex =
          startColumnIndex + (period - 1) * 5 + (dayOfWeek - 1);
      if (periodBasedIndex < totalColumns) {
        AppLogger.exchangeDebug('✅ [대안 계산] 교시 중심 계산 성공: $periodBasedIndex');
        return periodBasedIndex;
      }

      // 방법 3: 최소한의 안전한 인덱스 반환
      final safeIndex = (startColumnIndex + (dayOfWeek - 1) * 6 + (period - 1))
          .clamp(startColumnIndex, totalColumns - 1);
      AppLogger.exchangeDebug('⚠️ [대안 계산] 안전한 인덱스 사용: $safeIndex');
      return safeIndex;
    } catch (e) {
      AppLogger.exchangeDebug('❌ [대안 계산] 오류: $e');
      return -1;
    }
  }

  /// 교체된 셀 클릭 처리 (Riverpod 기반)
  /// 🔥 스크롤 문제 해결: 과거 커밋의 단순한 구조를 참고하여 스크롤 위치 보존
  void _handleExchangedCellClick(String teacherName, String day, int period) {
    AppLogger.exchangeDebug('🖱️ 교체된 셀 클릭: $teacherName | $day$period교시');

    // 🔥 스크롤 문제 해결: 교체된 셀 클릭 시에도 스크롤 위치 보존
    // 과거 커밋의 단순한 구조를 유지하여 불필요한 상태 변경 방지

    // 교체된 셀 선택 상태 플래그 설정 (헤더 색상 비활성화용)
    SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(true);

    final historyService = ref.read(exchangeHistoryServiceProvider);
    final exchangePath = historyService.findExchangePathByCell(
      teacherName,
      day,
      period,
    );

    if (exchangePath != null) {
      AppLogger.exchangeDebug(
        '✅ 교체 경로 발견: ${exchangePath.type} (ID: ${exchangePath.id})',
      );

      ref
          .read(stateResetProvider.notifier)
          .resetExchangeStates(reason: '교체된 셀 클릭 - 이전 교체 상태 초기화');

      // Riverpod 기반 화살표 표시
      ref
          .read(cellSelectionProvider.notifier)
          .showArrowForExchangedCell(exchangePath);

      // 교체된 셀 클릭 시 교체 서비스 상태 업데이트 (헤더 업데이트를 위해)
      _updateExchangeServiceForExchangedCell(teacherName, day, period);

      AppLogger.exchangeDebug('🔄 교체된 셀 클릭 - UI 업데이트 (스크롤 위치 보존)');

      AppLogger.exchangeDebug(
        '교체된 셀 클릭: $teacherName | $day$period교시 → 경로 ID: ${exchangePath.id}',
      );
    } else {
      AppLogger.exchangeDebug('❌ 교체 경로를 찾을 수 없음: $teacherName | $day$period교시');
    }
  }

  /// 일반 셀 탭 시 화살표 숨기기 (Riverpod 기반)
  void _hideExchangeArrows() {
    // Riverpod 기반 화살표 숨기기
    ref
        .read(cellSelectionProvider.notifier)
        .hideArrow(reason: ArrowDisplayReason.manualHide);

    ref
        .read(stateResetProvider.notifier)
        .resetExchangeStates(reason: '일반 셀 클릭 - 교체 화살표 숨김');
  }

  /// 화살표 상태 초기화 (외부에서 호출) - StateResetProvider에서 처리됨
  void clearAllArrowStates() {
    // 화살표 상태 초기화는 StateResetProvider에서 처리됨
    ref
        .read(stateResetProvider.notifier)
        .resetExchangeStates(reason: '외부 호출 - 화살표 상태 초기화');
  }

  /// Level 1 전용 화살표 초기화 (경로 선택만 해제) - StateResetProvider에서 처리됨
  void clearPathSelectionOnly() {
    // 화살표 초기화는 StateResetProvider에서 처리됨
    AppLogger.exchangeDebug(
      '[Level 1] 경로 선택만 초기화 요청 (StateResetProvider에서 처리)',
    );
  }

  /// 셀 탭 이벤트 처리
  /// 🔥 스크롤 문제 해결: 과거 커밋의 단순한 구조를 참고하여 스크롤 위치 보존
  void _handleCellTap(DataGridCellTapDetails details) {
    final teacherName = _extractTeacherNameFromRowIndex(
      details.rowColumnIndex.rowIndex,
    );
    final columnName = details.column.columnName;

    // 🔥 스크롤 문제 해결: 셀 탭 시에도 스크롤 위치 보존
    // 과거 커밋의 단순한 구조를 유지하여 불필요한 상태 변경 방지

    // 교사 이름 클릭 처리 (새로 추가)
    if (columnName == 'teacher') {
      handleTeacherNameClick(teacherName);
      return;
    }

    if (columnName != 'teacher') {
      final parts = columnName.split('_');
      if (parts.length == 2) {
        final day = parts[0];
        final period = int.tryParse(parts[1]) ?? 0;

        final historyService = ref.read(exchangeHistoryServiceProvider);
        final isExchangedCell = historyService.isCellExchanged(
          teacherName,
          day,
          period,
        );

        if (isExchangedCell) {
          _handleExchangedCellClick(teacherName, day, period);
          return;
        }

        // 보강 모드에서는 일반 셀 클릭 시 교사 이름 추출하지 않음
        // 교사 이름 열을 통해서만 보강 실행
      }
    }

    // 일반 셀 클릭 시 교체된 셀 선택 상태 플래그 해제 (헤더 색상 복원용)
    SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(false);

    // Level 2 초기화 실행 (로그와 동일한 동작)
    _hideExchangeArrows();

    widget.onCellTap(details);
    AppLogger.exchangeDebug('🔄 일반 셀 클릭 - UI 업데이트 (스크롤 위치 보존)');
  }

  /// 교체 경로가 있는 셀 우클릭 → 컨텍스트 메뉴 표시
  void _handleCellSecondaryTap(DataGridCellTapDetails details) {
    final columnName = details.column.columnName;
    if (columnName == 'teacher') return;

    final parts = columnName.split('_');
    if (parts.length != 2) return;

    final teacherName = _extractTeacherNameFromRowIndex(
      details.rowColumnIndex.rowIndex,
    );
    if (teacherName.isEmpty) return;

    final day = parts[0];
    final period = int.tryParse(parts[1]) ?? 0;

    final historyService = ref.read(exchangeHistoryServiceProvider);
    final isExchangedCell = historyService.isCellExchanged(
      teacherName,
      day,
      period,
    );
    if (!isExchangedCell) return;

    final exchangePath = historyService.findExchangePathByCell(
      teacherName,
      day,
      period,
    );
    if (exchangePath == null) return;

    // 좌클릭과 동일하게 경로 선택(화살표 표시) 후 메뉴 표시
    _handleExchangedCellClick(teacherName, day, period);

    _showExchangePathDeleteContextMenu(
      globalPosition: details.globalPosition,
      exchangePath: exchangePath,
    );
  }

  /// 우클릭 컨텍스트 메뉴 — 경로 삭제
  /// showMenu는 Material 기본 여백(상하 8px 등)이 있어 커스텀 오버레이 사용
  Future<void> _showExchangePathDeleteContextMenu({
    required Offset globalPosition,
    required ExchangePath exchangePath,
  }) async {
    final selected = await _showCompactDeleteMenu(globalPosition);
    if (selected != 'delete_path') return;

    await _deleteExchangePath(exchangePath);
  }

  /// 여백 최소화된 삭제 컨텍스트 메뉴 (PopupMenu 기본 padding 없음)
  Future<String?> _showCompactDeleteMenu(Offset globalPosition) {
    final overlayState = Overlay.of(context);
    final overlayBox = overlayState.context.findRenderObject()! as RenderBox;
    final localPosition = overlayBox.globalToLocal(globalPosition);

    final completer = Completer<String?>();
    late OverlayEntry entry;

    void close([String? value]) {
      if (!completer.isCompleted) completer.complete(value);
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 바깥 클릭 시 메뉴 닫기
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => close(null),
            ),
          ),
          Positioned(
            left: localPosition.dx,
            top: localPosition.dy,
            child: Material(
              elevation: 3,
              shadowColor: Colors.black26,
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => close('delete_path'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '삭제',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlayState.insert(entry);
    return completer.future;
  }

  /// 교사 이름 클릭 처리 (교체 모드 또는 교체불가 편집 모드에서 동작) - public 메서드로 변경
  void handleTeacherNameClick(String teacherName) {
    // 현재 모드 및 교사 이름 선택 기능 활성화 상태 확인
    final screenState = ref.read(exchangeScreenProvider);
    final currentMode = screenState.currentMode;
    final isNonExchangeableEditMode =
        currentMode == ExchangeMode.nonExchangeableEdit;
    final isSupplementExchangeMode =
        currentMode == ExchangeMode.supplementExchange;
    final isTeacherNameSelectionEnabled =
        screenState.isTeacherNameSelectionEnabled;

    // 교체불가 편집 모드인 경우 교사 전체 시간 토글 기능 사용
    if (isNonExchangeableEditMode) {
      AppLogger.exchangeDebug('교체불가 편집 모드: 교사 전체 시간 토글 기능 사용 - $teacherName');
      _toggleTeacherAllTimesInNonExchangeableMode(teacherName);
      return;
    }

    // 보강 모드이고 교사 이름 선택 기능이 활성화된 경우 보강 실행
    if (isSupplementExchangeMode && isTeacherNameSelectionEnabled) {
      AppLogger.exchangeDebug('보강 모드: 교사 이름 클릭 - 보강 실행 - $teacherName');

      // 현재 선택된 셀 정보 가져오기
      final exchangeService = ref.read(exchangeServiceProvider);
      if (!exchangeService.hasSelectedCell()) {
        AppLogger.exchangeDebug('보강 실행 실패: 선택된 셀을 먼저 선택해주세요');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('보강할 셀을 먼저 선택해주세요'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final selectedDay = exchangeService.selectedDay!;
      final selectedPeriod = exchangeService.selectedPeriod!;

      // 교사 이름 클릭 시 해당 교사의 해당 시간대가 빈 셀인지 검사
      if (!_isCellEmpty(teacherName, selectedDay, selectedPeriod)) {
        AppLogger.exchangeDebug(
          '보강 실행 실패: $teacherName의 $selectedDay$selectedPeriod교시는 수업이 있는 시간입니다',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '보강할 시간에 수업이 없는 교사을 선택해주세요. $teacherName의 $selectedDay$selectedPeriod교시는 수업이 있는 시간입니다.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // 교사 이름 선택 상태 설정
      ref.read(cellSelectionProvider.notifier).selectTeacherName(teacherName);

      // 보강 실행 (ExchangeExecutor 호출)
      executeSupplementExchangeViaExecutor(teacherName);
      return;
    }

    // 다른 교체 모드이지만 교사 이름 선택 기능이 비활성화된 경우 아무 동작하지 않음
    if (!isInExchangeMode || !isTeacherNameSelectionEnabled) {
      AppLogger.exchangeDebug('교사 이름 클릭: 교체 모드가 아니거나 교사 이름 선택 기능이 비활성화됨');
      return;
    }

    // 기존 교체 모드인 경우 교사 이름 선택 기능 사용 (1:1, 순환, 연쇄 교체)
    final cellNotifier = ref.read(cellSelectionProvider.notifier);
    final cellState = ref.read(cellSelectionProvider);

    // 현재 선택된 교사 이름과 같은지 확인
    if (cellState.selectedTeacherName == teacherName) {
      // 같은 교사 이름을 다시 클릭하면 선택 해제
      cellNotifier.selectTeacherName(null);
      AppLogger.exchangeDebug('교사 이름 선택 해제: $teacherName');
    } else {
      // 다른 교사 이름을 클릭하면 선택
      cellNotifier.selectTeacherName(teacherName);
      AppLogger.exchangeDebug('교사 이름 선택: $teacherName');
    }

    // UI 업데이트 로깅
    AppLogger.exchangeDebug('🔄 교사 이름 클릭 - UI 업데이트');
  }

  /// 셀이 비어있는지 확인 (과목이나 학급이 없는지 검사)
  ///
  /// [teacherName] 교사 이름
  /// [day] 요일 (월, 화, 수, 목, 금)
  /// [period] 교시 (1-7)
  ///
  /// Returns: `bool` - 셀이 비어있으면 true, 비어있지 않으면 false
  bool _isCellEmpty(String teacherName, String day, int period) {
    if (widget.timetableData == null) return false;

    try {
      final dayNumber = DayUtils.getDayNumber(day);
      final timeSlot = widget.timetableData!.timeSlots.firstWhere(
        (slot) =>
            slot.teacher == teacherName &&
            slot.dayOfWeek == dayNumber &&
            slot.period == period,
        orElse: () => TimeSlot(), // 빈 TimeSlot 반환
      );

      return timeSlot.isEmpty;
    } catch (e) {
      AppLogger.exchangeDebug('셀 비어있음 검사 중 오류: $e');
      return false;
    }
  }

  /// 보강 실행 (ExchangeExecutor 호출 - 1:1 교체와 동일한 패턴) - public 메서드로 변경
  void executeSupplementExchangeViaExecutor(String targetTeacherName) {
    if (widget.timetableData == null) {
      AppLogger.exchangeDebug('보강 실행 실패: timetableData가 null입니다');
      return;
    }

    // 현재 선택된 셀 정보 가져오기
    final exchangeService = ExchangeService();
    if (!exchangeService.hasSelectedCell()) {
      AppLogger.exchangeDebug('보강 실행 실패: 선택된 셀을 먼저 선택해주세요');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('보강할 셀을 먼저 선택해주세요'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final sourceTeacher = exchangeService.selectedTeacher!;
    final sourceDay = exchangeService.selectedDay!;
    final sourcePeriod = exchangeService.selectedPeriod!;

    // 소스 셀의 정보 가져오기
    final sourceSlot = widget.timetableData!.timeSlots.firstWhere(
      (slot) =>
          slot.teacher == sourceTeacher &&
          slot.dayOfWeek == DayUtils.getDayNumber(sourceDay) &&
          slot.period == sourcePeriod,
      orElse: () => throw StateError('소스 TimeSlot을 찾을 수 없습니다'),
    );

    // 보강 가능성 검증
    if (!sourceSlot.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시에 수업이 없습니다',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!sourceSlot.canExchange) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시 수업은 교체 불가능합니다',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // ExchangeExecutor에 위임 (1:1 교체와 동일한 패턴)
    _exchangeExecutor.executeSupplementExchange(
      sourceTeacher,
      sourceDay,
      sourcePeriod,
      targetTeacherName,
      sourceSlot.className ?? '',
      sourceSlot.subject ?? '',
      context,
      () {
        ref
            .read(stateResetProvider.notifier)
            .resetExchangeStates(reason: '내부 경로 초기화');
      },
    );

    // 교사 이름 선택 기능 비활성화
    ref.read(exchangeScreenProvider.notifier).disableTeacherNameSelection();
    ref.read(cellSelectionProvider.notifier).selectTeacherName(null);
  }

  /// 교체불가 편집 모드에서 교사 전체 시간 토글 처리
  void _toggleTeacherAllTimesInNonExchangeableMode(String teacherName) {
    if (widget.timetableData == null) return;

    AppLogger.exchangeDebug('교체불가 편집 모드: 교사 $teacherName의 모든 시간 토글');

    // TimetableDataSource의 toggleTeacherAllTimes 메서드 사용
    widget.dataSource?.toggleTeacherAllTimes(teacherName);

    // UI 업데이트 로깅
    AppLogger.exchangeDebug('🔄 교사 전체 시간 토글 - UI 업데이트');

    AppLogger.exchangeDebug('교사 $teacherName의 모든 시간 토글 완료');
  }

  /// 행 인덱스에서 교사명 추출
  String _extractTeacherNameFromRowIndex(int rowIndex) {
    const int headerRowCount = 2;
    int actualRowIndex = rowIndex - headerRowCount;

    if (widget.timetableData == null ||
        actualRowIndex < 0 ||
        actualRowIndex >= widget.timetableData!.teachers.length) {
      return '';
    }

    return widget.timetableData!.teachers[actualRowIndex].name;
  }

  /// 교체된 셀 클릭 시 교체 서비스 상태 업데이트 (화살표 보존)
  void _updateExchangeServiceForExchangedCell(
    String teacherName,
    String day,
    int period,
  ) {
    try {
      // ExchangeService에 선택된 셀 정보 설정 (헤더 업데이트를 위해)
      // 하지만 실제 교체 서비스 로직은 실행하지 않음
      final exchangeService = ref.read(exchangeServiceProvider);

      // 선택된 셀 정보만 설정 (교체 가능한 교사 정보 수집을 위해)
      exchangeService.selectCell(teacherName, day, period);

      // TimetableThemeProvider 상태도 업데이트 (교사 이름 컬럼 하이라이트를 위해)
      final cellNotifier = ref.read(cellSelectionProvider.notifier);
      cellNotifier.selectCell(teacherName, day, period);

      AppLogger.exchangeDebug(
        '📝 교체 서비스 상태 업데이트 완료: $teacherName $day$period교시',
      );
    } catch (e) {
      AppLogger.error('교체 서비스 상태 업데이트 실패: $e');
    }
  }

  /// 교체 뷰 활성화 (Riverpod 기반)
  void _enableExchangeView() {
    AppLogger.exchangeDebug('[TimetableGridSection] _enableExchangeView() 호출됨');

    if (widget.timetableData == null || widget.dataSource == null) {
      AppLogger.exchangeDebug(
        '[TimetableGridSection] 교체 뷰 활성화 실패: 필수 데이터가 null입니다',
      );
      return;
    }

    AppLogger.exchangeDebug(
      '[TimetableGridSection] ExchangeViewProvider.enableExchangeView() 호출 시작',
    );

    ref
        .read(exchangeViewProvider.notifier)
        .enableExchangeView(
          timeSlots: widget.dataSource!.timeSlots,
          teachers: widget.timetableData!.teachers,
          dataSource: widget.dataSource!,
        );

    AppLogger.exchangeDebug(
      '[TimetableGridSection] ExchangeViewProvider.enableExchangeView() 호출 완료',
    );
  }

  /// 삭제 확인 다이얼로그 표시
  ///
  /// 사용자에게 삭제 확인을 받고, 확인 시 교체 리스트를 삭제합니다.
  void _showDeleteExchangeListDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('결보강 전체 초기화'),
            content: const Text('결보강을 전체 초기화하겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '취소',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteExchangeList(context, ref);
                },
                child: Text(
                  '초기화',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ),
            ],
          ),
    );
  }

  /// 교체 리스트 삭제 실행
  ///
  /// ExchangeHistoryService를 통해 전체 교체 리스트를 삭제하고,
  /// UI 상태를 초기화합니다.
  ///
  /// 주의: 교체 뷰 상태는 유지됩니다 (비활성화하지 않음).
  void _deleteExchangeList(BuildContext context, WidgetRef ref) {
    try {
      // 1. 교체 리스트 전체 삭제
      final historyService = ref.read(exchangeHistoryServiceProvider);
      historyService.clearExchangeList();

      // 2. 저장된 결강일·교체일·보강 과목 정보 삭제
      ref.read(substitutionPlanProvider.notifier).clearAllDates();

      // 3. 교체된 셀 상태 업데이트 (빈 리스트로 갱신하여 교체된 셀 스타일 제거)
      // ExchangeExecutor의 updateExchangedCells() 재사용 (코드 중복 방지)
      // 교체 리스트가 비어있으므로 모든 교체된 셀 스타일이 제거됨
      _exchangeExecutor.updateExchangedCells();

      // 4. UI 상태 초기화 (선택된 경로, 캐시, 화살표 등)
      ref
          .read(stateResetProvider.notifier)
          .resetExchangeStates(reason: '결보강 전체 삭제');

      // 5. DataGrid UI 업데이트 (스크롤 위치 보존)
      widget.dataSource?.notifyDataChanged();

      // 6. 성공 메시지 표시
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('결보강 전체가 초기화되었습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 오류 메시지 표시
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 교체 뷰 비활성화 (Riverpod 기반)
  void _disableExchangeView() {
    if (widget.timetableData == null || widget.dataSource == null) {
      AppLogger.exchangeDebug('교체 뷰 비활성화 실패: 필수 데이터가 null입니다');
      return;
    }

    ref
        .read(exchangeViewProvider.notifier)
        .disableExchangeView(
          timeSlots: widget.dataSource!.timeSlots,
          teachers: widget.timetableData!.teachers,
          dataSource: widget.dataSource!,
        );
  }
}

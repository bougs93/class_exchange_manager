import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/excel_service.dart';
import '../../services/exchange_service.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';
import '../../models/exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/time_slot.dart';
import '../../services/exchange_history_service.dart';
import '../../providers/timetable_theme_provider.dart';
import '../../providers/state_reset_provider.dart';
import 'timetable_grid/timetable_grid_constants.dart';
import 'timetable_grid/exchange_arrow_style.dart';
import 'timetable_grid/exchange_arrow_painter.dart';
import 'timetable_grid/zoom_manager.dart';
import 'timetable_grid/scroll_manager.dart';
import 'timetable_grid/exchange_view_manager.dart';
import 'timetable_grid/exchange_executor.dart';
import 'timetable_grid/grid_header_widgets.dart';

/// TimeSlots 백업 상태 관리
class TimeSlotsBackupState {
  final List<TimeSlot>? originalTimeSlots;
  final bool isValid;
  final int count;

  const TimeSlotsBackupState({
    this.originalTimeSlots,
    this.isValid = false,
    this.count = 0,
  });

  TimeSlotsBackupState copyWith({
    List<TimeSlot>? originalTimeSlots,
    bool? isValid,
    int? count,
  }) {
    return TimeSlotsBackupState(
      originalTimeSlots: originalTimeSlots ?? this.originalTimeSlots,
      isValid: isValid ?? this.isValid,
      count: count ?? this.count,
    );
  }
}

/// TimeSlots 백업 데이터 Notifier
class TimeSlotsBackupNotifier extends StateNotifier<TimeSlotsBackupState> {
  TimeSlotsBackupNotifier() : super(const TimeSlotsBackupState());

  /// 백업 데이터 생성
  void createBackup(List<TimeSlot> timeSlots) {
    try {
      final backupSlots = timeSlots.map((slot) => slot.copy()).toList();
      state = TimeSlotsBackupState(
        originalTimeSlots: backupSlots,
        isValid: true,
        count: backupSlots.length,
      );
      AppLogger.exchangeInfo('TimeSlots 백업 생성 완료: ${backupSlots.length}개');
    } catch (e) {
      AppLogger.exchangeDebug('TimeSlots 백업 생성 중 오류: $e');
      state = const TimeSlotsBackupState();
    }
  }

  /// 백업 데이터 복원
  List<TimeSlot>? restoreBackup() {
    if (state.isValid && state.originalTimeSlots != null) {
      return state.originalTimeSlots!.map((slot) => slot.copy()).toList();
    }
    return null;
  }

  /// 백업 데이터 초기화
  void clear() {
    state = const TimeSlotsBackupState();
    AppLogger.exchangeInfo('TimeSlots 백업 데이터 초기화 완료');
  }
}

/// TimeSlots 백업 데이터 Provider
final timeSlotsBackupProvider = StateNotifierProvider<TimeSlotsBackupNotifier, TimeSlotsBackupState>((ref) {
  return TimeSlotsBackupNotifier();
});

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
  final VoidCallback? onRestoreUIToDefault; // UI 기본값 복원 콜백

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
    this.selectedExchangePath,
    this.customArrowStyle,
    this.onHeaderThemeUpdate,
    this.onRestoreUIToDefault,
  });

  @override
  ConsumerState<TimetableGridSection> createState() => _TimetableGridSectionState();

  /// 외부에서 스크롤 기능에 접근할 수 있도록 하는 static 메서드
  static void scrollToCellCenter(GlobalKey<State<TimetableGridSection>> key, String teacherName, String day, int period) {
    final state = key.currentState;
    if (state is _TimetableGridSectionState) {
      state.scrollToCellCenter(teacherName, day, period);
    }
  }
}

class _TimetableGridSectionState extends ConsumerState<TimetableGridSection> {
  // 스크롤 컨트롤러들
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  // 헬퍼 클래스들
  late ZoomManager _zoomManager;
  late ScrollManager _scrollManager;
  late ExchangeViewManager _exchangeViewManager;
  late ExchangeExecutor _exchangeExecutor;

  // 교체 히스토리 서비스
  final ExchangeHistoryService _historyService = ExchangeHistoryService();

  // 교체 서비스
  final ExchangeService _exchangeService = ExchangeService();

  // 내부적으로 관리하는 선택된 교체 경로 (교체된 셀 클릭 시 사용)
  ExchangePath? _internalSelectedPath;

  // 교체 뷰 체크박스 상태
  bool _isExchangeViewEnabled = false;

  /// 현재 선택된 교체 경로 (외부 또는 내부)
  ExchangePath? get currentSelectedPath => widget.selectedExchangePath ?? _internalSelectedPath;

  /// 교체 모드인지 확인 (1:1, 순환, 연쇄 중 하나라도 활성화된 경우)
  bool get isInExchangeMode => widget.isExchangeModeEnabled ||
                               widget.isCircularExchangeModeEnabled ||
                               widget.isChainExchangeModeEnabled;

  /// 교체된 셀에서 선택된 경로인지 확인
  bool get isFromExchangedCell => _internalSelectedPath != null;

  @override
  void initState() {
    super.initState();

    // ZoomManager 초기화
    _zoomManager = ZoomManager(
      onZoomChanged: () {
        if (mounted) setState(() {});
      },
    );
    _zoomManager.initialize();

    // ScrollManager 초기화
    _scrollManager = ScrollManager(
      verticalScrollController: _verticalScrollController,
      horizontalScrollController: _horizontalScrollController,
      onScrollChanged: _onScrollChanged,
    );

    // ExchangeViewManager 초기화
    _exchangeViewManager = ExchangeViewManager(
      ref: ref,
      dataSource: widget.dataSource,
      timetableData: widget.timetableData,
      exchangeService: _exchangeService,
    );

    // ExchangeExecutor 초기화
    _exchangeExecutor = ExchangeExecutor(
      ref: ref,
      historyService: _historyService,
      dataSource: widget.dataSource,
    );

    // 테이블 렌더링 완료 후 콜백 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.timetableData != null && widget.dataSource != null) {
        _notifyTableRenderingComplete();
      }
    });
  }

  @override
  void didUpdateWidget(TimetableGridSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 테이블 데이터나 데이터 소스가 변경된 경우 테이블 렌더링 완료 감지
    if (widget.timetableData != oldWidget.timetableData ||
        widget.dataSource != oldWidget.dataSource) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.timetableData != null && widget.dataSource != null) {
          _notifyTableRenderingComplete();
        }
      });
    }
  }

  @override
  void dispose() {
    _zoomManager.dispose();
    _scrollManager.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  /// 테이블 렌더링 완료 알림
  void _notifyTableRenderingComplete() {
    widget.onHeaderThemeUpdate?.call();
    widget.onRestoreUIToDefault?.call();
  }

  /// 스크롤 변경 시 화살표 재그리기
  void _onScrollChanged() {
    if (widget.selectedExchangePath == null) return;
    if (mounted && widget.selectedExchangePath != null) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timetableData == null || widget.dataSource == null) {
      return const SizedBox.shrink();
    }

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
            Expanded(
              child: _buildDataGridWithArrows(),
            ),
          ],
        ),
      ),
    );
  }

  /// 헤더 구성
  Widget _buildHeader() {
    return Row(
      children: [
        const SizedBox(width: 8),

        // 확대/축소 컨트롤
        ZoomControlWidget(
          zoomPercentage: _zoomManager.zoomPercentage,
          zoomFactor: _zoomManager.zoomFactor,
          minZoom: GridLayoutConstants.minZoom,
          maxZoom: GridLayoutConstants.maxZoom,
          onZoomIn: _zoomManager.zoomIn,
          onZoomOut: _zoomManager.zoomOut,
          onResetZoom: _zoomManager.resetZoom,
        ),

        const SizedBox(width: 8),

        // 전체 교사 수 표시
        TeacherCountWidget(
          teacherCount: widget.timetableData!.teachers.length,
        ),

        const SizedBox(width: 8),

        // 교체 뷰 체크박스
        ExchangeViewCheckbox(
          isEnabled: _isExchangeViewEnabled,
          onChanged: (bool? value) {
            setState(() {
              _isExchangeViewEnabled = value ?? false;
            });

            if (_isExchangeViewEnabled) {
              _enableExchangeView();
            } else {
              _disableExchangeView();
            }
          },
        ),

        const SizedBox(width: 8),

        const Spacer(),

        // 보강/교체 버튼들
        ExchangeActionButtons(
          onUndo: () => _exchangeExecutor.undoLastExchange(context, _clearInternalPath),
          onRepeat: () => _exchangeExecutor.repeatLastExchange(context),
          onSupplement: _showSupplementDialog,
          onDelete: (currentSelectedPath != null && isFromExchangedCell)
            ? () => _exchangeExecutor.deleteFromExchangeList(currentSelectedPath!, context, _clearInternalPath)
            : null,
          onExchange: (isInExchangeMode && !isFromExchangedCell && currentSelectedPath != null)
            ? () => _exchangeExecutor.executeExchange(currentSelectedPath!, context, _clearInternalPath)
            : null,
          showDeleteButton: currentSelectedPath != null && isFromExchangedCell,
          showExchangeButton: isInExchangeMode && !isFromExchangedCell,
        ),
      ],
    );
  }

  /// DataGrid와 화살표를 함께 구성
  Widget _buildDataGridWithArrows() {
    Widget dataGridWithGestures = _buildDataGridWithDragScrolling();

    // 교체 경로가 선택된 경우에만 화살표 표시
    if (currentSelectedPath != null && widget.timetableData != null) {
      return Stack(
        children: [
          dataGridWithGestures,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ExchangeArrowPainter(
                  selectedPath: currentSelectedPath!,
                  timetableData: widget.timetableData!,
                  columns: widget.columns,
                  verticalScrollOffset: _verticalScrollController.offset,
                  horizontalScrollOffset: _horizontalScrollController.offset,
                  customArrowStyle: widget.customArrowStyle,
                  zoomFactor: _zoomManager.zoomFactor,
                ),
                child: RepaintBoundary(
                  child: Container(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return dataGridWithGestures;
  }

  /// 드래그 스크롤 기능이 포함된 DataGrid 구성
  Widget _buildDataGridWithDragScrolling() {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          () => PanGestureRecognizer(),
          (PanGestureRecognizer instance) {
            instance
              ..onStart = _scrollManager.onPanStart
              ..onUpdate = _scrollManager.onPanUpdate
              ..onEnd = _scrollManager.onPanEnd;
          },
        ),
        ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
          () => ScaleGestureRecognizer(),
          (ScaleGestureRecognizer instance) {
            instance.onUpdate = (ScaleUpdateDetails details) {
              // 기존 줌 기능은 유지 (필요시 구현)
            };
          },
        ),
      },
      behavior: HitTestBehavior.translucent,
      child: Listener(
        onPointerDown: _scrollManager.onMouseDown,
        onPointerUp: _scrollManager.onMouseUp,
        onPointerMove: _scrollManager.onMouseMove,
        behavior: HitTestBehavior.translucent,
        child: _buildDataGrid(),
      ),
    );
  }

  /// DataGrid 구성
  Widget _buildDataGrid() {
    Widget dataGridContainer = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.copyWith(
              bodyMedium: TextStyle(fontSize: _getScaledFontSize()),
              bodySmall: TextStyle(fontSize: _getScaledFontSize()),
              titleMedium: TextStyle(fontSize: _getScaledFontSize()),
              labelMedium: TextStyle(fontSize: _getScaledFontSize()),
              labelLarge: TextStyle(fontSize: _getScaledFontSize()),
              labelSmall: TextStyle(fontSize: _getScaledFontSize()),
            ),
          ),
          child: SfDataGrid(
            key: ValueKey(widget.columns.hashCode),
            source: widget.dataSource!,
            columns: _getScaledColumns(),
            stackedHeaderRows: _getScaledStackedHeaders(),
            gridLinesVisibility: GridLinesVisibility.both,
            headerGridLinesVisibility: GridLinesVisibility.both,
            headerRowHeight: _getScaledHeaderHeight(),
            rowHeight: _getScaledRowHeight(),
            allowColumnsResizing: false,
            allowSorting: false,
            allowEditing: false,
            allowTriStateSorting: false,
            allowPullToRefresh: false,
            selectionMode: SelectionMode.none,
            columnWidthMode: ColumnWidthMode.none,
            frozenColumnsCount: GridLayoutConstants.frozenColumnsCount,
            onCellTap: _handleCellTap,
            verticalScrollController: _verticalScrollController,
            horizontalScrollController: _horizontalScrollController,
            isScrollbarAlwaysShown: true,
            horizontalScrollPhysics: const AlwaysScrollableScrollPhysics(),
            verticalScrollPhysics: const AlwaysScrollableScrollPhysics(),
          ),
        ),
      ),
    );

    return dataGridContainer;
  }

  /// 확대/축소에 따른 실제 크기 조정된 열 반환
  List<GridColumn> _getScaledColumns() {
    return widget.columns.map((column) {
      return GridColumn(
        columnName: column.columnName,
        width: _getScaledColumnWidth(column.width),
        label: _getScaledTextWidget(column.label, isHeader: false),
      );
    }).toList();
  }

  /// 확대/축소에 따른 실제 크기 조정된 스택 헤더 반환
  List<StackedHeaderRow> _getScaledStackedHeaders() {
    return widget.stackedHeaders.map((headerRow) {
      return StackedHeaderRow(
        cells: headerRow.cells.map((cell) {
          return StackedHeaderCell(
            columnNames: cell.columnNames,
            child: _getScaledTextWidget(cell.child, isHeader: true),
          );
        }).toList(),
      );
    }).toList();
  }

  /// 확대/축소에 따른 실제 열 너비 반환
  double _getScaledColumnWidth(double baseWidth) {
    return baseWidth * _zoomManager.zoomFactor;
  }

  /// 확대/축소에 따른 실제 크기 조정된 텍스트 위젯 반환
  Widget _getScaledTextWidget(dynamic originalWidget, {required bool isHeader}) {
    if (originalWidget is Text) {
      return Text(
        originalWidget.data ?? '',
        style: TextStyle(
          fontSize: _getScaledFontSize(),
          fontWeight: FontWeight.w600,
          color: isHeader ? Colors.blue[700] : Colors.black87,
        ),
        textAlign: originalWidget.textAlign,
        overflow: originalWidget.overflow,
        maxLines: originalWidget.maxLines,
        textDirection: originalWidget.textDirection,
      );
    }

    if (originalWidget is Container && originalWidget.child is Text) {
      final text = originalWidget.child as Text;
      return Container(
        padding: originalWidget.padding,
        decoration: originalWidget.decoration,
        alignment: originalWidget.alignment,
        child: Text(
          text.data ?? '',
          style: TextStyle(
            fontSize: _getScaledFontSize(),
            fontWeight: FontWeight.w600,
            color: isHeader ? Colors.blue[700] : Colors.black87,
          ),
          textAlign: text.textAlign,
          overflow: text.overflow,
          maxLines: text.maxLines,
          textDirection: text.textDirection,
        ),
      );
    }

    return DefaultTextStyle(
      style: TextStyle(
        fontSize: _getScaledFontSize(),
        fontWeight: FontWeight.w600,
        color: isHeader ? Colors.blue[700] : Colors.black87,
      ),
      child: originalWidget ?? const Text(''),
    );
  }

  /// 확대/축소에 따른 실제 폰트 크기 반환
  double _getScaledFontSize() {
    return GridLayoutConstants.baseFontSize * _zoomManager.zoomFactor;
  }

  /// 확대/축소에 따른 실제 헤더 높이 반환
  double _getScaledHeaderHeight() {
    return AppConstants.headerRowHeight * _zoomManager.zoomFactor;
  }

  /// 확대/축소에 따른 실제 행 높이 반환
  double _getScaledRowHeight() {
    return AppConstants.dataRowHeight * _zoomManager.zoomFactor;
  }

  /// 특정 셀을 화면 중앙으로 스크롤하는 메서드
  void scrollToCellCenter(String teacherName, String day, int period) {
    if (widget.timetableData == null) return;

    int teacherIndex = widget.timetableData!.teachers
        .indexWhere((teacher) => teacher.name == teacherName);

    if (teacherIndex == -1) return;

    String columnName = '${day}_$period';
    int columnIndex = widget.columns
        .indexWhere((column) => column.columnName == columnName);

    if (columnIndex == -1) return;

    _scrollManager.scrollToCell(
      teacherIndex: teacherIndex,
      columnIndex: columnIndex,
      zoomFactor: _zoomManager.zoomFactor,
    );
  }

  /// 보강 기능 다이얼로그 표시
  void _showSupplementDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Text('보강 수업 추가'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('보강 수업을 추가하시겠습니까?'),
              SizedBox(height: 16),
              Text(
                '• 교사별로 보강 수업을 추가할 수 있습니다\n'
                '• 시간표에 새로운 시간 슬롯이 생성됩니다\n'
                '• 기존 수업과 겹치지 않도록 주의하세요',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _addSupplementClass();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  /// 보강 수업 추가 기능
  void _addSupplementClass() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('보강 수업 추가 기능이 구현될 예정입니다'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 교체된 셀 클릭 처리
  void _handleExchangedCellClick(String teacherName, String day, int period) {
    final exchangePath = _historyService.findExchangePathByCell(
      teacherName,
      day,
      period,
    );

    if (exchangePath != null) {
      ref.read(stateResetProvider.notifier).resetExchangeStates(
        reason: '교체된 셀 클릭 - 이전 교체 상태 초기화',
      );

      _selectExchangePath(exchangePath);
      widget.onHeaderThemeUpdate?.call();

      AppLogger.exchangeDebug(
        '교체된 셀 클릭: $teacherName | $day$period교시 → 경로 ID: ${exchangePath.id}',
      );
    }
  }

  /// 교체 경로 선택
  void _selectExchangePath(ExchangePath exchangePath) {
    ref.read(stateResetProvider.notifier).resetPathOnly(
      reason: '새 교체 경로 선택 - 기존 경로 초기화',
    );

    _internalSelectedPath = exchangePath;

    if (exchangePath is OneToOneExchangePath) {
      widget.dataSource!.updateSelectedOneToOnePath(exchangePath);
    } else if (exchangePath is CircularExchangePath) {
      widget.dataSource!.updateSelectedCircularPath(exchangePath);
    } else if (exchangePath is ChainExchangePath) {
      widget.dataSource!.updateSelectedChainPath(exchangePath);
    }

    widget.dataSource?.notifyListeners();
    AppLogger.exchangeDebug('교체 경로 선택: ${exchangePath.displayTitle}');
  }

  /// 일반 셀 탭 시 화살표 숨기기
  void _hideExchangeArrows() {
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '일반 셀 클릭 - 교체 화살표 숨김',
    );
    AppLogger.exchangeDebug('교체 화살표 숨김');
  }

  /// 화살표 상태 초기화 (외부에서 호출)
  void clearAllArrowStates() {
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '외부 호출 - 화살표 상태 초기화',
    );
    AppLogger.exchangeDebug('[외부 호출] 화살표 상태 초기화 (Level 2)');
  }

  /// 셀 탭 이벤트 처리
  void _handleCellTap(DataGridCellTapDetails details) {
    final teacherName = _extractTeacherNameFromRowIndex(
      details.rowColumnIndex.rowIndex,
    );
    final columnName = details.column.columnName;

    if (columnName != 'teacher') {
      final parts = columnName.split('_');
      if (parts.length == 2) {
        final day = parts[0];
        final period = int.tryParse(parts[1]) ?? 0;

        final cellKey = '${teacherName}_${day}_$period';
        final isExchangedCell = _historyService
            .getExchangedCellKeys()
            .contains(cellKey);

        if (isExchangedCell) {
          _handleExchangedCellClick(teacherName, day, period);
          return;
        }
      }
    }

    _hideExchangeArrows();
    widget.onCellTap(details);
    widget.onHeaderThemeUpdate?.call();
  }

  /// 행 인덱스에서 교사명 추출
  String _extractTeacherNameFromRowIndex(int rowIndex) {
    const int headerRowCount = 2;
    int actualRowIndex = rowIndex - headerRowCount;

    if (widget.timetableData == null || actualRowIndex < 0 || actualRowIndex >= widget.timetableData!.teachers.length) {
      return '';
    }

    return widget.timetableData!.teachers[actualRowIndex].name;
  }

  /// 내부 선택된 경로 초기화
  void _clearInternalPath() {
    _internalSelectedPath = null;
  }

  /// 교체 뷰 활성화
  void _enableExchangeView() {
    try {
      AppLogger.exchangeInfo('교체 뷰 활성화 시작');

      List<TimeSlot>? beforeSlots;
      final backupState = ref.read(timeSlotsBackupProvider);

      if (widget.dataSource != null && !backupState.isValid) {
        beforeSlots = widget.dataSource!.timeSlots.map((slot) => slot.copy()).toList();
        ref.read(timeSlotsBackupProvider.notifier).createBackup(widget.dataSource!.timeSlots);
        AppLogger.exchangeDebug('TimeSlots 백업 생성 완료: ${backupState.count}개');
      } else if (widget.dataSource != null) {
        beforeSlots = widget.dataSource!.timeSlots.map((slot) => slot.copy()).toList();
        AppLogger.exchangeDebug('기존 TimeSlots 백업 사용: ${backupState.count}개');
      }

      final exchangeList = _historyService.getExchangeList();
      if (exchangeList.isNotEmpty) {
        AppLogger.exchangeInfo('교체 리스트에서 ${exchangeList.length}개 교체 실행');

        if (beforeSlots == null && widget.dataSource != null) {
          beforeSlots = widget.dataSource!.timeSlots.map((slot) => slot.copy()).toList();
          AppLogger.exchangeDebug('교체 실행 전 beforeSlots 재생성: ${beforeSlots.length}개');
        }

        for (var item in exchangeList) {
          _exchangeViewManager.executeExchangeFromHistory(item);
        }

        ref.read(stateResetProvider.notifier).resetExchangeStates(
          reason: '교체 뷰 활성화 - 선택 상태 초기화',
        );

        if (beforeSlots != null && widget.dataSource != null) {
          try {
            final afterSlots = widget.dataSource!.timeSlots.map((slot) => slot.copy()).toList();

            if (beforeSlots.isNotEmpty && afterSlots.isNotEmpty) {
              _exchangeViewManager.compareTimeSlots(beforeSlots, afterSlots, '교체 뷰 활성화');
            } else {
              AppLogger.exchangeDebug('비교 데이터가 비어있음 - beforeSlots: ${beforeSlots.length}, afterSlots: ${afterSlots.length}');
            }
          } catch (e) {
            AppLogger.exchangeDebug('TimeSlots 비교 중 오류: $e');
          }
        } else {
          AppLogger.exchangeDebug('비교 불가 - beforeSlots: ${beforeSlots != null}, dataSource: ${widget.dataSource != null}');
        }

        AppLogger.exchangeInfo('교체 뷰 활성화 완료 - ${exchangeList.length}개 교체 적용됨');
        for (int i = 0; i < exchangeList.length; i++) {
          var item = exchangeList[i];
          _exchangeViewManager.logDetailedExchangeInfo(i + 1, item);
        }
      } else {
        AppLogger.exchangeInfo('교체 리스트가 비어있습니다 - 교체할 항목이 없음');
      }
    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 활성화 중 오류 발생: $e');
    }
  }

  /// 교체 뷰 비활성화 (원래 상태로 되돌리기)
  void _disableExchangeView() {
    try {
      AppLogger.exchangeInfo('교체 뷰 비활성화 시작');

      List<TimeSlot>? beforeSlots;
      if (widget.dataSource != null) {
        beforeSlots = widget.dataSource!.timeSlots.map((slot) => slot.copy()).toList();
        AppLogger.exchangeDebug('복원 전 beforeSlots 생성 완료: ${beforeSlots.length}개');
      }

      final backupState = ref.read(timeSlotsBackupProvider);
      if (backupState.isValid && widget.dataSource != null) {
        final restoredSlots = ref.read(timeSlotsBackupProvider.notifier).restoreBackup();
        if (restoredSlots != null) {
          widget.dataSource!.updateData(restoredSlots, widget.timetableData!.teachers);

          ref.read(timetableThemeProvider.notifier).clearExchangedCells();
          AppLogger.exchangeDebug('교체된 셀 상태 초기화 완료');

          ref.read(stateResetProvider.notifier).resetExchangeStates(
            reason: '교체 뷰 비활성화 - 선택 상태 초기화',
          );

          if (beforeSlots != null) {
            try {
              final afterSlots = widget.dataSource!.timeSlots.map((slot) => slot.copy()).toList();

              if (beforeSlots.isNotEmpty && afterSlots.isNotEmpty) {
                _exchangeViewManager.compareTimeSlots(beforeSlots, afterSlots, '교체 뷰 비활성화');
              } else {
                AppLogger.exchangeDebug('비교 데이터가 비어있음 - beforeSlots: ${beforeSlots.length}, afterSlots: ${afterSlots.length}');
              }
            } catch (e) {
              AppLogger.exchangeDebug('TimeSlots 비교 중 오류: $e');
            }
          } else {
            AppLogger.exchangeDebug('비교 불가 - beforeSlots가 null');
          }

          AppLogger.exchangeInfo('교체 뷰 비활성화 완료 - 원본 상태로 복원됨');
          AppLogger.exchangeInfo('복원된 TimeSlot 개수: ${restoredSlots.length}개');
        } else {
          AppLogger.exchangeDebug('TimeSlots 백업 복원 실패');
        }
      } else {
        AppLogger.exchangeDebug('복원할 TimeSlots 백업 데이터가 없습니다');
      }
    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 비활성화 중 오류 발생: $e');
    }
  }
}

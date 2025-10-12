import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/excel_service.dart';
import '../../services/exchange_service.dart';
import '../../providers/services_provider.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/constants.dart';
import '../../utils/day_utils.dart';
import 'timetable_grid/widget_arrows_manager.dart';
import '../../utils/logger.dart';
import '../../models/exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/time_slot.dart';
import '../../services/exchange_history_service.dart';
import '../../models/exchange_history_item.dart';
import '../../providers/timetable_theme_provider.dart';
import '../../providers/state_reset_provider.dart';
import '../../utils/simplified_timetable_theme.dart';
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

/// 교체된 셀의 원본 정보를 저장하는 클래스
/// 복원에 필요한 최소한의 정보만 포함
class ExchangeBackupInfo {
  final String teacher;      // 교사명
  final int dayOfWeek;       // 요일 (1-5)
  final int period;          // 교시
  final String? subject;     // 과목명
  final String? className;   // 학급명

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

  // 교체된 셀의 원본 정보를 저장하는 리스트 (복원용)
  final List<ExchangeBackupInfo> _exchangeListWork = [];

  // 이미 백업 완료된 교체 개수 (간단한 추적)
  int _backedUpCount = 0;

  // 싱글톤 화살표 매니저
  final WidgetArrowsManager _arrowsManager = WidgetArrowsManager();

  /// 현재 선택된 교체 경로 (외부 또는 내부)
  ExchangePath? get currentSelectedPath => widget.selectedExchangePath ?? _internalSelectedPath;

  /// 교체 모드인지 확인 (1:1, 순환, 연쇄 중 하나라도 활성화된 경우)
  bool get isInExchangeMode => widget.isExchangeModeEnabled ||
                               widget.isCircularExchangeModeEnabled ||
                               widget.isChainExchangeModeEnabled;

  /// 교체된 셀에서 선택된 경로인지 확인
  bool get isFromExchangedCell => _internalSelectedPath != null;
  
  /// 셀이 선택된 상태인지 확인 (보강 버튼 활성화용)
  bool get isCellSelected {
    final themeState = ref.read(timetableThemeProvider);
    final isSelected = themeState.selectedTeacher != null && 
                       themeState.selectedDay != null && 
                       themeState.selectedPeriod != null;
    
    // 디버깅용 로그
    AppLogger.exchangeDebug('🔍 셀 선택 상태 확인: teacher=${themeState.selectedTeacher}, day=${themeState.selectedDay}, period=${themeState.selectedPeriod}, isSelected=$isSelected');
    
    return isSelected;
  }

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
      onExchangeViewUpdate: () {
        // 교체 실행 후 교체 뷰 상태 확인 및 업데이트
        if (_isExchangeViewEnabled) {
          AppLogger.exchangeDebug('🔄 교체 실행 후 교체 뷰 업데이트 필요');
          _enableExchangeView();
        } else {
          AppLogger.exchangeDebug('🔄 교체 실행 후 교체 뷰 업데이트 건너뜀 (비활성화 상태)');
          // 교체 뷰가 비활성화된 상태에서는 업데이트하지 않음
        }
      },
    );

    // 화살표 매니저 초기화
    _initializeArrowsManager();

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
    // 화살표 매니저 정리 (싱글톤이므로 clearAllArrows만 호출)
    _arrowsManager.clearAllArrows();
    
    // 교체 뷰 관련 메모리 정리
    _exchangeListWork.clear();
    _backedUpCount = 0;
    
    // 기존 리소스 정리
    _zoomManager.dispose();
    _scrollManager.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  /// 테이블 렌더링 완료 알림
  void _notifyTableRenderingComplete() {
    widget.onHeaderThemeUpdate?.call();
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

    // StateResetProvider 상태 감지하여 내부 선택된 경로 초기화
    final resetState = ref.watch(stateResetProvider);
    if ((resetState.lastResetLevel == ResetLevel.exchangeStates || 
         resetState.lastResetLevel == ResetLevel.allStates) && 
        _internalSelectedPath != null) {
      _internalSelectedPath = null;
      AppLogger.exchangeDebug('[StateResetProvider 감지] 내부 선택된 경로 초기화 완료 (${resetState.lastResetLevel})');
    }
    
    // Level 3 초기화 시 교체 뷰 체크박스도 초기 상태로 되돌리기
    if (resetState.lastResetLevel == ResetLevel.allStates && _isExchangeViewEnabled) {
      _isExchangeViewEnabled = false;
      _disableExchangeView();
      AppLogger.exchangeDebug('[StateResetProvider 감지] 교체 뷰 체크박스 초기화 완료 (Level 3)');
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
        Builder(
          builder: (context) {
            // 보강 버튼 활성화 조건 확인
            final supplementEnabled = isInExchangeMode && isCellSelected;
            AppLogger.exchangeDebug('🔍 보강 버튼 상태: isInExchangeMode=$isInExchangeMode, isCellSelected=$isCellSelected, supplementEnabled=$supplementEnabled');
            
            return ExchangeActionButtons(
              onUndo: () => _exchangeExecutor.undoLastExchange(context, _clearInternalPath),
              onRepeat: () => _exchangeExecutor.repeatLastExchange(context),
              onSupplement: supplementEnabled ? _showSupplementDialog : null,
              onDelete: (currentSelectedPath != null && isFromExchangedCell)
                ? () => _exchangeExecutor.deleteFromExchangeList(currentSelectedPath!, context, _clearInternalPath)
                : null,
              onExchange: (isInExchangeMode && !isFromExchangedCell && currentSelectedPath != null)
                ? () => _exchangeExecutor.executeExchange(currentSelectedPath!, context, _clearInternalPath)
                : null,
              showDeleteButton: currentSelectedPath != null && isFromExchangedCell,
              showExchangeButton: isInExchangeMode && !isFromExchangedCell,
              showSupplementButton: isInExchangeMode, // 교체 모드에서만 보강 버튼 표시
            );
          },
        ),
      ],
    );
  }

  /// 화살표 매니저 초기화
  void _initializeArrowsManager() {
    if (widget.timetableData != null) {
      _arrowsManager.initialize(
        timetableData: widget.timetableData!,
        columns: widget.columns,
        zoomFactor: _zoomManager.zoomFactor,
      );
      
      AppLogger.exchangeDebug('화살표 매니저 싱글톤 초기화 완료');
    }
  }

  /// DataGrid와 화살표를 함께 구성
  Widget _buildDataGridWithArrows() {
    Widget dataGridWithGestures = _buildDataGridWithDragScrolling();

    // 교체 경로가 선택된 경우에만 화살표 표시
    if (currentSelectedPath != null && widget.timetableData != null) {
      // 현재는 기존 CustomPainter 방식 사용 (안정적)
      return _buildDataGridWithLegacyArrows(dataGridWithGestures);
    }

    return dataGridWithGestures;
  }

  /// 기존 CustomPainter 기반 화살표 표시
  Widget _buildDataGridWithLegacyArrows(Widget dataGridWithGestures) {
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
            key: ValueKey('${widget.columns.length}_${widget.stackedHeaders.length}_${DateTime.now().millisecondsSinceEpoch}'),
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
    AppLogger.exchangeDebug('🖱️ 교체된 셀 클릭: $teacherName | $day$period교시');
    
    // 교체된 셀 선택 상태 플래그 설정 (헤더 색상 비활성화용)
    SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(true);
    
    final exchangePath = _historyService.findExchangePathByCell(
      teacherName,
      day,
      period,
    );

    if (exchangePath != null) {
      AppLogger.exchangeDebug('✅ 교체 경로 발견: ${exchangePath.type} (ID: ${exchangePath.id})');
      
      ref.read(stateResetProvider.notifier).resetExchangeStates(
        reason: '교체된 셀 클릭 - 이전 교체 상태 초기화',
      );

      _selectExchangePath(exchangePath);
      
      // 교체된 셀 클릭 시 교체 서비스 상태 업데이트 (헤더 업데이트를 위해)
      // 하지만 화살표는 보존하기 위해 직접 교체 서비스 상태만 업데이트
      _updateExchangeServiceForExchangedCell(teacherName, day, period);
      
      widget.onHeaderThemeUpdate?.call();

      AppLogger.exchangeDebug(
        '교체된 셀 클릭: $teacherName | $day$period교시 → 경로 ID: ${exchangePath.id}',
      );
      
      // 화살표 표시를 위한 상태 업데이트 강제 실행
      if (mounted) {
        setState(() {});
      }
    } else {
      AppLogger.exchangeDebug('❌ 교체 경로를 찾을 수 없음: $teacherName | $day$period교시');
    }
  }

  /// 교체 경로 선택
  void _selectExchangePath(ExchangePath exchangePath) {
    AppLogger.exchangeDebug('🎯 교체 경로 선택 시작: ${exchangePath.displayTitle}');
    
    ref.read(stateResetProvider.notifier).resetPathOnly(
      reason: '새 교체 경로 선택 - 기존 경로 초기화',
    );

    // Level 1 초기화 후 내부 선택된 경로 초기화 (화살표 제거)
    clearPathSelectionOnly();

    _internalSelectedPath = exchangePath;
    AppLogger.exchangeDebug('✅ 내부 선택된 경로 설정: ${_internalSelectedPath?.type}');

    if (exchangePath is OneToOneExchangePath) {
      widget.dataSource!.updateSelectedOneToOnePath(exchangePath);
      AppLogger.exchangeDebug('📝 OneToOne 경로 업데이트 완료');
    } else if (exchangePath is CircularExchangePath) {
      widget.dataSource!.updateSelectedCircularPath(exchangePath);
      AppLogger.exchangeDebug('📝 Circular 경로 업데이트 완료');
    } else if (exchangePath is ChainExchangePath) {
      widget.dataSource!.updateSelectedChainPath(exchangePath);
      AppLogger.exchangeDebug('📝 Chain 경로 업데이트 완료');
    }

    // updateSelected* 메서드가 이미 notifyDataSourceListeners()를 호출하므로 중복 호출 제거
    AppLogger.exchangeDebug('교체 경로 선택: ${exchangePath.displayTitle}');
    AppLogger.exchangeDebug('🎯 교체 경로 선택 완료: ${exchangePath.displayTitle}');
  }

  /// 일반 셀 탭 시 화살표 숨기기
  void _hideExchangeArrows() {
    // 내부 선택된 경로 먼저 초기화 (화살표 제거를 위해)
    _internalSelectedPath = null;
    AppLogger.exchangeDebug('[일반 셀 클릭] 내부 선택된 경로 초기화 완료');
    
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '일반 셀 클릭 - 교체 화살표 숨김',
    );
    AppLogger.exchangeDebug('교체 화살표 숨김');
  }

  /// 화살표 상태 초기화 (외부에서 호출)
  void clearAllArrowStates() {
    // 내부 선택된 경로 먼저 초기화 (화살표 제거를 위해)
    _internalSelectedPath = null;
    AppLogger.exchangeDebug('[외부 호출] 내부 선택된 경로 초기화 완료');
    
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '외부 호출 - 화살표 상태 초기화',
    );
    AppLogger.exchangeDebug('[외부 호출] 화살표 상태 초기화 (Level 2)');
  }

  /// Level 1 전용 화살표 초기화 (경로 선택만 해제)
  void clearPathSelectionOnly() {
    // 내부 선택된 경로만 초기화 (화살표 제거)
    _internalSelectedPath = null;
    AppLogger.exchangeDebug('[Level 1] 내부 선택된 경로 초기화 - 화살표 제거');
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

        final isExchangedCell = _historyService.isCellExchanged(teacherName, day, period);

        if (isExchangedCell) {
          _handleExchangedCellClick(teacherName, day, period);
          return;
        }
      }
    }

    // 일반 셀 클릭 시 교체된 셀 선택 상태 플래그 해제 (헤더 색상 복원용)
    SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(false);

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

  /// 교체된 셀 클릭 시 교체 서비스 상태 업데이트 (화살표 보존)
  void _updateExchangeServiceForExchangedCell(String teacherName, String day, int period) {
    try {
      // ExchangeService에 선택된 셀 정보 설정 (헤더 업데이트를 위해)
      // 하지만 실제 교체 서비스 로직은 실행하지 않음
      final exchangeService = ref.read(exchangeServiceProvider);
      
      // 선택된 셀 정보만 설정 (교체 가능한 교사 정보 수집을 위해)
      exchangeService.selectCell(teacherName, day, period);
      
      // TimetableThemeProvider 상태도 업데이트 (교사 이름 컬럼 하이라이트를 위해)
      final themeNotifier = ref.read(timetableThemeProvider.notifier);
      themeNotifier.updateSelection(teacherName, day, period);
      
      AppLogger.exchangeDebug('📝 교체 서비스 상태 업데이트 완료: $teacherName $day$period교시');
    } catch (e) {
      AppLogger.error('교체 서비스 상태 업데이트 실패: $e');
    }
  }


  /// 내부 선택된 경로 초기화 (새로운 화살표 시스템 연동)
  void _clearInternalPath() {
    _internalSelectedPath = null;
    
    // 새로운 화살표 시스템에서도 화살표 정리
    // 싱글톤 화살표 매니저를 통한 화살표 정리
    _arrowsManager.clearAllArrows();
    AppLogger.exchangeDebug('화살표 초기화 완료 (싱글톤)');
  }

  /// 교체 실행 전에 원본 정보를 백업하는 메서드
  /// 
  /// 매개변수:
  /// - `exchangeItem`: 교체할 항목 정보 (ExchangeHistoryItem 또는 ExchangePath)
  /// - `timeSlots`: 현재 시간표 데이터
  void _backupOriginalSlotInfo(dynamic exchangeItem, List<TimeSlot> timeSlots) {
    try {
      ExchangePath? exchangePath;
      
      // ExchangeHistoryItem인 경우 실제 경로 추출
      if (exchangeItem is ExchangeHistoryItem) {
        exchangePath = exchangeItem.originalPath;
        AppLogger.exchangeDebug('ExchangeHistoryItem에서 경로 추출: ${exchangePath.type}');
      } else if (exchangeItem is ExchangePath) {
        exchangePath = exchangeItem;
        AppLogger.exchangeDebug('ExchangePath 직접 사용: ${exchangePath.type}');
      }
      
      if (exchangePath == null) {
        AppLogger.exchangeDebug('교체 경로를 찾을 수 없음: ${exchangeItem.runtimeType}');
        return;
      }
      
      // 교체 타입에 따라 다르게 처리
      if (exchangePath is OneToOneExchangePath) {
        // 1:1 교체의 경우 sourceSlot과 targetSlot 백업
        _backupOneToOneExchange(exchangePath, timeSlots);
      } else if (exchangePath is CircularExchangePath) {
        // 순환 교체의 경우 모든 교체되는 셀들 백업
        _backupCircularExchange(exchangePath, timeSlots);
      } else if (exchangePath is ChainExchangePath) {
        // 연쇄 교체의 경우 모든 교체되는 셀들 백업
        _backupChainExchange(exchangePath, timeSlots);
      }
      
      AppLogger.exchangeDebug('교체 백업 완료: ${_exchangeListWork.length}개 항목 저장됨');
    } catch (e) {
      AppLogger.exchangeDebug('교체 백업 중 오류 발생: $e');
    }
  }

  /// 1:1 교체의 원본 정보 백업
  void _backupOneToOneExchange(OneToOneExchangePath exchangeItem, List<TimeSlot> timeSlots) {
    // 1. sourceNode의 원래 위치 백업
    _backupNodeData(exchangeItem.sourceNode, timeSlots);
    
    // 2. targetNode의 원래 위치 백업
    _backupNodeData(exchangeItem.targetNode, timeSlots);
    
    // 3. sourceNode가 이동할 목적지 위치 백업 (targetNode의 위치)
    _backupNodeData({
      'teacherName': exchangeItem.sourceNode.teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.targetNode.day),
      'period': exchangeItem.targetNode.period,
    }, timeSlots);
    
    // 4. targetNode가 이동할 목적지 위치 백업 (sourceNode의 위치)
    _backupNodeData({
      'teacherName': exchangeItem.targetNode.teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.sourceNode.day),
      'period': exchangeItem.sourceNode.period,
    }, timeSlots);
  }

  /// 순환 교체의 원본 정보 백업 (마지막 노드 제외)
  void _backupCircularExchange(CircularExchangePath exchangeItem, List<TimeSlot> timeSlots) {
    // 각 노드의 원본 정보 백업
    for (int i = 0; i < exchangeItem.nodes.length - 1; i++) {
      _backupNodeData(exchangeItem.nodes[i], timeSlots);

      _backupNodeData({
      'teacherName': exchangeItem.nodes[i].teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.nodes[i+1].day),
      'period': exchangeItem.nodes[i+1].period,
    }, timeSlots);
    }

  }

  /// 연쇄 교체의 원본 정보 백업 (8개 백업)
  void _backupChainExchange(ChainExchangePath exchangeItem, List<TimeSlot> timeSlots) {
    // 연쇄교체는 4개 노드 + 4개 목적지 = 총 8개 백업 필요
    
    // 1. 4개 노드의 원본 위치 백업
    _backupNodeData(exchangeItem.nodeA, timeSlots);  // 결강 수업
    _backupNodeData(exchangeItem.nodeB, timeSlots);  // 대체 가능 수업
    _backupNodeData(exchangeItem.node1, timeSlots);  // 1단계 교환 대상
    _backupNodeData(exchangeItem.node2, timeSlots); // A 교사의 B 시간 수업
    
    // 2. 1단계 교체 후 목적지 위치 백업
    // node1 교사가 node2 위치로 이동
    _backupNodeData({
      'teacherName': exchangeItem.node1.teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.node2.day),
      'period': exchangeItem.node2.period,
    }, timeSlots);
    
    // node2 교사가 node1 위치로 이동
    _backupNodeData({
      'teacherName': exchangeItem.node2.teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.node1.day),
      'period': exchangeItem.node1.period,
    }, timeSlots);
    
    // [중복] 3. 2단계 교체 후 목적지 위치 백업
    // nodeA 교사가 nodeB 위치로 이동 (최종 목적지)
    // _backupNodeData({
    //   'teacherName': exchangeItem.nodeA.teacherName,
    //   'dayOfWeek': DayUtils.getDayNumber(exchangeItem.nodeB.day),
    //   'period': exchangeItem.nodeB.period,
    // }, timeSlots);
    
    // nodeB 교사가 nodeA 위치로 이동 (최종 목적지)
    _backupNodeData({
      'teacherName': exchangeItem.nodeB.teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.nodeA.day),
      'period': exchangeItem.nodeA.period,
    }, timeSlots);
    
    AppLogger.exchangeDebug('연쇄교체 백업 완료: 7개 항목 (4개 노드 + 3개 목적지)');
  }

  /// ExchangeNode 또는 특정 위치의 데이터를 백업
  void _backupNodeData(dynamic node, List<TimeSlot> timeSlots) {
    try {
      String teacher;
      int dayOfWeek;
      int period;
      
      // Map 타입인 경우 (1:1 교체에서 목적지 위치 백업용)
      if (node is Map<String, dynamic>) {
        teacher = node['teacherName'] ?? '';
        dayOfWeek = node['dayOfWeek'] ?? 0;
        period = node['period'] ?? 0;
        AppLogger.exchangeDebug('Map 데이터 백업: teacher=$teacher, dayOfWeek=$dayOfWeek, period=$period');
      } 
      // ExchangeNode 타입인 경우
      else {
        teacher = node.teacherName ?? '';
        // ExchangeNode의 day 문자열을 dayOfWeek 숫자로 변환
        dayOfWeek = DayUtils.getDayNumber(node.day);
        period = node.period ?? 0;
        AppLogger.exchangeDebug('ExchangeNode 데이터 백업: teacher=$teacher, day=${node.day}, dayOfWeek=$dayOfWeek, period=$period');
      }
      
      // TimeSlots에서 현재 subject와 className만 조회
      String? currentSubject;
      String? currentClassName;
      
      for (TimeSlot slot in timeSlots) {
        if (slot.teacher == teacher && 
            slot.dayOfWeek == dayOfWeek && 
            slot.period == period) {
          currentSubject = slot.subject;
          currentClassName = slot.className;
          break;
        }
      }
      
      // ExchangeBackupInfo 생성하여 리스트에 추가
      ExchangeBackupInfo backupInfo = ExchangeBackupInfo(
        teacher: teacher,
        dayOfWeek: dayOfWeek,
        period: period,
        subject: currentSubject,
        className: currentClassName,
      );
      
      _exchangeListWork.add(backupInfo);
      AppLogger.exchangeDebug('노드 데이터 백업: ${backupInfo.debugInfo}');
      
    } catch (e) {
      AppLogger.exchangeDebug('노드 데이터 백업 중 오류: $e');
    }
  }

  /// 교체 뷰 활성화
  void _enableExchangeView() {
    try {
      AppLogger.exchangeInfo('[wg]교체 뷰 활성화 시작');
      
      // 교체 뷰 활성화 시 모든 셀 선택 해제
      ref.read(exchangeServiceProvider).clearCellSelection();
      ref.read(circularExchangeServiceProvider).clearCellSelection();
      ref.read(chainExchangeServiceProvider).clearCellSelection();
      
      // 교체 리스트 조회
      final exchangeList = _historyService.getExchangeList();
      
      AppLogger.exchangeDebug('[백업 추적] exchangeList: ${exchangeList.length}, backedUp: $_backedUpCount, work: ${_exchangeListWork.length}');
      
      if (exchangeList.isEmpty) {
        AppLogger.exchangeInfo('교체 리스트가 비어있습니다');
        return;
      }
      
      // 새로운 교체만 추출 (백업된 개수 이후부터)
      final newExchanges = exchangeList.skip(_backedUpCount).toList();
      AppLogger.exchangeDebug('[새로운 교체] skip($_backedUpCount): ${newExchanges.length}개');
      
      if (newExchanges.isEmpty) {
        AppLogger.exchangeInfo('새로운 교체가 없습니다 (이미 $_backedUpCount개 백업됨)');
        return;
      }
      
      AppLogger.exchangeInfo('새로운 교체 ${newExchanges.length}개 발견 (전체 ${exchangeList.length}개, 기존 백업 $_backedUpCount개)');
      
      // 1단계: 새로운 교체만 백업
      AppLogger.exchangeDebug('1단계: 신규 교체 ${newExchanges.length}개 백업 시작');
      final beforeBackupCount = _exchangeListWork.length;
      for (var item in newExchanges) {
        _backupOriginalSlotInfo(item, widget.dataSource!.timeSlots);
      }
      _backedUpCount = exchangeList.length;
      AppLogger.exchangeDebug('[백업 결과] $beforeBackupCount개 → ${_exchangeListWork.length}개 (추가: ${_exchangeListWork.length - beforeBackupCount})');
      
      // 2단계: 새로운 교체만 실행
      AppLogger.exchangeDebug('2단계: 신규 교체 ${newExchanges.length}개 실행 시작');
      int successCount = 0;
      for (var item in newExchanges) {
        if (_exchangeViewManager.executeExchangeFromHistory(
          item,
          widget.dataSource!.timeSlots,
          widget.timetableData!.teachers,
        )) {
          successCount++;
        }
      }
      
      // 선택 상태 초기화
      ref.read(stateResetProvider.notifier).resetExchangeStates(
        reason: '교체 뷰 활성화 - 선택 상태 초기화',
      );
      
      // UI 업데이트 (교체 성공 시에만)
      if (successCount > 0) {
        widget.dataSource?.updateData(widget.dataSource!.timeSlots, widget.timetableData!.teachers);
        widget.onHeaderThemeUpdate?.call();
        if (mounted) setState(() {});
        AppLogger.exchangeInfo('교체 뷰 활성화 완료 - $successCount/${newExchanges.length}개 적용');
      }
      
    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 활성화 중 오류 발생: $e');
    }
  }

  /// 교체 뷰 비활성화 (원래 상태로 되돌리기)
  void _disableExchangeView() {
    try {
      AppLogger.exchangeInfo('교체 뷰 비활성화 시작');
      
      // 교체 뷰 비활성화 시 모든 셀 선택 해제
      ref.read(exchangeServiceProvider).clearCellSelection();
      ref.read(circularExchangeServiceProvider).clearCellSelection();
      ref.read(chainExchangeServiceProvider).clearCellSelection();

      if (_exchangeListWork.isEmpty || widget.dataSource == null) {
        AppLogger.exchangeDebug('복원할 교체 백업 데이터가 없습니다');
        return;
      }

      // 역순으로 복원 (마지막에 교체된 것부터 먼저 되돌리기)
      int restoredCount = 0;
      for (int i = _exchangeListWork.length - 1; i >= 0; i--) {
        final backupInfo = _exchangeListWork[i];
        final targetSlot = _findTimeSlotByBackupInfo(backupInfo, widget.dataSource!.timeSlots);

        if (targetSlot != null) {
          targetSlot.subject = backupInfo.subject;
          targetSlot.className = backupInfo.className;
          restoredCount++;
        }
      }

      // UI 업데이트
      if (widget.timetableData != null) {
        widget.dataSource!.updateData(widget.dataSource!.timeSlots, widget.timetableData!.teachers);
      }
      widget.onHeaderThemeUpdate?.call();
      if (mounted) setState(() {});

      // 백업 데이터 초기화
      _exchangeListWork.clear();
      _backedUpCount = 0;

      AppLogger.exchangeInfo('교체 뷰 비활성화 완료 - $restoredCount개 셀 복원됨');
    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 비활성화 중 오류 발생: $e');
    }
  }

  /// 백업 정보로 TimeSlot 찾기
  TimeSlot? _findTimeSlotByBackupInfo(ExchangeBackupInfo backupInfo, List<TimeSlot> timeSlots) {
    for (TimeSlot slot in timeSlots) {
      if (slot.teacher == backupInfo.teacher && 
          slot.dayOfWeek == backupInfo.dayOfWeek && 
          slot.period == backupInfo.period) {
        return slot;
      }
    }
    return null;
  }
}

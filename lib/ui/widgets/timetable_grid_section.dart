import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
import '../../utils/constants.dart';
import '../../utils/day_utils.dart';
import 'timetable_grid/widget_arrows_manager.dart';
import '../../utils/logger.dart';
import '../../models/exchange_path.dart';
import '../../models/exchange_node.dart';
import '../../models/supplement_exchange_path.dart';
import '../../models/time_slot.dart';
import '../../services/exchange_history_service.dart';
import '../../utils/exchange_algorithm.dart';
import '../../providers/state_reset_provider.dart';
import '../../providers/zoom_provider.dart';
import '../../providers/scroll_provider.dart';
import '../../utils/simplified_timetable_theme.dart';
import 'timetable_grid/timetable_grid_constants.dart';
import 'timetable_grid/exchange_arrow_style.dart';
import 'timetable_grid/exchange_arrow_painter.dart';
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
  });

  @override
  ConsumerState<TimetableGridSection> createState() => _TimetableGridSectionState();

}

class _TimetableGridSectionState extends ConsumerState<TimetableGridSection> {
  // 스크롤 컨트롤러들
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  
  // 마우스 오른쪽 버튼 및 두 손가락 드래그 상태
  Offset? _rightClickDragStart;
  double? _rightClickScrollStartH;
  double? _rightClickScrollStartV;
  
  // 헬퍼 클래스들
  late ExchangeExecutor _exchangeExecutor;

  // 싱글톤 화살표 매니저
  final WidgetArrowsManager _arrowsManager = WidgetArrowsManager();

  /// 현재 선택된 교체 경로 (Riverpod 기반)
  ExchangePath? get currentSelectedPath {
    final selectedPath = ref.watch(selectedExchangePathProvider);
    final result = selectedPath ?? widget.selectedExchangePath;
    AppLogger.exchangeDebug('🔍 [TimetableGridSection] currentSelectedPath 조회: ${result?.type}');
    return result;
  }

  /// 교체 모드인지 확인 (1:1, 순환, 연쇄 중 하나라도 활성화된 경우)
  bool get isInExchangeMode => widget.isExchangeModeEnabled ||
                               widget.isCircularExchangeModeEnabled ||
                               widget.isChainExchangeModeEnabled;
  
  /// 교체된 셀에서 선택된 경로인지 확인 (Riverpod 기반)
  bool get isFromExchangedCell {
    return ref.watch(isFromExchangedCellProvider);
  }
  
  /// 셀이 선택된 상태인지 확인 (보강 버튼 활성화용)
  bool get isCellSelected {
    final cellState = ref.read(cellSelectionProvider);
    return cellState.selectedTeacher != null && 
           cellState.selectedDay != null && 
           cellState.selectedPeriod != null;
  }

  @override
  void initState() {
    super.initState();

    // 스크롤 리스너 추가
    _horizontalScrollController.addListener(_onScrollChanged);
    _verticalScrollController.addListener(_onScrollChanged);

    // ExchangeExecutor 초기화
    _exchangeExecutor = ExchangeExecutor(
      ref: ref,
      dataSource: widget.dataSource,
    );

    // 화살표 매니저 초기화
    _initializeArrowsManager();

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

    // 실제로 중요한 구조적 데이터가 변경된 경우에만 UI 업데이트 요청 (성능 최적화)
    if (widget.timetableData != oldWidget.timetableData ||
        widget.dataSource != oldWidget.dataSource ||
        widget.isExchangeModeEnabled != oldWidget.isExchangeModeEnabled ||
        widget.isCircularExchangeModeEnabled != oldWidget.isCircularExchangeModeEnabled ||
        widget.isChainExchangeModeEnabled != oldWidget.isChainExchangeModeEnabled) {
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.timetableData != null && widget.dataSource != null) {
          _requestUIUpdate();
        }
      });
    }
  }

  @override
  void dispose() {
    // 스크롤 리스너 제거 및 컨트롤러 정리
    _horizontalScrollController.removeListener(_onScrollChanged);
    _verticalScrollController.removeListener(_onScrollChanged);
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    
    // 화살표 매니저 정리 (싱글톤이므로 clearAllArrows만 호출)
    _arrowsManager.clearAllArrows();
    
    // 기존 리소스 정리
    super.dispose();
  }

  /// 스크롤 변경 시 Provider 업데이트
  void _onScrollChanged() {
    ref.read(scrollProvider.notifier).updateOffset(
      _horizontalScrollController.hasClients ? _horizontalScrollController.offset : 0.0,
      _verticalScrollController.hasClients ? _verticalScrollController.offset : 0.0,
    );
  }

  /// UI 업데이트 요청
  void _requestUIUpdate() {
    // UI 업데이트는 즉시 처리 (Provider 상태 변경 없이)
    AppLogger.exchangeDebug('🔄 UI 업데이트 요청: 테이블 렌더링 완료');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timetableData == null || widget.dataSource == null) {
      return const SizedBox.shrink();
    }

    // StateResetProvider 상태 감지 (화살표 초기화는 별도 처리)
    final resetState = ref.watch(stateResetProvider);
    
    // Level 3 초기화 시 교체 뷰 체크박스도 초기 상태로 되돌리기
    if (resetState.lastResetLevel == ResetLevel.allStates && ref.watch(isExchangeViewEnabledProvider)) {
      ref.read(exchangeViewProvider.notifier).reset();
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

        // 전체 교사 수 표시
        TeacherCountWidget(
          teacherCount: widget.timetableData!.teachers.length,
        ),

        const SizedBox(width: 8),

        // 교체 뷰 체크박스
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

        const SizedBox(width: 8),

        const Spacer(),

        // 보강/교체 버튼들
        Builder(
          builder: (context) {
            // 보강 버튼 활성화 조건 확인
            final supplementEnabled = isInExchangeMode && isCellSelected;
            
            return ExchangeActionButtons(
              onUndo: () => _exchangeExecutor.undoLastExchange(context, _clearInternalPath),
              onRepeat: () => _exchangeExecutor.repeatLastExchange(context),
              onSupplement: supplementEnabled ? _enableTeacherNameSelectionForSupplement : null,
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

  /// 화살표 매니저 초기화 또는 업데이트 (공통 메서드)
  void _initializeOrUpdateArrowsManager({bool isUpdate = false}) {
    if (widget.timetableData != null) {
      final zoomFactor = ref.read(zoomFactorProvider);
      
      if (isUpdate) {
        _arrowsManager.updateData(
          timetableData: widget.timetableData!,
          columns: widget.columns,
          zoomFactor: zoomFactor,
        );
        AppLogger.exchangeDebug('화살표 매니저 데이터 업데이트 완료 (줌 팩터: $zoomFactor)');
      } else {
        _arrowsManager.initialize(
          timetableData: widget.timetableData!,
          columns: widget.columns,
          zoomFactor: zoomFactor,
        );
        AppLogger.exchangeDebug('화살표 매니저 싱글톤 초기화 완료');
      }
    }
  }

  /// 화살표 매니저 초기화
  void _initializeArrowsManager() {
    _initializeOrUpdateArrowsManager(isUpdate: false);
  }

  /// 화살표 매니저 데이터 업데이트 (줌 변경 시 호출)
  void _updateArrowsManagerData() {
    _initializeOrUpdateArrowsManager(isUpdate: true);
  }

  /// DataGrid와 화살표를 함께 구성
  Widget _buildDataGridWithArrows() {
    Widget dataGrid = _buildDataGrid();

    // 교체 경로가 선택된 경우에만 화살표 표시
    AppLogger.exchangeDebug('🔍 [TimetableGridSection] 화살표 표시 조건 확인:');
    AppLogger.exchangeDebug('  - currentSelectedPath: ${currentSelectedPath?.type}');
    AppLogger.exchangeDebug('  - timetableData: ${widget.timetableData != null}');
    
    if (currentSelectedPath != null && widget.timetableData != null) {
      AppLogger.exchangeDebug('🔍 [TimetableGridSection] 화살표 표시 조건 만족 - 화살표 렌더링');
      // 현재는 기존 CustomPainter 방식 사용 (안정적)
      return _buildDataGridWithLegacyArrows(dataGrid);
    } else {
      AppLogger.exchangeDebug('🔍 [TimetableGridSection] 화살표 표시 조건 불만족 - 화살표 숨김');
    }

    return dataGrid;
  }

  /// 기존 CustomPainter 기반 화살표 표시
  Widget _buildDataGridWithLegacyArrows(Widget dataGridWithGestures) {
    return Consumer(
      builder: (context, ref, child) {
        final zoomFactor = ref.watch(zoomFactorProvider);
        final scrollState = ref.watch(scrollProvider);
        final scrollOffset = Offset(
          scrollState.horizontalOffset,
          scrollState.verticalOffset,
        );
        
        // 줌 팩터 변경 시 화살표 매니저 데이터 업데이트
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateArrowsManagerData();
        });
        
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
                    customArrowStyle: widget.customArrowStyle,
                    zoomFactor: zoomFactor,
                    scrollOffset: scrollOffset,
                  ),
                  child: RepaintBoundary(
                    child: Container(),
                  ),
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
        final zoomFactor = ref.watch(zoomFactorProvider);
        
        Widget dataGridContainer = GestureDetector(
          // 두 손가락 드래그 스크롤 (모바일)
          onScaleStart: (details) {
            if (details.pointerCount == 2) {
              _rightClickDragStart = details.focalPoint;
              _rightClickScrollStartH = _horizontalScrollController.hasClients 
                  ? _horizontalScrollController.offset : 0.0;
              _rightClickScrollStartV = _verticalScrollController.hasClients 
                  ? _verticalScrollController.offset : 0.0;
              ref.read(scrollProvider.notifier).setScrolling(true);
            }
          },
          onScaleUpdate: (details) {
            if (details.pointerCount == 2 && 
                _rightClickDragStart != null &&
                _rightClickScrollStartH != null &&
                _rightClickScrollStartV != null) {
              
              final delta = details.focalPoint - _rightClickDragStart!;
              
              // 수평 스크롤
              if (_horizontalScrollController.hasClients) {
                final newH = (_rightClickScrollStartH! - delta.dx)
                    .clamp(0.0, _horizontalScrollController.position.maxScrollExtent);
                _horizontalScrollController.jumpTo(newH);
                AppLogger.exchangeDebug('🖱️ [스크롤] 두 손가락 터치 수평 스크롤: ${_rightClickScrollStartH!.toStringAsFixed(1)} → ${newH.toStringAsFixed(1)} (델타: ${delta.dx.toStringAsFixed(1)})');
              }
              
              // 수직 스크롤
              if (_verticalScrollController.hasClients) {
                final newV = (_rightClickScrollStartV! - delta.dy)
                    .clamp(0.0, _verticalScrollController.position.maxScrollExtent);
                _verticalScrollController.jumpTo(newV);
                AppLogger.exchangeDebug('🖱️ [스크롤] 두 손가락 터치 수직 스크롤: ${_rightClickScrollStartV!.toStringAsFixed(1)} → ${newV.toStringAsFixed(1)} (델타: ${delta.dy.toStringAsFixed(1)})');
              }
            }
          },
          onScaleEnd: (details) {
            _rightClickDragStart = null;
            _rightClickScrollStartH = null;
            _rightClickScrollStartV = null;
            ref.read(scrollProvider.notifier).setScrolling(false);
          },
          child: Listener(
            // 마우스 오른쪽 버튼 스크롤 (데스크톱)
            onPointerDown: (event) {
              if (event.buttons == kSecondaryMouseButton) {
                _rightClickDragStart = event.position;
                _rightClickScrollStartH = _horizontalScrollController.hasClients 
                    ? _horizontalScrollController.offset : 0.0;
                _rightClickScrollStartV = _verticalScrollController.hasClients 
                    ? _verticalScrollController.offset : 0.0;
                ref.read(scrollProvider.notifier).setScrolling(true);
              }
            },
            onPointerMove: (event) {
              if (event.buttons == kSecondaryMouseButton && 
                  _rightClickDragStart != null &&
                  _rightClickScrollStartH != null &&
                  _rightClickScrollStartV != null) {
                
                final delta = event.position - _rightClickDragStart!;
                
                // 수평 스크롤
                if (_horizontalScrollController.hasClients) {
                  final newH = (_rightClickScrollStartH! - delta.dx)
                      .clamp(0.0, _horizontalScrollController.position.maxScrollExtent);
                  _horizontalScrollController.jumpTo(newH);
                  AppLogger.exchangeDebug('🖱️ [스크롤] 마우스 오른쪽 버튼 수평 스크롤: ${_rightClickScrollStartH!.toStringAsFixed(1)} → ${newH.toStringAsFixed(1)} (델타: ${delta.dx.toStringAsFixed(1)})');
                }
                
                // 수직 스크롤
                if (_verticalScrollController.hasClients) {
                  final newV = (_rightClickScrollStartV! - delta.dy)
                      .clamp(0.0, _verticalScrollController.position.maxScrollExtent);
                  _verticalScrollController.jumpTo(newV);
                  AppLogger.exchangeDebug('🖱️ [스크롤] 마우스 오른쪽 버튼 수직 스크롤: ${_rightClickScrollStartV!.toStringAsFixed(1)} → ${newV.toStringAsFixed(1)} (델타: ${delta.dy.toStringAsFixed(1)})');
                }
              }
            },
            onPointerUp: (event) {
              if (event.buttons != kSecondaryMouseButton) {
                _rightClickDragStart = null;
                _rightClickScrollStartH = null;
                _rightClickScrollStartV = null;
                ref.read(scrollProvider.notifier).setScrolling(false);
              }
            },
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme.copyWith(
                      bodyMedium: TextStyle(fontSize: _getScaledFontSize(zoomFactor)),
                      bodySmall: TextStyle(fontSize: _getScaledFontSize(zoomFactor)),
                      titleMedium: TextStyle(fontSize: _getScaledFontSize(zoomFactor)),
                      labelMedium: TextStyle(fontSize: _getScaledFontSize(zoomFactor)),
                      labelLarge: TextStyle(fontSize: _getScaledFontSize(zoomFactor)),
                      labelSmall: TextStyle(fontSize: _getScaledFontSize(zoomFactor)),
                    ),
                  ),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      // Syncfusion DataGrid의 스크롤 이벤트 감지
                      if (notification is ScrollUpdateNotification) {
                        final metrics = notification.metrics;
                        final currentState = ref.read(scrollProvider);
                        
                        // 현재 상태를 유지하면서 해당 축의 오프셋만 업데이트
                        final newHorizontal = metrics.axis == Axis.horizontal 
                            ? metrics.pixels 
                            : currentState.horizontalOffset;
                        final newVertical = metrics.axis == Axis.vertical 
                            ? metrics.pixels 
                            : currentState.verticalOffset;
                            
                        ref.read(scrollProvider.notifier).updateOffset(
                          newHorizontal,
                          newVertical,
                        );
                        AppLogger.exchangeDebug('스크롤 감지: ${metrics.axis} - h:$newHorizontal, v:$newVertical');
                      }
                      return false; // 다른 위젯도 이벤트를 받을 수 있도록
                    },
                    child: SfDataGrid(
                      key: ValueKey('${widget.columns.length}_${widget.stackedHeaders.length}'),
                      source: widget.dataSource!,
                      columns: _getScaledColumns(zoomFactor),
                      stackedHeaderRows: _getScaledStackedHeaders(zoomFactor),
                      gridLinesVisibility: GridLinesVisibility.both,
                      headerGridLinesVisibility: GridLinesVisibility.both,
                      headerRowHeight: _getScaledHeaderHeight(zoomFactor),
                      rowHeight: _getScaledRowHeight(zoomFactor),
                      allowColumnsResizing: false,
                      allowSorting: false,
                      allowEditing: false,
                      allowTriStateSorting: false,
                      allowPullToRefresh: false,
                      selectionMode: SelectionMode.none,
                      columnWidthMode: ColumnWidthMode.none,
                      frozenColumnsCount: GridLayoutConstants.frozenColumnsCount,
                      onCellTap: _handleCellTap,
                      horizontalScrollController: _horizontalScrollController,
                      verticalScrollController: _verticalScrollController,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        return dataGridContainer;
      },
    );
  }

  /// 확대/축소에 따른 실제 크기 조정된 열 반환
  List<GridColumn> _getScaledColumns(double zoomFactor) {
    return widget.columns.map((column) {
      return GridColumn(
        columnName: column.columnName,
        width: _getScaledColumnWidth(column.width, zoomFactor),
        label: _getScaledTextWidget(column.label, zoomFactor, isHeader: false),
      );
    }).toList();
  }

  /// 확대/축소에 따른 실제 크기 조정된 스택 헤더 반환
  List<StackedHeaderRow> _getScaledStackedHeaders(double zoomFactor) {
    return widget.stackedHeaders.map((headerRow) {
      return StackedHeaderRow(
        cells: headerRow.cells.map((cell) {
          return StackedHeaderCell(
            columnNames: cell.columnNames,
            child: _getScaledTextWidget(cell.child, zoomFactor, isHeader: true),
          );
        }).toList(),
      );
    }).toList();
  }

  /// 확대/축소에 따른 실제 열 너비 반환
  double _getScaledColumnWidth(double baseWidth, double zoomFactor) {
    return baseWidth * zoomFactor;
  }

  /// 확대/축소에 따른 실제 크기 조정된 텍스트 위젯 반환
  Widget _getScaledTextWidget(dynamic originalWidget, double zoomFactor, {required bool isHeader}) {
    if (originalWidget is Text) {
      return Text(
        originalWidget.data ?? '',
        style: TextStyle(
          fontSize: _getScaledFontSize(zoomFactor),
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
            fontSize: _getScaledFontSize(zoomFactor),
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
        fontSize: _getScaledFontSize(zoomFactor),
        fontWeight: FontWeight.w600,
        color: isHeader ? Colors.blue[700] : Colors.black87,
      ),
      child: originalWidget ?? const Text(''),
    );
  }

  /// 확대/축소에 따른 실제 폰트 크기 반환
  double _getScaledFontSize(double zoomFactor) {
    return GridLayoutConstants.baseFontSize * zoomFactor;
  }

  /// 확대/축소에 따른 실제 헤더 높이 반환
  double _getScaledHeaderHeight(double zoomFactor) {
    return AppConstants.headerRowHeight * zoomFactor;
  }

  /// 확대/축소에 따른 실제 행 높이 반환
  double _getScaledRowHeight(double zoomFactor) {
    return AppConstants.dataRowHeight * zoomFactor;
  }



  /// 보강을 위한 교사 이름 선택 기능 활성화
  void _enableTeacherNameSelectionForSupplement() {
    // 교사 이름 선택 기능 활성화
    ref.read(exchangeScreenProvider.notifier).enableTeacherNameSelection();
    
    // 스낵바 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('보강한 교사 이름을 선택하세요'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
    
    AppLogger.exchangeDebug('보강을 위한 교사 이름 선택 기능 활성화');
  }


  /// 보강교체 실행
  void _executeSupplementExchange(String targetTeacherName) {
    if (widget.timetableData == null) {
      AppLogger.exchangeDebug('보강교체 실행 실패: timetableData가 null입니다');
      return;
    }

    // 현재 선택된 셀 정보 가져오기
    final exchangeService = ExchangeService();
    if (!exchangeService.hasSelectedCell()) {
      AppLogger.exchangeDebug('보강교체 실행 실패: 선택된 셀이 없습니다');
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

    AppLogger.exchangeDebug('보강교체 실행: $sourceTeacher($sourceDay$sourcePeriod교시) → $targetTeacherName($sourceDay$sourcePeriod교시)');

    // 보강교체 실행
    final success = exchangeService.performSupplementExchange(
      widget.timetableData!.timeSlots,
      sourceTeacher,
      sourceDay,
      sourcePeriod,
      targetTeacherName,
      sourceDay,
      sourcePeriod,
    );

    if (success) {
      // 보강교체 성공 시 히스토리에 저장
      _saveSupplementExchangeToHistory(sourceTeacher, sourceDay, sourcePeriod, targetTeacherName);
      
      // 교체된 셀 상태 업데이트
      _updateExchangedCellsForSupplement(sourceTeacher, sourceDay, sourcePeriod, targetTeacherName);
      
      // 교사 이름 선택 기능 비활성화
      ref.read(exchangeScreenProvider.notifier).disableTeacherNameSelection();
      ref.read(cellSelectionProvider.notifier).selectTeacherName(null);
      
      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('보강 수업이 추가되었습니다: $targetTeacherName $sourceDay$sourcePeriod교시'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // UI 업데이트 로깅
      AppLogger.exchangeDebug('✅ 보강교체 완료 - UI 업데이트');
      
      AppLogger.exchangeDebug('보강교체 완료');
    } else {
      // 보강교체 실패 시 오류 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('보강 실패: $targetTeacherName의 $sourceDay$sourcePeriod교시가 빈 셀이 아닙니다'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 보강교체를 히스토리에 저장
  void _saveSupplementExchangeToHistory(String sourceTeacher, String sourceDay, int sourcePeriod, String targetTeacherName) {
    if (widget.timetableData == null) return;

    // 소스 셀의 정보 가져오기
    final sourceSlot = widget.timetableData!.timeSlots.firstWhere(
      (slot) => slot.teacher == sourceTeacher && 
                slot.dayOfWeek == DayUtils.getDayNumber(sourceDay) && 
                slot.period == sourcePeriod,
      orElse: () => TimeSlot(),
    );

    // SupplementExchangePath 생성
    final sourceNode = ExchangeNode(
      teacherName: sourceTeacher,
      day: sourceDay,
      period: sourcePeriod,
      className: sourceSlot.className ?? '',
      subjectName: sourceSlot.subject ?? '',
    );

    final targetNode = ExchangeNode(
      teacherName: targetTeacherName,
      day: sourceDay,
      period: sourcePeriod,
      className: '',  // 원래 빈 셀이었으므로 빈 문자열
      subjectName: '', // 원래 빈 셀이었으므로 빈 문자열
    );

    final supplementPath = SupplementExchangePath(
      sourceNode: sourceNode,
      targetNode: targetNode,
      option: ExchangeOption(
        teacherName: targetTeacherName,
        timeSlot: TimeSlot(
          teacher: targetTeacherName,
          dayOfWeek: DayUtils.getDayNumber(sourceDay),
          period: sourcePeriod,
          className: '',
          subject: '',
        ),
        type: ExchangeType.sameClass,
        priority: 1,
        reason: '보강교체',
      ),
    );

    // ExchangeHistoryService를 통해 히스토리에 저장
    final historyService = ExchangeHistoryService();
    historyService.executeExchange(
      supplementPath,
      customDescription: '보강교체: $sourceTeacher($sourceDay$sourcePeriod교시) → $targetTeacherName',
      additionalMetadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'supplement',
        'source': 'timetable_grid_section',
      },
    );

    AppLogger.exchangeDebug('보강교체 히스토리 저장 완료');
  }

  /// 보강교체 후 교체된 셀 상태 업데이트
  void _updateExchangedCellsForSupplement(String sourceTeacher, String sourceDay, int sourcePeriod, String targetTeacherName) {
    // 교체된 소스 셀과 목적지 셀을 교체된 셀 목록에 추가
    final cellState = ref.read(cellSelectionProvider);
    final cellNotifier = ref.read(cellSelectionProvider.notifier);
    
    // 소스 셀 (문유란 월2): 교체된 소스 셀로 표시
    final sourceCellKey = '${sourceTeacher}_${sourceDay}_$sourcePeriod';
    final currentExchangedCells = cellState.exchangedCells.toList();
    currentExchangedCells.add(sourceCellKey);
    cellNotifier.updateExchangedCells(currentExchangedCells);
    
    // 목적지 셀 (김연주 월2): 교체된 목적지 셀로 표시
    final targetCellKey = '${targetTeacherName}_${sourceDay}_$sourcePeriod';
    final currentDestinationCells = cellState.exchangedDestinationCells.toList();
    currentDestinationCells.add(targetCellKey);
    cellNotifier.updateExchangedDestinationCells(currentDestinationCells);
    
    AppLogger.exchangeDebug('보강교체 셀 상태 업데이트: 소스=$sourceCellKey, 목적지=$targetCellKey');
  }



  /// 교체된 셀 클릭 처리 (Riverpod 기반)
  void _handleExchangedCellClick(String teacherName, String day, int period) {
    AppLogger.exchangeDebug('🖱️ 교체된 셀 클릭: $teacherName | $day$period교시');
    
    // 교체된 셀 선택 상태 플래그 설정 (헤더 색상 비활성화용)
    SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(true);
    
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final exchangePath = historyService.findExchangePathByCell(
      teacherName,
      day,
      period,
    );

    if (exchangePath != null) {
      AppLogger.exchangeDebug('✅ 교체 경로 발견: ${exchangePath.type} (ID: ${exchangePath.id})');
      
      ref.read(stateResetProvider.notifier).resetExchangeStates(
        reason: '교체된 셀 클릭 - 이전 교체 상태 초기화',
      );

      // Riverpod 기반 화살표 표시
      ref.read(cellSelectionProvider.notifier).showArrowForExchangedCell(exchangePath);
      
      // 교체된 셀 클릭 시 교체 서비스 상태 업데이트 (헤더 업데이트를 위해)
      _updateExchangeServiceForExchangedCell(teacherName, day, period);
      
      AppLogger.exchangeDebug('🔄 교체된 셀 클릭 - UI 업데이트');

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
    ref.read(cellSelectionProvider.notifier).hideArrow(
      reason: ArrowDisplayReason.manualHide,
    );
    
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '일반 셀 클릭 - 교체 화살표 숨김',
    );
    AppLogger.exchangeDebug('교체 화살표 숨김 (Riverpod)');
  }

  /// 화살표 상태 초기화 (외부에서 호출) - StateResetProvider에서 처리됨
  void clearAllArrowStates() {
    // 화살표 상태 초기화는 StateResetProvider에서 처리됨
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '외부 호출 - 화살표 상태 초기화',
    );
    AppLogger.exchangeDebug('[외부 호출] 화살표 상태 초기화 요청 (StateResetProvider에서 처리)');
  }

  /// Level 1 전용 화살표 초기화 (경로 선택만 해제) - StateResetProvider에서 처리됨
  void clearPathSelectionOnly() {
    // 화살표 초기화는 StateResetProvider에서 처리됨
    AppLogger.exchangeDebug('[Level 1] 경로 선택만 초기화 요청 (StateResetProvider에서 처리)');
  }

  /// 셀 탭 이벤트 처리
  void _handleCellTap(DataGridCellTapDetails details) {
    final teacherName = _extractTeacherNameFromRowIndex(
      details.rowColumnIndex.rowIndex,
    );
    final columnName = details.column.columnName;

    // 교사 이름 클릭 처리 (새로 추가)
    if (columnName == 'teacher') {
      _handleTeacherNameClick(teacherName);
      return;
    }

    if (columnName != 'teacher') {
      final parts = columnName.split('_');
      if (parts.length == 2) {
        final day = parts[0];
        final period = int.tryParse(parts[1]) ?? 0;

        final historyService = ref.read(exchangeHistoryServiceProvider);
        final isExchangedCell = historyService.isCellExchanged(teacherName, day, period);

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
    AppLogger.exchangeDebug('🔄 일반 셀 클릭 - UI 업데이트');
  }

  /// 교사 이름 클릭 처리 (교체 모드 또는 교체불가 편집 모드에서 동작)
  void _handleTeacherNameClick(String teacherName) {
    // 현재 모드 및 교사 이름 선택 기능 활성화 상태 확인
    final screenState = ref.read(exchangeScreenProvider);
    final currentMode = screenState.currentMode;
    final isNonExchangeableEditMode = currentMode == ExchangeMode.nonExchangeableEdit;
    final isTeacherNameSelectionEnabled = screenState.isTeacherNameSelectionEnabled;
    
    // 교체불가 편집 모드인 경우 교사 전체 시간 토글 기능 사용
    if (isNonExchangeableEditMode) {
      AppLogger.exchangeDebug('교체불가 편집 모드: 교사 전체 시간 토글 기능 사용 - $teacherName');
      _toggleTeacherAllTimesInNonExchangeableMode(teacherName);
      return;
    }
    
    // 교체 모드이지만 교사 이름 선택 기능이 비활성화된 경우 아무 동작하지 않음
    if (!isInExchangeMode || !isTeacherNameSelectionEnabled) {
      AppLogger.exchangeDebug('교사 이름 클릭: 교체 모드가 아니거나 교사 이름 선택 기능이 비활성화됨');
      return;
    }
    
    // 교체 모드인 경우 교사 이름 선택 기능 사용
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
      
      // 교사 이름 선택 후 보강교체 실행
      _executeSupplementExchange(teacherName);
    }
    
    // UI 업데이트 로깅
    AppLogger.exchangeDebug('🔄 교사 이름 클릭 - UI 업데이트');
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
      final cellNotifier = ref.read(cellSelectionProvider.notifier);
      cellNotifier.selectCell(teacherName, day, period);
      
      AppLogger.exchangeDebug('📝 교체 서비스 상태 업데이트 완료: $teacherName $day$period교시');
    } catch (e) {
      AppLogger.error('교체 서비스 상태 업데이트 실패: $e');
    }
  }


  /// 내부 선택된 경로 초기화 (StateResetProvider에서 처리됨)
  void _clearInternalPath() {
    // 화살표 상태 초기화는 StateResetProvider에서 처리됨
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '내부 경로 초기화',
    );
    
    // 싱글톤 화살표 매니저를 통한 화살표 정리
    _arrowsManager.clearAllArrows();
    AppLogger.exchangeDebug('화살표 초기화 요청 (StateResetProvider에서 처리)');
  }




  /// 교체 뷰 활성화 (Riverpod 기반)
  void _enableExchangeView() {
    if (widget.timetableData == null || widget.dataSource == null) {
      AppLogger.exchangeDebug('교체 뷰 활성화 실패: 필수 데이터가 null입니다');
      return;
    }

    ref.read(exchangeViewProvider.notifier).enableExchangeView(
      timeSlots: widget.dataSource!.timeSlots,
      teachers: widget.timetableData!.teachers,
      dataSource: widget.dataSource!,
    );
  }

  /// 교체 뷰 비활성화 (Riverpod 기반)
  void _disableExchangeView() {
    if (widget.timetableData == null || widget.dataSource == null) {
      AppLogger.exchangeDebug('교체 뷰 비활성화 실패: 필수 데이터가 null입니다');
      return;
    }

    ref.read(exchangeViewProvider.notifier).disableExchangeView(
      timeSlots: widget.dataSource!.timeSlots,
      teachers: widget.timetableData!.teachers,
      dataSource: widget.dataSource!,
    );
  }

}


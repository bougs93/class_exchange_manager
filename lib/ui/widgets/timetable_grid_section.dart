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
import '../../utils/day_utils.dart';
import 'timetable_grid/widget_arrows_manager.dart';
import '../../utils/logger.dart';
import '../../models/exchange_path.dart';
import '../../models/time_slot.dart';
import '../../providers/state_reset_provider.dart';
import '../../providers/zoom_provider.dart';
import '../../providers/scroll_provider.dart';
import '../../utils/simplified_timetable_theme.dart';
import 'timetable_grid/timetable_grid_constants.dart';
import 'timetable_grid/exchange_arrow_style.dart';
import 'timetable_grid/exchange_arrow_painter.dart';
import 'timetable_grid/exchange_executor.dart';
import 'timetable_grid/grid_header_widgets.dart';

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

}

class _TimetableGridSectionState extends ConsumerState<TimetableGridSection> {
  // 🧪 테스트: GlobalKey만 사용 - 나머지 모든 수정사항 원상복구
  // GlobalKey만으로도 DataGrid 재생성 문제가 해결되는지 테스트
  final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();
  
  // 스크롤 컨트롤러들
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  
  // 마우스 오른쪽 버튼 및 두 손가락 드래그 상태
  Offset? _rightClickDragStart;
  double? _rightClickScrollStartH;
  double? _rightClickScrollStartV;
  
  // 헬퍼 클래스들 (매번 생성하도록 변경)
  ExchangeExecutor get _exchangeExecutor => ExchangeExecutor(
    ref: ref,
    dataSource: widget.dataSource,
    onEnableExchangeView: _enableExchangeView,
  );

  // 싱글톤 화살표 매니저
  final WidgetArrowsManager _arrowsManager = WidgetArrowsManager();

  /// 현재 선택된 교체 경로 (Riverpod 기반)
  ExchangePath? get currentSelectedPath {
    final selectedPath = ref.watch(selectedExchangePathProvider);
    final result = selectedPath ?? widget.selectedExchangePath;
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

    // Syncfusion DataGrid 초기화 로그
    AppLogger.exchangeDebug('[wg2] Syncfusion DataGrid 초기화: 위젯 생성 시 (initState)');

    // 스크롤 초기화 로그 (위젯 생성 시)
    AppLogger.exchangeDebug('[wg] 스크롤 초기화: 위젯 생성 시 (initState)');

    // 스크롤 리스너 추가
    _horizontalScrollController.addListener(_onScrollChanged);
    _verticalScrollController.addListener(_onScrollChanged);

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

    // 🔥 스크롤 문제 해결: 과거 커밋의 단순한 구조를 참고하여 불필요한 재빌드 방지
    // ValueKey는 fileLoadId를 사용하므로 파일 로드 시에만 변경됨
    // 경로 선택, 셀 선택, 헤더 업데이트 등에서는 ValueKey가 변경되지 않아 스크롤 유지됨

    // 실제로 중요한 구조적 데이터가 변경된 경우에만 UI 업데이트 요청 (성능 최적화)
    // 경로 선택으로 인한 columns/stackedHeaders 변경은 제외하여 불필요한 재빌드 방지
    if (widget.timetableData != oldWidget.timetableData ||
        widget.dataSource != oldWidget.dataSource ||
        widget.isExchangeModeEnabled != oldWidget.isExchangeModeEnabled ||
        widget.isCircularExchangeModeEnabled != oldWidget.isCircularExchangeModeEnabled ||
        widget.isChainExchangeModeEnabled != oldWidget.isChainExchangeModeEnabled) {

      // Syncfusion DataGrid 초기화 로그 (위젯 업데이트 시)
      AppLogger.exchangeDebug('[wg2] Syncfusion DataGrid 초기화: 위젯 업데이트 시 (didUpdateWidget) - 구조적 데이터 변경');

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
  /// 🔥 스크롤 문제 해결: 과거 커밋의 단순한 구조를 참고하여 스크롤 상태만 업데이트
  void _onScrollChanged() {
    final horizontalOffset = _horizontalScrollController.hasClients ? _horizontalScrollController.offset : 0.0;
    final verticalOffset = _verticalScrollController.hasClients ? _verticalScrollController.offset : 0.0;
    
    
    // 🔥 스크롤 문제 해결: 스크롤 상태만 업데이트하고 다른 상태는 건드리지 않음
    // 과거 커밋의 단순한 구조를 유지하여 불필요한 상태 변경 방지
    ref.read(scrollProvider.notifier).updateOffset(horizontalOffset, verticalOffset);
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

    // 🧪 테스트: ref.watch() 호출 복원 - Consumer 분리 제거로 원상복구
    // StateResetProvider 상태 감지 (화살표 초기화는 별도 처리)
    final resetState = ref.watch(stateResetProvider);
    
    // Level 3 초기화 시 교체 뷰 체크박스 초기화 및 UI 업데이트
    if (resetState.lastResetLevel == ResetLevel.allStates) {
      // 위젯 트리 빌드 완료 후 실행하도록 Future로 감싸기
      Future(() {
        // 교체 뷰 체크박스가 활성화되어 있으면 초기화
        if (ref.read(isExchangeViewEnabledProvider)) {
          ref.read(exchangeViewProvider.notifier).reset();
          AppLogger.exchangeDebug('[StateResetProvider 감지] 교체 뷰 체크박스 초기화 완료 (Level 3)');
        }
        
        // 엑셀 파일 로드 시 헤더셀, 일반셀 UI 업데이트 (교체 뷰 상태와 관계없이)
        if (widget.dataSource != null) {
          widget.dataSource!.notifyDataChanged();
          AppLogger.exchangeDebug('[StateResetProvider 감지] Level 3 초기화 - DataSource UI 업데이트 완료');
        }
      });
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

        // 교체 버튼들
        ExchangeActionButtons(
          onUndo: () => _exchangeExecutor.undoLastExchange(context, () {
            ref.read(stateResetProvider.notifier).resetExchangeStates(
              reason: '내부 경로 초기화',
            );
          }),
          onRepeat: () => _exchangeExecutor.repeatLastExchange(context),
          onDelete: (currentSelectedPath != null && isFromExchangedCell)
            ? () async => await _exchangeExecutor.deleteFromExchangeList(currentSelectedPath!, context, () {
                ref.read(stateResetProvider.notifier).resetExchangeStates(
                  reason: '내부 경로 초기화',
                );
              })
            : null,
          onExchange: (isInExchangeMode && !isFromExchangedCell && currentSelectedPath != null)
            ? () => _exchangeExecutor.executeExchange(currentSelectedPath!, context, () {
                ref.read(stateResetProvider.notifier).resetExchangeStates(
                  reason: '내부 경로 초기화',
                );
              })
            : null,
          showDeleteButton: currentSelectedPath != null && isFromExchangedCell,
          showExchangeButton: isInExchangeMode && !isFromExchangedCell,
        ),
      ],
    );
  }

  /// 화살표 매니저 초기화 또는 업데이트 (공통 메서드)
  /// 🔥 스크롤 문제 해결: 과거 커밋의 단순한 구조를 참고하여 스크롤 위치 보존
  void _initializeOrUpdateArrowsManager({bool isUpdate = false}) {
    if (widget.timetableData != null) {
      final zoomFactor = ref.read(zoomProvider.select((s) => s.zoomFactor));
      
      // 🔥 스크롤 문제 해결: 화살표 업데이트 시에도 스크롤 위치 보존
      // 과거 커밋의 단순한 구조를 유지하여 불필요한 상태 변경 방지
      
      if (isUpdate) {
        _arrowsManager.updateData(
          timetableData: widget.timetableData!,
          columns: widget.columns,
          zoomFactor: zoomFactor,
        );
      } else {
        _arrowsManager.initialize(
          timetableData: widget.timetableData!,
          columns: widget.columns,
          zoomFactor: zoomFactor,
        );
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
    if (currentSelectedPath != null && widget.timetableData != null) {
      // 현재는 기존 CustomPainter 방식 사용 (안정적)
      return _buildDataGridWithLegacyArrows(dataGrid);
    }

    return dataGrid;
  }

  /// 기존 CustomPainter 기반 화살표 표시
  Widget _buildDataGridWithLegacyArrows(Widget dataGridWithGestures) {
    return Consumer(
      builder: (context, ref, child) {
        final zoomFactor = ref.watch(zoomProvider.select((s) => s.zoomFactor));
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
        final zoomFactor = ref.watch(zoomProvider.select((s) => s.zoomFactor));

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
                }
                
                // 수직 스크롤
                if (_verticalScrollController.hasClients) {
                  final newV = (_rightClickScrollStartV! - delta.dy)
                      .clamp(0.0, _verticalScrollController.position.maxScrollExtent);
                  _verticalScrollController.jumpTo(newV);
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
                      bodyMedium: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                      bodySmall: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                      titleMedium: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                      labelMedium: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                      labelLarge: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
                      labelSmall: TextStyle(fontSize: GridLayoutConstants.baseFontSize * zoomFactor),
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
                      }
                      return false; // 다른 위젯도 이벤트를 받을 수 있도록
                    },
                    child: SfDataGrid(
                      // 🧪 테스트: GlobalKey만 사용 - 나머지 모든 수정사항 원상복구
                      // GlobalKey만으로도 DataGrid 재생성 문제가 해결되는지 테스트
                      key: _dataGridKey,
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

        // 🧪 테스트: Transform.scale 제거 - 직접 반환으로 원상복구
        return dataGridContainer;
      },
    );
  }




  /// 보강을 위한 교사 이름 선택 기능 활성화
  // ignore: unused_element
  void _enableTeacherNameSelectionForSupplement() {
    // 현재 선택된 셀이 수업이 있는 셀인지 확인
    final exchangeService = ref.read(exchangeServiceProvider);
    if (exchangeService.hasSelectedCell()) {
      final selectedTeacher = exchangeService.selectedTeacher!;
      final selectedDay = exchangeService.selectedDay!;
      final selectedPeriod = exchangeService.selectedPeriod!;
      
      // 선택된 셀이 빈 셀인 경우 보강 모드 취소
      if (_isCellEmpty(selectedTeacher, selectedDay, selectedPeriod)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수업이 있는 시간을 선택하고 보강 버튼을 눌려주세요.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        
        AppLogger.exchangeDebug('보강 모드 진입 실패: 빈 셀이 선택됨 - $selectedTeacher $selectedDay$selectedPeriod교시');
        return;
      }
    }

    // 🔥 Level 1 초기화: 보강 모드 진입 시 기존 교체 경로 정리
    // - ExchangeScreenProvider 배치 업데이트 (경로들을 null로 설정)
    // - TimetableDataSource 배치 업데이트 (Syncfusion DataGrid 전용)
    // - 공통 초기화 작업 수행 (WidgetArrowsManager().clearAllArrows())
    // - 화살표 상태 초기화 (hideArrow())
    ref.read(stateResetProvider.notifier).resetPathOnly(reason: '보강 모드 진입 - 기존 교체 경로 정리');

    // 🔥 내부 선택된 경로 초기화 (교체 버튼과 동일한 패턴 적용)
    ref.read(cellSelectionProvider.notifier).clearPathsOnly();

    // 🔥 헤더 테마 업데이트: 화살표 제거 및 UI 상태 정리
    // 다른 Level 1 초기화 코드들과 동일한 패턴 적용
    widget.onHeaderThemeUpdate?.call();

    // 🔥 UI 업데이트 (교체 버튼과 동일한 패턴 적용)
    widget.dataSource?.notifyDataChanged();

    // 교사 이름 선택 기능 활성화
    ref.read(exchangeScreenProvider.notifier).enableTeacherNameSelection();
    
    // 스낵바 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('보강 모드 활성화: 빈 셀을 클릭하여 보강할 시간을 선택하세요'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
    
    AppLogger.exchangeDebug('[보강 1단계] 보강을 위한 교사 이름 선택 기능 활성화');
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
      AppLogger.exchangeDebug('✅ 교체 경로 발견: ${exchangePath.type} (ID: ${exchangePath.id})');
      
      ref.read(stateResetProvider.notifier).resetExchangeStates(
        reason: '교체된 셀 클릭 - 이전 교체 상태 초기화',
      );

      // Riverpod 기반 화살표 표시
      ref.read(cellSelectionProvider.notifier).showArrowForExchangedCell(exchangePath);
      
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
    ref.read(cellSelectionProvider.notifier).hideArrow(
      reason: ArrowDisplayReason.manualHide,
    );
    
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '일반 셀 클릭 - 교체 화살표 숨김',
    );
  }

  /// 화살표 상태 초기화 (외부에서 호출) - StateResetProvider에서 처리됨
  void clearAllArrowStates() {
    // 화살표 상태 초기화는 StateResetProvider에서 처리됨
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '외부 호출 - 화살표 상태 초기화',
    );
  }

  /// Level 1 전용 화살표 초기화 (경로 선택만 해제) - StateResetProvider에서 처리됨
  void clearPathSelectionOnly() {
    // 화살표 초기화는 StateResetProvider에서 처리됨
    AppLogger.exchangeDebug('[Level 1] 경로 선택만 초기화 요청 (StateResetProvider에서 처리)');
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

        // 보강 모드에서는 일반 셀 클릭 시 교사 이름 추출하지 않음
        // 교사 이름 열을 통해서만 보강교체 실행
      }
    }

    // 일반 셀 클릭 시 교체된 셀 선택 상태 플래그 해제 (헤더 색상 복원용)
    SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(false);

    // Level 2 초기화 실행 (로그와 동일한 동작)
    _hideExchangeArrows();
    
    widget.onCellTap(details);
    AppLogger.exchangeDebug('🔄 일반 셀 클릭 - UI 업데이트 (스크롤 위치 보존)');
  }

  /// 교사 이름 클릭 처리 (교체 모드 또는 교체불가 편집 모드에서 동작)
  void _handleTeacherNameClick(String teacherName) {
    // 현재 모드 및 교사 이름 선택 기능 활성화 상태 확인
    final screenState = ref.read(exchangeScreenProvider);
    final currentMode = screenState.currentMode;
    final isNonExchangeableEditMode = currentMode == ExchangeMode.nonExchangeableEdit;
    final isSupplementExchangeMode = currentMode == ExchangeMode.supplementExchange;
    final isTeacherNameSelectionEnabled = screenState.isTeacherNameSelectionEnabled;
    
    // 교체불가 편집 모드인 경우 교사 전체 시간 토글 기능 사용
    if (isNonExchangeableEditMode) {
      AppLogger.exchangeDebug('교체불가 편집 모드: 교사 전체 시간 토글 기능 사용 - $teacherName');
      _toggleTeacherAllTimesInNonExchangeableMode(teacherName);
      return;
    }
    
    // 보강교체 모드이고 교사 이름 선택 기능이 활성화된 경우 보강교체 실행
    if (isSupplementExchangeMode && isTeacherNameSelectionEnabled) {
      AppLogger.exchangeDebug('보강교체 모드: 교사 이름 클릭 - 보강교체 실행 - $teacherName');
      
      // 현재 선택된 셀 정보 가져오기
      final exchangeService = ref.read(exchangeServiceProvider);
      if (!exchangeService.hasSelectedCell()) {
        AppLogger.exchangeDebug('보강교체 실행 실패: 선택된 셀을 먼저 선택해주세요');
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
        AppLogger.exchangeDebug('보강교체 실행 실패: $teacherName의 $selectedDay$selectedPeriod교시는 수업이 있는 시간입니다');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('보강할 시간에 수업이 없는 교사을 선택해주세요. $teacherName의 $selectedDay$selectedPeriod교시는 수업이 있는 시간입니다.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // 교사 이름 선택 상태 설정
      ref.read(cellSelectionProvider.notifier).selectTeacherName(teacherName);
      
      // 보강교체 실행 (ExchangeExecutor 호출)
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
        (slot) => slot.teacher == teacherName && 
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

  /// 보강교체 실행 (ExchangeExecutor 호출 - 1:1 교체와 동일한 패턴) - public 메서드로 변경
  void executeSupplementExchangeViaExecutor(String targetTeacherName) {
    if (widget.timetableData == null) {
      AppLogger.exchangeDebug('보강교체 실행 실패: timetableData가 null입니다');
      return;
    }

    // 현재 선택된 셀 정보 가져오기
    final exchangeService = ExchangeService();
    if (!exchangeService.hasSelectedCell()) {
      AppLogger.exchangeDebug('보강교체 실행 실패: 선택된 셀을 먼저 선택해주세요');
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
      (slot) => slot.teacher == sourceTeacher && 
                slot.dayOfWeek == DayUtils.getDayNumber(sourceDay) && 
                slot.period == sourcePeriod,
      orElse: () => throw StateError('소스 TimeSlot을 찾을 수 없습니다'),
    );

    // 보강 가능성 검증
    if (!sourceSlot.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시에 수업이 없습니다'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!sourceSlot.canExchange) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시 수업은 교체 불가능합니다'),
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
        ref.read(stateResetProvider.notifier).resetExchangeStates(
          reason: '내부 경로 초기화',
        );
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

  /// 교체 뷰 활성화 (Riverpod 기반)
  void _enableExchangeView() {
    AppLogger.exchangeDebug('[TimetableGridSection] _enableExchangeView() 호출됨');
    
    if (widget.timetableData == null || widget.dataSource == null) {
      AppLogger.exchangeDebug('[TimetableGridSection] 교체 뷰 활성화 실패: 필수 데이터가 null입니다');
      return;
    }

    AppLogger.exchangeDebug('[TimetableGridSection] ExchangeViewProvider.enableExchangeView() 호출 시작');
    
    ref.read(exchangeViewProvider.notifier).enableExchangeView(
      timeSlots: widget.dataSource!.timeSlots,
      teachers: widget.timetableData!.teachers,
      dataSource: widget.dataSource!,
    );
    
    AppLogger.exchangeDebug('[TimetableGridSection] ExchangeViewProvider.enableExchangeView() 호출 완료');
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

  // ==================== 줌 팩터 기반 스케일링 메서드들 ====================

  /// 줌 팩터에 따라 컬럼들을 스케일링하여 반환
  /// 
  /// [zoomFactor] 현재 줌 팩터 (1.0 = 100%)
  /// 
  /// Returns: `List<GridColumn>` - 스케일링된 컬럼 목록
  List<GridColumn> _getScaledColumns(double zoomFactor) {
    return widget.columns.map((column) {
      return GridColumn(
        columnName: column.columnName,
        width: column.width * zoomFactor, // 컬럼 너비에 줌 팩터 적용
        label: column.label,
      );
    }).toList();
  }

  /// 줌 팩터에 따라 스택 헤더들을 스케일링하여 반환
  /// 
  /// [zoomFactor] 현재 줌 팩터 (1.0 = 100%)
  /// 
  /// Returns: `List<StackedHeaderRow>` - 스케일링된 스택 헤더 목록
  List<StackedHeaderRow> _getScaledStackedHeaders(double zoomFactor) {
    return widget.stackedHeaders.map((headerRow) {
      return StackedHeaderRow(
        cells: headerRow.cells.map((cell) {
          return StackedHeaderCell(
            child: cell.child,
            columnNames: cell.columnNames,
          );
        }).toList(),
      );
    }).toList();
  }

  /// 줌 팩터에 따라 헤더 행 높이를 계산하여 반환
  /// 
  /// [zoomFactor] 현재 줌 팩터 (1.0 = 100%)
  /// 
  /// Returns: double - 스케일링된 헤더 행 높이
  double _getScaledHeaderHeight(double zoomFactor) {
    // 기본 헤더 높이에 줌 팩터 적용
    return 25.0 * zoomFactor;
  }

  /// 줌 팩터에 따라 데이터 행 높이를 계산하여 반환
  /// 
  /// [zoomFactor] 현재 줌 팩터 (1.0 = 100%)
  /// 
  /// Returns: double - 스케일링된 데이터 행 높이
  double _getScaledRowHeight(double zoomFactor) {
    // 기본 데이터 행 높이에 줌 팩터 적용
    return 25.0 * zoomFactor;
  }

}


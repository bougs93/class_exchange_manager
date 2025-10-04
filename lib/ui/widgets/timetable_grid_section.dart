import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/excel_service.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/constants.dart';
import '../../utils/exchange_visualizer.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../../models/exchange_path.dart';
import 'timetable_grid/timetable_grid_constants.dart';
import 'timetable_grid/exchange_arrow_style.dart';
import 'timetable_grid/exchange_arrow_painter.dart';

/// 시간표 그리드 섹션 위젯
/// Syncfusion DataGrid를 사용한 시간표 표시를 담당
class TimetableGridSection extends StatefulWidget {
  final TimetableData? timetableData;
  final TimetableDataSource? dataSource;
  final List<GridColumn> columns;
  final List<StackedHeaderRow> stackedHeaders;
  final bool isExchangeModeEnabled;
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
    required this.exchangeableCount,
    required this.onCellTap,
    this.selectedExchangePath, // 선택된 교체 경로 (모든 타입 지원)
    this.customArrowStyle, // 커스텀 화살표 스타일
  });

  @override
  State<TimetableGridSection> createState() => _TimetableGridSectionState();
  
  /// 외부에서 스크롤 기능에 접근할 수 있도록 하는 static 메서드
  static void scrollToCellCenter(GlobalKey<State<TimetableGridSection>> key, String teacherName, String day, int period) {
    final state = key.currentState;
    if (state is _TimetableGridSectionState) {
      state.scrollToCellCenter(teacherName, day, period);
    }
  }
}

class _TimetableGridSectionState extends State<TimetableGridSection> {
  // DataGrid 컨트롤을 위한 GlobalKey
  final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();
  
  // 스크롤 컨트롤러들
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  // 확대/축소 관련 변수들
  double _zoomFactor = GridLayoutConstants.defaultZoomFactor; // 현재 확대/축소 비율

  // 드래그 스크롤 관련 변수들
  Offset? _lastPanOffset; // 마지막 터치/마우스 위치
  bool _isDraggingForScroll = false; // 드래그 스크롤 중인지 여부
  bool _isRightButtonPressed = false; // 마우스 오른쪽 버튼이 눌린 상태인지

  // 성능 최적화: 스크롤 디바운스 타이머
  Timer? _scrollDebounceTimer;

  // 성능 최적화: GridColumn/Header 캐시
  List<GridColumn>? _cachedColumns;
  List<StackedHeaderRow>? _cachedHeaders;
  double? _lastCachedZoomFactor;

  @override
  void initState() {
    super.initState();
    // 스크롤 이벤트 리스너 추가 - 디바운스 적용
    _verticalScrollController.addListener(_onScrollChangedDebounced);
    _horizontalScrollController.addListener(_onScrollChangedDebounced);
    // 초기 폰트 배율 설정
    SimplifiedTimetableTheme.setFontScaleFactor(_zoomFactor);
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _verticalScrollController.removeListener(_onScrollChangedDebounced);
    _horizontalScrollController.removeListener(_onScrollChangedDebounced);
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TimetableGridSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 위젯이 변경되었을 때 헤더 캐시 무효화 (교시 선택 또는 경로 변경 시)
    if (oldWidget.columns.length != widget.columns.length ||
        oldWidget.stackedHeaders.length != widget.stackedHeaders.length ||
        oldWidget.selectedExchangePath?.id != widget.selectedExchangePath?.id) {
      _cachedColumns = null;
      _cachedHeaders = null;
    }
  }

  /// 확대/축소 관련 메서드들
  
  /// 그리드 확대
  void _zoomIn() {
    if (_zoomFactor < GridLayoutConstants.maxZoom) {
      setState(() {
        _zoomFactor = (_zoomFactor + GridLayoutConstants.zoomStep)
            .clamp(GridLayoutConstants.minZoom, GridLayoutConstants.maxZoom);
        SimplifiedTimetableTheme.setFontScaleFactor(_zoomFactor);
        // 캐시 무효화 (줌 배율 변경 시)
        _cachedColumns = null;
        _cachedHeaders = null;
      });
    }
  }

  /// 그리드 축소
  void _zoomOut() {
    if (_zoomFactor > GridLayoutConstants.minZoom) {
      setState(() {
        _zoomFactor = (_zoomFactor - GridLayoutConstants.zoomStep)
            .clamp(GridLayoutConstants.minZoom, GridLayoutConstants.maxZoom);
        SimplifiedTimetableTheme.setFontScaleFactor(_zoomFactor);
        // 캐시 무효화 (줌 배율 변경 시)
        _cachedColumns = null;
        _cachedHeaders = null;
      });
    }
  }

  /// 확대/축소 초기화
  void _resetZoom() {
    setState(() {
      _zoomFactor = GridLayoutConstants.defaultZoomFactor;
      SimplifiedTimetableTheme.setFontScaleFactor(GridLayoutConstants.defaultZoomFactor);
      // 캐시 무효화 (줌 배율 변경 시)
      _cachedColumns = null;
      _cachedHeaders = null;
    });
  }

  /// 현재 확대 비율을 퍼센트로 반환
  int get _zoomPercentage => (_zoomFactor * 100).round();

  /// 스크롤 변경 시 화살표 재그리기 (디바운스 적용)
  void _onScrollChangedDebounced() {
    if (widget.selectedExchangePath == null) return;

    // 기존 타이머 취소
    _scrollDebounceTimer?.cancel();

    // 16ms(~60fps) 후에 재그리기 (스크롤 중에는 건너뜀)
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 16), () {
      if (mounted && widget.selectedExchangePath != null) {
        setState(() {
          // 화살표만 재그리기 (CustomPainter의 shouldRepaint에서 최적화)
        });
      }
    });
  }

  /// 드래그 스크롤 관련 메서드들
  
  /// 마우스 오른쪽 버튼 또는 2손가락 드래그 시작
  void _onPanStart(DragStartDetails details) {
    _lastPanOffset = details.localPosition;
    _isDraggingForScroll = false;
    
    // 모바일에서는 모든 터치를 스크롤로 처리 (실제로는 2손가락 감지 필요)
    if (Platform.isAndroid || Platform.isIOS) {
      // 모바일에서는 우선 스크롤을 시도하지 않음 (셀 선택 우선)
      _isDraggingForScroll = false;
    }
    // PC에서는 마우스 버튼 상태에 따라 결정
  }

  /// 드래그 업데이트 - 스크롤 실행
  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDraggingForScroll || _lastPanOffset == null) return;

    Offset delta = details.localPosition - _lastPanOffset!;
    
    // 최소 이동 거리 체크 (실수 방지)
    if (delta.distance < 3.0) return;
    
    // 드래그 방향의 반대로 스크롤
    _scrollByOffset(-delta);
    
    _lastPanOffset = details.localPosition;
  }

  /// 드래그 종료
  void _onPanEnd(DragEndDetails details) {
    _isDraggingForScroll = false;
    _isRightButtonPressed = false;
    _lastPanOffset = null;
  }

  /// 오프셋만큼 스크롤 이동
  void _scrollByOffset(Offset delta) {
    if (_horizontalScrollController.hasClients) {
      _horizontalScrollController.jumpTo(
        (_horizontalScrollController.offset + delta.dx).clamp(
          _horizontalScrollController.position.minScrollExtent,
          _horizontalScrollController.position.maxScrollExtent,
        ),
      );
    }

    if (_verticalScrollController.hasClients) {
      _verticalScrollController.jumpTo(
        (_verticalScrollController.offset + delta.dy).clamp(
          _verticalScrollController.position.minScrollExtent,
          _verticalScrollController.position.maxScrollExtent,
        ),
      );
    }
  }


  /// 마우스 버튼 이벤트 처리 (오른쪽 버튼 감지)
  void _onMouseDown(PointerDownEvent event) {
    if (event.buttons == kSecondaryButton) {
      _isRightButtonPressed = true;
      _lastPanOffset = event.localPosition;
    }
  }

  void _onMouseUp(PointerUpEvent event) {
    _isRightButtonPressed = false;
    _isDraggingForScroll = false;
  }

  void _onMouseMove(PointerMoveEvent event) {
    if (_isRightButtonPressed && _lastPanOffset != null) {
      if (!_isDraggingForScroll) {
        _isDraggingForScroll = true;
      }
      
      Offset delta = event.localPosition - _lastPanOffset!;
      
      // 최소 이동 거리 체크 (실수 방지)
      if (delta.distance < 3.0) return;
      
      _scrollByOffset(-delta);
      _lastPanOffset = event.localPosition;
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
        
        // 전체 교사 수 표시
        _buildTeacherCountWidget(),
        
        const SizedBox(width: 8),
        
        // 교체 모드가 활성화된 경우에만 교체 가능한 수업 개수 표시
        if (widget.isExchangeModeEnabled) ...[
          ExchangeVisualizer.buildExchangeableCountWidget(widget.exchangeableCount),
          const SizedBox(width: 8),
        ],
        
        const Spacer(), // 공간을 최대한 활용
        
        // 확대/축소 컨트롤
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                            // 초기화 버튼 (확대 비율이 100%가 아닌 경우에만 표시)
              if (_zoomFactor != GridLayoutConstants.defaultZoomFactor)
                IconButton(
                  onPressed: _resetZoom,
                  icon: const Icon(Icons.refresh, size: 16),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  color: Colors.grey.shade600,
                  tooltip: '확대/축소 초기화',
                ),
              // 축소 버튼
              IconButton(
                onPressed: _zoomFactor > GridLayoutConstants.minZoom ? _zoomOut : null,
                icon: const Icon(Icons.zoom_out, size: 18),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: _zoomFactor > GridLayoutConstants.minZoom ? Colors.blue : Colors.grey,
                tooltip: '축소',
              ),
              
              // 현재 확대 비율 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_zoomPercentage%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              
              // 확대 버튼
              IconButton(
                onPressed: _zoomFactor < GridLayoutConstants.maxZoom ? _zoomIn : null,
                icon: const Icon(Icons.zoom_in, size: 18),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: _zoomFactor < GridLayoutConstants.maxZoom ? Colors.blue : Colors.grey,
                tooltip: '확대',
              ),
              

            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 교사 수 표시 위젯
  Widget _buildTeacherCountWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        '교사 ${widget.timetableData!.teachers.length}명',
        style: TextStyle(
          fontSize: 12,
          color: Colors.green.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// DataGrid와 화살표를 함께 구성
  Widget _buildDataGridWithArrows() {
    Widget dataGridWithGestures = _buildDataGridWithDragScrolling();
    
    
    // 교체 경로가 선택된 경우에만 화살표 표시 (모든 타입 지원)
    if (widget.selectedExchangePath != null) {
      return Stack(
        children: [
          dataGridWithGestures,
          // 화살표를 그리는 CustomPainter 오버레이 (터치 이벤트 무시)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ExchangeArrowPainter(
                  selectedPath: widget.selectedExchangePath!,
                  timetableData: widget.timetableData!,
                  columns: widget.columns,
                  verticalScrollController: _verticalScrollController,
                  horizontalScrollController: _horizontalScrollController,
                  customArrowStyle: widget.customArrowStyle,
                  zoomFactor: _zoomFactor, // 클리핑 계산용 (실제 크기는 이미 조정됨)
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
        // 마우스 오른쪽 버튼 드래그와 모바일 2손가락 드래그를 위한 PanGestureRecognizer
        PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          () => PanGestureRecognizer(),
          (PanGestureRecognizer instance) {
            instance
              ..onStart = _onPanStart
              ..onUpdate = _onPanUpdate
              ..onEnd = _onPanEnd;
          },
        ),
        // 줌 기능 유지
        ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
          () => ScaleGestureRecognizer(),
          (ScaleGestureRecognizer instance) {
            instance.onUpdate = (ScaleUpdateDetails details) {
              // 기존 줌 기능은 유지 (필요시 구현)
              // _handleZoom(details.scale);
            };
          },
        ),
      },
      behavior: HitTestBehavior.translucent,
      child: Listener(
        onPointerDown: _onMouseDown,
        onPointerUp: _onMouseUp,
        onPointerMove: _onMouseMove,
        behavior: HitTestBehavior.translucent,
        child: _buildDataGrid(),
      ),
    );
  }

  /// DataGrid 구성 - 실제 폰트 크기와 셀 크기 기반 확대/축소 방식
  Widget _buildDataGrid() {
    Widget dataGridContainer = RepaintBoundary(
      // RepaintBoundary: DataGrid를 별도 레이어로 분리하여 불필요한 리페인트 방지
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.copyWith(
            // 모든 텍스트 스타일에 확대된 폰트 크기 적용
            bodyMedium: TextStyle(fontSize: _getScaledFontSize()),
            bodySmall: TextStyle(fontSize: _getScaledFontSize()),
            titleMedium: TextStyle(fontSize: _getScaledFontSize()),
            labelMedium: TextStyle(fontSize: _getScaledFontSize()),
            labelLarge: TextStyle(fontSize: _getScaledFontSize()),
            labelSmall: TextStyle(fontSize: _getScaledFontSize()),
          ),
        ),
        child: SfDataGrid(
          key: _dataGridKey, // 스크롤 제어를 위한 GlobalKey 추가
          source: widget.dataSource!,
          columns: _getScaledColumns(), // 실제 크기 조정된 열 사용
          stackedHeaderRows: _getScaledStackedHeaders(), // 실제 크기 조정된 헤더 사용
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        headerRowHeight: _getScaledHeaderHeight(), // 실제 크기 조정된 헤더 높이
        rowHeight: _getScaledRowHeight(), // 실제 크기 조정된 행 높이
        allowColumnsResizing: false,
        allowSorting: false,
        allowEditing: false,
        allowTriStateSorting: false,
        allowPullToRefresh: false,
        selectionMode: SelectionMode.none,
        columnWidthMode: ColumnWidthMode.none,
        frozenColumnsCount: GridLayoutConstants.frozenColumnsCount, // 교사명 열(첫 번째 열) 고정
        onCellTap: widget.onCellTap, // 셀 탭 이벤트 핸들러
        // 스크롤 컨트롤러 설정
        verticalScrollController: _verticalScrollController,
        horizontalScrollController: _horizontalScrollController,
        // 확대 시 정확한 스크롤바 표시를 위해 내장 스크롤바 사용
        isScrollbarAlwaysShown: true,
          horizontalScrollPhysics: const AlwaysScrollableScrollPhysics(), // 가로 스크롤 활성화
          verticalScrollPhysics: const AlwaysScrollableScrollPhysics(), // 세로 스크롤 활성화
        ),
        ),
      ),
    );

    return dataGridContainer; // 실제 크기 조정 방식 사용
  }

  /// 확대/축소에 따른 실제 크기 조정된 열 반환 - 캐싱 적용
  List<GridColumn> _getScaledColumns() {
    // 캐시된 값이 있고 줌 배율이 동일하면 캐시 반환
    if (_cachedColumns != null && _lastCachedZoomFactor == _zoomFactor) {
      return _cachedColumns!;
    }

    // 새로 생성하고 캐시에 저장
    _cachedColumns = widget.columns.map((column) {
      return GridColumn(
        columnName: column.columnName,
        width: _getScaledColumnWidth(column.width), // 실제 열 너비 조정
        label: _getScaledTextWidget(column.label, isHeader: false), // 열 라벨 (검은색)
      );
    }).toList();
    _lastCachedZoomFactor = _zoomFactor;

    return _cachedColumns!;
  }

  /// 확대/축소에 따른 실제 크기 조정된 스택 헤더 반환 - 캐싱 적용
  List<StackedHeaderRow> _getScaledStackedHeaders() {
    // 캐시된 값이 있고 줌 배율이 동일하면 캐시 반환
    if (_cachedHeaders != null && _lastCachedZoomFactor == _zoomFactor) {
      return _cachedHeaders!;
    }

    // 새로 생성하고 캐시에 저장
    _cachedHeaders = widget.stackedHeaders.map((headerRow) {
      return StackedHeaderRow(
        cells: headerRow.cells.map((cell) {
          return StackedHeaderCell(
            columnNames: cell.columnNames,
            child: _getScaledTextWidget(cell.child, isHeader: true), // 헤더 셀 (파란색)
          );
        }).toList(),
      );
    }).toList();
    _lastCachedZoomFactor = _zoomFactor;

    return _cachedHeaders!;
  }

  /// 확대/축소에 따른 실제 열 너비 반환
  double _getScaledColumnWidth(double baseWidth) {
    return baseWidth * _zoomFactor;
  }

  /// 확대/축소에 따른 실제 크기 조정된 텍스트 위젯 반환
  /// [isHeader] true인 경우 파란색, false인 경우 검은색
  Widget _getScaledTextWidget(dynamic originalWidget, {required bool isHeader}) {
    // 원본 위젯이 Text인 경우 새로운 스타일로 교체
    if (originalWidget is Text) {
      return Text(
        originalWidget.data ?? '',
        style: TextStyle(
          fontSize: _getScaledFontSize(), // 확대된 폰트 크기
          fontWeight: FontWeight.w600,
          color: isHeader ? Colors.blue[700] : Colors.black87,
        ),
        textAlign: originalWidget.textAlign,
        overflow: originalWidget.overflow,
        maxLines: originalWidget.maxLines,
        textDirection: originalWidget.textDirection,
      );
    }
    
    // 원본 위젯이 Container인 경우 내부 텍스트를 추출하여 새로운 Container 생성
    if (originalWidget is Container && originalWidget.child is Text) {
      final text = originalWidget.child as Text;
      return Container(
        padding: originalWidget.padding,
        decoration: originalWidget.decoration,
        alignment: originalWidget.alignment,
        child: Text(
          text.data ?? '',
          style: TextStyle(
            fontSize: _getScaledFontSize(), // 확대된 폰트 크기
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
    
    // 다른 위젯인 경우 DefaultTextStyle로 감싸서 폰트 크기만 조정 (하위 호환성)
    return DefaultTextStyle(
      style: TextStyle(
        fontSize: _getScaledFontSize(), // 확대된 폰트 크기
        fontWeight: FontWeight.w600,
        color: isHeader ? Colors.blue[700] : Colors.black87,
      ),
      child: originalWidget ?? const Text(''), // 원본 위젯 사용
    );
  }

  /// 확대/축소에 따른 실제 폰트 크기 반환
  double _getScaledFontSize() {
    return GridLayoutConstants.baseFontSize * _zoomFactor; // 기본 폰트 크기에서 배율 적용
  }

  /// 확대/축소에 따른 실제 헤더 높이 반환
  double _getScaledHeaderHeight() {
    return AppConstants.headerRowHeight * _zoomFactor;
  }

  /// 확대/축소에 따른 실제 행 높이 반환
  double _getScaledRowHeight() {
    return AppConstants.dataRowHeight * _zoomFactor;
  }



  /// 특정 셀을 화면 중앙으로 스크롤하는 메서드
  void scrollToCellCenter(String teacherName, String day, int period) {
    if (widget.timetableData == null) {
      return;
    }

    // 교사 인덱스 찾기
    int teacherIndex = widget.timetableData!.teachers
        .indexWhere((teacher) => teacher.name == teacherName);
    
    if (teacherIndex == -1) {
      return; // 교사를 찾을 수 없음
    }

    // 컬럼 인덱스 찾기
    String columnName = '${day}_$period';
    int columnIndex = widget.columns
        .indexWhere((column) => column.columnName == columnName);
    
    if (columnIndex == -1) {
      return; // 컬럼을 찾을 수 없음
    }

    // 스크롤 위치 계산 (설정에 따라 중앙 또는 좌상단)
    _scrollToPosition(teacherIndex, columnIndex);
  }
  
  /// 스크롤 위치 계산 및 실행
  void _scrollToPosition(int teacherIndex, int columnIndex) {
    // 세로 스크롤 계산
    _scrollVertically(teacherIndex);
    
    // 가로 스크롤 계산 (첫 번째 열은 고정)
    if (columnIndex > 0) {
      _scrollHorizontally(columnIndex - 1);
    }
  }
  
  /// 세로 스크롤 실행
  void _scrollVertically(int teacherIndex) {
    if (!_verticalScrollController.hasClients) return;
    
    double targetRowOffset = teacherIndex * AppConstants.dataRowHeight * _zoomFactor;
    
    // 중앙 정렬인 경우 뷰포트 높이의 절반만큼 조정
    if (AppConstants.scrollAlignment == ScrollAlignment.center) {
      double viewportHeight = _verticalScrollController.position.viewportDimension;
      double cellHeight = AppConstants.dataRowHeight * _zoomFactor;
      targetRowOffset = targetRowOffset - (viewportHeight / 2) + (cellHeight / 2);
      
      // 스크롤 범위 내로 제한
      targetRowOffset = targetRowOffset.clamp(
        _verticalScrollController.position.minScrollExtent,
        _verticalScrollController.position.maxScrollExtent,
      );
    }
    
    _verticalScrollController.animateTo(
      targetRowOffset,
      duration: const Duration(milliseconds: ArrowConstants.scrollAnimationMilliseconds),
      curve: Curves.easeInOut,
    );
  }
  
  /// 가로 스크롤 실행
  void _scrollHorizontally(int scrollableColumnIndex) {
    if (!_horizontalScrollController.hasClients) return;
    
    double targetColumnOffset = scrollableColumnIndex * AppConstants.periodColumnWidth * _zoomFactor;
    
    // 중앙 정렬인 경우 뷰포트 너비의 절반만큼 조정
    if (AppConstants.scrollAlignment == ScrollAlignment.center) {
      double viewportWidth = _horizontalScrollController.position.viewportDimension;
      double cellWidth = AppConstants.periodColumnWidth * _zoomFactor;
      targetColumnOffset = targetColumnOffset - (viewportWidth / 2) + (cellWidth / 2);
      
      // 스크롤 범위 내로 제한
      targetColumnOffset = targetColumnOffset.clamp(
        _horizontalScrollController.position.minScrollExtent,
        _horizontalScrollController.position.maxScrollExtent,
      );
    }
    
    _horizontalScrollController.animateTo(
      targetColumnOffset,
      duration: const Duration(milliseconds: ArrowConstants.scrollAnimationMilliseconds),
      curve: Curves.easeInOut,
    );
  }
}

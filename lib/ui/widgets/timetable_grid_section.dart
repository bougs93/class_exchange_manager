import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/excel_service.dart';
import '../../services/exchange_service.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/constants.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../../utils/logger.dart';
import '../../models/exchange_path.dart';
import '../../models/exchange_history_item.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/time_slot.dart';
import '../../services/exchange_history_service.dart';
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
    this.selectedExchangePath, // 선택된 교체 경로 (모든 타입 지원)
    this.customArrowStyle, // 커스텀 화살표 스타일
    this.onHeaderThemeUpdate, // 헤더 테마 업데이트 콜백
    this.onRestoreUIToDefault, // UI 기본값 복원 콜백
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
  // 스크롤 컨트롤러들
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  // 확대/축소 관련 변수들
  double _zoomFactor = GridLayoutConstants.defaultZoomFactor; // 현재 확대/축소 비율

  // 드래그 스크롤 관련 변수들
  Offset? _lastPanOffset; // 마지막 터치/마우스 위치
  bool _isDragging = false; // 드래그 중인지 여부 (스크롤 또는 우클릭)

  // 성능 최적화: 스크롤 디바운스 타이머
  Timer? _scrollDebounceTimer;
  
  // 스크롤 업데이트 빈도 제한 (60fps = 16ms)
  DateTime _lastScrollUpdate = DateTime.now();

  // 교체 히스토리 서비스
  final ExchangeHistoryService _historyService = ExchangeHistoryService();
  
  // 교체 서비스
  final ExchangeService _exchangeService = ExchangeService();

  // 내부적으로 관리하는 선택된 교체 경로 (교체된 셀 클릭 시 사용)
  ExchangePath? _internalSelectedPath;
  
  // 교체 뷰 체크박스 상태
  bool _isExchangeViewEnabled = false;
  
  // 교체 뷰 상태 변경 전의 원본 TimeSlot 데이터 (되돌리기용)
  List<TimeSlot>? _originalTimeSlots;

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
    // 스크롤 이벤트 리스너 추가 - 디바운스 적용
    _verticalScrollController.addListener(_onScrollChangedDebounced);
    _horizontalScrollController.addListener(_onScrollChangedDebounced);
    // 초기 폰트 배율 설정
    SimplifiedTimetableTheme.setFontScaleFactor(_zoomFactor);
    
    // 테이블 렌더링 완료 후 콜백 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.timetableData != null && widget.dataSource != null) {
        // 테이블 렌더링 완료 후 UI 기본값 복원 호출
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
          // 테이블 렌더링 완료 후 UI 기본값 복원 호출
          _notifyTableRenderingComplete();
        }
      });
    }
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

  /// 테이블 렌더링 완료 알림
  void _notifyTableRenderingComplete() {
    // 헤더 테마 업데이트 콜백이 있으면 호출
    if (widget.onHeaderThemeUpdate != null) {
      widget.onHeaderThemeUpdate!();
    }
    
    // 테이블 렌더링 완료 후 UI 기본값 복원 호출
    if (widget.onRestoreUIToDefault != null) {
      widget.onRestoreUIToDefault!();
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
      });
    }
  }

  /// 확대/축소 초기화
  void _resetZoom() {
    setState(() {
      _zoomFactor = GridLayoutConstants.defaultZoomFactor;
      SimplifiedTimetableTheme.setFontScaleFactor(GridLayoutConstants.defaultZoomFactor);
    });
  }

  /// 현재 확대 비율을 퍼센트로 반환
  int get _zoomPercentage => (_zoomFactor * 100).round();

  /// 스크롤 변경 시 화살표 재그리기 (성능 최적화된 실시간 업데이트)
  void _onScrollChangedDebounced() {
    if (widget.selectedExchangePath == null) return;

    DateTime now = DateTime.now();
    
    // 업데이트 빈도 제한 (60fps = 16ms 간격)
    if (now.difference(_lastScrollUpdate).inMilliseconds < 16) {
      return; // 너무 빈번한 업데이트 방지
    }
    
    _lastScrollUpdate = now;

    // 즉시 화살표 재그리기 (실시간 반응)
    if (mounted && widget.selectedExchangePath != null) {
      setState(() {
        // 화살표만 재그리기 (CustomPainter의 shouldRepaint에서 최적화)
      });
    }
  }

  /// 드래그 스크롤 관련 메서드들
  
  /// 마우스 오른쪽 버튼 또는 2손가락 드래그 시작
  void _onPanStart(DragStartDetails details) {
    _lastPanOffset = details.localPosition;
    _isDragging = false;
  }

  /// 드래그 업데이트 - 스크롤 실행
  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _lastPanOffset == null) return;

    Offset delta = details.localPosition - _lastPanOffset!;

    // 최소 이동 거리 체크 (실수 방지)
    if (delta.distance < 3.0) return;

    // 드래그 방향의 반대로 스크롤
    _scrollByOffset(-delta);

    _lastPanOffset = details.localPosition;
  }

  /// 드래그 종료
  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
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
      _isDragging = true;
      _lastPanOffset = event.localPosition;
    }
  }

  void _onMouseUp(PointerUpEvent event) {
    _isDragging = false;
  }

  void _onMouseMove(PointerMoveEvent event) {
    if (_isDragging && _lastPanOffset != null) {
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
        
        // 확대/축소 컨트롤 (맨 왼쪽으로 이동)
        _buildZoomControl(),
        
        const SizedBox(width: 8),
        
        // 전체 교사 수 표시
        _buildTeacherCountWidget(),
        
        const SizedBox(width: 8),
        
        // 교체 뷰 체크박스
        _buildExchangeViewCheckbox(),
        
        const SizedBox(width: 8),
        
        const Spacer(), // 공간을 최대한 활용
        
        // 보강/교체 버튼들
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            // 되돌리기 버튼
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  _undoLastExchange();
                },
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('', style: TextStyle(fontSize: 12)), //되돌리기
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(50, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: BorderSide(color: Colors.orange.shade300),
                  ),
                ),
              ),
            ),
            
            // 다시 반복 버튼
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  _repeatLastExchange();
                },
                icon: const Icon(Icons.redo, size: 16),
                label: const Text('', style: TextStyle(fontSize: 12)), //다시 반복
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade100,
                  foregroundColor: Colors.purple.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(50, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: BorderSide(color: Colors.purple.shade300),
                  ),
                ),
              ),
            ),

            // 보강 버튼
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  // 보강 기능 구현
                  _showSupplementDialog();
                },
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('보강', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                  foregroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(60, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: BorderSide(color: Colors.green.shade300),
                  ),
                ),
              ),
            ),

            // 교체 리스트에서 셀이 선택된 경우 모든 모드에서 삭제 버튼 표시
            if (currentSelectedPath != null && isFromExchangedCell) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 삭제 기능 구현 (다이얼로그 없이 즉시 실행)
                    _deleteFromExchangeList();
                  },
                  icon: Icon(
                    Icons.delete_outline, 
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                  label: Text(
                    '삭제', 
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(60, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: BorderSide(
                        color: Colors.red.shade300,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            
            // 교체 모드이고 교체 리스트에서 셀이 선택되지 않은 경우에만 교체 버튼 표시
            if (isInExchangeMode && !isFromExchangedCell) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: currentSelectedPath != null ? () {
                    // 교체 다이얼로그 없이 바로 실행
                    _executeExchange();
                  } : null,
                  icon: Icon(
                    Icons.swap_horiz, 
                    size: 16,
                    color: currentSelectedPath != null 
                      ? Colors.blue.shade700 
                      : Colors.grey.shade400,
                  ),
                  label: Text(
                    '교체', 
                    style: TextStyle(
                      fontSize: 12,
                      color: currentSelectedPath != null 
                        ? Colors.blue.shade700 
                        : Colors.grey.shade400,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentSelectedPath != null 
                      ? Colors.blue.shade100 
                      : Colors.grey.shade100,
                    foregroundColor: currentSelectedPath != null 
                      ? Colors.blue.shade700 
                      : Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(60, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: BorderSide(
                        color: currentSelectedPath != null 
                          ? Colors.blue.shade300 
                          : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 확대/축소 컨트롤 위젯
  Widget _buildZoomControl() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 초기화 버튼 (100%일 때는 비활성화)
          IconButton(
            onPressed: _zoomPercentage != 100 ? _resetZoom : null,
            icon: const Icon(Icons.refresh, size: 16),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            color: _zoomPercentage != 100 ? Colors.grey.shade600 : Colors.grey.shade400,
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

  /// 교체 뷰 체크박스 위젯
  Widget _buildExchangeViewCheckbox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: _isExchangeViewEnabled,
            onChanged: (bool? value) {
              setState(() {
                _isExchangeViewEnabled = value ?? false;
              });
              
              // 교체 뷰 상태에 따른 동작
              if (_isExchangeViewEnabled) {
                _enableExchangeView();
              } else {
                _disableExchangeView();
              }
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            activeColor: Colors.blue.shade600,
            checkColor: Colors.white,
          ),
          Text(
            '교체 뷰',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _isExchangeViewEnabled ? Colors.blue.shade700 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// DataGrid와 화살표를 함께 구성
  Widget _buildDataGridWithArrows() {
    Widget dataGridWithGestures = _buildDataGridWithDragScrolling();
    
    
    // 교체 경로가 선택된 경우에만 화살표 표시 (모든 타입 지원)
    if (currentSelectedPath != null && widget.timetableData != null) {
      return Stack(
        children: [
          dataGridWithGestures,
          // 화살표를 그리는 CustomPainter 오버레이 (터치 이벤트 무시)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ExchangeArrowPainter(
                  selectedPath: currentSelectedPath!,
                  timetableData: widget.timetableData!,
                  columns: widget.columns,
                  verticalScrollController: _verticalScrollController,
                  horizontalScrollController: _horizontalScrollController,
                  customArrowStyle: widget.customArrowStyle,
                  zoomFactor: _zoomFactor, // 클리핑 계산용 (실제 크기는 이미 조정됨)
                ),
                // RepaintBoundary로 CustomPainter를 별도 레이어로 분리하여 성능 최적화
                child: RepaintBoundary(
                  child: Container(), // 빈 컨테이너로 레이어 생성
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
          key: ValueKey(widget.columns.hashCode), // columns 변경 시 SfDataGrid 강제 재생성
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
        onCellTap: _handleCellTap, // 커스텀 셀 탭 핸들러
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

  /// 확대/축소에 따른 실제 크기 조정된 열 반환 - 캐싱 비활성화
  List<GridColumn> _getScaledColumns() {
    // 캐싱 제거: widget.columns가 변경될 때마다 새로 생성
    // (헤더 테마 업데이트가 즉시 반영되도록 함)
    return widget.columns.map((column) {
      return GridColumn(
        columnName: column.columnName,
        width: _getScaledColumnWidth(column.width), // 실제 열 너비 조정
        label: _getScaledTextWidget(column.label, isHeader: false), // 열 라벨 (검은색)
      );
    }).toList();
  }

  /// 확대/축소에 따른 실제 크기 조정된 스택 헤더 반환 - 캐싱 비활성화
  List<StackedHeaderRow> _getScaledStackedHeaders() {
    // 캐싱 제거: widget.stackedHeaders가 변경될 때마다 새로 생성
    // (헤더 테마 업데이트가 즉시 반영되도록 함)
    return widget.stackedHeaders.map((headerRow) {
      return StackedHeaderRow(
        cells: headerRow.cells.map((cell) {
          return StackedHeaderCell(
            columnNames: cell.columnNames,
            child: _getScaledTextWidget(cell.child, isHeader: true), // 헤더 셀 (파란색)
          );
        }).toList(),
      );
    }).toList();
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
                // 보강 수업 추가 로직 구현
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
    // 보강 수업 추가 로직은 향후 구현 예정
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('보강 수업 추가 기능이 구현될 예정입니다'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  /// 교체된 목적지 셀 디버그 출력
  void _debugPrintExchangedDestinationCells(List<String> destinationCellKeys) {
    if (destinationCellKeys.isEmpty) {
      AppLogger.exchangeDebug('교체된 목적지 셀: 없음');
      return;
    }
    
    AppLogger.exchangeDebug('=== 교체된 목적지 셀 목록 ===');
    AppLogger.exchangeDebug('총 ${destinationCellKeys.length}개 목적지 셀');
    AppLogger.exchangeDebug('목적지 셀 키들: $destinationCellKeys');
    
    for (int i = 0; i < destinationCellKeys.length; i++) {
      final cellKey = destinationCellKeys[i];
      final parts = cellKey.split('_');
      if (parts.length == 3) {
        final teacherName = parts[0];
        final day = parts[1];
        final period = int.tryParse(parts[2]) ?? 0;
        
        // 교체된 목적지 셀의 원본 데이터 찾기
        // 목적지 셀: 교체 후 새로운 교사가 배정된 셀
        // 이 셀에서는 원래 그 위치에 있던 교사의 수업 정보를 표시해야 함
        String? originalTeacherName;
        String? originalClassName;
        String? originalSubjectName;
        
        // 현재 교체 리스트에서 해당 위치의 원본 교사 찾기
        final exchangeList = _historyService.getExchangeList();
        
        for (final item in exchangeList) {
          if (item.originalPath is OneToOneExchangePath) {
            final path = item.originalPath as OneToOneExchangePath;
            final sourceNode = path.sourceNode;
            final targetNode = path.targetNode;
            
            // 목적지 셀에서 현재 교사가 이동한 위치인지 확인
            if (sourceNode.day == day && sourceNode.period == period && targetNode.teacherName == teacherName) {
              // sourceNode 위치로 targetNode 교사가 이동한 경우
              // 목적지 셀에서는 원래 sourceNode에 있던 교사의 데이터를 표시
              originalTeacherName = sourceNode.teacherName;
              originalClassName = sourceNode.className;
              originalSubjectName = sourceNode.subjectName;
              break;
            } else if (targetNode.day == day && targetNode.period == period && sourceNode.teacherName == teacherName) {
              // targetNode 위치로 sourceNode 교사가 이동한 경우
              // 목적지 셀에서는 원래 targetNode에 있던 교사의 데이터를 표시
              originalTeacherName = targetNode.teacherName;
              originalClassName = targetNode.className;
              originalSubjectName = targetNode.subjectName;
              break;
            }
          }
        }
        
        final displayClassName = originalClassName ?? '없음';
        final displaySubjectName = originalSubjectName ?? '없음';
        final displayOriginalTeacher = originalTeacherName != null ? ' (원본: $originalTeacherName)' : '';
        
        AppLogger.exchangeDebug('${i + 1}. 목적지 셀: $teacherName | $day$period교시 | $displayClassName | $displaySubjectName$displayOriginalTeacher');
      } else {
        AppLogger.exchangeDebug('${i + 1}. 목적지 셀: $cellKey (형식 오류)');
      }
    }
    AppLogger.exchangeDebug('========================');
  }
  

  /// 교체된 셀 클릭 처리
  /// 교체된 셀을 클릭했을 때 해당 교체 경로를 다시 선택하여 화살표 표시
  void _handleExchangedCellClick(String teacherName, String day, int period) {
    // 교체된 셀에 해당하는 교체 경로 찾기
    final exchangePath = _historyService.findExchangePathByCell(teacherName, day, period);
    
    if (exchangePath != null) {
      // 1단계: UI를 완전히 기본값으로 복원 (모든 교체 관련 상태 초기화)
      widget.onRestoreUIToDefault?.call();
      
      // 2단계: 즉시 새로운 교체 경로 설정
      _selectExchangePath(exchangePath);
      
      // 3단계: 교사 이름과 교시 헤더 하이라이트 업데이트
      // ExchangeScreen._updateHeaderTheme() 메서드를 호출하여
      // 교체된 셀에 해당하는 교사명과 교시의 헤더 스타일을 업데이트
      // FixedHeaderStyleManager와 SyncfusionTimetableHelper를 통해
      // 선택된 교사명과 교시 헤더가 하이라이트되도록 함
      widget.onHeaderThemeUpdate?.call();
      
    }
  }
  
  /// 교체 경로 상태 초기화 (공통 로직)
  void _resetPathSelections({bool updateUI = true, bool updateHeader = true}) {
    _internalSelectedPath = null;
    widget.dataSource?.updateSelectedOneToOnePath(null);
    widget.dataSource?.updateSelectedCircularPath(null);
    widget.dataSource?.updateSelectedChainPath(null);
    widget.dataSource?.clearAllCaches();
    
    // 헤더 테마 업데이트는 선택적으로 호출
    if (updateHeader) {
      widget.onHeaderThemeUpdate?.call();
    }

    if (updateUI && mounted) {
      setState(() {});
    }
  }

  /// 교체 경로 선택 처리
  void _selectExchangePath(ExchangePath exchangePath) {
    // 기존 경로 초기화 (헤더 업데이트 비활성화)
    _resetPathSelections(updateUI: false, updateHeader: false);

    // 새로운 경로 설정
    _internalSelectedPath = exchangePath;

    if (exchangePath is OneToOneExchangePath) {
      widget.dataSource!.updateSelectedOneToOnePath(exchangePath);
    } else if (exchangePath is CircularExchangePath) {
      widget.dataSource!.updateSelectedCircularPath(exchangePath);
    } else if (exchangePath is ChainExchangePath) {
      widget.dataSource!.updateSelectedChainPath(exchangePath);
    }

    setState(() {});
  }

  /// 교체 경로 선택 해제 (화살표 숨기기)
  void _clearExchangePathSelection() {
    _resetPathSelections();
  }

  /// 모드 전환 시 모든 화살표 상태 초기화 (외부에서 호출 가능)
  void clearAllArrowStates() {
    _resetPathSelections();
  }
  
  /// 셀 탭 이벤트 처리
  void _handleCellTap(DataGridCellTapDetails details) {
    // 교사명과 셀 정보 추출
    final teacherName = _extractTeacherNameFromRowIndex(details.rowColumnIndex.rowIndex);
    final columnName = details.column.columnName;
    
    // 교사명 열이 아닌 경우에만 처리
    if (columnName != 'teacher') {
      final parts = columnName.split('_');
      if (parts.length == 2) {
        final day = parts[0];
        final period = int.tryParse(parts[1]) ?? 0;
        
        // 교체된 셀인지 확인
        if (_historyService.getExchangedCellKeys().contains('${teacherName}_${day}_$period')) {
          // 교체된 셀 클릭 처리
          _handleExchangedCellClick(teacherName, day, period);
          return;
        }
      }
    }
    
    // 일반 셀 클릭 시 화살표 숨기기
    _clearExchangePathSelection();
    
    // 기존 셀 탭 이벤트 처리
    widget.onCellTap(details);
    
    // 셀 선택 후 헤더 테마 업데이트 호출
    // 교체 모드에서 셀을 선택했을 때 헤더 UI가 변경되도록 함
    widget.onHeaderThemeUpdate?.call();
  }
  
  /// 행 인덱스에서 교사명 추출
  String _extractTeacherNameFromRowIndex(int rowIndex) {
    // Syncfusion DataGrid에서 헤더 구조:
    // - 일반 헤더: 1개 (컬럼명 표시)
    // - 스택된 헤더: 1개 (요일별 병합)
    // 총 2개의 헤더 행이 있으므로 실제 데이터 행 인덱스는 2를 빼야 함
    const int headerRowCount = 2;
    int actualRowIndex = rowIndex - headerRowCount;
    
    if (widget.timetableData == null || actualRowIndex < 0 || actualRowIndex >= widget.timetableData!.teachers.length) {
      return '';
    }
    
    return widget.timetableData!.teachers[actualRowIndex].name;
  }

  /// 교체 리스트에서 삭제 기능
  void _deleteFromExchangeList() {
    if (currentSelectedPath == null) return;
    
    // 교체 리스트에서 해당 경로를 찾아서 삭제
    final exchangeList = _historyService.getExchangeList();
    final targetItem = exchangeList.firstWhere(
      (item) => item.originalPath.id == currentSelectedPath!.id,
      orElse: () => throw StateError('해당 교체 경로를 교체 리스트에서 찾을 수 없습니다'),
    );
    
    // 1. 교체 리스트에서 삭제 (히스토리 관리자 통해)
    _historyService.removeFromExchangeList(targetItem.id);
    
    // 2. 교체된 셀 목록 강제 업데이트
    _historyService.updateExchangedCells();
    
    // 3. 콘솔 출력
    _historyService.printExchangeList();
    _historyService.printUndoHistory();
    
    // 4. 교체된 셀 상태 업데이트
    final exchangedCellKeys = _historyService.getExchangedCellKeys();
    widget.dataSource!.updateExchangedCells(exchangedCellKeys);
    
    // 4-1. 교체된 목적지 셀 상태 업데이트
    final exchangedDestinationCellKeys = _historyService.getExchangedDestinationCellKeys();
    widget.dataSource!.updateExchangedDestinationCells(exchangedDestinationCellKeys);
    
    // 4-2. 교체된 목적지 셀 디버그 출력
    _debugPrintExchangedDestinationCells(exchangedDestinationCellKeys);
    
    // 5. 캐시 강제 무효화 및 UI 업데이트
    widget.dataSource!.clearAllCaches();
    
    // 6. 모든 선택 상태 초기화 (교체 삭제 후 모든 선택 상태 제거)
    widget.dataSource!.clearAllSelections();

    // 7. 내부 선택된 경로 초기화 (삭제 완료 후)
    _internalSelectedPath = null;

    // 8. UI 업데이트
    setState(() {});
  }

  /// 교체 실행 기능
  void _executeExchange() {
    if (currentSelectedPath == null) return;
    
    // 1. 교체 실행 (히스토리 관리자 통해)
    _historyService.executeExchange(
      currentSelectedPath!,
      customDescription: '교체 실행: ${currentSelectedPath!.displayTitle}',
      additionalMetadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'manual',
        'source': 'timetable_grid_section',
      },
    );
    
    // 2. 콘솔 출력
    _historyService.printExchangeList();
    _historyService.printUndoHistory();
    
    // 3. 교체된 셀 상태 업데이트
    final exchangedCellKeys = _historyService.getExchangedCellKeys();
    widget.dataSource!.updateExchangedCells(exchangedCellKeys);
    
    // 3-1. 교체된 목적지 셀 상태 업데이트
    final exchangedDestinationCellKeys = _historyService.getExchangedDestinationCellKeys();
    widget.dataSource!.updateExchangedDestinationCells(exchangedDestinationCellKeys);
    
    // 3-2. 교체된 목적지 셀 디버그 출력
    _debugPrintExchangedDestinationCells(exchangedDestinationCellKeys);
    
    // 4. 캐시 강제 무효화 및 UI 업데이트
    widget.dataSource!.clearAllCaches();

    // 5. 모든 선택 상태 초기화 (교체 완료 후 모든 선택 상태 제거)
    widget.dataSource!.clearAllSelections();

    // 6. 내부 선택된 경로 초기화 (교체 완료 후)
    _internalSelectedPath = null;

    // 7. UI 업데이트
    setState(() {});

    // 8. 사용자 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('교체 경로 "${currentSelectedPath!.id}"가 실행되었습니다'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '되돌리기',
          textColor: Colors.white,
          onPressed: () {
            _undoLastExchange();
          },
        ),
      ),
    );
  }

  /// 되돌리기 기능
  void _undoLastExchange() {
    // 1. 되돌리기 실행
    final item = _historyService.undoLastExchange();
    
    if (item != null) {
      // 2. 교체 리스트에서 삭제
      _historyService.removeFromExchangeList(item.id);
      
      // 3. 콘솔 출력
      _historyService.printExchangeList();
      _historyService.printUndoHistory();
      
      // 4. 교체된 셀 상태 업데이트
      final exchangedCellKeys = _historyService.getExchangedCellKeys();
      widget.dataSource!.updateExchangedCells(exchangedCellKeys);
      
      // 4-1. 교체된 목적지 셀 상태 업데이트
      final exchangedDestinationCellKeys = _historyService.getExchangedDestinationCellKeys();
      widget.dataSource!.updateExchangedDestinationCells(exchangedDestinationCellKeys);
      
      // 4-2. 교체된 목적지 셀 디버그 출력
      _debugPrintExchangedDestinationCells(exchangedDestinationCellKeys);
      
      // 5. 캐시 강제 무효화 및 UI 업데이트
      widget.dataSource!.clearAllCaches();

      // 6. 모든 선택 상태 초기화 (되돌리기 후 모든 선택 상태 제거)
      widget.dataSource!.clearAllSelections();

      // 7. UI 업데이트
      setState(() {});
      
      // 9. 사용자 피드백
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('교체 "${item.description}"가 되돌려졌습니다'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('되돌릴 교체가 없습니다'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 다시 반복 기능
  void _repeatLastExchange() {
    // 1. 마지막 교체 항목 조회
    final exchangeList = _historyService.getExchangeList();
    if (exchangeList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('반복할 교체가 없습니다'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // 가장 최근 교체 항목 가져오기
    final lastItem = exchangeList.last;
    
    // 2. 교체 다시 실행
    _historyService.executeExchange(
      lastItem.originalPath,
      customDescription: '다시 반복: ${lastItem.description}',
      additionalMetadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'repeat',
        'source': 'timetable_grid_section',
        'originalId': lastItem.id,
      },
    );
    
    // 3. 콘솔 출력
    _historyService.printExchangeList();
    _historyService.printUndoHistory();
    
    // 4. 교체된 셀 상태 업데이트
    final exchangedCellKeys = _historyService.getExchangedCellKeys();
    widget.dataSource!.updateExchangedCells(exchangedCellKeys);
    
    // 5. 캐시 강제 무효화 및 UI 업데이트
    widget.dataSource!.clearAllCaches();

    // 6. 모든 선택 상태 초기화 (다시 반복 후 모든 선택 상태 제거)
    widget.dataSource!.clearAllSelections();

    // 7. UI 업데이트
    setState(() {});

    // 8. 사용자 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('교체 "${lastItem.description}"가 다시 실행되었습니다'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  /// 교체 뷰 활성화
  void _enableExchangeView() {
    try {
      AppLogger.exchangeInfo('교체 뷰 활성화 시작');
      
      // 1. 현재 TimeSlot 데이터 백업 (되돌리기용)
      if (widget.dataSource != null && _originalTimeSlots == null) {
        _originalTimeSlots = widget.dataSource!.timeSlots.map((slot) => slot.copy()).toList();
        AppLogger.exchangeDebug('원본 TimeSlot 데이터 백업 완료: ${_originalTimeSlots!.length}개');
      }
      
      // 2. 교체 리스트에서 교체 실행
      final exchangeList = _historyService.getExchangeList();
      if (exchangeList.isNotEmpty) {
        AppLogger.exchangeInfo('교체 리스트에서 ${exchangeList.length}개 교체 실행');
        
        for (var item in exchangeList) {
          _executeExchangeFromHistory(item);
        }
        
        // 3. UI 업데이트
        widget.dataSource?.clearAllCaches();
        setState(() {});
        
        // 4. 교체 내역 로깅
        AppLogger.exchangeInfo('교체 뷰 활성화 완료 - ${exchangeList.length}개 교체 적용됨');
        for (int i = 0; i < exchangeList.length; i++) {
          var item = exchangeList[i];
          _logDetailedExchangeInfo(i + 1, item);
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
      
      if (_originalTimeSlots != null && widget.dataSource != null) {
        // 1. 원본 TimeSlot 데이터로 복원
        widget.dataSource!.updateData(_originalTimeSlots!, widget.timetableData!.teachers);
        
        // 2. UI 업데이트
        widget.dataSource?.clearAllCaches();
        setState(() {});
        
        // 3. 교체 내역 로깅
        AppLogger.exchangeInfo('교체 뷰 비활성화 완료 - 원본 상태로 복원됨');
        AppLogger.exchangeInfo('복원된 TimeSlot 개수: ${_originalTimeSlots!.length}개');
      } else {
        AppLogger.exchangeDebug('복원할 원본 데이터가 없습니다');
      }
    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 비활성화 중 오류 발생: $e');
    }
  }
  
  /// 교체 히스토리에서 교체 실행
  void _executeExchangeFromHistory(dynamic exchangeItem) {
    try {
      AppLogger.exchangeDebug('교체 히스토리 실행 시작: ${exchangeItem.runtimeType}');
      
      // ExchangeHistoryItem인 경우 originalPath를 추출
      ExchangePath? path;
      if (exchangeItem is ExchangeHistoryItem) {
        path = exchangeItem.originalPath;
        AppLogger.exchangeDebug('ExchangeHistoryItem에서 경로 추출: ${path.runtimeType}');
      } else if (exchangeItem is ExchangePath) {
        path = exchangeItem;
      }
      
      if (path != null) {
        if (path is OneToOneExchangePath) {
          _executeOneToOneExchangeFromPath(path);
        } else if (path is CircularExchangePath) {
          _executeCircularExchangeFromPath(path);
        } else if (path is ChainExchangePath) {
          _executeChainExchangeFromPath(path);
        } else {
          AppLogger.exchangeDebug('알 수 없는 교체 경로 타입: ${path.runtimeType}');
        }
      } else {
        AppLogger.exchangeDebug('교체 경로를 찾을 수 없음: ${exchangeItem.runtimeType}');
      }
    } catch (e) {
      AppLogger.exchangeDebug('교체 히스토리 실행 중 오류 발생: $e');
    }
  }
  
  /// 1:1 교체 경로에서 교체 실행
  void _executeOneToOneExchangeFromPath(OneToOneExchangePath path) {
    if (widget.timetableData == null) {
      AppLogger.exchangeDebug('1:1 교체 실행 실패: timetableData가 null');
      return;
    }
    
    final sourceNode = path.sourceNode;
    final targetNode = path.targetNode;
    
    // 교체 전 상태 로깅
    AppLogger.exchangeInfo('교체 전:');
    AppLogger.exchangeInfo('  └─ ${sourceNode.day}|${sourceNode.period}|${sourceNode.className}|${sourceNode.teacherName}|${sourceNode.subjectName}');
    AppLogger.exchangeInfo('  └─ ${targetNode.day}|${targetNode.period}|${targetNode.className}|${targetNode.teacherName}|${targetNode.subjectName}');
    
    AppLogger.exchangeInfo('1:1 교체 실행: ${sourceNode.teacherName}(${sourceNode.day}${sourceNode.period}교시) ↔ ${targetNode.teacherName}(${targetNode.day}${targetNode.period}교시)');
    
    bool success = _exchangeService.performOneToOneExchange(
      widget.dataSource!.timeSlots,
      sourceNode.teacherName,
      sourceNode.day,
      sourceNode.period,
      targetNode.teacherName,
      targetNode.day,
      targetNode.period,
    );
    
    if (success) {
      AppLogger.exchangeInfo('교체 후:');
      AppLogger.exchangeInfo('  └─ ${sourceNode.day}|${sourceNode.period}|${sourceNode.className}|${targetNode.teacherName}|${targetNode.subjectName}');
      AppLogger.exchangeInfo('  └─ ${targetNode.day}|${targetNode.period}|${targetNode.className}|${sourceNode.teacherName}|${sourceNode.subjectName}');
      AppLogger.exchangeInfo('✅ 1:1 교체 성공: ${sourceNode.teacherName}(${sourceNode.day}${sourceNode.period}교시) ↔ ${targetNode.teacherName}(${targetNode.day}${targetNode.period}교시)');
      
      // TimetableDataSource 업데이트
      widget.dataSource?.clearAllCaches();
      widget.dataSource?.updateData(widget.dataSource!.timeSlots, widget.timetableData!.teachers);
    } else {
      AppLogger.exchangeDebug('❌ 1:1 교체 실패: ${sourceNode.teacherName}(${sourceNode.day}${sourceNode.period}교시) ↔ ${targetNode.teacherName}(${targetNode.day}${targetNode.period}교시)');
    }
  }
  
  /// 순환 교체 경로에서 교체 실행
  void _executeCircularExchangeFromPath(CircularExchangePath path) {
    AppLogger.exchangeInfo('순환 교체 실행 (구현 예정): ${path.id}');
    AppLogger.exchangeDebug('순환 교체 노드 수: ${path.nodes.length}개');
    for (int i = 0; i < path.nodes.length; i++) {
      var node = path.nodes[i];
      AppLogger.exchangeDebug('노드 ${i + 1}: ${node.teacherName}(${node.day}${node.period}교시)');
    }
  }
  
  /// 연쇄 교체 경로에서 교체 실행
  void _executeChainExchangeFromPath(ChainExchangePath path) {
    AppLogger.exchangeInfo('연쇄 교체 실행 (구현 예정): ${path.id}');
    AppLogger.exchangeDebug('연쇄 교체 단계 수: ${path.steps.length}개');
    AppLogger.exchangeDebug('목표 노드: ${path.nodeA.teacherName}(${path.nodeA.day}${path.nodeA.period}교시)');
    AppLogger.exchangeDebug('대체 노드: ${path.nodeB.teacherName}(${path.nodeB.day}${path.nodeB.period}교시)');
  }
  
  /// 상세한 교체 정보 로깅
  void _logDetailedExchangeInfo(int exchangeNumber, dynamic exchangeItem) {
    try {
      // ExchangeHistoryItem인 경우 originalPath를 추출
      dynamic path = exchangeItem;
      if (exchangeItem is ExchangeHistoryItem) {
        path = exchangeItem.originalPath;
      }
      
      if (path is OneToOneExchangePath) {
        final sourceNode = path.sourceNode;
        final targetNode = path.targetNode;
        
        AppLogger.exchangeInfo('교체 $exchangeNumber: 1:1 교체');
        AppLogger.exchangeInfo('  └─ ${sourceNode.day}|${sourceNode.period}|${sourceNode.className}|${sourceNode.teacherName}|${sourceNode.subjectName}');
        AppLogger.exchangeInfo('  └─ ${targetNode.day}|${targetNode.period}|${targetNode.className}|${targetNode.teacherName}|${targetNode.subjectName}');
        AppLogger.exchangeInfo('  └─ 결과: ${sourceNode.teacherName}(${sourceNode.day}${sourceNode.period}교시) ↔ ${targetNode.teacherName}(${targetNode.day}${targetNode.period}교시)');
        
      } else if (path is CircularExchangePath) {
        AppLogger.exchangeInfo('교체 $exchangeNumber: 순환 교체 (구현 예정)');
        AppLogger.exchangeInfo('  └─ 순환 노드 수: ${path.nodes.length}개');
        for (int i = 0; i < path.nodes.length; i++) {
          var node = path.nodes[i];
          AppLogger.exchangeInfo('  └─ 노드 ${i + 1}: ${node.day}|${node.period}|${node.className}|${node.teacherName}|${node.subjectName}');
        }
        
      } else if (path is ChainExchangePath) {
        AppLogger.exchangeInfo('교체 $exchangeNumber: 연쇄 교체 (구현 예정)');
        AppLogger.exchangeInfo('  └─ 목표: ${path.nodeA.day}|${path.nodeA.period}|${path.nodeA.className}|${path.nodeA.teacherName}|${path.nodeA.subjectName}');
        AppLogger.exchangeInfo('  └─ 대체: ${path.nodeB.day}|${path.nodeB.period}|${path.nodeB.className}|${path.nodeB.teacherName}|${path.nodeB.subjectName}');
        AppLogger.exchangeInfo('  └─ 단계 수: ${path.steps.length}개');
        
      } else {
        AppLogger.exchangeInfo('교체 $exchangeNumber: 알 수 없는 교체 타입 (${exchangeItem.runtimeType})');
      }
    } catch (e) {
      AppLogger.exchangeDebug('교체 $exchangeNumber 상세 정보 로깅 중 오류: $e');
    }
  }
}

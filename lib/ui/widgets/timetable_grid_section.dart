import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/excel_service.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/constants.dart';
import '../../utils/exchange_visualizer.dart';
import '../../models/one_to_one_exchange_path.dart';

/// 화살표의 시작점과 끝점이 어느 경계면에서 나야 하는지 결정하는 열거형
enum ArrowEdge {
  top,    // 상단 경계면 중앙
  bottom, // 하단 경계면 중앙
  left,   // 왼쪽 경계면 중앙
  right,  // 오른쪽 경계면 중앙
}

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
  final OneToOneExchangePath? selectedOneToOnePath; // 선택된 1:1 교체 경로

  const TimetableGridSection({
    super.key,
    required this.timetableData,
    required this.dataSource,
    required this.columns,
    required this.stackedHeaders,
    required this.isExchangeModeEnabled,
    required this.exchangeableCount,
    required this.onCellTap,
    this.selectedOneToOnePath, // 선택된 1:1 교체 경로
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

  @override
  void initState() {
    super.initState();
    // 스크롤 이벤트 리스너 추가 - 화살표 재그리기를 위해
    _verticalScrollController.addListener(_onScrollChanged);
    _horizontalScrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _verticalScrollController.removeListener(_onScrollChanged);
    _horizontalScrollController.removeListener(_onScrollChanged);
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  /// 스크롤 변경 시 화살표 재그리기를 위한 콜백
  void _onScrollChanged() {
    if (widget.selectedOneToOnePath != null && widget.isExchangeModeEnabled) {
      setState(() {
        // 화살표가 표시되는 경우에만 재그리기
      });
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            _buildHeader(),
            
            const SizedBox(height: 16),
            
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
        Icon(
          Icons.grid_on,
          color: Colors.green.shade600,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          '시간표 그리드 (Syncfusion)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade600,
          ),
        ),
        const Spacer(),
        
        // 파싱 통계 표시
        _buildTeacherCountWidget(),
        
        const SizedBox(width: 8),
        
        // 교체 모드가 활성화된 경우에만 교체 가능한 수업 개수 표시
        if (widget.isExchangeModeEnabled)
          ExchangeVisualizer.buildExchangeableCountWidget(widget.exchangeableCount),
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
    Widget dataGrid = _buildDataGrid();
    
    // 1:1 교체 경로가 선택된 경우에만 화살표 표시
    if (widget.selectedOneToOnePath != null && widget.isExchangeModeEnabled) {
      return Stack(
        children: [
          dataGrid,
          // 화살표를 그리는 CustomPainter 오버레이 (터치 이벤트 무시)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ExchangeArrowPainter(
                  selectedPath: widget.selectedOneToOnePath!,
                  timetableData: widget.timetableData!,
                  columns: widget.columns,
                  verticalScrollController: _verticalScrollController,
                  horizontalScrollController: _horizontalScrollController,
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    return dataGrid;
  }

  /// DataGrid 구성
  Widget _buildDataGrid() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SfDataGrid(
        key: _dataGridKey, // 스크롤 제어를 위한 GlobalKey 추가
        source: widget.dataSource!,
        columns: widget.columns,
        stackedHeaderRows: widget.stackedHeaders,
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        headerRowHeight: AppConstants.headerRowHeight,
        rowHeight: AppConstants.dataRowHeight,
        allowColumnsResizing: false,
        allowSorting: false,
        allowEditing: false,
        allowTriStateSorting: false,
        allowPullToRefresh: false,
        selectionMode: SelectionMode.none,
        columnWidthMode: ColumnWidthMode.none,
        frozenColumnsCount: 1, // 교사명 열(첫 번째 열) 고정
        onCellTap: widget.onCellTap, // 셀 탭 이벤트 핸들러
        // 스크롤 컨트롤러 설정
        verticalScrollController: _verticalScrollController,
        horizontalScrollController: _horizontalScrollController,
        // 스크롤바 설정 - 명확하게 보이도록 설정
        isScrollbarAlwaysShown: true, // 스크롤바 항상 표시
        horizontalScrollPhysics: const AlwaysScrollableScrollPhysics(), // 가로 스크롤 활성화
        verticalScrollPhysics: const AlwaysScrollableScrollPhysics(), // 세로 스크롤 활성화
      ),
    );
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
    
    double targetRowOffset = teacherIndex * AppConstants.dataRowHeight;
    
    // 중앙 정렬인 경우 뷰포트 높이의 절반만큼 조정
    if (AppConstants.scrollAlignment == ScrollAlignment.center) {
      double viewportHeight = _verticalScrollController.position.viewportDimension;
      double cellHeight = AppConstants.dataRowHeight;
      targetRowOffset = targetRowOffset - (viewportHeight / 2) + (cellHeight / 2);
      
      // 스크롤 범위 내로 제한
      targetRowOffset = targetRowOffset.clamp(
        _verticalScrollController.position.minScrollExtent,
        _verticalScrollController.position.maxScrollExtent,
      );
    }
    
    _verticalScrollController.animateTo(
      targetRowOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }
  
  /// 가로 스크롤 실행
  void _scrollHorizontally(int scrollableColumnIndex) {
    if (!_horizontalScrollController.hasClients) return;
    
    double targetColumnOffset = scrollableColumnIndex * AppConstants.periodColumnWidth;
    
    // 중앙 정렬인 경우 뷰포트 너비의 절반만큼 조정
    if (AppConstants.scrollAlignment == ScrollAlignment.center) {
      double viewportWidth = _horizontalScrollController.position.viewportDimension;
      double cellWidth = AppConstants.periodColumnWidth;
      targetColumnOffset = targetColumnOffset - (viewportWidth / 2) + (cellWidth / 2);
      
      // 스크롤 범위 내로 제한
      targetColumnOffset = targetColumnOffset.clamp(
        _horizontalScrollController.position.minScrollExtent,
        _horizontalScrollController.position.maxScrollExtent,
      );
    }
    
    _horizontalScrollController.animateTo(
      targetColumnOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }
}

/// 교체 경로 화살표를 그리는 CustomPainter
class ExchangeArrowPainter extends CustomPainter {
  final OneToOneExchangePath selectedPath;
  final TimetableData timetableData;
  final List<GridColumn> columns;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;

  ExchangeArrowPainter({
    required this.selectedPath,
    required this.timetableData,
    required this.columns,
    required this.verticalScrollController,
    required this.horizontalScrollController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sourceNode = selectedPath.sourceNode;
    final targetNode = selectedPath.targetNode;

    // 교사 인덱스 찾기
    int sourceTeacherIndex = timetableData.teachers
        .indexWhere((teacher) => teacher.name == sourceNode.teacherName);
    int targetTeacherIndex = timetableData.teachers
        .indexWhere((teacher) => teacher.name == targetNode.teacherName);

    if (sourceTeacherIndex == -1 || targetTeacherIndex == -1) {
      return;
    }

    // 컬럼 인덱스 찾기
    String sourceColumnName = '${sourceNode.day}_${sourceNode.period}';
    String targetColumnName = '${targetNode.day}_${targetNode.period}';
    
    int sourceColumnIndex = columns
        .indexWhere((column) => column.columnName == sourceColumnName);
    int targetColumnIndex = columns
        .indexWhere((column) => column.columnName == targetColumnName);

    if (sourceColumnIndex == -1 || targetColumnIndex == -1) {
      return;
    }

    // 화살표의 시작점과 끝점 경계면 결정
    Map<String, ArrowEdge> edges = _determineArrowEdges(
      sourceColumnIndex,
      sourceTeacherIndex,
      targetColumnIndex,
      targetTeacherIndex,
    );

    // 시작점과 끝점 위치 계산
    Offset sourcePos = _getCellEdgePosition(
      sourceColumnIndex,
      sourceTeacherIndex,
      edges['start']!,
    );

    Offset targetPos = _getCellEdgePosition(
      targetColumnIndex,
      targetTeacherIndex,
      edges['end']!,
    );

    // 화면 영역 내에 화살표가 있는지 검사
    if (!_isArrowVisible(sourcePos, targetPos, size)) {
      return; // 화면 밖에 있으면 그리지 않음
    }

    // 고정 영역 클리핑 적용
    canvas.save();
    _applyFrozenAreaClipping(canvas, size);

    // 직각 방향 화살표 그리기 (외곽선과 내부선)
    _drawRightAngleArrowWithOutline(canvas, sourcePos, targetPos);
    
    canvas.restore();
  }

  /// 고정 영역 클리핑을 적용하는 메서드
  /// 스크롤 가능한 영역에서만 화살표 그리기를 허용 (고정 영역에서는 가림)
  /// 
  /// [canvas] 그리기 캔버스
  /// [size] 캔버스 크기
  void _applyFrozenAreaClipping(Canvas canvas, Size size) {
    // 고정 영역 경계 계산
    const double frozenColumnWidth = AppConstants.teacherColumnWidth; // 고정 열 너비
    const double headerHeight = AppConstants.headerRowHeight * 2; // 헤더 행 높이 (2개 행)
    
    // 스크롤 가능한 영역만 허용하는 클리핑 경로 생성
    Path clippingPath = Path();
    
    // 스크롤 가능한 영역만 허용: 고정 열 오른쪽, 헤더 아래쪽
    clippingPath.addRect(Rect.fromLTWH(
      frozenColumnWidth,  // 고정 열 오른쪽부터
      headerHeight,       // 헤더 아래쪽부터
      size.width - frozenColumnWidth,  // 나머지 너비
      size.height - headerHeight,     // 나머지 높이
    ));
    
    // 클리핑 적용 - 스크롤 영역에서만 그리기 허용
    canvas.clipPath(clippingPath);
  }

  /// 화살표가 화면 영역 내에 있는지 검사하는 메서드
  /// 고정 영역과 스크롤 영역을 모두 고려
  /// 
  /// [sourcePos] 화살표 시작점 좌표
  /// [targetPos] 화살표 끝점 좌표
  /// [canvasSize] 캔버스 크기
  /// 
  /// Returns: bool - 화살표가 화면에 보이는지 여부
  bool _isArrowVisible(Offset sourcePos, Offset targetPos, Size canvasSize) {
    // 고정 영역 경계
    const double frozenColumnWidth = AppConstants.teacherColumnWidth;
    const double headerHeight = AppConstants.headerRowHeight * 2;
    
    // 화살표의 모든 점들 (시작점, 끝점, 중간점)
    List<Offset> arrowPoints = [
      sourcePos,
      targetPos,
      Offset(sourcePos.dx, targetPos.dy), // 직각 화살표의 중간점
    ];
    
    // 각 점이 보이는 영역에 있는지 검사
    for (Offset point in arrowPoints) {
      if (_isPointInVisibleArea(point, canvasSize, frozenColumnWidth, headerHeight)) {
        return true; // 하나라도 보이는 영역에 있으면 화살표를 그림
      }
    }
    
    return false; // 모든 점이 보이지 않는 영역에 있으면 그리지 않음
  }

  /// 특정 점이 보이는 영역에 있는지 검사하는 메서드
  /// 스크롤 가능한 영역에서만 화살표를 그리도록 함
  /// 
  /// [point] 검사할 점의 좌표
  /// [canvasSize] 캔버스 크기
  /// [frozenColumnWidth] 고정 열 너비
  /// [headerHeight] 헤더 높이
  /// 
  /// Returns: bool - 점이 스크롤 영역에 있는지 여부
  bool _isPointInVisibleArea(Offset point, Size canvasSize, double frozenColumnWidth, double headerHeight) {
    // 스크롤 가능한 영역에서만 화살표 그리기 허용
    // 고정 열 오른쪽, 헤더 아래쪽 영역만 허용
    bool inScrollableArea = point.dx > frozenColumnWidth && 
                           point.dy > headerHeight &&
                           point.dx <= canvasSize.width && 
                           point.dy <= canvasSize.height;
    
    return inScrollableArea;
  }

  /// 셀의 상대적 위치에 따라 화살표의 시작점과 끝점 경계면을 결정하는 함수
  /// 
  /// [sourceColumnIndex] 시작 셀의 열 인덱스
  /// [sourceTeacherIndex] 시작 셀의 교사 인덱스
  /// [targetColumnIndex] 목표 셀의 열 인덱스
  /// [targetTeacherIndex] 목표 셀의 교사 인덱스
  /// 
  /// Returns: Map&lt;String, ArrowEdge&gt; - 'start'와 'end' 키로 시작점과 끝점의 경계면 반환
  Map<String, ArrowEdge> _determineArrowEdges(
    int sourceColumnIndex,
    int sourceTeacherIndex,
    int targetColumnIndex,
    int targetTeacherIndex,
  ) {
    // 상대적 위치 계산
    bool isTargetBelow = targetTeacherIndex > sourceTeacherIndex; // 목표가 아래쪽에 있는지
    bool isTargetRight = targetColumnIndex > sourceColumnIndex;   // 목표가 오른쪽에 있는지
    bool isTargetAbove = targetTeacherIndex < sourceTeacherIndex; // 목표가 위쪽에 있는지
    bool isTargetLeft = targetColumnIndex < sourceColumnIndex;   // 목표가 왼쪽에 있는지

    // 시작점 경계면 결정
    ArrowEdge startEdge;
    if (isTargetBelow) {
      startEdge = ArrowEdge.bottom; // 목표가 아래쪽: 하단에서 시작
    } else if (isTargetAbove) {
      startEdge = ArrowEdge.top;    // 목표가 위쪽: 상단에서 시작
    } else {
      // 같은 행에 있는 경우, 열 위치에 따라 결정
      if (isTargetRight) {
        startEdge = ArrowEdge.right; // 목표가 오른쪽: 오른쪽에서 시작
      } else if (isTargetLeft) {
        startEdge = ArrowEdge.left;  // 목표가 왼쪽: 왼쪽에서 시작
      } else {
        startEdge = ArrowEdge.right; // 같은 위치 (기본값)
      }
    }

    // 끝점 경계면 결정
    ArrowEdge endEdge;
    if (isTargetRight) {
      endEdge = ArrowEdge.left;   // 목표가 오른쪽: 왼쪽 경계면에서 끝
    } else if (isTargetLeft) {
      endEdge = ArrowEdge.right;  // 목표가 왼쪽: 오른쪽 경계면에서 끝
    } else {
      // 같은 열에 있는 경우, 행 위치에 따라 결정
      if (isTargetBelow) {
        endEdge = ArrowEdge.top;    // 목표가 아래쪽: 상단에서 끝
      } else if (isTargetAbove) {
        endEdge = ArrowEdge.bottom; // 목표가 위쪽: 하단에서 끝
      } else {
        endEdge = ArrowEdge.left;   // 같은 위치 (기본값)
      }
    }

    return {
      'start': startEdge,
      'end': endEdge,
    };
  }

  /// 셀의 경계면 중앙 위치 계산 (화살표 시작점/끝점용)
  /// 스크롤 오프셋과 고정 영역을 반영하여 실제 화면상의 위치를 계산
  /// 
  /// [columnIndex] 셀의 열 인덱스
  /// [teacherIndex] 셀의 교사 인덱스
  /// [edge] 경계면 종류 (상, 하, 좌, 우)
  /// 
  /// Returns: Offset - 경계면 중앙의 좌표 (스크롤 오프셋 및 고정 영역 반영)
  Offset _getCellEdgePosition(int columnIndex, int teacherIndex, ArrowEdge edge) {
    // 기본 X 좌표 계산
    double x = 0;
    for (int i = 0; i < columnIndex; i++) {
      if (i == 0) {
        // 교사명 열 너비 (고정 열)
        x += AppConstants.teacherColumnWidth;
      } else {
        // 교시 열 너비
        x += AppConstants.periodColumnWidth;
      }
    }

    // 기본 Y 좌표 계산 (고정된 헤더 행들 고려)
    double y = AppConstants.headerRowHeight * 2; // 헤더 행 2개 높이
    y += teacherIndex * AppConstants.dataRowHeight; // 교사 인덱스에 따른 행 높이

    // 스크롤 오프셋 반영 (고정 영역 고려)
    double horizontalOffset = 0.0;
    double verticalOffset = verticalScrollController.hasClients 
        ? verticalScrollController.offset 
        : 0.0;

    // 고정 열(교사명 열)이 아닌 경우에만 가로 스크롤 오프셋 적용
    if (columnIndex > 0) {
      horizontalOffset = horizontalScrollController.hasClients 
          ? horizontalScrollController.offset 
          : 0.0;
    }

    // 스크롤 오프셋을 좌표에 반영
    x -= horizontalOffset;
    y -= verticalOffset;

    // 셀의 경계면 중앙 위치 계산
    if (columnIndex == 0) {
      // 교사명 열의 경우
      switch (edge) {
        case ArrowEdge.top:
          x += AppConstants.teacherColumnWidth / 2; // 가로 중앙
          y += 0; // 상단
          break;
        case ArrowEdge.bottom:
          x += AppConstants.teacherColumnWidth / 2; // 가로 중앙
          y += AppConstants.dataRowHeight; // 하단
          break;
        case ArrowEdge.left:
          x += 0; // 왼쪽 경계
          y += AppConstants.dataRowHeight / 2; // 세로 중앙
          break;
        case ArrowEdge.right:
          x += AppConstants.teacherColumnWidth; // 오른쪽 경계
          y += AppConstants.dataRowHeight / 2; // 세로 중앙
          break;
      }
    } else {
      // 교시 열의 경우
      switch (edge) {
        case ArrowEdge.top:
          x += AppConstants.periodColumnWidth / 2; // 가로 중앙
          y += 0; // 상단
          break;
        case ArrowEdge.bottom:
          x += AppConstants.periodColumnWidth / 2; // 가로 중앙
          y += AppConstants.dataRowHeight; // 하단
          break;
        case ArrowEdge.left:
          x += 0; // 왼쪽 경계
          y += AppConstants.dataRowHeight / 2; // 세로 중앙
          break;
        case ArrowEdge.right:
          x += AppConstants.periodColumnWidth; // 오른쪽 경계
          y += AppConstants.dataRowHeight / 2; // 세로 중앙
          break;
      }
    }

    return Offset(x, y);
  }

  /// 직각 방향 화살표 그리기 (외곽선과 내부선)
  void _drawRightAngleArrowWithOutline(Canvas canvas, Offset start, Offset end) {
    // 직각 방향으로 그리기 위해 중간점 계산
    Offset midPoint = Offset(start.dx, end.dy);
    
    // 외곽선용 Paint (흰색, 더 두꺼운 선)
    final outlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // 내부선용 Paint (연한 녹색, 얇은 선)
    final innerPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.7) // 연한 녹색
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // 직선 그리기 (시작점 -> 중간점 -> 끝점)
    Path path = Path();
    path.moveTo(start.dx, start.dy);
    path.lineTo(midPoint.dx, midPoint.dy);
    path.lineTo(end.dx, end.dy);
    
    // 외곽선 먼저 그리기
    canvas.drawPath(path, outlinePaint);
    
    // 내부선 그리기
    canvas.drawPath(path, innerPaint);
    
    // 화살표 머리 그리기 (외곽선과 내부선)
    _drawArrowHeadWithOutline(canvas, midPoint, end);
  }


  /// 화살표 머리 그리기 (외곽선과 내부선)
  void _drawArrowHeadWithOutline(Canvas canvas, Offset from, Offset to) {
    // 화살표 머리 크기
    double headLength = 12.0;
    double headAngle = 0.5; // 라디안

    // 방향 벡터 계산
    double dx = to.dx - from.dx;
    double dy = to.dy - from.dy;
    double distance = math.sqrt(dx * dx + dy * dy);

    if (distance == 0) return;

    // 정규화
    dx /= distance;
    dy /= distance;

    // 화살표 머리 점들 계산
    double x1 = to.dx - headLength * (dx * math.cos(headAngle) + dy * math.sin(headAngle));
    double y1 = to.dy - headLength * (dy * math.cos(headAngle) - dx * math.sin(headAngle));
    
    double x2 = to.dx - headLength * (dx * math.cos(-headAngle) + dy * math.sin(-headAngle));
    double y2 = to.dy - headLength * (dy * math.cos(-headAngle) - dx * math.sin(-headAngle));

    // 외곽선용 Paint (흰색, 더 두꺼운 선)
    final outlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 내부선용 Paint (연한 녹색, 얇은 선)
    final innerPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.7) // 연한 녹색
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 화살표 머리 그리기 (외곽선 먼저)
    Path arrowHead = Path();
    arrowHead.moveTo(to.dx, to.dy);
    arrowHead.lineTo(x1, y1);
    arrowHead.moveTo(to.dx, to.dy);
    arrowHead.lineTo(x2, y2);
    
    // 외곽선 먼저 그리기
    canvas.drawPath(arrowHead, outlinePaint);
    
    // 내부선 그리기
    canvas.drawPath(arrowHead, innerPaint);
  }


  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ExchangeArrowPainter &&
           oldDelegate.selectedPath != selectedPath;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../services/excel_service.dart';
import '../../../models/exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/exchange_node.dart';
import '../../../utils/constants.dart';
import 'timetable_grid_constants.dart';
import 'exchange_arrow_style.dart';

/// 교체 경로 화살표를 그리는 CustomPainter
class ExchangeArrowPainter extends CustomPainter {
  final ExchangePath selectedPath;
  final TimetableData timetableData;
  final List<GridColumn> columns;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final ExchangeArrowStyle? customArrowStyle;
  final double zoomFactor; // 클리핑 계산용 (실제 크기는 이미 조정됨)

  ExchangeArrowPainter({
    required this.selectedPath,
    required this.timetableData,
    required this.columns,
    required this.verticalScrollController,
    required this.horizontalScrollController,
    this.customArrowStyle,
    required this.zoomFactor, // 클리핑 계산용
  }) : assert(columns.isNotEmpty, 'columns cannot be empty'),
       assert(zoomFactor > 0, 'zoomFactor must be positive');

  @override
  void paint(Canvas canvas, Size size) {
    // 안전성 검사: 필수 데이터가 유효하지 않은 경우 그리기 중단
    if (columns.isEmpty ||
        size.width <= 0 || 
        size.height <= 0) {
      return;
    }

    try {
      // 교체 경로 타입에 따라 다른 화살표 그리기
      switch (selectedPath.type) {
        case ExchangePathType.oneToOne:
          _drawOneToOneArrows(canvas, size);
          break;
        case ExchangePathType.circular:
          _drawCircularArrows(canvas, size);
          break;
        case ExchangePathType.chain:
          _drawChainArrows(canvas, size);
          break;
      }
    } catch (e) {
      // 오류 발생 시 안전하게 종료 (디버그 모드에서만 로그 출력)
      debugPrint('ExchangeArrowPainter paint error: $e');
    }
  }

  /// 1:1 교체 화살표 그리기 (2개의 단방향 화살표)
  void _drawOneToOneArrows(Canvas canvas, Size size) {
    final oneToOnePath = selectedPath as OneToOneExchangePath;
    final sourceNode = oneToOnePath.sourceNode;
    final targetNode = oneToOnePath.targetNode;

    // A → B 방향 화살표 그리기 (세로 우선, 머리 사이즈 12)
    _drawArrowBetweenNodes(canvas, size, sourceNode, targetNode, priority: ArrowPriority.verticalFirst, arrowHeadSize: 12.0);
    
    // B → A 방향 화살표 그리기 (세로 우선, 머리 사이즈 12)
    _drawArrowBetweenNodes(canvas, size, targetNode, sourceNode, priority: ArrowPriority.verticalFirst, arrowHeadSize: 12.0);
  }

  /// 순환 교체 화살표 그리기
  void _drawCircularArrows(Canvas canvas, Size size) {
    final circularPath = selectedPath as CircularExchangePath;
    final nodes = circularPath.nodes;

    // 순환 경로의 각 단계별로 화살표 그리기 (가로 우선, 머리 사이즈 10)
    for (int i = 0; i < nodes.length - 1; i++) {
      
      // 4단계 이상인 경우에만 화살표 중간점에 숫자 표시
      String? stepText = nodes.length >= 4 ? "${i + 1}" : null;
      
      _drawArrowBetweenNodes(canvas, size, nodes[i], nodes[i + 1], priority: ArrowPriority.horizontalFirst, arrowHeadSize: 10.0, text: stepText);
    }
    
    // 순환 교체의 핵심: 마지막 노드에서 첫 번째 노드로 돌아가는 화살표 그리기
    if (nodes.length > 4) { // 5개 이상 노드가 있어야 마지막 화살표 그리기
      
      // 마지막 화살표에도 단계 번호 표시 (마지막 단계 번호)
      String lastStepText = "${nodes.length}";
      _drawArrowBetweenNodes(canvas, size, nodes.last, nodes.first, priority: ArrowPriority.horizontalFirst, arrowHeadSize: 10.0, text: lastStepText);
    }
  }

  /// 연쇄 교체 화살표 그리기
  void _drawChainArrows(Canvas canvas, Size size) {
    final chainPath = selectedPath as ChainExchangePath;
    
    // 연쇄 교체의 각 단계별로 화살표 그리기 (세로 우선, 머리 사이즈 8, 단계별 텍스트)
    int stepNumber = 1;
    for (final step in chainPath.steps) {
      if (step.stepType == 'exchange') {
        _drawArrowBetweenNodes(canvas, size, step.fromNode, step.toNode, priority: ArrowPriority.verticalFirst, arrowHeadSize: 8.0, text: "$stepNumber");
        stepNumber++;
      }
    }
  }

  /// 두 노드 간의 화살표 그리기
  void _drawArrowBetweenNodes(Canvas canvas, Size size, ExchangeNode sourceNode, ExchangeNode targetNode, {ArrowPriority priority = ArrowPriority.verticalFirst, double? arrowHeadSize, String? text}) {
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

    // 화살표의 시작점과 끝점을 셀의 경계면 중앙으로 설정
    Map<String, ArrowEdge> edges = _determineArrowEdges(
      sourceColumnIndex,
      sourceTeacherIndex,
      targetColumnIndex,
      targetTeacherIndex,
      priority,
    );

    Offset sourcePos = _getCellEdgeCenterPosition(
      sourceColumnIndex,
      sourceTeacherIndex,
      edges['start']!,
    );

    Offset targetPos = _getCellEdgeCenterPosition(
      targetColumnIndex,
      targetTeacherIndex,
      edges['end']!,
    );

    // 화면 영역 내에 화살표가 있는지 검사
    bool isVisible = _isArrowVisible(sourcePos, targetPos, size);
    if (!isVisible) {
      return; // 화면 밖에 있으면 그리지 않음
    }

    // 고정 영역 클리핑 적용
    canvas.save();
    _applyFrozenAreaClipping(canvas, size);

    // 교체 경로 타입에 따른 스타일 적용하여 화살표 그리기 (우선 방향, 머리 사이즈, 텍스트 지정)
    _drawStyledArrow(canvas, sourcePos, targetPos, priority: priority, arrowHeadSize: arrowHeadSize, text: text);
    
    canvas.restore();
  }


  /// 고정 영역 클리핑을 적용하는 메서드
  /// 스크롤 가능한 영역에서만 화살표 그리기를 허용 (고정 영역에서는 가림)
  /// 
  /// [canvas] 그리기 캔버스
  /// [size] 캔버스 크기
  void _applyFrozenAreaClipping(Canvas canvas, Size size) {
    // 고정 영역 경계 계산 (실제 크기 조정된 값 사용)
    double frozenColumnWidth = AppConstants.teacherColumnWidth * zoomFactor; // 실제 확대된 고정 열 너비
    double headerHeight = (AppConstants.headerRowHeight * GridLayoutConstants.headerRowsCount) * zoomFactor; // 실제 확대된 헤더 행 높이
    
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
    // 고정 영역 경계 (확대/축소 배율 적용)
    double frozenColumnWidth = AppConstants.teacherColumnWidth * zoomFactor;
    double headerHeight = (AppConstants.headerRowHeight * GridLayoutConstants.headerRowsCount) * zoomFactor;
    
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
    
    // 모든 점이 화면 밖에 있어도 화살표가 화면 영역과 교차하는지 확인
    return _isArrowIntersectingVisibleArea(sourcePos, targetPos, canvasSize, frozenColumnWidth, headerHeight);
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

  /// 화살표가 화면 영역과 교차하는지 확인하는 메서드
  /// 직각 화살표의 두 선분이 화면 영역과 교차하는지 검사
  /// 
  /// [sourcePos] 화살표 시작점 좌표
  /// [targetPos] 화살표 끝점 좌표
  /// [canvasSize] 캔버스 크기
  /// [frozenColumnWidth] 고정 열 너비
  /// [headerHeight] 헤더 높이
  /// 
  /// Returns: bool - 화살표가 화면 영역과 교차하는지 여부
  bool _isArrowIntersectingVisibleArea(Offset sourcePos, Offset targetPos, Size canvasSize, double frozenColumnWidth, double headerHeight) {
    // 화면 영역 정의 (스크롤 가능한 영역)
    Rect visibleArea = Rect.fromLTWH(
      frozenColumnWidth,
      headerHeight,
      canvasSize.width - frozenColumnWidth,
      canvasSize.height - headerHeight,
    );

    // 직각 화살표의 중간점 계산 (세로 우선 기준)
    Offset midPoint = Offset(sourcePos.dx, targetPos.dy);

    // 첫 번째 선분: 시작점 → 중간점
    bool firstSegmentIntersects = _lineIntersectsRect(sourcePos, midPoint, visibleArea);
    
    // 두 번째 선분: 중간점 → 끝점
    bool secondSegmentIntersects = _lineIntersectsRect(midPoint, targetPos, visibleArea);

    return firstSegmentIntersects || secondSegmentIntersects;
  }

  /// 선분이 사각형과 교차하는지 확인하는 메서드
  /// 
  /// [start] 선분 시작점
  /// [end] 선분 끝점
  /// [rect] 사각형 영역
  /// 
  /// Returns: bool - 선분이 사각형과 교차하는지 여부
  bool _lineIntersectsRect(Offset start, Offset end, Rect rect) {
    // 선분의 경계 상자
    Rect lineBounds = Rect.fromPoints(start, end);
    
    // 경계 상자가 사각형과 교차하는지 확인
    if (!rect.overlaps(lineBounds)) {
      return false;
    }

    // 선분의 양 끝점이 사각형 내부에 있는지 확인
    if (rect.contains(start) || rect.contains(end)) {
      return true;
    }

    // 선분이 사각형의 경계와 교차하는지 확인
    // 수직선인 경우
    if (start.dx == end.dx) {
      double x = start.dx;
      if (x >= rect.left && x <= rect.right) {
        double minY = math.min(start.dy, end.dy);
        double maxY = math.max(start.dy, end.dy);
        return !(maxY < rect.top || minY > rect.bottom);
      }
    }
    
    // 수평선인 경우
    if (start.dy == end.dy) {
      double y = start.dy;
      if (y >= rect.top && y <= rect.bottom) {
        double minX = math.min(start.dx, end.dx);
        double maxX = math.max(start.dx, end.dx);
        return !(maxX < rect.left || minX > rect.right);
      }
    }

    return false;
  }



  /// 셀의 경계면 중앙 위치 계산 (화살표 시작점/끝점용)
  /// 스크롤 오프셋과 고정 영역을 반영하여 실제 화면상의 위치를 계산
  /// 
  /// [columnIndex] 셀의 열 인덱스
  /// [teacherIndex] 셀의 교사 인덱스
  /// [edge] 경계면 종류 (상, 하, 좌, 우)
  /// 
  /// Returns: Offset - 경계면 중앙의 좌표 (스크롤 오프셋 및 고정 영역 반영)
  Offset _getCellEdgeCenterPosition(int columnIndex, int teacherIndex, ArrowEdge edge) {
    // 기본 X 좌표 계산 (줌 배율 적용)
    double x = 0;
    for (int i = 0; i < columnIndex; i++) {
      if (i == 0) {
        // 교사명 열 너비 (고정 열) - 줌 배율 적용
        x += AppConstants.teacherColumnWidth * zoomFactor;
      } else {
        // 교시 열 너비 - 줌 배율 적용
        x += AppConstants.periodColumnWidth * zoomFactor;
      }
    }

    // 기본 Y 좌표 계산 (고정된 헤더 행들 고려, 줌 배율 적용)
    double y = AppConstants.headerRowHeight * GridLayoutConstants.headerRowsCount * zoomFactor; // 헤더 행 높이 - 줌 배율 적용
    y += teacherIndex * AppConstants.dataRowHeight * zoomFactor; // 교사 인덱스에 따른 행 높이 - 줌 배율 적용

    // 스크롤 오프셋 반영 (고정 영역 고려) - 안전한 방식으로 오프셋 가져오기
    double horizontalOffset = 0.0;
    double verticalOffset = 0.0;
    
    try {
      // 세로 스크롤 오프셋 안전하게 가져오기
      if (verticalScrollController.hasClients && verticalScrollController.positions.isNotEmpty) {
        verticalOffset = verticalScrollController.offset;
      }
      
      // 고정 열(교사명 열)이 아닌 경우에만 가로 스크롤 오프셋 적용
      if (columnIndex > 0) {
        if (horizontalScrollController.hasClients && horizontalScrollController.positions.isNotEmpty) {
          horizontalOffset = horizontalScrollController.offset;
        }
      }
    } catch (e) {
      // ScrollController 오류 발생 시 기본값 사용 (디버그 모드에서만 로그 출력)
      debugPrint('ExchangeArrowPainter ScrollController 오류: $e');
      horizontalOffset = 0.0;
      verticalOffset = 0.0;
    }

    // 스크롤 오프셋을 좌표에 반영
    x -= horizontalOffset;
    y -= verticalOffset;

    // 셀의 경계면 중앙 위치 계산
    if (columnIndex == 0) {
      // 교사명 열의 경우
      switch (edge) {
        case ArrowEdge.top:
          x += AppConstants.teacherColumnWidth * zoomFactor / 2; // 가로 중앙 - 줌 배율 적용
          y += 0; // 상단
          break;
        case ArrowEdge.bottom:
          x += AppConstants.teacherColumnWidth * zoomFactor / 2; // 가로 중앙 - 줌 배율 적용
          y += AppConstants.dataRowHeight * zoomFactor; // 하단 - 줌 배율 적용
          break;
        case ArrowEdge.left:
          x += 0; // 왼쪽 경계
          y += AppConstants.dataRowHeight * zoomFactor / 2; // 세로 중앙 - 줌 배율 적용
          break;
        case ArrowEdge.right:
          x += AppConstants.teacherColumnWidth * zoomFactor; // 오른쪽 경계 - 줌 배율 적용
          y += AppConstants.dataRowHeight * zoomFactor / 2; // 세로 중앙 - 줌 배율 적용
          break;
      }
    } else {
      // 교시 열의 경우
      switch (edge) {
        case ArrowEdge.top:
          x += AppConstants.periodColumnWidth * zoomFactor / 2; // 가로 중앙 - 줌 배율 적용
          y += 0; // 상단
          break;
        case ArrowEdge.bottom:
          x += AppConstants.periodColumnWidth * zoomFactor / 2; // 가로 중앙 - 줌 배율 적용
          y += AppConstants.dataRowHeight * zoomFactor; // 하단 - 줌 배율 적용
          break;
        case ArrowEdge.left:
          x += 0; // 왼쪽 경계
          y += AppConstants.dataRowHeight * zoomFactor / 2; // 세로 중앙 - 줌 배율 적용
          break;
        case ArrowEdge.right:
          x += AppConstants.periodColumnWidth * zoomFactor; // 오른쪽 경계 - 줌 배율 적용
          y += AppConstants.dataRowHeight * zoomFactor / 2; // 세로 중앙 - 줌 배율 적용
          break;
      }
    }

    // 실제 크기가 조정되므로 원본 좌표 사용 (클리핑은 실제 크기로 자동 조정됨)
    return Offset(x, y);
  }

  /// 화살표의 시작점과 끝점 경계면을 결정하는 함수
  /// 
  /// [sourceColumnIndex] 시작 셀의 열 인덱스
  /// [sourceTeacherIndex] 시작 셀의 교사 인덱스
  /// [targetColumnIndex] 목표 셀의 열 인덱스
  /// [targetTeacherIndex] 목표 셀의 교사 인덱스
  /// [priority] 화살표 우선 방향 (세로 우선 또는 가로 우선)
  /// 
  /// Returns: `Map<String, ArrowEdge>` - 'start'와 'end' 키로 시작점과 끝점의 경계면 반환
  Map<String, ArrowEdge> _determineArrowEdges(
    int sourceColumnIndex,
    int sourceTeacherIndex,
    int targetColumnIndex,
    int targetTeacherIndex,
    ArrowPriority priority,
  ) {
    // 상대적 위치 계산
    bool isTargetBelow = targetTeacherIndex > sourceTeacherIndex; // 목표가 아래쪽에 있는지
    bool isTargetRight = targetColumnIndex > sourceColumnIndex;   // 목표가 오른쪽에 있는지
    bool isTargetAbove = targetTeacherIndex < sourceTeacherIndex; // 목표가 위쪽에 있는지
    bool isTargetLeft = targetColumnIndex < sourceColumnIndex;   // 목표가 왼쪽에 있는지

    ArrowEdge startEdge;
    ArrowEdge endEdge;

    if (priority == ArrowPriority.verticalFirst) {
      // 세로 우선: 먼저 세로 이동, 그 다음 가로 이동
      // 시작점: 세로 방향으로 나가도록
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

      // 끝점: 가로 방향으로 들어오도록
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
    } else {
      // 가로 우선: 먼저 가로 이동, 그 다음 세로 이동
      // 시작점: 가로 방향으로 나가도록
      if (isTargetRight) {
        startEdge = ArrowEdge.right; // 목표가 오른쪽: 오른쪽에서 시작
      } else if (isTargetLeft) {
        startEdge = ArrowEdge.left;  // 목표가 왼쪽: 왼쪽에서 시작
      } else {
        // 같은 열에 있는 경우, 행 위치에 따라 결정
        if (isTargetBelow) {
          startEdge = ArrowEdge.bottom; // 목표가 아래쪽: 하단에서 시작
        } else if (isTargetAbove) {
          startEdge = ArrowEdge.top;    // 목표가 위쪽: 상단에서 시작
        } else {
          startEdge = ArrowEdge.right; // 같은 위치 (기본값)
        }
      }

      // 끝점: 세로 방향으로 들어오도록
      if (isTargetBelow) {
        endEdge = ArrowEdge.top;    // 목표가 아래쪽: 상단에서 끝
      } else if (isTargetAbove) {
        endEdge = ArrowEdge.bottom; // 목표가 위쪽: 하단에서 끝
      } else {
        // 같은 행에 있는 경우, 열 위치에 따라 결정
        if (isTargetRight) {
          endEdge = ArrowEdge.left;   // 목표가 오른쪽: 왼쪽 경계면에서 끝
        } else if (isTargetLeft) {
          endEdge = ArrowEdge.right;  // 목표가 왼쪽: 오른쪽 경계면에서 끝
        } else {
          endEdge = ArrowEdge.left;   // 같은 위치 (기본값)
        }
      }
    }

    return {
      'start': startEdge,
      'end': endEdge,
    };
  }

  /// 스타일이 적용된 화살표 그리기
  void _drawStyledArrow(Canvas canvas, Offset start, Offset end, {ArrowPriority priority = ArrowPriority.verticalFirst, double? arrowHeadSize, String? text}) {
    // 교체 경로 타입에 따른 스타일 결정
    ExchangeArrowStyle style = _getArrowStyle();
    
    // 커스텀 머리 사이즈가 있으면 스타일에 적용
    if (arrowHeadSize != null) {
      style = ExchangeArrowStyle(
        color: style.color,
        strokeWidth: style.strokeWidth,
        outlineColor: style.outlineColor,
        outlineWidth: style.outlineWidth,
        arrowHeadSize: arrowHeadSize,
        direction: style.direction,
      );
    }
    
    // 우선 방향에 따라 직각 화살표 그리기
    _drawRightAngleArrowWithStyle(canvas, start, end, style, priority: priority, text: text);
  }


  /// 교체 경로 타입에 따른 화살표 스타일 결정
  ExchangeArrowStyle _getArrowStyle() {
    // 커스텀 스타일이 있으면 사용
    if (customArrowStyle != null) {
      return customArrowStyle!;
    }
    
    // 교체 경로 타입에 따른 기본 스타일
    switch (selectedPath.type) {
      case ExchangePathType.oneToOne:
        return ExchangeArrowStyle.oneToOne;
      case ExchangePathType.circular:
        return ExchangeArrowStyle.circular;
      case ExchangePathType.chain:
        return ExchangeArrowStyle.chain;
    }
  }

  /// 직각 방향 화살표 그리기 (외곽선과 내부선) - 스타일 적용 버전
  void _drawRightAngleArrowWithStyle(Canvas canvas, Offset start, Offset end, ExchangeArrowStyle style, {ArrowPriority priority = ArrowPriority.verticalFirst, String? text}) {
    // 우선 방향에 따라 중간점 계산
    Offset midPoint;
    if (priority == ArrowPriority.verticalFirst) {
      // 세로 우선: 먼저 수직 이동, 그 다음 수평 이동
      midPoint = Offset(start.dx, end.dy);
    } else {
      // 가로 우선: 먼저 수평 이동, 그 다음 수직 이동
      midPoint = Offset(end.dx, start.dy);
    }
    
    // 외곽선용 Paint (설정된 외곽선 색상과 두께)
    final outlinePaint = Paint()
      ..color = style.outlineColor
      ..strokeWidth = style.outlineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // 내부선용 Paint (설정된 색상과 두께)
    final innerPaint = Paint()
      ..color = style.color
      ..strokeWidth = style.strokeWidth
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
    
    // 화살표 방향에 따른 머리 그리기
    switch (style.direction) {
      case ArrowDirection.forward:
        // 시작 → 끝 방향만 화살표 머리 그리기
        _drawArrowHeadWithStyle(canvas, midPoint, end, style);
        break;
      case ArrowDirection.bidirectional:
        // 양쪽 방향 화살표 머리 그리기
        _drawArrowHeadWithStyle(canvas, midPoint, end, style); // 끝점 방향
        _drawArrowHeadWithStyle(canvas, midPoint, start, style); // 시작점 방향
        break;
    }
    
    // 텍스트가 있으면 중간점에 텍스트 그리기
    if (text != null && text.isNotEmpty) {
      _drawArrowText(canvas, midPoint, text, style);
    }
  }

  /// 화살표 중간점에 텍스트 그리기
  void _drawArrowText(Canvas canvas, Offset position, String text, ExchangeArrowStyle style) {
    // 텍스트 스타일 설정
    final textStyle = TextStyle(
      fontSize: ArrowConstants.textFontSize,
      fontWeight: FontWeight.bold,
      color: style.color,
    );

    // 텍스트 페인트 설정
    final textPaint = Paint()
      ..color = Colors.white  // 배경색 (외곽선)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = style.color  // 텍스트 색상
      ..style = PaintingStyle.stroke
      ..strokeWidth = ArrowConstants.textOutlineWidth;
    
    // 텍스트 크기 계산
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // 텍스트 위치 계산 (중간점을 중심으로)
    final textOffset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );
    
    // 텍스트 배경 원 그리기 (원 크기를 더 작게 조정)
    final backgroundRadius = math.max(textPainter.width, textPainter.height) / 2 + ArrowConstants.textBackgroundPadding;
    canvas.drawCircle(position, backgroundRadius, textPaint);
    canvas.drawCircle(position, backgroundRadius, outlinePaint);
    
    // 텍스트 그리기
    textPainter.paint(canvas, textOffset);
  }

  /// 화살표 머리 그리기 (외곽선과 내부선) - 스타일 적용 버전
  void _drawArrowHeadWithStyle(Canvas canvas, Offset from, Offset to, ExchangeArrowStyle style) {
    // 화살표 머리 크기 (스타일에서 설정)
    double headLength = style.arrowHeadSize;
    double headAngle = ArrowConstants.headAngle;

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

    // 외곽선용 Paint (설정된 외곽선 색상과 두께)
    final outlinePaint = Paint()
      ..color = style.outlineColor
      ..strokeWidth = style.outlineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 내부선용 Paint (설정된 색상과 두께)
    final innerPaint = Paint()
      ..color = style.color
      ..strokeWidth = style.strokeWidth
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
    // 타입 검사 및 안전성 검사
    if (oldDelegate is! ExchangeArrowPainter) {
      return true; // 다른 타입의 CustomPainter인 경우 재그리기
    }

    final oldPainter = oldDelegate;
    
    // 핵심 데이터 변경 확인
    bool hasChanged = false;
    
    // 선택된 경로 변경 확인
    if (oldPainter.selectedPath.id != selectedPath.id) {
      hasChanged = true;
    }
    
    // 커스텀 화살표 스타일 변경 확인
    if (oldPainter.customArrowStyle != customArrowStyle) {
      hasChanged = true;
    }
    
    // 확대/축소 배율 변경 확인
    if ((oldPainter.zoomFactor - zoomFactor).abs() > 0.001) {
      hasChanged = true;
    }
    
    // 스크롤 위치 변경 확인 (화살표 위치에 영향) - 안전한 방식으로 확인
    try {
      // 세로 스크롤 위치 변경 확인
      if (oldPainter.verticalScrollController.hasClients && 
          oldPainter.verticalScrollController.positions.isNotEmpty &&
          verticalScrollController.hasClients && 
          verticalScrollController.positions.isNotEmpty) {
        if ((oldPainter.verticalScrollController.offset - verticalScrollController.offset).abs() > 1.0) {
          hasChanged = true;
        }
      }
      
      // 가로 스크롤 위치 변경 확인
      if (oldPainter.horizontalScrollController.hasClients && 
          oldPainter.horizontalScrollController.positions.isNotEmpty &&
          horizontalScrollController.hasClients && 
          horizontalScrollController.positions.isNotEmpty) {
        if ((oldPainter.horizontalScrollController.offset - horizontalScrollController.offset).abs() > 1.0) {
          hasChanged = true;
        }
      }
    } catch (e) {
      // ScrollController 오류 발생 시 변경사항이 있다고 가정하여 재그리기
      debugPrint('ExchangeArrowPainter shouldRepaint ScrollController 오류: $e');
      hasChanged = true;
    }
    
    return hasChanged;
  }
}

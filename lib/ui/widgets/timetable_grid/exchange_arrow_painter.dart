import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../services/excel_service.dart';
import '../../../models/exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/dual_exchange_path.dart';
import '../../../models/supplement_exchange_path.dart';
import '../../../models/exchange_node.dart';
import '../../../utils/constants.dart';
import 'timetable_grid_constants.dart';
import 'exchange_arrow_style.dart';
import 'exchange_arrow_step.dart';
import 'exchange_arrow_draw_helper.dart';

/// 교체 경로 화살표를 그리는 CustomPainter
class ExchangeArrowPainter extends CustomPainter {
  final ExchangePath selectedPath;
  final TimetableData timetableData;
  final List<GridColumn> columns;
  final ExchangeArrowStyle? customArrowStyle;
  final double zoomFactor; // 클리핑 계산용 (실제 크기는 이미 조정됨)
  final Offset scrollOffset; // 스크롤 오프셋 (화살표가 스크롤을 따라 이동)

  /// 1:1 교체 화살표 방향 (설정값, 기본: 단방향)
  final ArrowDirection oneToOneArrowDirection;

  /// 2중 교체 화살표 방향 (설정값, 기본: 양방향)
  final ArrowDirection dualArrowDirection;

  ExchangeArrowPainter({
    required this.selectedPath,
    required this.timetableData,
    required this.columns,
    this.customArrowStyle,
    required this.zoomFactor, // 클리핑 계산용
    required this.scrollOffset, // 스크롤 오프셋
    this.oneToOneArrowDirection = ArrowDirection.bidirectional,
    this.dualArrowDirection = ArrowDirection.bidirectional,
  }) : assert(columns.isNotEmpty, 'columns cannot be empty'),
       assert(zoomFactor > 0, 'zoomFactor must be positive');

  @override
  void paint(Canvas canvas, Size size) {
    // 안전성 검사: 필수 데이터가 유효하지 않은 경우 그리기 중단
    if (columns.isEmpty || size.width <= 0 || size.height <= 0) {
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
        case ExchangePathType.dual:
          _drawDualArrows(canvas, size);
          break;
        case ExchangePathType.supplement:
          _drawSupplementArrows(canvas, size);
          break;
      }
    } catch (e) {
      // 오류 발생 시 안전하게 종료 (디버그 모드에서만 로그 출력)
      debugPrint('ExchangeArrowPainter paint error: $e');
    }
  }

  /// 두 노드 사이 화살표 그리기를 헬퍼에 위임하기 위한 콜백 생성
  /// [positionOffset]만큼 화살표 전체 좌표를 평행 이동시키는 콜백을 만든다.
  /// (2중 교체에서 그룹 간 겹침을 피하기 위해 특정 그룹 전체를 이동할 때 사용)
  ArrowDrawCallback _arrowDrawCallback(
    Canvas canvas,
    Size size, {
    Offset positionOffset = Offset.zero,
    bool dashed = false,
  }) {
    return (
      ExchangeNode from,
      ExchangeNode to, {
      ArrowPriority priority = ArrowPriority.verticalFirst,
      double? arrowHeadSize,
      String? text,
      ArrowDirection direction = ArrowDirection.forward,
    }) {
      _drawArrowBetweenNodes(
        canvas,
        size,
        from,
        to,
        priority: priority,
        arrowHeadSize: arrowHeadSize,
        text: text,
        direction: direction,
        positionOffset: positionOffset,
        dashed: dashed,
      );
    };
  }

  /// 1:1 교체 화살표 그리기
  ///
  /// - 단방향(기본): A→B, B→A 2개의 선을 각각 단방향 화살표로 그린다.
  /// - 양방향: 1개의 선에 양쪽 화살표 머리(↔)와 중간 숫자 "1"을 그린다.
  void _drawOneToOneArrows(Canvas canvas, Size size) {
    final oneToOnePath = selectedPath as OneToOneExchangePath;
    final draw = _arrowDrawCallback(canvas, size);

    if (oneToOneArrowDirection == ArrowDirection.bidirectional) {
      ExchangeArrowDrawHelper.drawStepArrows(
        steps: [
          ExchangeArrowStep(
            fromNode: oneToOnePath.sourceNode,
            toNode: oneToOnePath.targetNode,
            stepNumber: 1,
          ),
        ],
        direction: ArrowDirection.bidirectional,
        drawArrow: draw,
        arrowHeadSize: 12.0,
      );
    } else {
      ExchangeArrowDrawHelper.drawSplitUnidirectional(
        nodeA: oneToOnePath.sourceNode,
        nodeB: oneToOnePath.targetNode,
        drawArrow: draw,
        arrowHeadSize: 12.0,
      );
    }
  }

  /// 순환 교체 화살표 그리기
  void _drawCircularArrows(Canvas canvas, Size size) {
    final circularPath = selectedPath as CircularExchangePath;
    final nodes = circularPath.nodes;

    // 순환 경로의 각 단계별로 화살표 그리기 (가로 우선, 머리 사이즈 10)
    for (int i = 0; i < nodes.length - 1; i++) {
      // 4단계 이상인 경우에만 화살표 중간점에 숫자 표시
      String? stepText = nodes.length >= 4 ? "${i + 1}" : null;

      _drawArrowBetweenNodes(
        canvas,
        size,
        nodes[i],
        nodes[i + 1],
        priority: ArrowPriority.horizontalFirst,
        arrowHeadSize: 10.0,
        text: stepText,
      );
    }

    // 순환 교체의 핵심: 마지막 노드에서 첫 번째 노드로 돌아가는 화살표 그리기
    if (nodes.length > 4) {
      // 5개 이상 노드가 있어야 마지막 화살표 그리기

      // 마지막 화살표에도 단계 번호 표시 (마지막 단계 번호)
      String lastStepText = "${nodes.length}";
      _drawArrowBetweenNodes(
        canvas,
        size,
        nodes.last,
        nodes.first,
        priority: ArrowPriority.horizontalFirst,
        arrowHeadSize: 10.0,
        text: lastStepText,
      );
    }
  }

  /// 2중 교체 화살표 그리기
  ///
  /// 1:1 교체와 동일한 방향 의미를 따른다.
  /// - 단방향: 각 교체를 A→B, B→A 2선으로 분리 (교체 2개 → 총 4선). 중간 숫자 없음.
  /// - 양방향: 각 교체를 양쪽 머리(↔) 1선으로 (교체 2개 → 2선) + 중간 숫자 "1","2".
  ///
  /// 1번 그룹(1단계)은 **점선**으로, 2번 그룹(2단계)은 실선으로 그려 단계를 구분한다.
  /// 단방향에서는 1번 그룹을 셀 모서리를 따라 이동시켜 2번 그룹과 겹치지 않게 한다.
  /// 어느 방향이든 셀 모서리 단계 번호(1, 2)는 오버레이에서 별도로 표시된다.
  void _drawDualArrows(Canvas canvas, Size size) {
    final dualPath = selectedPath as DualExchangePath;
    final steps = _dualPathToSteps(dualPath);

    for (final step in steps) {
      final bool isFirstGroup = step.stepNumber == 1; // 1번 그룹: 점선 + 오프셋

      if (dualArrowDirection == ArrowDirection.bidirectional) {
        // 양방향: 각 교체를 ↔ 1선으로
        ExchangeArrowDrawHelper.drawStepArrows(
          steps: [step],
          direction: ArrowDirection.bidirectional,
          drawArrow: _arrowDrawCallback(canvas, size, dashed: isFirstGroup),
          arrowHeadSize: 8.0,
        );
      } else {
        // 단방향: 각 교체를 A→B, B→A 2선으로 분리
        // 1번 그룹 화살표를 셀 모서리를 따라 이동시켜 2번 그룹과 겹치지 않게 한다.
        final Offset groupOffset =
            isFirstGroup
                ? Offset(
                      ArrowConstants.dualFirstGroupOffsetX,
                      ArrowConstants.dualFirstGroupOffsetY,
                    ) *
                    zoomFactor
                : Offset.zero;

        ExchangeArrowDrawHelper.drawSplitUnidirectional(
          nodeA: step.fromNode,
          nodeB: step.toNode,
          drawArrow: _arrowDrawCallback(
            canvas,
            size,
            positionOffset: groupOffset,
            dashed: isFirstGroup,
          ),
          arrowHeadSize: 8.0,
        );
      }
    }
  }

  /// 2중 교체 경로를 화살표 단계 목록으로 변환
  ///
  /// 'exchange' 타입 단계만 포함하며, 단계 번호는 1부터 순차 증가한다.
  List<ExchangeArrowStep> _dualPathToSteps(DualExchangePath dualPath) {
    final steps = <ExchangeArrowStep>[];
    int stepNumber = 1;
    for (final step in dualPath.steps) {
      if (step.stepType == 'exchange') {
        steps.add(
          ExchangeArrowStep(
            fromNode: step.fromNode,
            toNode: step.toNode,
            stepNumber: stepNumber,
          ),
        );
        stepNumber++;
      }
    }
    return steps;
  }

  /// 보강 화살표 그리기 (단방향 화살표)
  void _drawSupplementArrows(Canvas canvas, Size size) {
    final supplementPath = selectedPath as SupplementExchangePath;
    final sourceNode = supplementPath.sourceNode; // 보강할 셀 (수업이 있는 셀)
    final targetNode = supplementPath.targetNode; // 보강할 교사 (빈 셀)

    // 보강는 보강할 교사(빈 셀)에서 보강할 셀(수업이 있는 셀)로의 방향
    // 보강 전용 화살표 그리기 (명시적 방향 지정)
    _drawSupplementArrowDirectly(canvas, size, targetNode, sourceNode);
  }

  /// 보강 전용 화살표 그리기 (직접 그리기 방식)
  /// 보강는 같은 교시의 다른 교사들 간 교체이므로 수직선으로 직접 그리기
  void _drawSupplementArrowDirectly(
    Canvas canvas,
    Size size,
    ExchangeNode sourceNode,
    ExchangeNode targetNode,
  ) {
    // 교사 인덱스 찾기
    int sourceTeacherIndex = timetableData.teachers.indexWhere(
      (teacher) => teacher.name == sourceNode.teacherName,
    );
    int targetTeacherIndex = timetableData.teachers.indexWhere(
      (teacher) => teacher.name == targetNode.teacherName,
    );

    if (sourceTeacherIndex == -1 || targetTeacherIndex == -1) {
      return;
    }

    // 컬럼 인덱스 찾기 (보강는 같은 교시이므로 같은 컬럼)
    String columnName = '${sourceNode.day}_${sourceNode.period}';
    int columnIndex = columns.indexWhere(
      (column) => column.columnName == columnName,
    );

    if (columnIndex == -1) {
      return;
    }

    // 보강 스타일 가져오기
    ExchangeArrowStyle style = ExchangeArrowStyle.supplement;

    // 보강 전용: 시작점은 보강 교사(빈 셀)의 정중앙
    // (다른 교체 모드처럼 셀 경계 밖이 아닌 셀 안쪽에서 출발)
    Offset sourcePos = _getCellCenterPosition(columnIndex, sourceTeacherIndex);

    // 끝점은 수업이 있는 셀의 경계면 중앙 (기존 로직 유지)
    Map<String, ArrowEdge> edges = _determineArrowEdges(
      columnIndex,
      sourceTeacherIndex,
      columnIndex,
      targetTeacherIndex,
      ArrowPriority.verticalFirst,
    );
    Offset targetPos = _getCellEdgeCenterPosition(
      columnIndex,
      targetTeacherIndex,
      edges['end']!,
    );

    // 화면 영역 내에 화살표가 있는지 검사
    bool isVisible = _isArrowVisible(sourcePos, targetPos, size);
    if (!isVisible) {
      return;
    }

    // 고정 영역 클리핑 적용
    canvas.save();
    _applyFrozenAreaClipping(canvas, size);

    // 수직선 그리기 (외곽선 먼저)
    final outlinePaint =
        Paint()
          ..color = style.outlineColor
          ..strokeWidth = style.outlineWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final innerPaint =
        Paint()
          ..color = style.color
          ..strokeWidth = style.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    // 외곽선 먼저 그리기
    canvas.drawLine(sourcePos, targetPos, outlinePaint);

    // 내부선 그리기
    canvas.drawLine(sourcePos, targetPos, innerPaint);

    // 화살표 머리 그리기 (source에서 target 방향)
    _drawArrowHeadWithStyle(canvas, sourcePos, targetPos, style);

    canvas.restore();
  }

  /// 두 노드 간의 화살표 그리기
  void _drawArrowBetweenNodes(
    Canvas canvas,
    Size size,
    ExchangeNode sourceNode,
    ExchangeNode targetNode, {
    ArrowPriority priority = ArrowPriority.verticalFirst,
    double? arrowHeadSize,
    String? text,
    ArrowDirection? direction,
    Offset positionOffset = Offset.zero,
    bool dashed = false,
  }) {
    // 교사 인덱스 찾기
    int sourceTeacherIndex = timetableData.teachers.indexWhere(
      (teacher) => teacher.name == sourceNode.teacherName,
    );
    int targetTeacherIndex = timetableData.teachers.indexWhere(
      (teacher) => teacher.name == targetNode.teacherName,
    );

    if (sourceTeacherIndex == -1 || targetTeacherIndex == -1) {
      return;
    }

    // 컬럼 인덱스 찾기
    String sourceColumnName = '${sourceNode.day}_${sourceNode.period}';
    String targetColumnName = '${targetNode.day}_${targetNode.period}';

    int sourceColumnIndex = columns.indexWhere(
      (column) => column.columnName == sourceColumnName,
    );
    int targetColumnIndex = columns.indexWhere(
      (column) => column.columnName == targetColumnName,
    );

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

    // 그룹 단위 분리 (2중 교체에서 2번 그룹을 1번 그룹과 분리)
    // 시작/끝점이 셀 경계에서 떨어지지 않도록, 오프셋을 각 모서리의 접선 방향으로만 적용한다.
    // (상/하단 모서리 → x 방향만, 좌/우 모서리 → y 방향만 이동)
    if (positionOffset != Offset.zero) {
      sourcePos += _offsetAlongEdge(edges['start']!, positionOffset);
      targetPos += _offsetAlongEdge(edges['end']!, positionOffset);
    }

    // 화면 영역 내에 화살표가 있는지 검사
    bool isVisible = _isArrowVisible(sourcePos, targetPos, size);
    if (!isVisible) {
      return; // 화면 밖에 있으면 그리지 않음
    }

    // 고정 영역 클리핑 적용
    canvas.save();
    _applyFrozenAreaClipping(canvas, size);

    // 교체 경로 타입에 따른 스타일 적용하여 화살표 그리기 (우선 방향, 머리 사이즈, 텍스트, 방향, 점선 지정)
    _drawStyledArrow(
      canvas,
      sourcePos,
      targetPos,
      priority: priority,
      arrowHeadSize: arrowHeadSize,
      text: text,
      direction: direction,
      dashed: dashed,
    );

    canvas.restore();
  }

  /// 주어진 경로를 대시(점선) 패턴으로 그린다.
  ///
  /// PathMetric으로 경로를 길이 기준으로 잘라 [ArrowConstants.dashLength]만큼
  /// 그리고 [ArrowConstants.dashGapLength]만큼 띄우기를 반복한다.
  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final double dash = ArrowConstants.dashLength;
    final double gap = ArrowConstants.dashGapLength;
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  /// 셀 모서리의 접선 방향으로만 오프셋을 적용한다.
  ///
  /// 끝점이 셀 경계(모서리) 위에 그대로 남도록, 모서리에 수직인 성분은 버리고
  /// 모서리를 따라 미끄러지는 성분만 사용한다.
  /// - 상/하단(수평) 모서리: x 성분만 적용
  /// - 좌/우(수직) 모서리: y 성분만 적용
  Offset _offsetAlongEdge(ArrowEdge edge, Offset offset) {
    switch (edge) {
      case ArrowEdge.top:
      case ArrowEdge.bottom:
        return Offset(offset.dx, 0);
      case ArrowEdge.left:
      case ArrowEdge.right:
        return Offset(0, offset.dy);
    }
  }

  /// 고정 영역 클리핑을 적용하는 메서드
  /// 스크롤 가능한 영역에서만 화살표 그리기를 허용 (고정 영역에서는 가림)
  ///
  /// [canvas] 그리기 캔버스
  /// [size] 캔버스 크기
  void _applyFrozenAreaClipping(Canvas canvas, Size size) {
    // 고정 영역 경계 계산 (실제 크기 조정된 값 사용)
    double frozenColumnWidth =
        AppConstants.teacherColumnWidth * zoomFactor; // 실제 확대된 고정 열 너비
    double headerHeight =
        (AppConstants.headerRowHeight * GridLayoutConstants.headerRowsCount) *
        zoomFactor; // 실제 확대된 헤더 행 높이

    // 스크롤 가능한 영역만 허용하는 클리핑 경로 생성
    Path clippingPath = Path();

    // 스크롤 가능한 영역만 허용: 고정 열 오른쪽, 헤더 아래쪽
    clippingPath.addRect(
      Rect.fromLTWH(
        frozenColumnWidth, // 고정 열 오른쪽부터
        headerHeight, // 헤더 아래쪽부터
        size.width - frozenColumnWidth, // 나머지 너비
        size.height - headerHeight, // 나머지 높이
      ),
    );

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
    double headerHeight =
        (AppConstants.headerRowHeight * GridLayoutConstants.headerRowsCount) *
        zoomFactor;

    // 화살표의 모든 점들 (시작점, 끝점, 중간점)
    List<Offset> arrowPoints = [
      sourcePos,
      targetPos,
      Offset(sourcePos.dx, targetPos.dy), // 직각 화살표의 중간점
    ];

    // 각 점이 보이는 영역에 있는지 검사
    for (Offset point in arrowPoints) {
      if (_isPointInVisibleArea(
        point,
        canvasSize,
        frozenColumnWidth,
        headerHeight,
      )) {
        return true; // 하나라도 보이는 영역에 있으면 화살표를 그림
      }
    }

    // 모든 점이 화면 밖에 있어도 화살표가 화면 영역과 교차하는지 확인
    return _isArrowIntersectingVisibleArea(
      sourcePos,
      targetPos,
      canvasSize,
      frozenColumnWidth,
      headerHeight,
    );
  }

  /// 특정 점이 보이는 영역에 있는지 검사하는 메서드
  /// 화면 영역에서만 화살표를 그리도록 함
  ///
  /// [point] 검사할 점의 좌표
  /// [canvasSize] 캔버스 크기
  /// [frozenColumnWidth] 고정 열 너비
  /// [headerHeight] 헤더 높이
  ///
  /// Returns: bool - 점이 화면 영역에 있는지 여부
  bool _isPointInVisibleArea(
    Offset point,
    Size canvasSize,
    double frozenColumnWidth,
    double headerHeight,
  ) {
    // 화면 영역에서만 화살표 그리기 허용
    // 고정 열 오른쪽, 헤더 아래쪽 영역만 허용
    bool inVisibleArea =
        point.dx > frozenColumnWidth &&
        point.dy > headerHeight &&
        point.dx <= canvasSize.width &&
        point.dy <= canvasSize.height;

    return inVisibleArea;
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
  bool _isArrowIntersectingVisibleArea(
    Offset sourcePos,
    Offset targetPos,
    Size canvasSize,
    double frozenColumnWidth,
    double headerHeight,
  ) {
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
    bool firstSegmentIntersects = _lineIntersectsRect(
      sourcePos,
      midPoint,
      visibleArea,
    );

    // 두 번째 선분: 중간점 → 끝점
    bool secondSegmentIntersects = _lineIntersectsRect(
      midPoint,
      targetPos,
      visibleArea,
    );

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

  /// 컬럼 너비 (줌 배율 적용) — 0번 열은 교사명 고정열, 이후는 교시 열
  double _columnWidth(int columnIndex) {
    final base =
        columnIndex == 0
            ? AppConstants.teacherColumnWidth
            : AppConstants.periodColumnWidth;
    return base * zoomFactor;
  }

  /// 데이터 행 높이 (줌 배율 적용)
  double get _rowHeight => AppConstants.dataRowHeight * zoomFactor;

  /// 셀 좌상단 좌표 계산 (헤더·스크롤 오프셋·고정 영역 반영)
  ///
  /// 셀 중앙/경계면 좌표 계산의 공통 기준점이다.
  /// 교사명 열(columnIndex == 0)은 고정 영역이므로 수평 스크롤을 적용하지 않는다.
  Offset _getCellOrigin(int columnIndex, int teacherIndex) {
    double x = 0;
    for (int i = 0; i < columnIndex; i++) {
      x += _columnWidth(i);
    }

    double y =
        AppConstants.headerRowHeight *
        GridLayoutConstants.headerRowsCount *
        zoomFactor;
    y += teacherIndex * _rowHeight;

    // 교사명 열은 고정 영역이므로 수평 오프셋 미적용
    final horizontalOffset = columnIndex == 0 ? 0.0 : scrollOffset.dx;
    x -= horizontalOffset;
    y -= scrollOffset.dy;

    return Offset(x, y);
  }

  /// 셀의 정중앙 위치 계산 (보강 화살표 시작점 전용)
  ///
  /// Returns: Offset - 셀 가로·세로 중앙 좌표 (스크롤 오프셋 반영)
  Offset _getCellCenterPosition(int columnIndex, int teacherIndex) {
    final origin = _getCellOrigin(columnIndex, teacherIndex);
    return origin + Offset(_columnWidth(columnIndex) / 2, _rowHeight / 2);
  }

  /// 셀의 경계면 중앙 위치 계산 (화살표 시작점/끝점용)
  /// 스크롤 오프셋과 고정 영역을 반영하여 실제 화면상의 위치를 계산
  ///
  /// [columnIndex] 셀의 열 인덱스
  /// [teacherIndex] 셀의 교사 인덱스
  /// [edge] 경계면 종류 (상, 하, 좌, 우)
  ///
  /// Returns: Offset - 경계면 중앙의 좌표 (스크롤 오프셋 및 고정 영역 반영)
  Offset _getCellEdgeCenterPosition(
    int columnIndex,
    int teacherIndex,
    ArrowEdge edge,
  ) {
    final origin = _getCellOrigin(columnIndex, teacherIndex);
    final cw = _columnWidth(columnIndex);
    final rowH = _rowHeight;

    // 좌상단 기준으로 각 경계면 중앙까지의 오프셋
    switch (edge) {
      case ArrowEdge.top: // 상단 가로 중앙
        return origin + Offset(cw / 2, 0);
      case ArrowEdge.bottom: // 하단 가로 중앙
        return origin + Offset(cw / 2, rowH);
      case ArrowEdge.left: // 왼쪽 경계 세로 중앙
        return origin + Offset(0, rowH / 2);
      case ArrowEdge.right: // 오른쪽 경계 세로 중앙
        return origin + Offset(cw, rowH / 2);
    }
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
    bool isTargetBelow =
        targetTeacherIndex > sourceTeacherIndex; // 목표가 아래쪽에 있는지
    bool isTargetRight = targetColumnIndex > sourceColumnIndex; // 목표가 오른쪽에 있는지
    bool isTargetAbove = targetTeacherIndex < sourceTeacherIndex; // 목표가 위쪽에 있는지
    bool isTargetLeft = targetColumnIndex < sourceColumnIndex; // 목표가 왼쪽에 있는지

    ArrowEdge startEdge;
    ArrowEdge endEdge;

    if (priority == ArrowPriority.verticalFirst) {
      // 세로 우선: 먼저 세로 이동, 그 다음 가로 이동
      // 시작점: 세로 방향으로 나가도록
      if (isTargetBelow) {
        startEdge = ArrowEdge.bottom; // 목표가 아래쪽: 하단에서 시작
      } else if (isTargetAbove) {
        startEdge = ArrowEdge.top; // 목표가 위쪽: 상단에서 시작
      } else {
        // 같은 행에 있는 경우, 열 위치에 따라 결정
        if (isTargetRight) {
          startEdge = ArrowEdge.right; // 목표가 오른쪽: 오른쪽에서 시작
        } else if (isTargetLeft) {
          startEdge = ArrowEdge.left; // 목표가 왼쪽: 왼쪽에서 시작
        } else {
          startEdge = ArrowEdge.right; // 같은 위치 (기본값)
        }
      }

      // 끝점: 가로 방향으로 들어오도록
      if (isTargetRight) {
        endEdge = ArrowEdge.left; // 목표가 오른쪽: 왼쪽 경계면에서 끝
      } else if (isTargetLeft) {
        endEdge = ArrowEdge.right; // 목표가 왼쪽: 오른쪽 경계면에서 끝
      } else {
        // 같은 열에 있는 경우, 행 위치에 따라 결정
        if (isTargetBelow) {
          endEdge = ArrowEdge.top; // 목표가 아래쪽: 상단에서 끝
        } else if (isTargetAbove) {
          endEdge = ArrowEdge.bottom; // 목표가 위쪽: 하단에서 끝
        } else {
          endEdge = ArrowEdge.left; // 같은 위치 (기본값)
        }
      }
    } else {
      // 가로 우선: 먼저 가로 이동, 그 다음 세로 이동
      // 시작점: 가로 방향으로 나가도록
      if (isTargetRight) {
        startEdge = ArrowEdge.right; // 목표가 오른쪽: 오른쪽에서 시작
      } else if (isTargetLeft) {
        startEdge = ArrowEdge.left; // 목표가 왼쪽: 왼쪽에서 시작
      } else {
        // 같은 열에 있는 경우, 행 위치에 따라 결정
        if (isTargetBelow) {
          startEdge = ArrowEdge.bottom; // 목표가 아래쪽: 하단에서 시작
        } else if (isTargetAbove) {
          startEdge = ArrowEdge.top; // 목표가 위쪽: 상단에서 시작
        } else {
          startEdge = ArrowEdge.right; // 같은 위치 (기본값)
        }
      }

      // 끝점: 세로 방향으로 들어오도록
      if (isTargetBelow) {
        endEdge = ArrowEdge.top; // 목표가 아래쪽: 상단에서 끝
      } else if (isTargetAbove) {
        endEdge = ArrowEdge.bottom; // 목표가 위쪽: 하단에서 끝
      } else {
        // 같은 행에 있는 경우, 열 위치에 따라 결정
        if (isTargetRight) {
          endEdge = ArrowEdge.left; // 목표가 오른쪽: 왼쪽 경계면에서 끝
        } else if (isTargetLeft) {
          endEdge = ArrowEdge.right; // 목표가 왼쪽: 오른쪽 경계면에서 끝
        } else {
          endEdge = ArrowEdge.left; // 같은 위치 (기본값)
        }
      }
    }

    return {'start': startEdge, 'end': endEdge};
  }

  /// 스타일이 적용된 화살표 그리기
  void _drawStyledArrow(
    Canvas canvas,
    Offset start,
    Offset end, {
    ArrowPriority priority = ArrowPriority.verticalFirst,
    double? arrowHeadSize,
    String? text,
    ArrowDirection? direction,
    bool dashed = false,
  }) {
    // 교체 경로 타입에 따른 스타일 결정
    ExchangeArrowStyle style = _getArrowStyle();

    // 커스텀 스타일이 없을 때만 런타임 방향 적용
    // (커스텀 스타일이 지정된 경우 해당 스타일의 방향을 그대로 존중)
    if (customArrowStyle == null && direction != null) {
      style = style.copyWith(direction: direction);
    }

    // 커스텀 머리 사이즈가 있으면 스타일에 적용
    if (arrowHeadSize != null) {
      style = style.copyWith(arrowHeadSize: arrowHeadSize);
    }

    // 우선 방향에 따라 직각 화살표 그리기
    _drawRightAngleArrowWithStyle(
      canvas,
      start,
      end,
      style,
      priority: priority,
      text: text,
      dashed: dashed,
    );
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
      case ExchangePathType.dual:
        return ExchangeArrowStyle.dual;
      case ExchangePathType.supplement:
        return ExchangeArrowStyle.supplement;
    }
  }

  /// 직각 방향 화살표 그리기 (외곽선과 내부선) - 스타일 적용 버전
  void _drawRightAngleArrowWithStyle(
    Canvas canvas,
    Offset start,
    Offset end,
    ExchangeArrowStyle style, {
    ArrowPriority priority = ArrowPriority.verticalFirst,
    String? text,
    bool dashed = false,
  }) {
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
    final outlinePaint =
        Paint()
          ..color = style.outlineColor
          ..strokeWidth = style.outlineWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    // 내부선용 Paint (설정된 색상과 두께)
    final innerPaint =
        Paint()
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

    if (dashed) {
      // 점선: 외곽선·내부선을 같은 대시 패턴으로 그림 (화살표 머리는 실선 유지)
      _drawDashedPath(canvas, path, outlinePaint);
      _drawDashedPath(canvas, path, innerPaint);
    } else {
      // 외곽선 먼저 그리기
      canvas.drawPath(path, outlinePaint);
      // 내부선 그리기
      canvas.drawPath(path, innerPaint);
    }

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
  void _drawArrowText(
    Canvas canvas,
    Offset position,
    String text,
    ExchangeArrowStyle style,
  ) {
    // 텍스트 스타일 설정
    final textStyle = TextStyle(
      fontSize: ArrowConstants.textFontSize,
      fontWeight: FontWeight.bold,
      color: style.color,
    );

    // 텍스트 페인트 설정
    final textPaint =
        Paint()
          ..color =
              Colors
                  .white // 배경색 (외곽선)
          ..style = PaintingStyle.fill;

    final outlinePaint =
        Paint()
          ..color =
              style
                  .color // 텍스트 색상
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
    final backgroundRadius =
        math.max(textPainter.width, textPainter.height) / 2 +
        ArrowConstants.textBackgroundPadding;
    canvas.drawCircle(position, backgroundRadius, textPaint);
    canvas.drawCircle(position, backgroundRadius, outlinePaint);

    // 텍스트 그리기
    textPainter.paint(canvas, textOffset);
  }

  /// 화살표 머리 그리기 (외곽선과 내부선) - 스타일 적용 버전
  void _drawArrowHeadWithStyle(
    Canvas canvas,
    Offset from,
    Offset to,
    ExchangeArrowStyle style,
  ) {
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
    double x1 =
        to.dx -
        headLength * (dx * math.cos(headAngle) + dy * math.sin(headAngle));
    double y1 =
        to.dy -
        headLength * (dy * math.cos(headAngle) - dx * math.sin(headAngle));

    double x2 =
        to.dx -
        headLength * (dx * math.cos(-headAngle) + dy * math.sin(-headAngle));
    double y2 =
        to.dy -
        headLength * (dy * math.cos(-headAngle) - dx * math.sin(-headAngle));

    // 외곽선용 Paint (설정된 외곽선 색상과 두께)
    final outlinePaint =
        Paint()
          ..color = style.outlineColor
          ..strokeWidth = style.outlineWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    // 내부선용 Paint (설정된 색상과 두께)
    final innerPaint =
        Paint()
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

    // 화살표 방향 설정 변경 확인 (설정에서 단방향/양방향 전환 시 재그리기)
    if (oldPainter.oneToOneArrowDirection != oneToOneArrowDirection ||
        oldPainter.dualArrowDirection != dualArrowDirection) {
      hasChanged = true;
    }

    // 확대/축소 배율 변경 확인
    if ((oldPainter.zoomFactor - zoomFactor).abs() > 0.001) {
      hasChanged = true;
    }

    // 스크롤 오프셋 변경 확인
    // 화살표 좌표는 scrollOffset을 반영해 계산되므로, 스크롤이 바뀌면
    // 반드시 다시 그려야 화살표가 실제 셀 위치를 따라간다.
    // (경로 선택 시 자동 스크롤되면서 화살표가 어긋나는 문제 해결)
    if (oldPainter.scrollOffset != scrollOffset) {
      hasChanged = true;
    }

    return hasChanged;
  }
}

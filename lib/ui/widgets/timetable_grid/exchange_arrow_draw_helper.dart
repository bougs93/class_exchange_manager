import '../../../models/exchange_node.dart';
import 'exchange_arrow_step.dart';
import 'timetable_grid_constants.dart';

/// 두 노드 사이에 화살표 1개를 그리는 콜백
///
/// 저수준 그리기(좌표 계산·클리핑·스타일 적용)는 [ExchangeArrowPainter]에
/// 유지하고, 이 콜백을 통해 헬퍼가 그리기를 위임한다.
typedef ArrowDrawCallback =
    void Function(
      ExchangeNode from,
      ExchangeNode to, {
      ArrowPriority priority,
      double? arrowHeadSize,
      String? text,
      ArrowDirection direction,
    });

/// 1:1·2중 교체 화살표 그리기 전략을 공통화한 헬퍼
///
/// Painter의 저수준 그리기 로직을 [ArrowDrawCallback]으로 주입받아,
/// 화살표 배치 전략(분리 단방향 / 단계별 1선)만 담당한다.
class ExchangeArrowDrawHelper {
  const ExchangeArrowDrawHelper._();

  /// 분리 단방향 전략: A→B, B→A 2개의 선을 각각 단방향 화살표로 그린다.
  ///
  /// 1:1·2중 교체 **단방향**에서 사용한다. 중간 숫자는 표시하지 않는다.
  static void drawSplitUnidirectional({
    required ExchangeNode nodeA,
    required ExchangeNode nodeB,
    required ArrowDrawCallback drawArrow,
    ArrowPriority priority = ArrowPriority.verticalFirst,
    double arrowHeadSize = 12.0,
  }) {
    drawArrow(
      nodeA,
      nodeB,
      priority: priority,
      arrowHeadSize: arrowHeadSize,
      direction: ArrowDirection.forward,
    );
    drawArrow(
      nodeB,
      nodeA,
      priority: priority,
      arrowHeadSize: arrowHeadSize,
      direction: ArrowDirection.forward,
    );
  }

  /// 단계별 1선 전략: 각 단계를 1개의 선으로 그린다.
  ///
  /// 1:1 교체 **양방향** 및 2중 교체(단방향/양방향)에서 사용한다.
  /// [direction]에 따라 화살표 머리가 한쪽(→) 또는 양쪽(↔)에 그려지며,
  /// [showStepNumbers]가 true면 화살표 중간에 단계 번호를 표시한다.
  static void drawStepArrows({
    required List<ExchangeArrowStep> steps,
    required ArrowDirection direction,
    required ArrowDrawCallback drawArrow,
    ArrowPriority priority = ArrowPriority.verticalFirst,
    double arrowHeadSize = 8.0,
    bool showStepNumbers = true,
  }) {
    for (final step in steps) {
      drawArrow(
        step.fromNode,
        step.toNode,
        priority: priority,
        arrowHeadSize: arrowHeadSize,
        text: showStepNumbers ? '${step.stepNumber}' : null,
        direction: direction,
      );
    }
  }
}

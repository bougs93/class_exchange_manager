import '../../../models/exchange_node.dart';

/// 교체 화살표 1단계 정보 (1:1·2중 교체 공통)
///
/// 화살표 1개(선 1개)를 그리는 데 필요한 출발/도착 노드와
/// 화살표 중간·셀 모서리에 표시할 단계 번호를 담는다.
class ExchangeArrowStep {
  /// 화살표 출발 노드
  final ExchangeNode fromNode;

  /// 화살표 도착 노드
  final ExchangeNode toNode;

  /// 단계 번호 (화살표 중간 숫자 및 셀 모서리 숫자에 사용)
  final int stepNumber;

  const ExchangeArrowStep({
    required this.fromNode,
    required this.toNode,
    required this.stepNumber,
  });
}

import 'package:flutter/material.dart';
import '../../../models/exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/dual_exchange_path.dart';
import '../../../models/exchange_node.dart';
import '../../../theme/design_tokens.dart';
import 'sidebar_color_scheme.dart';
import 'animated_sidebar_node.dart';

/// 경로 타입별 노드 렌더링 위젯
///
/// [UnifiedExchangeSidebar]의 사이드바 경로 아이템에서 1:1교체 / 2중교체 /
/// 순환교체 각각의 노드 구성과 화살표·단계 배지를 그린다. 탭/더블탭 동작은
/// 콜백으로만 받아 상태(Provider 접근, 경로 선택 등)는 호출부가 책임진다.
class PathNodeRenderer extends StatelessWidget {
  final ExchangePath path;
  final int index;
  final bool isSelected;
  final PathColorScheme colorScheme;
  final DesignTokens tokens;
  final Function(ExchangeNode) getSubjectName;

  /// 노드 탭 — 첫 탭은 경로만 고르고, 이미 선택된 카드의 노드를
  /// 누르면 그 칸으로 스크롤한다.
  final void Function(ExchangeNode node, String nodeKey, bool isSelected)
  onNodeTap;

  /// 노드 더블 클릭 — 그 경로의 교체를 실행한다.
  final void Function(String nodeKey) onNodeDoubleTap;

  const PathNodeRenderer({
    super.key,
    required this.path,
    required this.index,
    required this.isSelected,
    required this.colorScheme,
    required this.tokens,
    required this.getSubjectName,
    required this.onNodeTap,
    required this.onNodeDoubleTap,
  });

  /// 경로 노드들 구성 (타입별 화살표 차별화)
  @override
  Widget build(BuildContext context) {
    if (path.type == ExchangePathType.oneToOne) {
      return _buildOneToOneNodes(path as OneToOneExchangePath);
    } else if (path.type == ExchangePathType.circular) {
      return _buildCircularNodes(path as CircularExchangePath);
    } else {
      return _buildDualNodes(path as DualExchangePath);
    }
  }

  /// 화살표 + 단계 숫자 배지 (2중·순환교체 공통)
  ///
  /// [arrow] 방향 아이콘(2중: swap_vert, 순환: arrow_downward),
  /// [badgeColor] 선택 시 배지 색상(2중: 빨강, 순환: 경로색),
  /// [arrowColor] 선택 시 화살표 색상(2중은 배지와 달리 경로색을 쓰므로 분리).
  ///   생략 시 [badgeColor]와 동일. [number] 단계 번호. 미선택 시 회색으로 통일된다.
  Widget _buildArrowWithBadge({
    required IconData arrow,
    required double arrowSize,
    required String number,
    required Color badgeColor,
    required bool isSelected,
    Color? arrowColor,
    EdgeInsets margin = const EdgeInsets.symmetric(vertical: 2),
  }) {
    final effectiveBadgeColor = isSelected ? badgeColor : tokens.textMuted;
    final effectiveArrowColor =
        isSelected ? (arrowColor ?? badgeColor) : tokens.textMuted;

    return Container(
      margin: margin,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(arrow, color: effectiveArrowColor, size: arrowSize),
          const SizedBox(width: 4),
          Container(
            width: 20,
            height: 16,
            decoration: BoxDecoration(
              color: effectiveBadgeColor,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: effectiveBadgeColor, width: 1),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 1:1교체 노드들 구성
  Widget _buildOneToOneNodes(OneToOneExchangePath path) {
    return Column(
      children: [
        // 첫 번째 노드 (선택된 셀)
        _buildNodeContainer(path.nodes[0], '${index}_0', true),

        // 양방향 화살표 (1:1교체 특징)
        // 선택됨: 각 경로 타입별 색상, 선택안됨: 회색으로 통일
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Icon(
            Icons.swap_vert,
            color: isSelected ? colorScheme.primary : tokens.textMuted,
            size: 14,
          ),
        ),

        // 두 번째 노드 (교체 대상 셀, 진한 색상 적용)
        _buildNodeContainer(
          path.nodes[1],
          '${index}_1',
          false,
          isSecondNode: true,
        ),
      ],
    );
  }

  /// 2중교체 노드들 구성
  Widget _buildDualNodes(DualExchangePath path) {
    List<Widget> nodeWidgets = [];

    // 2중교체 단계별 표시:
    // 1단계: node1 ↔ node2
    // 2단계: nodeA ↔ nodeB

    // 1단계: node2 ↔ node1 (순서 수정)
    nodeWidgets.add(_buildNodeContainer(path.node2, '${index}_2', false));

    // 1단계 양방향 화살표와 빨간색 숫자 박스
    nodeWidgets.add(
      _buildArrowWithBadge(
        arrow: Icons.swap_vert,
        arrowSize: 14,
        number: '1',
        badgeColor: Colors.red,
        arrowColor: colorScheme.primary,
        isSelected: isSelected,
      ),
    );

    nodeWidgets.add(_buildNodeContainer(path.node1, '${index}_1', false));

    // 단계 간 구분선 (선택사항)
    nodeWidgets.add(
      Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        height: 1,
        color: tokens.cardBorder,
      ),
    );

    // 2단계: nodeA ↔ nodeB
    nodeWidgets.add(_buildNodeContainer(path.nodeA, '${index}_A', false));

    // 2단계 양방향 화살표와 빨간색 숫자 박스
    nodeWidgets.add(
      _buildArrowWithBadge(
        arrow: Icons.swap_vert,
        arrowSize: 14,
        number: '2',
        badgeColor: Colors.red,
        arrowColor: colorScheme.primary,
        isSelected: isSelected,
      ),
    );

    nodeWidgets.add(
      _buildNodeContainer(path.nodeB, '${index}_B', false, isSecondNode: true),
    );

    return Column(children: nodeWidgets);
  }

  /// 순환교체 노드들 구성
  Widget _buildCircularNodes(CircularExchangePath path) {
    List<Widget> nodeWidgets = [];

    // 시작점 표시 (첫 번째 노드)
    nodeWidgets.add(_buildNodeContainer(path.nodes[0], '${index}_0', true));

    // 노드 길이가 3인 경우: 1번째와 2번째 노드 사이를 상하 화살표로 (3번째 노드는 숨김)
    if (path.nodes.length == 3) {
      // 상하 화살표만 표시 (숫자 박스 제거)
      nodeWidgets.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.swap_vert, // 상하 화살표
                color: isSelected ? colorScheme.primary : tokens.textMuted,
                size: 14,
              ),
            ],
          ),
        ),
      );

      // 두 번째 노드 (마지막으로 표시되는 노드, 진한 색상 적용)
      nodeWidgets.add(
        _buildNodeContainer(
          path.nodes[1],
          '${index}_1',
          false,
          isSecondNode: true,
        ),
      );

      // 3번째 노드는 표시하지 않음 (숨김)
    } else {
      // 노드 길이가 4 이상인 경우: 각 화살표에 단계별 숫자 추가
      for (int i = 1; i < path.nodes.length - 1; i++) {
        // 단방향 화살표와 숫자 (순환교체 특징)
        nodeWidgets.add(
          _buildArrowWithBadge(
            arrow: Icons.arrow_downward,
            arrowSize: 12,
            number: '$i',
            badgeColor: colorScheme.primary,
            isSelected: isSelected,
            margin: const EdgeInsets.symmetric(vertical: 1),
          ),
        );

        // 노드 (2번째 노드인 경우 진한 색상 적용)
        bool isSecondNode = (i == 1); // 인덱스 1이 2번째 노드
        nodeWidgets.add(
          _buildNodeContainer(
            path.nodes[i],
            '${index}_$i',
            false,
            isSecondNode: isSecondNode,
          ),
        );
      }

      // 마지막 노드 추가 (4개 이상인 경우)
      if (path.nodes.length > 3) {
        // 마지막 화살표와 숫자
        nodeWidgets.add(
          _buildArrowWithBadge(
            arrow: Icons.arrow_downward,
            arrowSize: 12,
            number: '${path.nodes.length - 1}',
            badgeColor: colorScheme.primary,
            isSelected: isSelected,
            margin: const EdgeInsets.symmetric(vertical: 1),
          ),
        );

        // 마지막 노드 (연하게 표시)
        nodeWidgets.add(
          _buildNodeContainer(
            path.nodes.last,
            '${index}_${path.nodes.length - 1}',
            false,
            isLastNode: true,
          ),
        );
      }
    }

    return Column(children: nodeWidgets);
  }

  /// 노드 컨테이너 구성 (공통) — 물결 효과를 가진 AnimatedSidebarNode로 위임
  ///
  /// [isStartNode]는 호출부 호환을 위해 유지하나 표시에는 사용하지 않는다.
  Widget _buildNodeContainer(
    ExchangeNode node,
    String nodeKey,
    bool isStartNode, {
    bool isLastNode = false,
    bool isSecondNode = false,
    String? labelOverride,
  }) {
    return AnimatedSidebarNode(
      node: node,
      isSelected: isSelected,
      colorScheme: colorScheme,
      isLastNode: isLastNode,
      isSecondNode: isSecondNode,
      label:
          labelOverride ??
          '${node.day}${node.period}|${node.className}|${node.teacherName}|${getSubjectName(node)}',
      onTap: () => onNodeTap(node, nodeKey, isSelected),
      onDoubleTap: () => onNodeDoubleTap(nodeKey),
    );
  }
}

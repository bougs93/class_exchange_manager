import 'package:flutter/material.dart';
import '../../../models/exchange_node.dart';
import 'sidebar_color_scheme.dart';
import 'sidebar_constants.dart';

/// 사이드바 경로 노드 (탭 시 물결 효과를 가진 단일 노드)
///
/// 노드별로 자신의 애니메이션 컨트롤러를 소유한다 — 물결 효과는 "이미 선택된
/// 경로의 노드를 다시 탭"할 때만 재생되므로(중앙 집중 관리 불필요), 각 노드가
/// 스스로 처리하는 편이 단순하다.
///
/// 탭 로직(경로 선택 / 스크롤)은 [onTap]으로 부모가 담당한다.
class AnimatedSidebarNode extends StatefulWidget {
  final ExchangeNode node;
  final bool isSelected;
  final PathColorScheme colorScheme;
  final bool isLastNode;
  final bool isSecondNode;

  /// 표시할 라벨(부모가 과목명까지 조합해 전달)
  final String label;

  /// 노드 탭 콜백(경로 선택 또는 스크롤 처리)
  final VoidCallback onTap;

  const AnimatedSidebarNode({
    super.key,
    required this.node,
    required this.isSelected,
    required this.colorScheme,
    required this.label,
    required this.onTap,
    this.isLastNode = false,
    this.isSecondNode = false,
  });

  @override
  State<AnimatedSidebarNode> createState() => _AnimatedSidebarNodeState();
}

class _AnimatedSidebarNodeState extends State<AnimatedSidebarNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  );

  // 물결 효과 스케일 애니메이션 (5% 확대 후 복귀)
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 1.05,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // 이미 선택된 경로의 노드를 탭한 경우에만 물결 효과 재생
    if (widget.isSelected) {
      _controller.forward(from: 0).then((_) => _controller.reverse());
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.colorScheme;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: scheme.backgroundFor(
              widget.isSelected,
              widget.isLastNode,
              widget.isSecondNode,
            ),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: scheme.borderFor(
                widget.isSelected,
                widget.isLastNode,
                widget.isSecondNode,
              ),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (widget.isSelected && !widget.isLastNode) // 마지막 노드는 그림자 제거
                BoxShadow(
                  color: scheme.shadow,
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: SidebarFontSizes.nodeText,
              fontWeight: FontWeight.w500,
              color: scheme.textFor(
                widget.isSelected,
                widget.isLastNode,
                widget.isSecondNode,
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

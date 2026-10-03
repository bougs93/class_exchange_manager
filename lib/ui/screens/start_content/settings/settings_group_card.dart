import 'package:flutter/material.dart';
import '../../../../theme/design_tokens.dart';

/// 설정 그룹 공통 외곽 카드 (화살표 표시 · 간접교체 등에서 재사용)
///
/// [StartSettingsCard]의 `_buildSettingsGroupCard`를 그대로 옮긴 순수
/// 표현 위젯이다. 시각적 출력(패딩·테두리·배경)은 변경하지 않았다.
class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({
    super.key,
    required this.child,
    this.stretchHeight = false,
  });

  final Widget child;
  final bool stretchHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: double.infinity,
      height: stretchHeight ? double.infinity : null,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

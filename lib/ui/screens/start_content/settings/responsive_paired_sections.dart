import 'package:flutter/material.dart';

/// 2개 카드 섹션 배치 (넓으면 1행·높이 연동, 좁으면 2행)
///
/// [StartSettingsCard]의 `_buildResponsivePairedSections`를 그대로 옮긴 순수
/// 레이아웃 위젯이다. ExpansionTile 자식은 세로 max가 무한이므로 Row+stretch
/// 단독 사용은 위험하다. [IntrinsicHeight]로 행 높이를 먼저 확정한 뒤 stretch 한다.
class ResponsivePairedSections extends StatelessWidget {
  const ResponsivePairedSections({
    super.key,
    required this.buildFirst,
    required this.buildSecond,
    this.minSectionWidth = 280,
    this.spacing = 12,
  });

  final Widget Function(bool stretchHeight) buildFirst;
  final Widget Function(bool stretchHeight) buildSecond;
  final double minSectionWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            constraints.maxWidth >= minSectionWidth * 2 + spacing;
        final first = buildFirst(twoColumns);
        final second = buildSecond(twoColumns);

        if (twoColumns) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: first),
                SizedBox(width: spacing),
                Expanded(child: second),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, SizedBox(height: spacing), second],
        );
      },
    );
  }
}

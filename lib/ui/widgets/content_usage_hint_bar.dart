import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'content_toolbar_layout.dart';

/// 화면 상단 사용 안내 바
///
/// 안내 문구가 비어 있으면 레이아웃에 영향을 주지 않습니다.
/// 결보강 일정·결보강 출력·교사안내·학급안내에서 동일한 형식으로 사용합니다.
///
/// [linkText]가 [message] 안에 있고 [onLinkTap]이 있으면 해당 구간을
/// 클릭 링크로 표시합니다.
class ContentUsageHintBar extends StatelessWidget {
  /// 표시할 안내 문구 (비어 있으면 숨김)
  final String message;

  /// 탭 테마 색상 (아이콘·테두리·배경)
  final Color accentColor;

  /// [true]이면 [ContentToolbarLayout.hintPadding] 적용 (카드 내부 등)
  final bool padded;

  /// 클릭 가능하게 할 문구 ([message] 안의 부분 문자열)
  final String? linkText;

  /// [linkText] 탭 시 동작
  final VoidCallback? onLinkTap;

  const ContentUsageHintBar({
    super.key,
    required this.message,
    required this.accentColor,
    this.padded = false,
    this.linkText,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    final bar = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: ContentToolbarLayout.buttonIconSize,
            color: accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildMessage(tokens)),
        ],
      ),
    );

    if (!padded) {
      return bar;
    }

    return Padding(padding: ContentToolbarLayout.hintPadding, child: bar);
  }

  Widget _buildMessage(DesignTokens tokens) {
    final baseStyle = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: tokens.textPrimary,
    );
    final trimmed = message.trim();
    final link = linkText?.trim();
    final onTap = onLinkTap;

    if (link == null || link.isEmpty || onTap == null) {
      return Text(trimmed, style: baseStyle);
    }

    final index = trimmed.indexOf(link);
    if (index < 0) {
      return Text(trimmed, style: baseStyle);
    }

    final before = trimmed.substring(0, index);
    final after = trimmed.substring(index + link.length);
    final linkStyle = baseStyle.copyWith(
      color: accentColor,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: accentColor,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onTap,
                child: Text(link, style: linkStyle),
              ),
            ),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );
  }
}

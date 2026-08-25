import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// 빈 상태 안내 위젯 (아이콘 + 메시지 + 선택적 보조 메시지)
///
/// 데이터 없음·검색 결과 없음·선택 안내 등 여러 화면에서 반복되던
/// 중앙 정렬 `Icon + Text` 레이아웃을 한곳에 모은다.
/// 바깥 여백·배경·Scaffold 등은 호출부가 감싸 처리하고,
/// 이 위젯은 중앙 정렬 Column만 제공한다.
class EmptyStateMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  /// 아이콘 크기 (기본 64 — 큰 빈 화면용, 사이드바는 48 등)
  final double iconSize;

  /// 아이콘 색상 (기본 grey.shade400)
  final Color? iconColor;

  /// 아이콘과 메시지 사이 간격 (기본 16)
  final double iconSpacing;

  final double messageFontSize;

  /// 메시지 색상 (기본 grey.shade600)
  final Color? messageColor;
  final FontWeight? messageFontWeight;

  /// 보조 메시지 (null이면 표시 안 함)
  final String? subMessage;

  /// 메시지와 보조 메시지 사이 간격 (기본 8)
  final double subMessageSpacing;
  final double subMessageFontSize;

  /// 보조 메시지 색상 (기본 grey.shade500)
  final Color? subMessageColor;

  /// Column이 가용 높이를 모두 차지할지(true) 내용 크기만 쓸지(false)
  final bool expand;

  const EmptyStateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.iconSize = 64,
    this.iconColor,
    this.iconSpacing = 16,
    this.messageFontSize = 16,
    this.messageColor,
    this.messageFontWeight,
    this.subMessage,
    this.subMessageSpacing = 8,
    this.subMessageFontSize = 14,
    this.subMessageColor,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Center(
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: iconColor ?? tokens.textMuted),
          SizedBox(height: iconSpacing),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: messageFontSize,
              fontWeight: messageFontWeight,
              color: messageColor ?? tokens.textSecondary,
            ),
          ),
          if (subMessage != null) ...[
            SizedBox(height: subMessageSpacing),
            Text(
              subMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: subMessageFontSize,
                color: subMessageColor ?? tokens.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../../theme/design_tokens.dart';

/// 선택 목록 행 — 왼쪽 accent 막대 + 배경 하이라이트 (라디오 대신)
///
/// [PlanBackupScreen]의 `_SelectableListRow`에서 추출한 순수 렌더링 위젯입니다.
class BackupSelectableListRow extends StatelessWidget {
  const BackupSelectableListRow({
    super.key,
    required this.selected,
    required this.accent,
    required this.tokens,
    required this.label,
    required this.onTap,
    this.countBadge,
  });

  final bool selected;
  final Color accent;
  final DesignTokens tokens;
  final String label;
  final VoidCallback onTap;

  /// 있으면 이름 옆에 원형 숫자 배지 (예: 계획서 개수)
  final int? countBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: selected ? accent : Colors.transparent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                            color: tokens.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (countBadge != null) ...[
                        const SizedBox(width: 8),
                        BackupCountBadge(
                          count: countBadge!,
                          accent: accent,
                          selected: selected,
                          muted: tokens.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 계획서 개수 원형 배지 — 정원길 ① 형태
///
/// [PlanBackupScreen]의 `_CountCircleBadge`에서 추출한 순수 렌더링 위젯입니다.
class BackupCountBadge extends StatelessWidget {
  const BackupCountBadge({
    super.key,
    required this.count,
    required this.accent,
    required this.selected,
    required this.muted,
  });

  final int count;
  final Color accent;
  final bool selected;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final border = selected ? accent : muted;
    final fg = selected ? accent : muted;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.2),
        color: selected ? accent.withValues(alpha: 0.08) : Colors.transparent,
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          height: 1,
        ),
      ),
    );
  }
}

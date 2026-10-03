import 'package:flutter/material.dart';

import '../../../models/timetable_registry.dart';
import '../../../theme/design_tokens.dart';

/// 시간표 카드 제목 줄 (선택 표시 + 이름 + '사용 중' 배지)
class TimetableCardTitleRow extends StatelessWidget {
  const TimetableCardTitleRow({
    super.key,
    required this.entry,
    required this.isActive,
  });

  final TimetableRegistryEntry entry;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Row(
      children: [
        Icon(
          isActive ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 20,
          color: isActive ? theme.primaryColor : tokens.textMuted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '사용 중',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }
}

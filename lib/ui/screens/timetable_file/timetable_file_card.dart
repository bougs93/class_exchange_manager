import 'package:flutter/material.dart';

import '../../../models/timetable_registry.dart';
import '../../../theme/design_tokens.dart';
import 'timetable_active_card_body.dart';
import 'timetable_card_actions.dart';
import 'timetable_card_source_line.dart';
import 'timetable_card_title_row.dart';
import 'timetable_collapsed_card_body.dart';

/// 시간표 카드 1건
///
/// 활성 항목만 계층 트리(교사 → 계획서)를 펼치고, 비활성 항목은 한 줄로 접습니다.
/// 교체·결보강 건수는 교사가 아니라 **시간표 아래**에 표시해, 교체 상태가
/// 교사와 무관하게 공유된다는 원칙을 배치로 드러냅니다(문서 §3①).
class TimetableFileCard extends StatelessWidget {
  const TimetableFileCard({
    super.key,
    required this.entry,
    required this.isActive,
    required this.onSwitch,
    required this.onRename,
    required this.onDelete,
  });

  final TimetableRegistryEntry entry;
  final bool isActive;
  final VoidCallback onSwitch;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isActive
                  ? theme.primaryColor.withValues(alpha: 0.5)
                  : tokens.cardBorder,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimetableCardTitleRow(entry: entry, isActive: isActive),
          const SizedBox(height: 6),
          TimetableCardSourceLine(entry: entry),
          if (isActive)
            TimetableActiveCardBody(entry: entry)
          else
            TimetableCollapsedCardBody(entry: entry),
          const SizedBox(height: 10),
          TimetableCardActions(
            isActive: isActive,
            onSwitch: onSwitch,
            onRename: onRename,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

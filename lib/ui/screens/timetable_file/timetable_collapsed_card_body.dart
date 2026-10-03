import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/timetable_registry.dart';
import '../../../providers/timetable_summary_provider.dart';
import '../../../theme/design_tokens.dart';

/// 비활성 시간표: 교사·계획서·교체 건수를 한 줄 요약으로 접는다
class TimetableCollapsedCardBody extends ConsumerWidget {
  const TimetableCollapsedCardBody({super.key, required this.entry});

  final TimetableRegistryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final summary = ref.watch(timetableSummaryProvider(entry.id)).valueOrNull;
    final hasTeacher = entry.hasTeacher;

    final parts = <String>[
      hasTeacher ? entry.teacherName! : '교사 미지정',
      if (summary != null) summary.description,
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 4),
      child: Row(
        children: [
          Icon(
            hasTeacher ? Icons.person_outline : Icons.warning_amber_rounded,
            size: 13,
            color: hasTeacher ? tokens.textMuted : Colors.orange,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: TextStyle(
                fontSize: 12,
                color: hasTeacher ? tokens.textMuted : Colors.orange,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

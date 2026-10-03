import 'package:flutter/material.dart';

import '../../../models/print_profile.dart';
import '../../../theme/design_tokens.dart';

/// 트리 한 줄 (교사 → 그 교사의 계획서들)
class TimetableTeacherTreeRow extends StatelessWidget {
  const TimetableTeacherTreeRow({
    super.key,
    required this.teacher,
    required this.profiles,
    required this.isLast,
  });

  final String teacher;
  final List<PrintProfile> profiles;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLast ? '└─ ' : '├─ ',
            style: TextStyle(fontSize: 12, color: tokens.textMuted),
          ),
          Text(
            teacher,
            style: TextStyle(fontSize: 12.5, color: tokens.textPrimary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              profiles.isEmpty
                  ? '계획서 없음'
                  : profiles.map((p) => p.name).join(' · '),
              style: TextStyle(
                fontSize: 12,
                color: profiles.isEmpty ? tokens.textMuted : tokens.textPrimary,
                fontStyle:
                    profiles.isEmpty ? FontStyle.italic : FontStyle.normal,
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

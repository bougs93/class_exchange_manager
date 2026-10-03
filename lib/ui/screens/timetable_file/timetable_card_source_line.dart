import 'package:flutter/material.dart';

import '../../../models/timetable_registry.dart';
import '../../../theme/design_tokens.dart';

/// 원본 파일·학교명·등록일 한 줄
class TimetableCardSourceLine extends StatelessWidget {
  const TimetableCardSourceLine({super.key, required this.entry});

  final TimetableRegistryEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final parts = <String>[
      if (entry.schoolName != null) entry.schoolName!,
      entry.fileName.isEmpty ? '원본 정보 없음' : entry.fileName,
      '${entry.registeredAt.month}/${entry.registeredAt.day} 등록',
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 28),
      child: Row(
        children: [
          Icon(Icons.school_outlined, size: 13, color: tokens.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

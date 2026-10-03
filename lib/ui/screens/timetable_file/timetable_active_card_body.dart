import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/timetable_registry.dart';
import '../../../providers/print_profile_provider.dart';
import '../../../providers/timetable_summary_provider.dart';
import '../../../theme/design_tokens.dart';
import 'timetable_teacher_tree_row.dart';

/// 활성 시간표: 교사 → 계획서 트리 + 시간표 단위 건수
class TimetableActiveCardBody extends ConsumerWidget {
  const TimetableActiveCardBody({super.key, required this.entry});

  final TimetableRegistryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final store = ref.watch(printProfileStoreProvider);
    final summary = ref.watch(timetableSummaryProvider(entry.id)).valueOrNull;

    // 계획서를 가진 교사 목록. 지정 교사는 계획서가 없어도 항상 맨 앞에 보인다
    final teachers = <String>[
      if (entry.hasTeacher) entry.teacherName!,
      ...store.teacherNames.where((t) => t != entry.teacherName),
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                entry.hasTeacher
                    ? Icons.person_outline
                    : Icons.warning_amber_rounded,
                size: 14,
                color: entry.hasTeacher ? tokens.textSecondary : Colors.orange,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entry.hasTeacher
                      ? '교사: ${entry.teacherName}'
                      : '교사 미지정 — 홈 화면에서 선택하세요',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color:
                        entry.hasTeacher ? tokens.textSecondary : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < teachers.length; i++)
            TimetableTeacherTreeRow(
              teacher: teachers[i],
              profiles: store.byTeacher(teachers[i]),
              isLast: i == teachers.length - 1,
            ),
          const SizedBox(height: 6),
          Text(
            summary == null
                ? '데이터 확인 중…'
                : '${summary.description}  (시간표 전체가 공유)',
            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

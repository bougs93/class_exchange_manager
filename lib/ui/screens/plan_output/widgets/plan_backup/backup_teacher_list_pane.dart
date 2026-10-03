import 'package:flutter/material.dart';

import '../../../../../models/print_profile.dart';
import '../../../../../theme/design_tokens.dart';
import 'backup_selectable_list_row.dart';

/// 결강 교사 목록 패널 (좌측)
///
/// [PlanBackupScreen]의 `_TeacherListPane`에서 추출한 순수 렌더링 위젯입니다.
class BackupTeacherListPane extends StatelessWidget {
  const BackupTeacherListPane({
    super.key,
    required this.teachers,
    required this.selectedTeacher,
    required this.store,
    required this.accent,
    required this.tokens,
    required this.onSelect,
  });

  final List<String> teachers;
  final String? selectedTeacher;
  final PrintProfileStore store;
  final Color accent;
  final DesignTokens tokens;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              '결강 교사',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tokens.textSecondary,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                teachers.isEmpty
                    ? Center(
                      child: Text(
                        '결강 교사가 없습니다',
                        style: TextStyle(fontSize: 13, color: tokens.textMuted),
                      ),
                    )
                    : Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        itemCount: teachers.length,
                        itemBuilder: (context, index) {
                          final name = teachers[index];
                          final selected = name == selectedTeacher;
                          final planCount = store.byTeacher(name).length;
                          return BackupSelectableListRow(
                            selected: selected,
                            accent: accent,
                            tokens: tokens,
                            label: name,
                            countBadge: planCount,
                            onTap: () => onSelect(name),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

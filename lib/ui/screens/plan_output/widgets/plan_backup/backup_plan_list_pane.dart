import 'package:flutter/material.dart';

import '../../../../../models/print_profile.dart';
import '../../../../../theme/design_tokens.dart';
import 'backup_selectable_list_row.dart';

/// 선택된 교사의 계획서 목록 패널 (우측)
///
/// [PlanBackupScreen]의 `_PlanListPane`에서 추출한 순수 렌더링 위젯입니다.
class BackupPlanListPane extends StatelessWidget {
  const BackupPlanListPane({
    super.key,
    required this.teacher,
    required this.profiles,
    required this.selectedProfileId,
    required this.accent,
    required this.tokens,
    required this.onSelect,
    required this.onOpenContentEdit,
    this.onDeleteSelected,
  });

  final String? teacher;
  final List<PrintProfile> profiles;
  final String? selectedProfileId;
  final Color accent;
  final DesignTokens tokens;
  final ValueChanged<PrintProfile> onSelect;
  final VoidCallback onOpenContentEdit;
  final VoidCallback? onDeleteSelected;

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
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    teacher == null ? '계획서 목록' : '$teacher 계획서',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenContentEdit,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('결보강 일정', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: onDeleteSelected,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor:
                        onDeleteSelected == null ? null : Colors.red.shade700,
                  ),
                  child: const Text('계획서 삭제', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                teacher == null
                    ? Center(
                      child: Text(
                        '왼쪽에서 결강 교사를 선택하세요',
                        style: TextStyle(fontSize: 13, color: tokens.textMuted),
                      ),
                    )
                    : profiles.isEmpty
                    ? Center(
                      child: Text(
                        '이 교사의 계획서가 없습니다',
                        style: TextStyle(fontSize: 13, color: tokens.textMuted),
                      ),
                    )
                    : Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        itemCount: profiles.length,
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          final selected = profile.id == selectedProfileId;
                          return BackupSelectableListRow(
                            selected: selected,
                            accent: accent,
                            tokens: tokens,
                            label: profile.name,
                            onTap: () => onSelect(profile),
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

import 'package:flutter/material.dart';

import '../../../../../models/print_profile.dart';
import '../../../../../theme/design_tokens.dart';

/// 교사·계획서 선택 바
///
/// [SubstitutionOutputWidgetState._buildProfileBar]에서 추출한 순수 렌더링
/// 위젯입니다. 결보강 출력은 결보강 일정에서 만든 계획서를 **선택·출력만**
/// 합니다. 새로 만들기/이름 변경/삭제는 결보강 일정 화면에서 합니다.
///
/// 화면이 넓으면 교사·계획서를 1행에, 좁으면 2행에 배치합니다.
/// 상태 변경(교사·계획서 선택, 삭제, 이동)은 모두 콜백으로 위임하고,
/// 이 위젯 자신은 `setState`를 호출하지 않습니다.
class ProfileSelectionBar extends StatelessWidget {
  const ProfileSelectionBar({
    super.key,
    required this.store,
    required this.teachers,
    required this.selectedTeacher,
    required this.selectedProfileId,
    required this.onTeacherChanged,
    required this.onProfileChanged,
    required this.onNavigateToPlanDate,
    required this.onDeleteProfile,
  });

  /// 계획서 스토어 (교사별 계획서 조회용)
  final PrintProfileStore store;

  /// 현재 시간표의 교사 목록 (가나다순)
  final List<String> teachers;

  /// 현재 선택 교사 (null이면 교사 선택 전)
  final String? selectedTeacher;

  /// 현재 선택 계획서 ID (null이면 미지정)
  final String? selectedProfileId;

  /// 교사 드롭다운 변경 콜백
  final ValueChanged<String?> onTeacherChanged;

  /// 계획서 드롭다운 변경 콜백 (id가 null이 아닐 때만 호출됨)
  final ValueChanged<String> onProfileChanged;

  /// '결보강 일정' 이동 버튼 콜백
  final VoidCallback onNavigateToPlanDate;

  /// 선택한 계획서 삭제 버튼 콜백
  final ValueChanged<PrintProfile> onDeleteProfile;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final teacher = selectedTeacher;
    final profiles =
        teacher != null ? store.byTeacher(teacher) : <PrintProfile>[];
    final selectedProfile = store.getById(selectedProfileId);

    // 드롭다운 value는 items에 있어야 함 (미지정 null 항목 제거)
    final dropdownValue =
        selectedProfile != null &&
                profiles.any((p) => p.id == selectedProfile.id)
            ? selectedProfile.id
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '선택한 계획서',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              // 선택 바 본문 (안내 문구 제외)
              final Widget selectors;
              if (constraints.maxWidth >= 620) {
                // 1행: 교사 | 계획서 | 결보강 일정
                selectors = Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 18,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    const Text('교사', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTeacherDropdown(tokens, teachers, teacher),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    const Text('계획서', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPlanDropdown(
                        tokens,
                        profiles,
                        dropdownValue,
                      ),
                    ),
                    _buildContentEditNavButton(),
                    _buildDeleteProfileButton(selectedProfile),
                  ],
                );
              } else {
                // 2행: 1행 교사 선택, 2행 계획서 선택 + 결보강 일정
                selectors = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 18,
                          color: tokens.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        const Text('교사', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTeacherDropdown(
                            tokens,
                            teachers,
                            teacher,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: tokens.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        const Text('계획서', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPlanDropdown(
                            tokens,
                            profiles,
                            dropdownValue,
                          ),
                        ),
                        _buildContentEditNavButton(),
                        _buildDeleteProfileButton(selectedProfile),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  selectors,
                  // 안내 (설정은 입력 즉시 자동 저장됨)
                  if (teacher != null && profiles.isEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "'$teacher'의 계획서가 없습니다. [결보강 일정]에서 결강일을 지정해 계획서를 만드세요.",
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textMuted,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onNavigateToPlanDate,
                          child: const Text(
                            '이동',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ] else if (selectedProfile == null &&
                      profiles.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '출력을 위해 위에서 계획서를 선택하세요. (미지정 상태에서는 PDF 출력이 불가합니다)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 교사 선택 드롭다운
  Widget _buildTeacherDropdown(
    DesignTokens tokens,
    List<String> teachers,
    String? teacher,
  ) {
    return DropdownButton<String>(
      value: (teacher != null && teachers.contains(teacher)) ? teacher : null,
      isExpanded: true,
      isDense: true,
      underline: const SizedBox.shrink(),
      hint: const Text('교사 선택', style: TextStyle(fontSize: 13)),
      items:
          teachers.map((name) {
            final count = store.byTeacher(name).length;
            return DropdownMenuItem<String>(
              value: name,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    count > 0 ? '계획서 $count' : '계획서 없음',
                    style: TextStyle(
                      fontSize: 11,
                      color: count > 0 ? tokens.textMuted : Colors.orange,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      onChanged: onTeacherChanged,
    );
  }

  /// 계획서 선택 드롭다운 (없으면 안내 문구)
  Widget _buildPlanDropdown(
    DesignTokens tokens,
    List<PrintProfile> profiles,
    String? dropdownValue,
  ) {
    if (profiles.isEmpty) {
      return Text(
        '계획서 없음 — 결보강 일정에서 지정',
        style: TextStyle(fontSize: 13, color: tokens.textMuted),
      );
    }
    return DropdownButton<String>(
      value: dropdownValue,
      isExpanded: true,
      isDense: true,
      underline: const SizedBox.shrink(),
      hint: Text(
        '계획서를 선택하세요',
        style: TextStyle(fontSize: 13, color: tokens.textMuted),
      ),
      items: [
        for (final p in profiles)
          DropdownMenuItem<String>(
            value: p.id,
            child: Text(
              p.name,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) {
        if (id != null) onProfileChanged(id);
      },
    );
  }

  /// 결보강 일정으로 이동 버튼 (계획서 생성·관리는 그쪽에서)
  Widget _buildContentEditNavButton() {
    return TextButton(
      onPressed: onNavigateToPlanDate,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: const Text('결보강 일정', style: TextStyle(fontSize: 12)),
    );
  }

  /// 현재 선택된 계획서만 삭제하는 버튼 (2026-09-30)
  ///
  /// 결보강 내역 전체 초기화는 결보강 일정 화면에 이미 있다 — 여기는 "지금
  /// 보고 있는 계획서 1건만" 지우고 싶을 때 쓴다. 선택된 계획서가 없으면
  /// 비활성화된다.
  Widget _buildDeleteProfileButton(PrintProfile? selectedProfile) {
    return IconButton(
      onPressed:
          selectedProfile != null
              ? () => onDeleteProfile(selectedProfile)
              : null,
      icon: const Icon(Icons.delete_outline, size: 18),
      tooltip: '선택한 계획서 삭제',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

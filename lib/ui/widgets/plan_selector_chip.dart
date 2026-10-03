import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/print_profile.dart';
import '../../providers/print_profile_provider.dart';
import '../../theme/design_tokens.dart';
import 'content_toolbar_layout.dart';
import 'timetable_grid/grid_header_widgets.dart';

/// 계획서 표시 이름 (공통 규칙): 교사가 있으면 `교사 · 이름`, 없으면 이름만.
///
/// 교체 화면 칩과 계획서 페이지 드롭다운이 같은 표기를 쓴다.
String planDropdownLabel(PrintProfile p) {
  final teacher = p.teacherName.trim();
  return teacher.isEmpty ? p.name : '$teacher · ${p.name}';
}

/// 계획서 관리 버튼 묶음 (공유 위젯).
///
/// 계획서 페이지 2열 헤더에서 [새계획][수정][삭제]로 쓴다.
/// 교체 페이지 툴바 버튼과 같은 컴팩트 크기(높이 34·글자 12)를 쓴다.
class PlanCrudButtons extends StatelessWidget {
  const PlanCrudButtons({
    super.key,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    required this.canCreate,
    required this.canModify,
  });

  final VoidCallback? onCreate;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  /// 만들기 가능 여부 (예: 교체 건이 있을 때만).
  final bool canCreate;

  /// 수정·삭제 가능 여부 (예: 선택된 계획서가 있을 때만).
  final bool canModify;

  Widget _button({
    required BuildContext context,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required String tooltip,
  }) {
    final tokens = context.tokens;
    // 교체 헤더 토글 버튼과 동일 스펙 — 라벨 길이에 맞춘 intrinsic 폭
    return CompactToolbarLabelButton(
      onPressed: onPressed,
      icon: icon,
      label: label,
      tooltip: tooltip,
      backgroundColor: ContentToolbarLayout.neutralButtonBackground(tokens),
      foregroundColor: ContentToolbarLayout.neutralButtonForeground(tokens),
      borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
      height: 34,
      fontSize: 12,
      iconSize: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(
          context: context,
          onPressed: canCreate ? onCreate : null,
          icon: Icons.add,
          label: '새계획',
          tooltip: '새 계획서 만들기',
        ),
        const SizedBox(width: 6),
        _button(
          context: context,
          onPressed: canModify ? onRename : null,
          icon: Icons.edit_outlined,
          label: '수정',
          tooltip: '계획서 이름 수정',
        ),
        const SizedBox(width: 6),
        _button(
          context: context,
          onPressed: canModify ? onDelete : null,
          icon: Icons.delete_outline,
          label: '삭제',
          tooltip: '계획서 삭제 (연결된 결보강 내역도 함께 삭제)',
        ),
      ],
    );
  }
}

/// 계획서 선택 드롭다운 본체 (공유 위젯, 테두리 없음).
///
/// 교체 화면 칩과 계획서 페이지 왼쪽 절반이 **동일하게** 쓴다.
/// 항목 0개면 `계획서 없음` 텍스트를 보여준다 (빈 DropdownButton은
/// 레이아웃 예외를 낼 수 있음).
class PlanSelectorDropdown extends StatelessWidget {
  const PlanSelectorDropdown({
    super.key,
    required this.profiles,
    required this.value,
    required this.onChanged,
    this.cacheKey,
  });

  final List<PrintProfile> profiles;
  final String? value;
  final ValueChanged<String?> onChanged;

  /// 위젯 식별 키 재료 (목록·선택이 바뀌면 드롭다운을 다시 만든다).
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (profiles.isEmpty) {
      return SizedBox(
        height: 34,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '계획서 없음',
            style: TextStyle(fontSize: 13, color: tokens.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return SizedBox(
      height: 34,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: ValueKey(cacheKey ?? 'plan-dd-${value ?? 'none'}'),
            value: value,
            isExpanded: true,
            isDense: true,
            hint: const Text('계획서 선택', style: TextStyle(fontSize: 13)),
            items: [
              for (final p in profiles)
                DropdownMenuItem<String>(
                  value: p.id,
                  child: Text(
                    planDropdownLabel(p),
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

///
/// 결보강 작성의 기준이 되는 계획서를 어느 화면에서든 고를 수 있게 한다.
/// 선택은 전역(`PrintProfileStore.lastUsedProfileId`)에 바로 반영되며,
/// 결보강 일정·결보강 출력 화면이 같은 값을 기준으로 동작한다.
/// 계획서 만들기·수정·삭제는 결보강 일정 화면에서만 한다.
class PlanSelectorChip extends ConsumerWidget {
  /// 교체·계획서·안내·시간표 헤더에서 공통으로 쓰는 칩 너비.
  /// ("교사 · 결보강 YY.MM.DD" 한 줄이 잘리지 않는 최소 폭)
  static const double standardWidth = 200;

  const PlanSelectorChip({super.key, this.width = standardWidth});

  /// 칩 전체 너비 (툴바 행에 고정 폭으로 들어간다).
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final store = ref.watch(printProfileStoreProvider);

    return SizedBox(
      width: width,
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: 16,
            color: tokens.textSecondary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: PlanSelectorDropdown(
              profiles: store.profiles,
              value: store.getById(store.lastUsedProfileId)?.id,
              onChanged: (id) {
                if (id == null) return;
                unawaited(
                  ref
                      .read(printProfileStoreProvider.notifier)
                      .setLastUsedProfile(id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

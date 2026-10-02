import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/print_profile_provider.dart';
import '../../theme/design_tokens.dart';

/// 현재 계획서 선택 칩 (공유 위젯)
///
/// 결보강 작성의 기준이 되는 계획서를 어느 화면에서든 고를 수 있게 한다.
/// 선택은 전역(`PrintProfileStore.lastUsedProfileId`)에 바로 반영되며,
/// 내용 수정·결보강 출력 화면이 같은 값을 기준으로 동작한다.
/// 계획서 만들기·수정·삭제는 내용 수정 화면에서만 한다.
class PlanSelectorChip extends ConsumerWidget {
  const PlanSelectorChip({super.key, this.width = 210});

  /// 칩 전체 너비 (툴바 행에 고정 폭으로 들어간다).
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final store = ref.watch(printProfileStoreProvider);
    final profiles = store.profiles;
    final selectedId = store.getById(store.lastUsedProfileId)?.id;

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
            child:
                profiles.isEmpty
                    ? Text(
                      '계획서 없음',
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      overflow: TextOverflow.ellipsis,
                    )
                    : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedId,
                        isExpanded: true,
                        isDense: true,
                        hint: const Text(
                          '계획서 선택',
                          style: TextStyle(fontSize: 12),
                        ),
                        items: [
                          for (final p in profiles)
                            DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(
                                p.teacherName.trim().isEmpty
                                    ? p.name
                                    : '${p.teacherName} · ${p.name}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
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
          ),
        ],
      ),
    );
  }
}

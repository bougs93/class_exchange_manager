import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/plan_crud_actions_provider.dart';
import 'exchange_control_panel.dart';
import 'plan_selector_chip.dart';

/// 메인 탭 바 아래 2번째 줄 헤더 — 계획서·안내 화면 공용.
///
/// 교체 화면의 `ExchangeWeekBar`와 같은 컨테이너 모양(패딩·배경·하단 보더)을
/// 쓴다. 사이드바가 있는 화면에서도 사이드바까지 포함한 전체 폭 위에 놓는다.
///
/// [showPlanCrud]가 true이면(계획서 탭) 선택 칩 옆에 [새계획][수정][삭제]를
/// 교체 헤더와 같은 컴팩트 버튼으로 붙인다. 안내 탭은 칩만 둔다.
class PlanContextHeaderBar extends ConsumerWidget {
  const PlanContextHeaderBar({super.key, this.showPlanCrud = false});

  /// 계획서 페이지에서만 true — IndexedStack으로 CRUD 액션이 남아 있어도
  /// 안내 화면 헤더에는 버튼을 그리지 않는다.
  final bool showPlanCrud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crud = showPlanCrud ? ref.watch(planCrudActionsProvider) : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          const PlanSelectorChip(),
          if (crud != null) ...[
            const ToolbarGroupDivider(),
            PlanCrudButtons(
              onCreate: crud.onCreate,
              onRename: crud.onRename,
              onDelete: crud.onDelete,
              canCreate: crud.canCreate,
              canModify: crud.canModify,
            ),
          ],
        ],
      ),
    );
  }
}

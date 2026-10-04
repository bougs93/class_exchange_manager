import 'package:flutter/material.dart';

import '../../../../../theme/design_tokens.dart';
import '../../../../../utils/plan_sort.dart';
import '../../../../widgets/content_toolbar_layout.dart';
import '../../../../widgets/timetable_grid/grid_header_widgets.dart';

/// 결보강 일정 그리드(`ContentInputGrid`) 상단 액션 버튼 바.
///
/// 버튼 활성 여부(`allSelected`, `hasAnyGroup`, `hasSelection`, `canUndo`,
/// `canRedo`)와 각 버튼이 눌렸을 때 할 일(`onRefresh` 등)을 모두 생성자로
/// 전달받는 순수 표시 위젯이다 — 계획서 생성/삭제·되돌리기 등 실제 동작은
/// `_ContentInputGridState`가 콜백 안에서 그대로 수행한다.
class PlanGridActionToolbar extends StatelessWidget {
  const PlanGridActionToolbar({
    super.key,
    required this.allSelected,
    required this.hasAnyGroup,
    required this.hasSelection,
    required this.canUndo,
    required this.canRedo,
    required this.onRefresh,
    required this.onToggleSelectAll,
    required this.onDeleteSelected,
    required this.onUndo,
    required this.onRedo,
    required this.onCopyTable,
    required this.onPrint,
    required this.sortMode,
    required this.onSortModeChanged,
  });

  /// 현재 모든 교체 건이 선택됐는지 (라벨 '모두 선택' ↔ '선택 해제' 전환용)
  final bool allSelected;

  /// 선택할 수 있는 교체 건(그룹)이 하나라도 있는지
  final bool hasAnyGroup;

  /// 체크된 교체 건이 하나라도 있는지
  final bool hasSelection;

  /// 되돌리기 가능 여부 (교체 화면과 동일 히스토리 스택 기준)
  final bool canUndo;

  /// 다시실행 가능 여부
  final bool canRedo;

  final VoidCallback onRefresh;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onDeleteSelected;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onCopyTable;
  final VoidCallback onPrint;

  /// 현재 정렬 방식 (결보강 출력과 공유)
  final PlanSortMode sortMode;
  final ValueChanged<PlanSortMode> onSortModeChanged;

  @override
  Widget build(BuildContext context) {
    const buttonHeight = ContentToolbarLayout.buttonHeight;
    final tokens = context.tokens;

    return Row(
      children: [
        // 왼쪽: 새로고침 · 정렬 │ 선택 · 삭제 │ 되돌리기 · 다시실행
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                CompactToolbarIconButton(
                  onPressed: onRefresh,
                  icon: Icons.refresh,
                  tooltip: '표 새로고침',
                  backgroundColor: ContentToolbarLayout.neutralButtonBackground(
                    tokens,
                  ),
                  foregroundColor: ContentToolbarLayout.neutralButtonForeground(
                    tokens,
                  ),
                  borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
                  iconSize: ContentToolbarLayout.buttonIconSize,
                  size: buttonHeight,
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                _SortModeToggle(
                  mode: sortMode,
                  onChanged: onSortModeChanged,
                  height: buttonHeight,
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                _ToolbarDivider(
                  height: buttonHeight,
                  color: ContentToolbarLayout.neutralButtonBorder(tokens),
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                CompactToolbarLabelButton(
                  onPressed: hasAnyGroup ? onToggleSelectAll : null,
                  icon: Icons.checklist,
                  label: allSelected ? '선택 해제' : '모두 선택',
                  tooltip: '결보강 출력에 포함할 교체 건을 선택/해제합니다',
                  backgroundColor: ContentToolbarLayout.neutralButtonBackground(
                    tokens,
                  ),
                  foregroundColor: ContentToolbarLayout.neutralButtonForeground(
                    tokens,
                  ),
                  borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
                  height: buttonHeight,
                  fontSize: ContentToolbarLayout.buttonFontSize,
                  iconSize: ContentToolbarLayout.buttonIconSize,
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                CompactToolbarLabelButton(
                  onPressed: hasSelection ? onDeleteSelected : null,
                  icon: Icons.delete_outline,
                  label: '선택 삭제',
                  tooltip: '선택한 교체 건만 삭제합니다. 되돌리기로 1건씩 복원할 수 있습니다.',
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  borderColor: Colors.red.shade300,
                  height: buttonHeight,
                  fontSize: ContentToolbarLayout.buttonFontSize,
                  iconSize: ContentToolbarLayout.buttonIconSize,
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                _ToolbarDivider(
                  height: buttonHeight,
                  color: ContentToolbarLayout.neutralButtonBorder(tokens),
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                CompactToolbarLabelButton(
                  onPressed: canUndo ? onUndo : null,
                  icon: Icons.undo,
                  label: '되돌리기',
                  tooltip: canUndo ? '되돌리기 (교체와 동일)' : '되돌리기 (불가)',
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.orange.shade700,
                  borderColor: Colors.orange.shade300,
                  height: buttonHeight,
                  fontSize: ContentToolbarLayout.buttonFontSize,
                  iconSize: ContentToolbarLayout.buttonIconSize,
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                CompactToolbarLabelButton(
                  onPressed: canRedo ? onRedo : null,
                  icon: Icons.redo,
                  label: '다시실행',
                  tooltip: canRedo ? '다시 실행 (교체와 동일)' : '다시 실행 (불가)',
                  backgroundColor: Colors.purple.shade100,
                  foregroundColor: Colors.purple.shade700,
                  borderColor: Colors.purple.shade300,
                  height: buttonHeight,
                  fontSize: ContentToolbarLayout.buttonFontSize,
                  iconSize: ContentToolbarLayout.buttonIconSize,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: ContentToolbarLayout.buttonGap),
        // 오른쪽: 엑셀 복사 → 결보강 출력(맨 끝)
        CompactToolbarLabelButton(
          onPressed: onCopyTable,
          icon: Icons.copy,
          label: '엑셀서식 복사',
          tooltip: '엑셀서식 복사',
          backgroundColor: ContentToolbarLayout.neutralButtonBackground(tokens),
          foregroundColor: ContentToolbarLayout.neutralButtonForeground(tokens),
          borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
          height: buttonHeight,
          fontSize: ContentToolbarLayout.buttonFontSize,
          iconSize: ContentToolbarLayout.buttonIconSize,
        ),
        const SizedBox(width: ContentToolbarLayout.buttonGap),
        CompactToolbarLabelButton(
          onPressed: onPrint,
          icon: Icons.print,
          label: '결보강 출력',
          tooltip: '체크한 교체 건만 결보강 출력에서 PDF 미리보기·인쇄',
          backgroundColor: Colors.purple.shade50,
          foregroundColor: Colors.purple.shade600,
          borderColor: Colors.purple.shade600,
          height: buttonHeight,
          fontSize: ContentToolbarLayout.buttonFontSize,
          iconSize: ContentToolbarLayout.buttonIconSize,
        ),
      ],
    );
  }
}

/// 정렬 방식 세그먼트 버튼 `[등록순 | 날짜순]` — 현재 선택이 강조된다.
class _SortModeToggle extends StatelessWidget {
  const _SortModeToggle({
    required this.mode,
    required this.onChanged,
    required this.height,
  });

  final PlanSortMode mode;
  final ValueChanged<PlanSortMode> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final border = ContentToolbarLayout.neutralButtonBorder(context.tokens);
    return Tooltip(
      message: '결보강 일정과 결보강 출력의 행 정렬 방식',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segment('등록순', PlanSortMode.byRegistration),
            Container(width: 1, color: border),
            _segment('날짜순', PlanSortMode.byDate),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, PlanSortMode value) {
    final selected = mode == value;
    return InkWell(
      onTap: selected ? null : () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        color: selected ? Colors.blue.shade600 : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: ContentToolbarLayout.buttonFontSize,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// 툴바 버튼 그룹 사이의 세로 구분선
class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: height * 0.6, color: color);
  }
}

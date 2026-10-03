import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/exchange_path.dart';
import '../../../providers/cell_selection_provider.dart';
import '../../../theme/design_tokens.dart';
import '../timetable_grid/grid_header_widgets.dart';
import 'sidebar_constants.dart';

/// 통합 교체 사이드바 헤더 — [교체 실행] | [닫기]
///
/// (경로 개수는 검색 필터 헤더에 표시) 보강 모드에서 경로 미선택 시에는
/// 안내 문구만 보여주고, 그 외에는 다른 모드와 동일하게 실행 버튼을 보여준다.
/// 실제 교체 실행 로직(Provider 접근, 실행 가능 여부 판단)은 호출부가
/// [onExecute] 콜백으로 책임지며, 이 위젯은 UI 구성과 활성화 조건만 담당한다.
class SidebarHeader extends StatelessWidget {
  final ExchangePathType mode;
  final ExchangePath? selectedPath;
  final bool isLoading;
  final VoidCallback onToggleSidebar;

  /// 교체 실행 (헤더 버튼용) — 활성화 가능할 때만 호출된다.
  final void Function(ExchangePath path) onExecute;

  const SidebarHeader({
    super.key,
    required this.mode,
    required this.selectedPath,
    required this.isLoading,
    required this.onToggleSidebar,
    required this.onExecute,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // 보강: 경로 미선택 시 안내, 선택 시 다른 모드와 동일하게 [교체 실행] 표시
    if (mode == ExchangePathType.supplement && selectedPath == null) {
      final headerText = isLoading ? '보강 준비 중...' : '보강 선택';
      return _buildHeaderContainer(
        tokens,
        child: Row(
          children: [
            Expanded(
              child: Text(
                headerText,
                style: TextStyle(
                  fontSize: SidebarFontSizes.headerText,
                  color: tokens.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            _buildCloseButton(tokens),
          ],
        ),
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final cellState = ref.watch(cellSelectionProvider);

        // 사이드바에서 사용자가 클릭하여 선택한 경로만 사용
        // (cellSelectionProvider 잔여값으로 잘못 활성화되는 것 방지)
        final currentSelectedPath = selectedPath;
        final isFromExchangedCell = cellState.isFromExchangedCell;

        // 경로를 명시적으로 선택했고, 교체된 셀 조회가 아니며, 로딩 중이 아닐 때만 활성화
        final canExchange =
            currentSelectedPath != null && !isFromExchangedCell && !isLoading;

        VoidCallback? onExchange;
        if (canExchange) {
          onExchange = () => onExecute(currentSelectedPath);
        }

        // 보강 모드는 '보강 실행', 그 외는 '교체 실행'
        final executeLabel =
            mode == ExchangePathType.supplement ? '보강 실행' : '교체 실행';

        return _buildHeaderContainer(
          tokens,
          child: Row(
            children: [
              CompactToolbarLabelButton(
                onPressed: onExchange,
                icon: Icons.swap_horiz,
                label: executeLabel,
                tooltip: executeLabel,
                minWidth: 140,
                height: 33,
                fontSize: 12,
                iconSize: 18,
                backgroundColor: tokens.primary.withValues(alpha: 0.2),
                foregroundColor: tokens.primary,
                borderColor: tokens.primary,
              ),
              const Spacer(),
              _buildCloseButton(tokens),
            ],
          ),
        );
      },
    );
  }

  /// 헤더 공통 컨테이너
  Widget _buildHeaderContainer(DesignTokens tokens, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: tokens.appBarSubtleBackground,
        border: Border(bottom: BorderSide(color: tokens.cardBorder)),
      ),
      child: child,
    );
  }

  /// 사이드바 닫기 버튼
  Widget _buildCloseButton(DesignTokens tokens) {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: onToggleSidebar,
      color: tokens.primary,
      iconSize: 16,
      padding: const EdgeInsets.all(3),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/cell_status_symbol_visibility_provider.dart';
import 'exchanged_cell_status_overlay.dart';

/// X·O 표시 토글이 가능한 범례 항목 (빠진·맡은·교체불가)
class ToggleableStatusLegendItem extends ConsumerWidget {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final String label;
  final CellStatusSymbolType symbolType;

  const ToggleableStatusLegendItem({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.label,
    required this.symbolType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSymbolVisible = ref.watch(cellStatusSymbolVisibilityProvider);

    return InkWell(
      onTap: () {
        ref.read(cellStatusSymbolVisibilityProvider.notifier).state =
            !isSymbolVisible;
      },
      borderRadius: BorderRadius.circular(4),
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: isSymbolVisible ? 1 : 0.45,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border:
                      borderWidth > 0
                          ? Border.all(color: borderColor, width: borderWidth)
                          : null,
                  borderRadius: BorderRadius.circular(2),
                ),
                child:
                    isSymbolVisible
                        ? ExchangedStatusSymbol(type: symbolType)
                        : null,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSymbolVisible ? Colors.grey : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

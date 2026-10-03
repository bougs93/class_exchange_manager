import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_settings_provider.dart';
import '../../../../theme/design_tokens.dart';
import '../../../widgets/timetable_grid/exchange_arrow_direction_icon.dart';
import '../../../widgets/timetable_grid/exchange_arrow_style.dart';
import '../../../widgets/timetable_grid/timetable_grid_constants.dart';
import 'settings_group_card.dart';

/// 화살표 표시 설정 섹션 (1:1·2중·연쇄 교체 화살표 방향)
///
/// [StartSettingsCard]의 `_buildArrowDirectionSection` ·
/// `_buildArrowDirectionCard` · `_buildArrowDirectionStaticCard`를 그대로
/// 옮긴 위젯이다. 각 방향 값과 활성화 여부는 Provider를 직접 구독하고,
/// 변경 시 [onOneToOneChanged] · [onDualChanged] 콜백으로 부모에 알린다
/// (실제 저장은 부모의 `saveSetting` 로직이 담당).
class ArrowDirectionSection extends ConsumerWidget {
  const ArrowDirectionSection({
    super.key,
    required this.onOneToOneChanged,
    required this.onDualChanged,
    this.stretchHeight = false,
  });

  final ValueChanged<ArrowDirection> onOneToOneChanged;
  final ValueChanged<ArrowDirection> onDualChanged;
  final bool stretchHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final oneToOneDir = ref.watch(oneToOneArrowDirectionProvider);
    final dualDir = ref.watch(dualArrowDirectionProvider);
    final isDualExchangeEnabled = ref.watch(dualExchangeEnabledProvider);
    final isCircularExchangeEnabled = ref.watch(
      circularExchangeEnabledProvider,
    );

    return SettingsGroupCard(
      stretchHeight: stretchHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: stretchHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Text(
            '화살표 표시',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '교체 화면 시간표에 표시되는 화살표 방향을 설정합니다.',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _ArrowDirectionCard(
                label: '1:1 교체',
                value: oneToOneDir,
                arrowColor: ExchangeArrowStyle.oneToOne.color,
                onChanged: onOneToOneChanged,
              ),
              _ArrowDirectionCard(
                label: '2중 교체',
                value: dualDir,
                arrowColor: ExchangeArrowStyle.dual.color,
                enabled: isDualExchangeEnabled,
                onChanged: onDualChanged,
              ),
              _ArrowDirectionStaticCard(
                label: '연쇄교체',
                arrowColor: ExchangeArrowStyle.circular.color,
                enabled: isCircularExchangeEnabled,
              ),
            ],
          ),
          if (stretchHeight) const Spacer(),
        ],
      ),
    );
  }
}

/// 연쇄교체 화살표 표시 카드 (단방향 1개 고정, 선택 불가)
class _ArrowDirectionStaticCard extends StatelessWidget {
  const _ArrowDirectionStaticCard({
    required this.label,
    required this.arrowColor,
    this.enabled = true,
  });

  final String label;
  final Color arrowColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? tokens.surface : tokens.sectionBackground,
          border: Border.all(color: tokens.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.black87 : tokens.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            ExchangeArrowDirectionIcon(
              direction: ArrowDirection.forward,
              color: enabled ? arrowColor : tokens.textMuted,
              singleLine: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// 화살표 방향 선택 카드 (1:1·2중 각각 그룹)
class _ArrowDirectionCard extends StatelessWidget {
  const _ArrowDirectionCard({
    required this.label,
    required this.value,
    required this.arrowColor,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final ArrowDirection value;
  final Color arrowColor;
  final ValueChanged<ArrowDirection> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final effectiveColor = enabled ? arrowColor : tokens.textMuted;

    Widget arrowIcon(ArrowDirection direction) {
      return ExchangeArrowDirectionIcon(
        direction: direction,
        color: effectiveColor,
      );
    }

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? tokens.surface : tokens.sectionBackground,
          border: Border.all(color: tokens.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.black87 : tokens.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            DropdownButton<ArrowDirection>(
              value: value,
              underline: const SizedBox.shrink(),
              isDense: true,
              iconSize: 18,
              selectedItemBuilder:
                  (context) => [
                    arrowIcon(ArrowDirection.forward),
                    arrowIcon(ArrowDirection.bidirectional),
                  ],
              items: [
                DropdownMenuItem(
                  value: ArrowDirection.forward,
                  child: arrowIcon(ArrowDirection.forward),
                ),
                DropdownMenuItem(
                  value: ArrowDirection.bidirectional,
                  child: arrowIcon(ArrowDirection.bidirectional),
                ),
              ],
              onChanged:
                  !enabled
                      ? null
                      : (newValue) =>
                          newValue != null && newValue != value
                              ? onChanged(newValue)
                              : null,
            ),
          ],
        ),
      ),
    );
  }
}

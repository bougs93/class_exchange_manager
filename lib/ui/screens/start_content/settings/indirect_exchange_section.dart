import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_settings_provider.dart';
import '../../../../theme/design_tokens.dart';
import '../../../widgets/app_switch.dart';
import 'settings_group_card.dart';

/// 간접교체 그룹 (2중 교체 · 순환 교체 메뉴 표시 설정)
///
/// [StartSettingsCard]의 `_buildIndirectExchangeGroupSection` ·
/// `_buildIndirectExchangeCard`를 그대로 옮긴 위젯이다. 2중/순환 교체 활성화
/// 여부는 각 Provider를 직접 구독하고, 변경 시 [onDualChanged] ·
/// [onCircularChanged] 콜백으로 부모에 알린다(실제 저장은 부모의
/// `saveSetting` 로직이 담당).
class IndirectExchangeGroupSection extends ConsumerWidget {
  const IndirectExchangeGroupSection({
    super.key,
    required this.onDualChanged,
    required this.onCircularChanged,
    this.stretchHeight = false,
  });

  final ValueChanged<bool> onDualChanged;
  final ValueChanged<bool> onCircularChanged;
  final bool stretchHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return SettingsGroupCard(
      stretchHeight: stretchHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: stretchHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Text(
            '간접교체',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '1:1 교체가 어려울 때 교체 화면에 표시할 메뉴를 설정합니다.',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _IndirectExchangeCard(
                label: '2중교체',
                description: '2회 간접 교체',
                showRecommended: true,
                isEnabled: ref.watch(dualExchangeEnabledProvider),
                onChanged: onDualChanged,
              ),
              _IndirectExchangeCard(
                label: '순환교체',
                description: '3~4회 간접 교체',
                isEnabled: ref.watch(circularExchangeEnabledProvider),
                onChanged: onCircularChanged,
              ),
            ],
          ),
          if (stretchHeight) const Spacer(),
        ],
      ),
    );
  }
}

/// 간접교체 토글 카드 (화살표 설정 카드와 동일한 컴팩트 스타일)
class _IndirectExchangeCard extends StatelessWidget {
  const _IndirectExchangeCard({
    required this.label,
    required this.description,
    this.showRecommended = false,
    required this.isEnabled,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool showRecommended;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showRecommended) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '추천',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                description,
                style: TextStyle(fontSize: 10, color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 8),
          AppSwitch(value: isEnabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../theme/app_theme_type.dart';
import '../../../../theme/design_tokens.dart';

/// 디자인 테마 선택 섹션 (클래식 / 머티리얼 3 / 플랫 모노)
///
/// [StartSettingsCard]의 `_buildThemeSection` · `_buildThemeOptionCard` ·
/// `_buildThemePreviewSwatch`를 그대로 옮긴 위젯이다. 현재 선택된 테마는
/// [appThemeTypeProvider]를 직접 구독하고, 선택 시 [onSelect] 콜백으로
/// 부모에 알린다(실제 저장은 부모의 `saveSetting` 로직이 담당).
class DesignThemeSection extends ConsumerWidget {
  const DesignThemeSection({super.key, required this.onSelect});

  final ValueChanged<AppThemeType> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTheme = ref.watch(appThemeTypeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '디자인 테마',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < AppThemeType.displayOrder.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _ThemeOptionCard(
                  type: AppThemeType.displayOrder[i],
                  isSelected: selectedTheme == AppThemeType.displayOrder[i],
                  onSelect: onSelect,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 개별 디자인 테마 옵션 카드
class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.type,
    required this.isSelected,
    required this.onSelect,
  });

  final AppThemeType type;
  final bool isSelected;
  final ValueChanged<AppThemeType> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final previewTokens = DesignTokens.of(type);

    return InkWell(
      onTap: () => onSelect(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.sectionBackground,
          border: Border.all(
            color: isSelected ? previewTokens.primary : tokens.cardBorder,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _ThemePreviewSwatch(tokens: previewTokens),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color:
                            isSelected
                                ? previewTokens.primary
                                : tokens.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          type.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.description,
                    style: TextStyle(fontSize: 10, color: tokens.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 테마 미리보기 스와치 (미니 화면 목업)
class _ThemePreviewSwatch extends StatelessWidget {
  const _ThemePreviewSwatch({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      width: 36,
      height: 30,
      decoration: BoxDecoration(
        color: t.scaffoldBackground,
        border: Border.all(color: t.cardBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 7, color: t.appBarBackground),
          Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.8,
                  child: Container(
                    height: 3,
                    color: t.textPrimary.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 14,
                  height: 7,
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

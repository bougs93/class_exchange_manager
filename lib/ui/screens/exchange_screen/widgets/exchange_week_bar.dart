import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/exchange_week_summary_provider.dart';
import '../../../../providers/selected_week_provider.dart';
import '../../../../utils/week_date_calculator.dart';
import '../../personal_schedule_screen/exchange_week_collector.dart';

/// 교체 화면 상단 주차 선택 바 (§10.5)
///
/// - 교체가 있는 주는 칩으로 표시하고 건수를 함께 보여준다(결강일 기준 · A안)
/// - `◀ ▶`로는 교체가 없는 주로도 이동할 수 있다 — 새 교체를 만들려면
///   빈 주로도 갈 수 있어야 하기 때문이다
/// - 주를 바꾸면 [selectedWeekProvider]만 갱신한다. 그리드 재합성은
///   이 값을 구독하는 쪽(교체 화면)에서 처리한다
class ExchangeWeekBar extends ConsumerWidget {
  /// 주가 바뀐 뒤 그리드를 다시 그리기 위한 콜백
  final VoidCallback? onWeekChanged;

  const ExchangeWeekBar({super.key, this.onWeekChanged});

  void _moveWeek(WidgetRef ref, int offset) {
    final current = ref.read(selectedWeekProvider);
    ref.read(selectedWeekProvider.notifier).state =
        WeekDateCalculator.moveWeek(current, offset);
    onWeekChanged?.call();
  }

  void _selectWeek(WidgetRef ref, DateTime weekMonday) {
    ref.read(selectedWeekProvider.notifier).state = weekMonday;
    onWeekChanged?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final counts = ref.watch(exchangeWeekCountsProvider);
    final weeks = ref.watch(exchangeWeeksProvider);

    final currentCount = exchangeCountForWeek(counts, selectedWeek);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            tooltip: '이전 주',
            visualDensity: VisualDensity.compact,
            onPressed: () => _moveWeek(ref, -1),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final week in weeks)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _WeekChip(
                        label: ExchangeWeekCollector.monthWeekLabel(week),
                        count: counts[week] ?? 0,
                        selected: ExchangeWeekCollector.isSameWeek(
                          week,
                          selectedWeek,
                        ),
                        onTap: () => _selectWeek(ref, week),
                      ),
                    ),
                  // 선택된 주에 교체가 없으면 칩 목록에 없으므로 별도로 보여준다
                  if (currentCount == 0)
                    _WeekChip(
                      label: ExchangeWeekCollector.monthWeekLabel(selectedWeek),
                      count: 0,
                      selected: true,
                      onTap: () {},
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            tooltip: '다음 주',
            visualDensity: VisualDensity.compact,
            onPressed: () => _moveWeek(ref, 1),
          ),
          const SizedBox(width: 4),
          Text(
            '${WeekDateCalculator.formatWeekRange(selectedWeek)} · 교체 $currentCount건',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 주차 칩 — 라벨 + 교체 건수 배지
class _WeekChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _WeekChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:
                    selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        color: selected ? theme.colorScheme.onPrimaryContainer : null,
      ),
      selectedColor: theme.colorScheme.primaryContainer,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

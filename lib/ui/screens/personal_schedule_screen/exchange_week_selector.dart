import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';import '../../../providers/personal_schedule_provider.dart';
import '../../../utils/week_date_calculator.dart';
import 'exchange_week_collector.dart';
import 'teacher_card_grid_constants.dart';

/// AppBar용 — 교체 주 드롭다운 + 이전/다음 교체 주 이동 버튼
class ExchangeWeekToolbar extends ConsumerWidget {
  final List<DateTime> exchangeWeeks;
  final DateTime currentWeekMonday;

  const ExchangeWeekToolbar({
    super.key,
    required this.exchangeWeeks,
    required this.currentWeekMonday,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(personalScheduleProvider.notifier);
    final theme = Theme.of(context);
    final hasWeeks = exchangeWeeks.isNotEmpty;

    final previousWeek = hasWeeks
        ? ExchangeWeekCollector.findPreviousWeek(
            currentWeekMonday,
            exchangeWeeks,
          )
        : null;
    final nextWeek = hasWeeks
        ? ExchangeWeekCollector.findNextWeek(currentWeekMonday, exchangeWeeks)
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 교체 주 드롭다운
        PopupMenuButton<DateTime>(
          tooltip: hasWeeks ? '교체 주 선택' : '지정된 교체 주가 없습니다',
          enabled: hasWeeks,
          onSelected: notifier.moveToWeek,
          itemBuilder: (context) {
            return exchangeWeeks.map((weekMonday) {
              final selected = ExchangeWeekCollector.isSameWeek(
                weekMonday,
                currentWeekMonday,
              );
              return PopupMenuItem<DateTime>(
                value: weekMonday,
                child: Row(
                  children: [
                    if (selected)
                      Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        WeekDateCalculator.formatWeekRange(weekMonday),
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_available,
                  size: 16,
                  color: hasWeeks
                      ? theme.colorScheme.primary
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  '교체 주',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hasWeeks
                        ? theme.colorScheme.primary
                        : Colors.grey.shade500,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: hasWeeks
                      ? theme.colorScheme.primary
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 2),
        // 이전 교체 주
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 18),
          onPressed: previousWeek != null
              ? () => notifier.moveToWeek(previousWeek)
              : null,
          tooltip: '이전 교체 주',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        // 다음 교체 주
        IconButton(
          icon: const Icon(Icons.skip_next, size: 18),
          onPressed:
              nextWeek != null ? () => notifier.moveToWeek(nextWeek) : null,
          tooltip: '다음 교체 주',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }
}

/// 본문 상단 — 교체 주차 칩 가로 스크롤
class ExchangeWeekChipRow extends ConsumerWidget {
  final List<DateTime> exchangeWeeks;
  final DateTime currentWeekMonday;

  /// true면 툴바 한 줄 안에 배치 (바깥 여백 없음)
  final bool inline;

  const ExchangeWeekChipRow({
    super.key,
    required this.exchangeWeeks,
    required this.currentWeekMonday,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exchangeWeeks.isEmpty) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(personalScheduleProvider.notifier);
    final theme = Theme.of(context);
    final chipLabels = ExchangeWeekCollector.buildChipLabels(exchangeWeeks);

    final chipRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: exchangeWeeks.map((weekMonday) {
          final selected = ExchangeWeekCollector.isSameWeek(
            weekMonday,
            currentWeekMonday,
          );
          final label =
              chipLabels[ExchangeWeekCollector.weekKey(weekMonday)] ??
              ExchangeWeekCollector.monthWeekLabel(weekMonday);

          return Padding(
            padding: const EdgeInsets.only(
              right: TeacherCardGridConstants.weekChipSpacing,
            ),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => notifier.moveToWeek(weekMonday),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? theme.colorScheme.onPrimaryContainer : null,
              ),
              selectedColor: theme.colorScheme.primaryContainer,
              side: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.grey.shade300,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(
                horizontal: TeacherCardGridConstants.weekChipPaddingHorizontal,
                vertical: 0,
              ),
              labelPadding: const EdgeInsets.symmetric(
                horizontal:
                    TeacherCardGridConstants.weekChipLabelPaddingHorizontal,
                vertical: 0,
              ),
            ),
          );
        }).toList(),
      ),
    );

    if (inline) {
      return chipRow;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TeacherCardGridConstants.toolbarHorizontalPadding,
      ),
      child: chipRow,
    );
  }
}

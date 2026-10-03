import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/personal_schedule_provider.dart';
import '../../../providers/substitution_plan_viewmodel.dart';
import '../../../utils/week_date_calculator.dart';
import '../../widgets/exchange_control_panel.dart';
import '../../widgets/plan_selector_chip.dart';
import '../../widgets/timetable_grid/grid_header_widgets.dart';
import 'exchange_week_collector.dart';

/// 시간표 화면 2열 헤더 — 교체 페이지 [ExchangeWeekBar]와 같은 뼈대.
///
/// `[계획서칩] | [교체 보기] | [<] [이번주] | [주차칩(건수)…] [>]`
class PersonalScheduleHeaderBar extends ConsumerWidget {
  const PersonalScheduleHeaderBar({
    super.key,
    required this.exchangeWeeks,
    required this.relatedPlanData,
    required this.isExchangeViewEnabled,
    required this.onToggleExchangeView,
    this.semesterStart,
    this.semesterEnd,
  });

  final List<DateTime> exchangeWeeks;
  final List<SubstitutionPlanData> relatedPlanData;
  final bool isExchangeViewEnabled;
  final ValueChanged<bool> onToggleExchangeView;
  final DateTime? semesterStart;
  final DateTime? semesterEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheduleState = ref.watch(personalScheduleProvider);
    final currentWeek = scheduleState.currentWeekMonday;
    final notifier = ref.read(personalScheduleProvider.notifier);
    final isThisWeek = _isSameWeek(
      currentWeek,
      WeekDateCalculator.getThisWeekMonday(),
    );

    final chipLabels = ExchangeWeekCollector.buildChipLabels(exchangeWeeks);
    final weekCounts = ExchangeWeekCollector.countByWeek(
      relatedPlanData,
      referenceDate: currentWeek,
      semesterStart: semesterStart,
      semesterEnd: semesterEnd,
    );

    // 보고 있는 주가 교체 주 목록에 없으면 끼워 넣어 순서를 유지한다.
    final chipWeeks = [
      ...exchangeWeeks,
      if (!exchangeWeeks.any(
        (w) => ExchangeWeekCollector.isSameWeek(w, currentWeek),
      ))
        currentWeek,
    ]..sort((a, b) => a.compareTo(b));

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
          const ToolbarGroupDivider(),
          _exchangeViewButton(theme),
          const ToolbarGroupDivider(),
          _weekNavButton(
            theme,
            icon: Icons.chevron_left,
            tooltip: '이전 주',
            onPressed: notifier.moveToPreviousWeek,
          ),
          const SizedBox(width: 4),
          _thisWeekButton(theme, isThisWeek, notifier.moveToThisWeek),
          const ToolbarGroupDivider(),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final week in chipWeeks)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _WeekChip(
                        label:
                            chipLabels[ExchangeWeekCollector.weekKey(week)] ??
                            ExchangeWeekCollector.monthWeekLabel(week),
                        count:
                            weekCounts[ExchangeWeekCollector.weekKey(week)] ??
                            0,
                        selected: ExchangeWeekCollector.isSameWeek(
                          week,
                          currentWeek,
                        ),
                        onTap: () => notifier.moveToWeek(week),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _weekNavButton(
            theme,
            icon: Icons.chevron_right,
            tooltip: '다음 주',
            onPressed: notifier.moveToNextWeek,
          ),
        ],
      ),
    );
  }

  Widget _exchangeViewButton(ThemeData theme) {
    return CompactToolbarLabelButton(
      onPressed: () => onToggleExchangeView(!isExchangeViewEnabled),
      icon: Icons.swap_horiz,
      label: '교체 보기',
      tooltip: isExchangeViewEnabled ? '교체 보기 끄기' : '교체 보기 켜기',
      height: 34,
      fontSize: 12,
      iconSize: 16,
      backgroundColor:
          isExchangeViewEnabled
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : Colors.grey.shade100,
      foregroundColor:
          isExchangeViewEnabled
              ? theme.colorScheme.primary
              : Colors.grey.shade700,
      borderColor:
          isExchangeViewEnabled
              ? theme.colorScheme.primary
              : Colors.grey.shade400,
    );
  }

  Widget _thisWeekButton(
    ThemeData theme,
    bool isThisWeek,
    VoidCallback onPressed,
  ) {
    // CompactToolbarLabelButton은 onPressed==null일 때 "(경로를 선택하세요)"를
    // 툴팁에 붙이므로, 이번 주면 동일 스타일의 비활성 칩으로 그린다.
    if (isThisWeek) {
      return Tooltip(
        message: '이번 주입니다',
        child: Material(
          color: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.today, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    '이번주',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return CompactToolbarLabelButton(
      onPressed: onPressed,
      icon: Icons.today,
      label: '이번주',
      tooltip: '이번 주로 이동',
      height: 34,
      fontSize: 12,
      iconSize: 16,
      backgroundColor: Colors.grey.shade100,
      foregroundColor: Colors.grey.shade700,
      borderColor: Colors.grey.shade400,
    );
  }

  Widget _weekNavButton(
    ThemeData theme, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.6,
        ),
        side: BorderSide(color: theme.dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// 주차 칩 — 라벨 + 교체 건수 배지 (교체 페이지 _WeekChip과 동일 톤)
class _WeekChip extends StatelessWidget {
  const _WeekChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alpha = selected ? 1.0 : 0.6;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
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

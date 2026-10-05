import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/personal_schedule_provider.dart';
import '../../../providers/substitution_plan_viewmodel.dart';
import '../../widgets/exchange_control_panel.dart';
import '../../widgets/header_segmented_toggle.dart';
import '../../widgets/plan_selector_chip.dart';
import '../../widgets/week_navigator_strip.dart';
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
          _exchangeViewButton(),
          const ToolbarGroupDivider(),
          Expanded(
            child: WeekNavigatorStrip(
              weeks: chipWeeks,
              selectedWeek: currentWeek,
              countOf:
                  (week) =>
                      weekCounts[ExchangeWeekCollector.weekKey(week)] ?? 0,
              onSelectWeek: notifier.moveToWeek,
              onPrevious: notifier.moveToPreviousWeek,
              onNext: notifier.moveToNextWeek,
            ),
          ),
        ],
      ),
    );
  }

  Widget _exchangeViewButton() {
    return HeaderSegmentedToggle(
      value: isExchangeViewEnabled,
      offLabel: '원본',
      onLabel: '교체',
      tooltip: isExchangeViewEnabled ? '교체 보기 끄기' : '교체 보기 켜기',
      onChanged: (v) => onToggleExchangeView(v),
      height: 34,
    );
  }
}

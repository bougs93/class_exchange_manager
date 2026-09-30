import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/dated_semester_provider.dart';
import '../../../../providers/exchange_view_provider.dart';
import '../../../../providers/exchange_week_summary_provider.dart';
import '../../../../providers/selected_week_provider.dart';
import '../../../../providers/show_week_header_provider.dart';
import '../../../../utils/week_date_calculator.dart';
import '../../../../utils/week_semester_status.dart';
import '../../../widgets/app_switch.dart';
import '../../../widgets/timetable_grid/grid_header_widgets.dart';
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

  /// 날짜표시 스위치가 바뀐 뒤 헤더를 강제로 다시 그리기 위한 콜백 (S1.5)
  final VoidCallback? onShowWeekHeaderChanged;

  /// 교체/원본 스위치가 바뀔 때 호출된다. 원래 그리드 툴바에 있던 스위치를
  /// "실제 날짜" 옆으로 옮겨왔다(두 스위치를 붙여 달라는 요청, 2026-09-30) —
  /// 실제 켜기/끄기 로직은 그대로 `TimetableTabContent`가 가지고 있다.
  final ValueChanged<bool>? onToggleExchangeView;

  const ExchangeWeekBar({
    super.key,
    this.onWeekChanged,
    this.onShowWeekHeaderChanged,
    this.onToggleExchangeView,
  });

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
    final showWeekHeader = ref.watch(showWeekHeaderProvider);

    final currentCount = exchangeCountForWeek(counts, selectedWeek);

    // 학기 범위 밖 주 안내 (S4.2) — 날짜표시가 꺼져 있으면 실제 날짜 개념 자체가
    // 화면에 드러나지 않으므로 이 아이콘도 함께 숨긴다(OQ-5 확정).
    final datedSemester = ref.watch(datedSemesterProvider).valueOrNull;
    final weekSemesterStatus = WeekSemesterStatusChecker.check(
      weekMonday: selectedWeek,
      semester: datedSemester,
    );
    final showOutOfSemesterIcon =
        showWeekHeader &&
        (weekSemesterStatus == WeekSemesterStatus.beforeRange ||
            weekSemesterStatus == WeekSemesterStatus.afterRange);

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
          // 주차 칩(예: "10월1주")은 실제 월·주 정보를 드러내므로 날짜표시 OFF일 때는 숨긴다 (S1.5)
          if (showWeekHeader)
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
                        label: ExchangeWeekCollector.monthWeekLabel(
                          selectedWeek,
                        ),
                        count: 0,
                        selected: true,
                        onTap: () {},
                      ),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            tooltip: '다음 주',
            visualDensity: VisualDensity.compact,
            onPressed: () => _moveWeek(ref, 1),
          ),
          const SizedBox(width: 4),
          Text(
            // 날짜표시 OFF(기본값)일 때는 실제 날짜 범위를 숨기고 건수만 표시한다 (S1.5)
            showWeekHeader
                ? '${WeekDateCalculator.formatWeekRange(selectedWeek)} · 교체 $currentCount건'
                : '교체 $currentCount건',
            style: theme.textTheme.bodySmall?.copyWith(
              // 학기 범위 밖 주는 날짜 텍스트도 아이콘과 같은 색으로 강조한다 (S4.2, 2026-09-29 피드백)
              color:
                  showOutOfSemesterIcon
                      ? Colors.orange.shade700
                      : theme.colorScheme.onSurfaceVariant,
              fontWeight: showOutOfSemesterIcon ? FontWeight.w600 : null,
            ),
          ),
          if (showOutOfSemesterIcon) ...[
            const SizedBox(width: 4),
            Tooltip(
              message:
                  weekSemesterStatus == WeekSemesterStatus.beforeRange
                      ? '학기 시작 전 주입니다'
                      : '학기 종료 후 주입니다',
              // 눈에 잘 안 띈다는 피드백(2026-09-29)에 따라 주황 계열로 강조한다.
              child: Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
            ),
          ],
          const SizedBox(width: 8),
          Tooltip(
            message: showWeekHeader ? '실제 날짜 끄기' : '실제 날짜 켜기',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '실제 날짜',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSwitch(
                  value: showWeekHeader,
                  onChanged: (value) {
                    ref.read(showWeekHeaderProvider.notifier).state = value;
                    onShowWeekHeaderChanged?.call();
                  },
                ),
              ],
            ),
          ),
          // "교체/원본" 스위치 — 원래 그리드 툴바(다른 줄)에 있었으나, "실제
          // 날짜" 스위치 옆에 붙여 달라는 요청(2026-09-30)으로 이 자리로
          // 옮겨왔다. 실제 켜기/끄기 로직은 `onToggleExchangeView` 콜백으로
          // 위임한다(그리드의 timeSlots·dataSource가 필요해서 이 위젯 자체는
          // 그 값을 모른다).
          if (onToggleExchangeView != null) ...[
            const SizedBox(width: 6),
            SizedBox(
              height: 20,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 6),
            ExchangeViewCheckbox(
              isEnabled: ref.watch(isExchangeViewEnabledProvider),
              onChanged:
                  (value) => onToggleExchangeView!.call(value ?? false),
            ),
          ],
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

import 'package:flutter/material.dart';

import '../screens/personal_schedule_screen/exchange_week_collector.dart';
import '../../utils/week_date_calculator.dart';
import 'exchange_control_panel.dart';
import 'timetable_grid/grid_header_widgets.dart';

/// 주 이동 띠 — `◀ [이번주] | [10월1주 ①] [10월2주 ①] … ▶`
///
/// 교체 화면(`ExchangeWeekBar`)과 시간표 화면(`PersonalScheduleHeaderBar`)이
/// **이 위젯 하나를 그대로** 쓴다. 두 화면의 주 이동 UI가 어긋나지 않게 하려고
/// 버튼·칩·간격을 여기에만 둔다. 화면마다 다른 것은 데이터(주 목록·건수)와
/// 콜백뿐이다.
///
/// 내부에 `Expanded`가 있으므로 부모 `Row`에서 `Expanded`로 감싸서 쓴다.
class WeekNavigatorStrip extends StatelessWidget {
  const WeekNavigatorStrip({
    super.key,
    required this.weeks,
    required this.selectedWeek,
    required this.countOf,
    required this.onSelectWeek,
    required this.onPrevious,
    required this.onNext,
    this.substitutionCountOf,
    this.isOutOfRange,
  });

  /// 칩으로 보여줄 주(월요일) 목록 — 날짜순 정렬된 상태로 넘긴다.
  final List<DateTime> weeks;
  final DateTime selectedWeek;

  /// 주 칩의 교체 건수(색 배지)
  final int Function(DateTime week) countOf;

  /// 주 칩의 보강 건수(회색 배지) — 없으면 표시하지 않는다.
  final int Function(DateTime week)? substitutionCountOf;

  /// 학기 범위 밖 주(주황 테두리) — 없으면 표시하지 않는다.
  final bool Function(DateTime week)? isOutOfRange;

  /// 칩·[이번주] 버튼으로 주를 고를 때. [이번주]는 이번 주 월요일을 넘긴다.
  final ValueChanged<DateTime> onSelectWeek;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thisWeek = WeekDateCalculator.getThisWeekMonday();

    return Row(
      children: [
        _WeekNavButton(
          icon: Icons.chevron_left,
          tooltip: '이전 주',
          onPressed: onPrevious,
          theme: theme,
        ),
        const SizedBox(width: 4),
        ThisWeekButton(
          isThisWeek: ExchangeWeekCollector.isSameWeek(selectedWeek, thisWeek),
          onPressed: () => onSelectWeek(thisWeek),
        ),
        const ToolbarGroupDivider(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final week in weeks)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: WeekChip(
                      label: ExchangeWeekCollector.monthWeekLabel(week),
                      count: countOf(week),
                      substitutionCount: substitutionCountOf?.call(week) ?? 0,
                      selected: ExchangeWeekCollector.isSameWeek(
                        week,
                        selectedWeek,
                      ),
                      outOfRange: isOutOfRange?.call(week) ?? false,
                      onTap: () => onSelectWeek(week),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _WeekNavButton(
          icon: Icons.chevron_right,
          tooltip: '다음 주',
          onPressed: onNext,
          theme: theme,
        ),
      ],
    );
  }
}

/// 주 이동 버튼 — 가는 아이콘보다 배경·테두리를 주어 잘 보이게 한다.
class _WeekNavButton extends StatelessWidget {
  const _WeekNavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.theme,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
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
}

/// 주차 칩 — 라벨 + 교체 건수(색) + 보강 건수(회색) 배지, 학기 범위 밖이면 주황 테두리
class WeekChip extends StatelessWidget {
  final String label;
  final int count;
  final int substitutionCount;
  final bool selected;
  final bool outOfRange;
  final VoidCallback onTap;

  const WeekChip({
    super.key,
    required this.label,
    required this.count,
    this.substitutionCount = 0,
    required this.selected,
    this.outOfRange = false,
    required this.onTap,
  });

  Widget _badge(int value, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alpha = selected ? 1.0 : 0.6;

    final chip = ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0)
            _badge(count, theme.colorScheme.primary.withValues(alpha: alpha)),
          if (substitutionCount > 0)
            _badge(substitutionCount, Colors.grey.withValues(alpha: alpha)),
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
      side:
          outOfRange
              ? BorderSide(color: Colors.orange.shade700, width: 1.5)
              : null,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (!outOfRange) return chip;
    return Tooltip(message: '학기 범위 밖 주입니다', child: chip);
  }
}

/// [이번주] 버튼 — [WeekNavigatorStrip] 안에서 쓴다.
///
/// 이미 이번 주를 보고 있으면([isThisWeek]) 같은 모양의 비활성 칩으로 그린다.
class ThisWeekButton extends StatelessWidget {
  const ThisWeekButton({
    super.key,
    required this.isThisWeek,
    required this.onPressed,
  });

  final bool isThisWeek;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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
}

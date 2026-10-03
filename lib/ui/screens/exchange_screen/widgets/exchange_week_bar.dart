import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/school_semester.dart';
import '../../../../providers/combined_view_switch_provider.dart';
import '../../../../providers/dated_semester_provider.dart';
import '../../../../providers/exchange_view_provider.dart';
import '../../../../providers/exchange_week_summary_provider.dart';
import '../../../../providers/selected_week_provider.dart';
import '../../../../providers/show_week_header_provider.dart';
import '../../../../utils/week_date_calculator.dart';
import '../../../../utils/week_semester_status.dart';
import '../../../widgets/exchange_control_panel.dart';
import '../../../widgets/plan_selector_chip.dart';
import '../../../widgets/timetable_grid/grid_header_widgets.dart';
import '../../personal_schedule_screen/exchange_week_collector.dart';

/// 교체 화면 상단 주차 선택 바 (§10.5)
///
/// 행 구성: [계획서 선택 | 날짜·교체 반영 버튼 | ◀ 주차 칩 ▶]
/// - 계획서 칩: 결보강 작성의 기준. 선택은 전역(lastUsedProfileId)에 반영
/// - 날짜 범·건수 텍스트는 삭제 — 건수는 주 칩 뱃지로, 범위 밖 안내는
///   해당 주 칩의 주황 테두리로 표시한다
/// - `◀ ▶`로는 교체가 없는 주로도 이동할 수 있다 — 새 교체를 만들려면
///   빈 주로도 갈 수 있어야 하기 때문이다
/// - 날짜 반영 OFF에서는 `◀ ▶`·칩을 숨긴다 ([_setShowWeekHeader])
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
    ref.read(selectedWeekProvider.notifier).state = WeekDateCalculator.moveWeek(
      current,
      offset,
    );
    onWeekChanged?.call();
  }

  /// 칩 라벨 — 이번 주는 "이번주"로 쓴다. 교체가 없어도 보고 있는 주는
  /// 칩으로 뜨는데(아래 build 참고), 표시가 없으면 "교체 없는 주가 왜 있지?"로 보인다.
  static String _chipLabel(DateTime week) {
    final isThisWeek = ExchangeWeekCollector.isSameWeek(
      week,
      WeekDateCalculator.getThisWeekMonday(),
    );
    return isThisWeek ? '이번주' : ExchangeWeekCollector.monthWeekLabel(week);
  }

  void _selectWeek(WidgetRef ref, DateTime weekMonday) {
    ref.read(selectedWeekProvider.notifier).state = weekMonday;
    onWeekChanged?.call();
  }

  /// 날짜 반영 스위치 변경 — 반드시 이 함수로만 바꾼다.
  ///
  /// 날짜 반영 OFF = "날짜 없는 주간 시간표 1장" 모드(2026-09-30 사용자 확정):
  /// - 화면·검증은 모든 주 교체를 합친다(`ResolvedWeek.allWeeks`)
  /// - 주 이동(◀ ▶)은 숨긴다
  /// - **불변 조건: OFF에서 선택 주 = 항상 이번 주.** 새 교체 날짜
  ///   (`ExchangeExecutor._computeExchangeDates`), 날짜 지정 교체불가 셀,
  ///   계획서 날짜 선택기가 모두 이 값을 쓰므로, 주가 안 보이는데 다른 주로
  ///   남아 있으면 엉뚱한 날짜로 저장된다. 되돌리기의 주 이동도 OFF에선 막는다.
  ///
  /// ON으로 켤 때는 이번 주부터 처음 나오는 교체(결강일) 주로 자동 이동한다
  /// ([firstExchangeWeekFrom]) — 빈 이번 주가 먼저 보이면 교체를 찾아 다시 눌러야 한다.
  void _setShowWeekHeader(WidgetRef ref, bool value) {
    ref.read(showWeekHeaderProvider.notifier).state = value;
    final thisWeek = WeekDateCalculator.getThisWeekMonday();
    ref.read(selectedWeekProvider.notifier).state =
        value
            ? firstExchangeWeekFrom(ref.read(exchangeWeeksProvider), thisWeek)
            : thisWeek;
    onShowWeekHeaderChanged?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final counts = ref.watch(exchangeWeekCountsProvider);
    // 칩 목록은 "결강일 기준"이 아니라 "실제로 그 주에 뭔가 보이는가" 기준을
    // 쓴다(교체일이 다른 주로 넘어간 경우도 포함) — 2026-09-30 버그 수정,
    // exchange_week_summary_provider.dart의 exchangeVisibleWeeksProvider 참고.
    final weeks = ref.watch(exchangeVisibleWeeksProvider);
    final showWeekHeader = ref.watch(showWeekHeaderProvider);

    // OFF는 모든 주를 한 장에 합쳐 보여주므로 칩 목록은 숨긴다.
    // 학기 범위 밖 안내는 각 주 칩의 테두리로 표시한다.
    // (datedSemester는 아래에서 주 칩의 범위 밖 표시에 쓴다)
    final substitutionCounts = ref.watch(
      exchangeSubstitutionWeekCountsProvider,
    );
    // 보고 있는 주가 목록에 없으면(진짜 빈 주) 끼워 넣고 날짜순으로 정렬한다 —
    // 끝에 따로 붙이면 [9월3주][10월1주][이번주]처럼 순서가 뒤섞인다.
    final chipWeeks = [
      ...weeks,
      if (!weeks.any((w) => ExchangeWeekCollector.isSameWeek(w, selectedWeek)))
        selectedWeek,
    ]..sort((a, b) => a.compareTo(b));

    // 학기 정보는 주 칩의 범위 밖 표시에만 쓴다.
    final datedSemester = ref.watch(datedSemesterProvider).valueOrNull;

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
          // 계획서 선택 — 결보강 작성의 기준
          const PlanSelectorChip(),
          const ToolbarGroupDivider(),
          // 날짜·교체 반영 버튼 (스위치 대신)
          ..._buildDateAndExchangeSwitches(context, ref, theme, showWeekHeader),
          const ToolbarGroupDivider(),
          // ◀ ▶·주차 칩은 날짜 반영 ON에서만 — OFF는 주 개념이 없는 한 장짜리 화면이다
          // (선택 주를 이번 주로 고정하는 이유는 `_setShowWeekHeader` 참고)
          if (showWeekHeader) ...[
            _buildWeekNavButton(
              theme,
              icon: Icons.chevron_left,
              tooltip: '이전 주',
              onPressed: () => _moveWeek(ref, -1),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final week in chipWeeks)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _WeekChip(
                          label: _chipLabel(week),
                          count: exchangeCountForWeek(counts, week),
                          substitutionCount: exchangeCountForWeek(
                            substitutionCounts,
                            week,
                          ),
                          selected: ExchangeWeekCollector.isSameWeek(
                            week,
                            selectedWeek,
                          ),
                          outOfRange: _isOutOfRangeWeek(week, datedSemester),
                          onTap: () => _selectWeek(ref, week),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _buildWeekNavButton(
              theme,
              icon: Icons.chevron_right,
              tooltip: '다음 주',
              onPressed: () => _moveWeek(ref, 1),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  /// 학기 범위 밖 주 여부 (S4.2) — 해당 주 칩에 주황 테두리로 표시한다.
  /// 날짜표시가 꺼져 있으면 날짜 개념 자체가 화면에 드러나지 않으므로
  /// 항상 false다 (OQ-5 확정).
  bool _isOutOfRangeWeek(DateTime week, SchoolSemester? semester) {
    if (semester == null) return false;
    final status = WeekSemesterStatusChecker.check(
      weekMonday: week,
      semester: semester,
    );
    return status == WeekSemesterStatus.beforeRange ||
        status == WeekSemesterStatus.afterRange;
  }

  /// 주 이동 버튼 — 기존 가는 아이콘보다 배경·테두리를 주어 잘 보이게 한다.
  Widget _buildWeekNavButton(
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

  /// "날짜 반영"·"교체" 버튼 — 통합 여부는 "준비 > 기타 설정"의
  /// [combinedViewSwitchProvider]로 사용자가 고른다(2026-09-30, 기본 통합).
  /// 통합이면 버튼 하나로 둘 다 같이 켜고 끄고, 아니면 예전처럼 각각
  /// 따로 켜고 끌 수 있게 나눠서 보여준다(둘 중 하나만 켜야 하는 경우가
  /// 실제로 있다는 사용자 확인에 따라 계속 남겨둔 선택지).
  ///
  /// 스위치 대신 버튼으로 그린 이유: 계획서 칩·주 이동 버튼과 같은 행에
  /// 두기 위해 같은 버튼 계열로 통일한다. ON/OFF는 색으로 구분한다.
  List<Widget> _buildDateAndExchangeSwitches(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool showWeekHeader,
  ) {
    // onToggleExchangeView가 없으면(시간표 미로드 등) "교체" 버튼 자체를
    // 못 그리므로, 통합 모드든 아니든 "날짜 반영" 하나만 보여준다.
    if (onToggleExchangeView == null) {
      return [
        _reflectToggleButton(
          theme,
          value: showWeekHeader,
          icon: Icons.calendar_month,
          label: '날짜 반영',
          tooltip: showWeekHeader ? '날짜 반영 끄기' : '날짜 반영 켜기',
          onPressed: () => _setShowWeekHeader(ref, !showWeekHeader),
        ),
      ];
    }

    final combined = ref.watch(combinedViewSwitchProvider);
    if (!combined) {
      return [
        _reflectToggleButton(
          theme,
          value: showWeekHeader,
          icon: Icons.calendar_month,
          label: '날짜 반영',
          tooltip: showWeekHeader ? '날짜 반영 끄기' : '날짜 반영 켜기',
          onPressed: () => _setShowWeekHeader(ref, !showWeekHeader),
        ),
        const SizedBox(width: 6),
        _exchangeViewToggleButton(ref, theme),
      ];
    }

    // 통합 버튼 — 둘 다 켜져 있을 때만 ON으로 보이고, 누르면 둘 다
    // 같은 값으로 맞춘다.
    final isExchangeViewEnabled = ref.watch(isExchangeViewEnabledProvider);
    final combinedOn = showWeekHeader && isExchangeViewEnabled;
    return [
      _toggleButton(
        theme,
        value: combinedOn,
        icon: Icons.event_repeat,
        label: '날짜·교체 반영',
        tooltip: combinedOn ? '날짜·교체 반영 끄기' : '날짜·교체 반영 켜기',
        onPressed: () {
          final next = !combinedOn;
          _setShowWeekHeader(ref, next);
          onToggleExchangeView!.call(next);
        },
      ),
    ];
  }

  /// "교체" 단독 토글 버튼 (스위치 분리 모드용).
  Widget _exchangeViewToggleButton(WidgetRef ref, ThemeData theme) {
    final isEnabled = ref.watch(isExchangeViewEnabledProvider);
    return _toggleButton(
      theme,
      value: isEnabled,
      icon: Icons.swap_horiz,
      label: '교체',
      tooltip: isEnabled ? '교체된 시간표 보기 끄기' : '교체된 시간표 보기 켜기',
      onPressed: () => onToggleExchangeView!.call(!isEnabled),
    );
  }

  /// "날짜 반영" 단독 토글 버튼 (스위치 분리 모드·시간표 미로드용).
  Widget _reflectToggleButton(
    ThemeData theme, {
    required bool value,
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return _toggleButton(
      theme,
      value: value,
      icon: icon,
      label: label,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  /// ON/OFF를 색으로 구분하는 토글 버튼.
  Widget _toggleButton(
    ThemeData theme, {
    required bool value,
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return CompactToolbarLabelButton(
      onPressed: onPressed,
      icon: icon,
      label: label,
      tooltip: tooltip,
      height: 34,
      fontSize: 12,
      iconSize: 16,
      backgroundColor:
          value
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : Colors.grey.shade100,
      foregroundColor: value ? theme.colorScheme.primary : Colors.grey.shade700,
      borderColor: value ? theme.colorScheme.primary : Colors.grey.shade400,
    );
  }
}

/// 주차 칩 — 라벨 + 결강 건수(파란 배지) + 교체·보강 수업만 걸린 건수(회색 배지).
/// 학기 범위 밖 주는 주황 테두리로 표시한다.
class _WeekChip extends StatelessWidget {
  final String label;
  final int count;
  final int substitutionCount;
  final bool selected;
  final bool outOfRange;
  final VoidCallback onTap;

  const _WeekChip({
    required this.label,
    required this.count,
    required this.substitutionCount,
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

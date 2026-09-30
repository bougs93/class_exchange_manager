import 'package:flutter/material.dart';

import '../../../../theme/design_tokens.dart';

/// 계획서 화면의 날짜 선택 팝업 (결강일/교체일 셀 전용).
///
/// 기존에는 서드파티 패키지(`calendar_date_picker_2`)의 범용 달력 팝업을
/// 그대로 썼으나, 그 자리(요일·교시·학급·과목·교사)를 알아볼 수 없어 사용자
/// 요청으로 전용 팝업으로 교체했다. 크기·달력 모양은 `D:\Project\EduLink`의
/// `compact_date_range_field.dart`(기간 선택기)를 참고해 맞췄고, 이 화면은
/// 셀 하나당 날짜 하나만 고르므로 그 위젯의 "시작~종료" 탭은 없앴다.
///
/// 확정된 시안(2026-09-30):
/// - 정보 블록(요일·교시·학급 / 과목·교사) → "현재 주차로 되돌리기" →
///   달력(대상 요일만 활성, 나머지는 흐리게 비활성) → [취소][확인]
/// - 날짜를 눌러도 바로 반영되지 않는다 — [확인]을 눌러야 적용된다.
Future<DateTime?> showPlanDatePickerDialog(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime currentWeekMonday,
  required String targetWeekday,
  required String periodLabel,
  required String classLabel,
  required String subjectLabel,
  required String teacherLabel,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder:
        (ctx) => _PlanDatePickerDialog(
          initialDate: initialDate,
          currentWeekMonday: currentWeekMonday,
          targetWeekday: targetWeekday,
          periodLabel: periodLabel,
          classLabel: classLabel,
          subjectLabel: subjectLabel,
          teacherLabel: teacherLabel,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime(2030),
        ),
  );
}

/// 요일명(한 글자) → `DateTime.weekday` 대응 숫자. 일요일만 0(그 외 요일과
/// 동일하게 `content_input_grid.dart`의 `_isTargetWeekday`와 맞춘 값).
const Map<String, int> _weekdayNumberByName = {
  '일': 0,
  '월': 1,
  '화': 2,
  '수': 3,
  '목': 4,
  '금': 5,
  '토': 6,
};

bool _matchesTargetWeekday(DateTime date, String targetWeekday) {
  final target = _weekdayNumberByName[targetWeekday];
  if (target == null) return true; // 대상 요일 정보가 없으면 전부 허용(기존 동작과 동일)
  final dateWeekday = date.weekday == 7 ? 0 : date.weekday;
  return dateWeekday == target;
}

class _PlanDatePickerDialog extends StatefulWidget {
  const _PlanDatePickerDialog({
    required this.initialDate,
    required this.currentWeekMonday,
    required this.targetWeekday,
    required this.periodLabel,
    required this.classLabel,
    required this.subjectLabel,
    required this.teacherLabel,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime currentWeekMonday;
  final String targetWeekday;
  final String periodLabel;
  final String classLabel;
  final String subjectLabel;
  final String teacherLabel;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_PlanDatePickerDialog> createState() => _PlanDatePickerDialogState();
}

class _PlanDatePickerDialogState extends State<_PlanDatePickerDialog> {
  static const double _panelWidth = 304;

  late DateTime _selected;

  /// 달력을 강제로 다시 그려야 할 때마다(주로 "현재 주차로 되돌리기") 올린다.
  /// 되돌린 날짜가 이미 선택 중이던 날짜와 같으면 [_selected] 값 자체는
  /// 안 바뀌어서 `ValueKey`만으로는 `CalendarDatePicker`가 리마운트되지
  /// 않는다 — 그러면 사용자가 ‹ › 로 다른 달을 보고 있던 상태 그대로 남아
  /// "눌러도 이번 달로 안 돌아온다"는 버그가 된다. 이 카운터를 키에 함께
  /// 섞어서, 값이 같아도 버튼을 누를 때마다 무조건 다시 만들어지게 한다.
  int _resetSignal = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  /// "현재 주차로 되돌리기" — 지금 보고 있는 주의, 이 칸이 속한 요일 날짜로
  /// 선택을 되돌리고, 달력이 어느 달을 보고 있었든 그 날짜가 속한 달로
  /// 강제로 다시 이동시킨다.
  void _resetToCurrentWeek() {
    final target = _weekdayNumberByName[widget.targetWeekday];
    if (target == null || target == 0) return; // 대상 요일 불명 또는 일요일(교시 없음)이면 무시
    setState(() {
      _selected = widget.currentWeekMonday.add(Duration(days: target - 1));
      _resetSignal++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    // 월·연 제목("2026년 9월"). 아래 textScaler 0.88이 같이 적용되므로
    // 화면에 약 16으로 보이도록 기본 크기를 18로 둔다.
    final monthTitleStyle = (theme.datePickerTheme.toggleButtonTextStyle ??
            DatePickerTheme.defaults(context).toggleButtonTextStyle ??
            const TextStyle())
        .copyWith(fontSize: 18);

    return Dialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: _panelWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoBlock(tokens),
              const SizedBox(height: 2),
              Center(
                child: TextButton(
                  onPressed: _resetToCurrentWeek,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                  ),
                  child: const Text('현재 주차로 되돌리기'),
                ),
              ),
              // 월 이동 줄 여백은 Material 표준이라 직접 줄일 수 없다.
              // 날짜 숫자만 살짝 줄이고, "2026년 9월" 제목은 monthTitleStyle로 키운다.
              Theme(
                data: theme.copyWith(
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                  datePickerTheme: theme.datePickerTheme.copyWith(
                    toggleButtonTextStyle: monthTitleStyle,
                  ),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(0.88)),
                  child: CalendarDatePicker(
                    // CalendarDatePicker는 `initialDate`를 첫 빌드 때만 읽고
                    // 이후로는 자체 내부 상태(선택된 날짜뿐 아니라 지금
                    // 보여주는 달까지)로만 관리한다 — "현재 주차로 되돌리기"로
                    // `_selected`를 바꿔도 이 키가 없으면 달력에 전혀 반영
                    // 안 되고, `_selected` 값만으로 키를 만들면 되돌릴 날짜가
                    // 이미 선택 중이던 날짜와 같을 때(값이 안 바뀌니) 여전히
                    // 다시 안 그려져 ‹ › 로 넘어간 달에 그대로 머문다. 그래서
                    // 버튼을 누를 때마다 무조건 증가하는 [_resetSignal]도
                    // 같이 섞어 항상 리마운트를 강제한다.
                    key: ValueKey((_selected, _resetSignal)),
                    initialDate: _selected,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    currentDate: DateTime.now(),
                    selectableDayPredicate:
                        (date) =>
                            _matchesTargetWeekday(date, widget.targetWeekday),
                    onDateChanged: (date) => setState(() => _selected = date),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('확인'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBlock(DesignTokens tokens) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.targetWeekday}요일 ${widget.periodLabel}교시 · ${widget.classLabel}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.subjectLabel} · ${widget.teacherLabel}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

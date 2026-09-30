import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// 달력 위에 붙는 안내. [jumpTo]를 호출하면 그 날짜가 선택되고,
/// 지금 다른 달을 보고 있어도 그 날짜가 있는 달로 이동한다.
typedef CompactDateHeaderBuilder =
    Widget Function(BuildContext context, void Function(DateTime date) jumpTo);

/// 좁은 달력 팝업. 날짜를 눌러도 바로 닫히지 않고 [확인]을 눌러야 반영된다.
///
/// 계획서 날짜 선택과 학기 기간(시작일·종료일)이 같은 달력을 쓴다.
/// 화면마다 다른 안내는 [title] 또는 [headerBuilder]로 붙인다.
Future<DateTime?> showCompactDatePickerDialog(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? title,
  CompactDateHeaderBuilder? headerBuilder,
  bool Function(DateTime date)? selectableDayPredicate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder:
        (ctx) => _CompactDatePickerDialog(
          initialDate: initialDate,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime(2030),
          title: title,
          headerBuilder: headerBuilder,
          selectableDayPredicate: selectableDayPredicate,
        ),
  );
}

class _CompactDatePickerDialog extends StatefulWidget {
  const _CompactDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.headerBuilder,
    required this.selectableDayPredicate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? title;
  final CompactDateHeaderBuilder? headerBuilder;
  final bool Function(DateTime date)? selectableDayPredicate;

  @override
  State<_CompactDatePickerDialog> createState() =>
      _CompactDatePickerDialogState();
}

class _CompactDatePickerDialogState extends State<_CompactDatePickerDialog> {
  static const double _panelWidth = 304;

  late DateTime _selected;

  /// 달력을 강제로 다시 그려야 할 때마다 올린다.
  /// [CalendarDatePicker]는 `initialDate`를 첫 빌드 때만 읽는다. 선택 날짜가
  /// 그대로면 `ValueKey`만으로는 다시 만들어지지 않아, ‹ › 로 넘어간 달에
  /// 그대로 남는다. 그래서 [jumpTo]마다 이 값을 키에 섞는다.
  int _resetSignal = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  void _jumpTo(DateTime date) {
    setState(() {
      _selected = date;
      _resetSignal++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    // 아래 textScaler 0.88이 같이 적용되므로, 화면에 약 16으로 보이게 18로 둔다.
    final monthTitleStyle = (theme.datePickerTheme.toggleButtonTextStyle ??
            DatePickerTheme.defaults(context).toggleButtonTextStyle ??
            const TextStyle())
        .copyWith(fontSize: 18);

    final header =
        widget.headerBuilder?.call(context, _jumpTo) ?? _titleHeader(tokens);

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
              if (header != null) header,
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
                    key: ValueKey((_selected, _resetSignal)),
                    initialDate: _selected,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    currentDate: DateTime.now(),
                    selectableDayPredicate: widget.selectableDayPredicate,
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

  Widget? _titleHeader(DesignTokens tokens) {
    final title = widget.title;
    if (title == null || title.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.sectionBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
      ),
    );
  }
}

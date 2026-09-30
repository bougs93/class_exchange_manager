import 'package:flutter/material.dart';

import '../../models/school_semester.dart';
import '../../theme/design_tokens.dart';
import '../widgets/compact_date_picker_dialog.dart';

/// 시간표 이름과 학기 기간을 한 번에 확인·수정하는 등록 창.
///
/// 학년도·학기는 오늘 날짜가 속한 기본 학기([SchoolSemester.containing])로
/// 미리 선택된다. 시작·종료일도 그 학기의 기본 기간이다.
/// 취소하면 null.
Future<({String name, SchoolSemester semester})?> showRegisterTimetableDialog(
  BuildContext context, {
  required String initialName,
}) {
  return showDialog<({String name, SchoolSemester semester})>(
    context: context,
    barrierDismissible: false,
    builder:
        (dialogContext) => _RegisterTimetableDialog(initialName: initialName),
  );
}

class _RegisterTimetableDialog extends StatefulWidget {
  const _RegisterTimetableDialog({required this.initialName});

  final String initialName;

  @override
  State<_RegisterTimetableDialog> createState() =>
      _RegisterTimetableDialogState();
}

class _RegisterTimetableDialogState extends State<_RegisterTimetableDialog> {
  late final TextEditingController _nameController;
  late int _year;
  late int _semesterNumber;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    // 엑셀을 가져온 오늘이 속한 학기를 미리 고른다.
    final suggested = SchoolSemester.containing(DateTime.now());
    _year = suggested.schoolYear;
    _semesterNumber = suggested.semester;
    _start = suggested.startDate;
    _end = suggested.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _rangeValid => !_end.isBefore(_start);

  void _applyYearOrSemester({int? year, int? semesterNumber}) {
    final nextYear = year ?? _year;
    final nextSemester = semesterNumber ?? _semesterNumber;
    final def = SchoolSemester.defaultFor(
      schoolYear: nextYear,
      semester: nextSemester,
    );
    setState(() {
      _year = nextYear;
      _semesterNumber = nextSemester;
      _start = def.startDate;
      _end = def.endDate;
    });
  }

  void _restoreDefaults() {
    final def = SchoolSemester.defaultFor(
      schoolYear: _year,
      semester: _semesterNumber,
    );
    setState(() {
      _start = def.startDate;
      _end = def.endDate;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final firstDate = isStart ? DateTime(now.year - 5) : _start;
    final lastDate = DateTime(now.year + 5);
    // 종료일이 시작일보다 빠르면 종료일 달력의 initialDate가 firstDate보다
    // 앞에 있어 CalendarDatePicker가 예외를 던진다. 범위 안으로 붙인다.
    var initial = isStart ? _start : _end;
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;

    final picked = await showCompactDatePickerDialog(
      context,
      title: isStart ? '시작일' : '종료일',
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _confirm() {
    if (!_rangeValid) return;
    final trimmed = _nameController.text.trim();
    final name = trimmed.isEmpty ? widget.initialName.trim() : trimmed;
    Navigator.of(context).pop((
      name: name,
      semester: SchoolSemester(
        schoolYear: _year,
        semester: _semesterNumber,
        startDate: _start,
        endDate: _end,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      title: const Text('시간표 등록'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '시간표 이름',
                hintText: '예: 월계중1학기',
              ),
              onSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: 16),
            _yearSemesterRow(tokens),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '기간',
                  style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _restoreDefaults,
                  child: const Text('기본값'),
                ),
              ],
            ),
            _dateRow(tokens),
            if (!_rangeValid) ...[
              const SizedBox(height: 6),
              const Text(
                '종료일이 시작일보다 빠를 수 없습니다.',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _rangeValid ? _confirm : null,
          child: const Text('확인'),
        ),
      ],
    );
  }

  /// 시작 > 기타 > 학기 기간과 같은 한 줄 (학년도 드롭다운 + 1·2학기 버튼).
  Widget _yearSemesterRow(DesignTokens tokens) {
    final currentYear = DateTime.now().year;
    final years =
        {
            currentYear - 1,
            currentYear,
            currentYear + 1,
            currentYear + 2,
            _year,
          }.toList()
          ..sort();

    return Row(
      children: [
        Text(
          '학년도',
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: _year,
          underline: const SizedBox.shrink(),
          items: [
            for (final year in years)
              DropdownMenuItem(
                value: year,
                child: Text('$year', style: const TextStyle(fontSize: 12)),
              ),
          ],
          onChanged: (year) {
            if (year == null) return;
            _applyYearOrSemester(year: year);
          },
        ),
        const SizedBox(width: 16),
        Text('학기', style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
        const SizedBox(width: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1학기')),
            ButtonSegment(value: 2, label: Text('2학기')),
          ],
          selected: {_semesterNumber},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            _applyYearOrSemester(semesterNumber: selection.first);
          },
        ),
      ],
    );
  }

  Widget _dateRow(DesignTokens tokens) {
    String format(DateTime date) => '${date.year}.${date.month}.${date.day}';

    Widget dateButton({
      required String label,
      required DateTime date,
      required VoidCallback onPressed,
    }) {
      return Expanded(
        child: OutlinedButton(
          onPressed: onPressed,
          child: Text('$label  ${format(date)}'),
        ),
      );
    }

    return Row(
      children: [
        dateButton(
          label: '시작일',
          date: _start,
          onPressed: () => _pickDate(isStart: true),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('~', style: TextStyle(color: tokens.textSecondary)),
        ),
        dateButton(
          label: '종료일',
          date: _end,
          onPressed: () => _pickDate(isStart: false),
        ),
      ],
    );
  }
}

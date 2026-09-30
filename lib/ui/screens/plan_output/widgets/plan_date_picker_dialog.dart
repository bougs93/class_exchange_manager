import 'package:flutter/material.dart';

import '../../../../theme/design_tokens.dart';
import '../../../widgets/compact_date_picker_dialog.dart';

/// 계획서 화면의 날짜 선택 팝업 (결강일/교체일 셀 전용).
///
/// 달력 껍데기는 [showCompactDatePickerDialog]를 쓰고, 이 화면만
/// 칸 정보(요일·교시·학급·과목·교사)와 "현재 주차로 되돌리기",
/// 대상 요일만 선택 가능한 제한을 붙인다.
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
  return showCompactDatePickerDialog(
    context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    selectableDayPredicate:
        (date) => _matchesTargetWeekday(date, targetWeekday),
    headerBuilder:
        (context, jumpTo) => _PlanDatePickerHeader(
          targetWeekday: targetWeekday,
          periodLabel: periodLabel,
          classLabel: classLabel,
          subjectLabel: subjectLabel,
          teacherLabel: teacherLabel,
          onResetToCurrentWeek: () {
            final target = _weekdayNumberByName[targetWeekday];
            // 대상 요일 불명 또는 일요일(교시 없음)이면 되돌리지 않는다.
            if (target == null || target == 0) return;
            jumpTo(currentWeekMonday.add(Duration(days: target - 1)));
          },
        ),
  );
}

/// 요일명(한 글자) → `DateTime.weekday` 대응 숫자. 일요일만 0
/// (`content_input_grid.dart`의 `_isTargetWeekday`와 같은 값).
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
  if (target == null) return true;
  final dateWeekday = date.weekday == 7 ? 0 : date.weekday;
  return dateWeekday == target;
}

class _PlanDatePickerHeader extends StatelessWidget {
  const _PlanDatePickerHeader({
    required this.targetWeekday,
    required this.periodLabel,
    required this.classLabel,
    required this.subjectLabel,
    required this.teacherLabel,
    required this.onResetToCurrentWeek,
  });

  final String targetWeekday;
  final String periodLabel;
  final String classLabel;
  final String subjectLabel;
  final String teacherLabel;
  final VoidCallback onResetToCurrentWeek;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                '$targetWeekday요일 $periodLabel교시 · $classLabel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$subjectLabel · $teacherLabel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: TextButton(
            onPressed: onResetToCurrentWeek,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            child: const Text('현재 주차로 되돌리기'),
          ),
        ),
      ],
    );
  }
}

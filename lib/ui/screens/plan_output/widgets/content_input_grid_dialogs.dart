import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/exchange_screen_provider.dart';
import '../../../../providers/selected_week_provider.dart';
import '../../../../providers/services_provider.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/day_utils.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/snackbar_helper.dart';
import 'content_input_grid_plan_ops.dart';
import 'plan_date_picker_dialog.dart';

/// `ContentInputGrid`(결보강 일정 그리드)가 띄우는 다이얼로그 모음.
///
/// `setState`를 직접 호출하지 않는 다이얼로그 로직만 모았다 — 결강일 선택
/// 이후 계획서 이름을 바꾸는 등 `_ContentInputGridState`에 의존하는 후속
/// 처리는 [onAbsenceDateSelected] 콜백으로 주입받는다.

/// 과목 선택 다이얼로그 표시
Future<void> showSubjectPickerDialog(
  BuildContext context,
  WidgetRef ref,
  SubstitutionPlanViewModel viewModel,
  String exchangeId,
  List<SubstitutionPlanData> planData,
) async {
  // 1) 행 데이터에서 교사명 결정 (보강교사 우선, 없으면 원래 교사)
  final SubstitutionPlanData rowData = planData.firstWhere(
    (d) => d.exchangeId == exchangeId,
    orElse:
        () => SubstitutionPlanData(
          exchangeId: '',
          absenceDate: '',
          absenceDay: '',
          period: '',
          grade: '',
          className: '',
          subject: '',
          teacher: '',
          supplementSubject: '',
          supplementTeacher: '',
          substitutionDate: '',
          substitutionDay: '',
          substitutionPeriod: '',
          substitutionSubject: '',
          substitutionTeacher: '',
          remarks: '',
        ),
  );

  if (rowData.exchangeId.isEmpty) {
    SnackBarHelper.showInfo(context, '행 정보를 찾을 수 없습니다.');
    return;
  }

  final String teacherName =
      (rowData.supplementTeacher.isNotEmpty)
          ? rowData.supplementTeacher
          : rowData.teacher;

  if (teacherName.isEmpty) {
    SnackBarHelper.showInfo(context, '교사 정보를 찾을 수 없습니다.');
    return;
  }

  // 2) 전역 시간표에서 해당 교사가 실제로 가르친 과목 목록 추출
  final timetableData = ref.read(exchangeScreenProvider).timetableData;
  if (timetableData == null) {
    SnackBarHelper.showInfo(context, '시간표 데이터가 없어 과목을 불러올 수 없습니다.');
    return;
  }

  final Set<String> subjectSet = <String>{};
  for (final slot in timetableData.timeSlots) {
    if (slot.teacher == teacherName &&
        (slot.subject != null) &&
        slot.subject!.trim().isNotEmpty) {
      subjectSet.add(slot.subject!.trim());
    }
  }

  final List<String> subjects = subjectSet.toList()..sort();

  if (subjects.isEmpty) {
    SnackBarHelper.showInfo(context, '교사 "$teacherName"의 과목 정보를 찾지 못했습니다.');
    return;
  }

  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) {
      String customInput = '';
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('보강 과목 선택 - $teacherName'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...subjects.map(
                      (s) => ListTile(
                        title: Text(s),
                        onTap: () => Navigator.of(ctx).pop(s),
                      ),
                    ),
                    const Divider(),
                    const Text('직접 입력'),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: '과목명을 입력하세요',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => customInput = v),
                      onSubmitted: (v) {
                        final t = v.trim();
                        if (t.isNotEmpty) Navigator.of(ctx).pop(t);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed:
                    customInput.trim().isEmpty
                        ? null
                        : () => Navigator.of(ctx).pop(customInput.trim()),
                child: const Text('입력 적용'),
              ),
            ],
          );
        },
      );
    },
  );

  if (selected != null && selected.isNotEmpty) {
    if (!context.mounted) return;
    viewModel.updateSupplementSubject(exchangeId, selected);
    SnackBarHelper.showInfo(context, '보강 과목이 "$selected"(으)로 설정되었습니다.');
  }
}

/// 날짜 선택 다이얼로그 표시 (결강일/교체일 공통)
///
/// 결강일(`absenceDate`)을 선택해 저장에 성공하면 [onAbsenceDateSelected]를
/// 호출한다 — 호출측(`_ContentInputGridState`)이 계획서 이름을 "결보강
/// YY.MM.DD"로 바꾸는 등 `setState`가 필요한 후속 처리를 하기 위함이다.
Future<void> showSubstitutionDatePickerDialog(
  BuildContext context,
  WidgetRef ref,
  String exchangeId,
  String columnName,
  List<SubstitutionPlanData> planData, {
  required Future<void> Function(
    DateTime selectedDate,
    List<SubstitutionPlanData> planData,
  )
  onAbsenceDateSelected,
}) async {
  AppLogger.exchangeDebug(
    '날짜 선택 시작 - exchangeId: $exchangeId, columnName: $columnName',
  );

  // 해당 데이터 찾기
  try {
    final data = planData.firstWhere((d) => d.exchangeId == exchangeId);
    AppLogger.exchangeDebug('데이터 찾기 성공');

    // 요일 정보 추출
    final targetWeekday =
        columnName == 'absenceDate' ? data.absenceDay : data.substitutionDay;
    AppLogger.exchangeDebug('대상 요일: $targetWeekday');

    // 이미 입력된 날짜가 있으면 달력 기본값으로 사용 (없으면 오늘)
    final rawDate =
        columnName == 'absenceDate' ? data.absenceDate : data.substitutionDate;
    final initialDate =
        DateFormatUtils.parseYearMonthDay(
          DateFormatUtils.normalizePlanDate(rawDate),
        ) ??
        DateTime.now();

    // 요일 제한이 생기기 전(빈 문자열)이면 대상 요일이 없다는 뜻 — 오늘
    // 요일 이름으로 보여줄 것이 없으므로 초기 날짜의 요일명을 그대로 쓴다.
    final effectiveWeekday =
        targetWeekday.isNotEmpty
            ? targetWeekday
            : DayUtils.getDayName(initialDate.weekday);

    final isAbsence = columnName == 'absenceDate';
    final periodLabel = isAbsence ? data.period : data.substitutionPeriod;
    final subjectLabel = isAbsence ? data.subject : data.substitutionSubject;
    final teacherLabel = isAbsence ? data.teacher : data.substitutionTeacher;
    final classLabel = '${data.grade}-${data.className}';

    // 날짜 선택기 표시 (계획서 전용 팝업 — 요일·교시·학급·과목·교사 표시)
    final selectedDate = await showPlanDatePickerDialog(
      context,
      initialDate: initialDate,
      currentWeekMonday: ref.read(selectedWeekProvider),
      targetWeekday: effectiveWeekday,
      periodLabel: periodLabel,
      classLabel: classLabel,
      subjectLabel: subjectLabel,
      teacherLabel: teacherLabel,
    );

    AppLogger.exchangeDebug('선택 결과: $selectedDate');

    if (selectedDate != null) {
      if (targetWeekday.isNotEmpty &&
          !ContentInputGridPlanOps.isTargetWeekday(
            selectedDate,
            targetWeekday,
          )) {
        AppLogger.warning(
          '요일 불일치 - 선택: ${selectedDate.weekday}, 대상: $targetWeekday',
        );
        if (context.mounted) {
          SnackBarHelper.showError(
            context,
            '$targetWeekday요일이 아닌 날짜는 선택할 수 없습니다.',
          );
        }
        return;
      }

      // §10.10: 날짜는 ExchangeHistoryItem에 직접 반영한다 (savedDates 제거).
      if (!context.mounted) return;
      final saved = await applyDateSelection(
        context,
        ref,
        data,
        columnName,
        selectedDate,
      );
      if (!saved) return;

      // 결강일 선택 → 현재 계획서 이름을 "결보강 YY.MM.DD"로 (여러 건이면 마지막 선택이 기준)
      if (columnName == 'absenceDate') {
        await onAbsenceDateSelected(selectedDate, planData);
      }
    } else {
      AppLogger.exchangeDebug('날짜 선택 취소됨');
    }
  } catch (e) {
    AppLogger.error('날짜 선택 중 오류 발생', e);
    if (context.mounted) {
      SnackBarHelper.showError(context, '날짜 선택 중 오류가 발생했습니다: $e');
    }
  }
}

/// 선택한 날짜를 교체 건(`ExchangeHistoryItem`)에 반영한다 (§10.10).
///
/// 2026-09-29 사용자 확정: 다른 주로 옮기는 변경이어도 확인 다이얼로그 없이
/// 즉시 저장한다. 과거에는 §10.5 A안에 따라 결강일이 실제로 다른 주로
/// 이동할 때만 "다른 주로 이동" 확인을 띄웠으나(교체일 수정 시 불필요하게
/// 뜨던 버그는 이미 고쳤었다), 사용자가 그 확인 자체도 없애 달라고 요청했다.
///
/// 대상이 순환·2중이면(S5.6.6) 이 행이 가리키는 노드(요일·교시) 하나에만
/// 확정 날짜를 저장한다(`updateNodeDate`) — 같은 그룹의 다른 행(다른 노드)은
/// 건드리지 않는다. 1:1·보강은 기존 `updateDates`(항목 전체의 결강일/교체일
/// 쌍) 그대로다. `updateNodeDate`가 가드에 걸려 null을 반환하면(요일 불일치
/// 등) "저장 안 됨"으로 끝내지 않고 기존 경로로 폴백한다.
///
/// 반환값: 실제로 저장했으면 true, 실패했으면 false.
Future<bool> applyDateSelection(
  BuildContext context,
  WidgetRef ref,
  SubstitutionPlanData data,
  String columnName,
  DateTime selectedDate,
) async {
  final groupId = data.groupId;
  if (groupId == null || groupId.isEmpty) {
    SnackBarHelper.showError(context, '교체 건을 찾을 수 없어 날짜를 저장하지 못했습니다.');
    return false;
  }

  final historyService = ref.read(exchangeHistoryServiceProvider);
  final item = historyService.getExchangeItem(groupId);
  if (item == null) {
    SnackBarHelper.showError(context, '교체 건을 찾을 수 없어 날짜를 저장하지 못했습니다.');
    return false;
  }

  if (item.supportsNodeDates) {
    final dayName =
        columnName == 'absenceDate' ? data.absenceDay : data.substitutionDay;
    final periodStr =
        columnName == 'absenceDate' ? data.period : data.substitutionPeriod;
    final period = int.tryParse(periodStr);
    if (dayName.isNotEmpty && period != null) {
      final saved = historyService.updateNodeDate(
        groupId,
        dayName: dayName,
        period: period,
        date: selectedDate,
      );
      if (saved != null) {
        AppLogger.exchangeInfo(
          '노드 날짜 업데이트: $groupId, $dayName|$period → ${DateFormatUtils.toYearMonthDay(selectedDate)}',
        );
        return true;
      }
      // 가드에 걸렸다(요일 불일치 등) — 아래 기존 경로로 폴백한다. 이론상
      // 발생하지 않아야 한다(달력이 이미 이 행의 요일만 고를 수 있게
      // 강제한다) — 발생하면 노드별 정밀도 없이 항목 전체 날짜로만
      // 저장되어 다른 노드와 격차가 생길 수 있으므로 진단용으로 남긴다.
      AppLogger.warning('노드 날짜 저장 실패 → 항목 전체 날짜로 폴백(격차 발생 가능): $groupId');
    }
  }

  historyService.updateDates(
    groupId,
    absenceDate: columnName == 'absenceDate' ? selectedDate : null,
    substitutionDate: columnName == 'substitutionDate' ? selectedDate : null,
  );
  AppLogger.exchangeInfo(
    '날짜 업데이트: $groupId.$columnName → ${DateFormatUtils.toYearMonthDay(selectedDate)}',
  );
  return true;
}

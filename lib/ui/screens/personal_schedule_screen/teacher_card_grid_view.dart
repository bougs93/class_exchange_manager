import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/time_slot.dart';
import '../../../providers/personal_schedule_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/substitution_plan_provider.dart';
import '../../../services/excel_service.dart';
import '../../../utils/personal_exchange_info_extractor.dart';
import '../../../providers/zoom_provider.dart';
import 'teacher_card_grid_constants.dart';
import 'teacher_card_teacher_collector.dart';
import 'teacher_timetable_card.dart';

/// 교사별 시간표 카드를 그리드(Wrap) 형태로 배치합니다.
class TeacherCardGridView extends ConsumerWidget {
  final List<TeacherCardTarget> targets;
  final TimetableData timetableData;
  final List<TimeSlot> timeSlots;
  final List<DateTime> weekDates;
  final bool isExchangeViewEnabled;
  final PersonalScheduleState scheduleState;

  const TeacherCardGridView({
    super.key,
    required this.targets,
    required this.timetableData,
    required this.timeSlots,
    required this.weekDates,
    required this.isExchangeViewEnabled,
    required this.scheduleState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (targets.isEmpty) {
      return const Center(
        child: Text(
          '표시할 교사가 없습니다.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final zoomFactor = ref.watch(zoomProvider.select((s) => s.zoomFactor));
    final exchangeList = ref.read(exchangeHistoryServiceProvider).getExchangeList();
    final substitutionPlanState = ref.read(substitutionPlanProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TeacherCardGridConstants.toolbarHorizontalPadding,
        TeacherCardGridConstants.toolbarGridGap,
        TeacherCardGridConstants.toolbarHorizontalPadding,
        TeacherCardGridConstants.cardOuterPadding,
      ),
      child: Wrap(
        spacing: TeacherCardGridConstants.cardOuterPadding,
        runSpacing: TeacherCardGridConstants.cardOuterPadding,
        alignment: WrapAlignment.start,
        children: targets.map((target) {
          final exchangeInfoList = PersonalExchangeInfoExtractor.extractExchangeInfo(
            exchangeList: exchangeList,
            teacherName: target.name,
            weekDates: weekDates,
            substitutionPlanState: substitutionPlanState,
            scheduleState: scheduleState,
          );

          return TeacherTimetableCard(
            key: ValueKey(target.name),
            teacherName: target.name,
            subject: _findTeacherSubject(timetableData, target.name),
            roleLabel: target.roleLabel,
            dateStatusMessage: target.dateStatusMessage,
            timeSlots: timeSlots,
            weekDates: weekDates,
            zoomFactor: zoomFactor,
            exchangeInfoList: exchangeInfoList,
            isExchangeViewEnabled: isExchangeViewEnabled,
            isHighlighted: target.isSaved,
          );
        }).toList(),
      ),
    );
  }

  String? _findTeacherSubject(TimetableData timetableData, String teacherName) {
    for (final teacher in timetableData.teachers) {
      if (teacher.name == teacherName) {
        return teacher.subject;
      }
    }
    return null;
  }
}

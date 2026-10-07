import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/time_slot.dart';
import '../../../providers/personal_schedule_provider.dart';
import '../../../providers/plan_output_menu_provider.dart';
import '../../../providers/substitution_plan_viewmodel.dart';
import '../../../services/excel_service.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/personal_exchange_info_extractor.dart';
import '../../../utils/week_date_calculator.dart';
import '../../../providers/zoom_provider.dart';
import '../../../ui/mixins/scroll_management_mixin.dart';
import 'teacher_card_grid_constants.dart';
import 'teacher_card_teacher_collector.dart';
import 'teacher_timetable_card.dart';
import 'exchange_week_collector.dart';

/// 교사별 시간표 카드를 그리드(Wrap) 형태로 배치합니다.
///
/// PC는 오른쪽 버튼, 웹은 휠 버튼, 왼쪽은 끌어서 세로 스크롤이 가능합니다.
/// (교체 관리 화면과 동일한 [ScrollManagementMixin] 사용)
class TeacherCardGridView extends ConsumerStatefulWidget {
  final List<TeacherCardTarget> targets;
  final TimetableData timetableData;
  final List<TimeSlot> timeSlots;
  final List<DateTime> weekDates;
  final List<DateTime>? weekMondays;
  final bool isExchangeViewEnabled;
  final PersonalScheduleState scheduleState;

  /// 헤더 계획서·선택 교사 기준으로 걸러진 교체 행 (셀 하이라이트용)
  final List<SubstitutionPlanData> relatedPlanData;

  const TeacherCardGridView({
    super.key,
    required this.targets,
    required this.timetableData,
    required this.timeSlots,
    required this.weekDates,
    this.weekMondays,
    required this.isExchangeViewEnabled,
    required this.scheduleState,
    required this.relatedPlanData,
  });

  @override
  ConsumerState<TeacherCardGridView> createState() =>
      _TeacherCardGridViewState();
}

class _TeacherCardGridViewState extends ConsumerState<TeacherCardGridView>
    with ScrollManagementMixin {
  /// 시간표 카드 스크롤은 교체 화면 화살표용 전역 provider에 올리지 않습니다.
  @override
  bool get syncScrollToGlobalProvider => false;
  @override
  void initState() {
    super.initState();
    // 스크롤 컨트롤러 초기화 (오른쪽 버튼 드래그 스크롤용)
    initializeScrollControllers();
  }

  @override
  void dispose() {
    disposeScrollControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.targets.isEmpty) {
      return Center(
        child: Text(
          '표시할 교사가 없습니다.',
          style: TextStyle(color: context.tokens.textMuted),
        ),
      );
    }

    final zoomFactor = ref.watch(zoomProvider.select((s) => s.zoomFactor));
    // 부모에서 넘긴 헤더 계획서 기준 행을 그대로 쓴다 (교사로 재필터하지 않음).
    final planData = widget.relatedPlanData;

    // 오른쪽 버튼 드래그로 스크롤 가능하도록 믹신으로 감쌉니다.
    return wrapWithDragScroll(
      SingleChildScrollView(
        controller: verticalScrollController,
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
          children: [
            for (final target in widget.targets)
              if (widget.weekMondays == null)
                _buildCard(target, widget.weekDates, null, zoomFactor, planData)
              else
                for (final week in widget.weekMondays!)
                  _buildCard(
                    target,
                    WeekDateCalculator.getWeekDatesWithAvailableDays(
                      week,
                      widget.timetableData.timeSlots,
                    ),
                    '${week.year}년 ${ExchangeWeekCollector.monthWeekLabel(week)}',
                    zoomFactor,
                    planData,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    TeacherCardTarget target,
    List<DateTime> dates,
    String? weekLabel,
    double zoomFactor,
    List<SubstitutionPlanData> planData,
  ) {
    return TeacherTimetableCard(
      key: ValueKey('${target.name}-$weekLabel'),
      teacherName: target.name,
      weekLabel: weekLabel,
      subject: _findTeacherSubject(widget.timetableData, target.name),
      roleLabel: target.roleLabel,
      dateStatusMessage: target.dateStatusMessage,
      onDateStatusTap:
          target.hasUnspecifiedDate
              ? () => navigateToPlanDateSelection(ref)
              : null,
      timeSlots: widget.timeSlots,
      weekDates: dates,
      zoomFactor: zoomFactor,
      exchangeInfoList: PersonalExchangeInfoExtractor.extractExchangeInfo(
        planData: planData,
        teacherName: target.name,
        weekDates: dates,
      ),
      isExchangeViewEnabled: widget.isExchangeViewEnabled,
      isHighlighted: target.isSaved,
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

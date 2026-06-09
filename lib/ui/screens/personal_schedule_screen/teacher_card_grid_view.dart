import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/time_slot.dart';
import '../../../providers/personal_schedule_provider.dart';
import '../../../providers/substitution_plan_viewmodel.dart';
import '../../../services/excel_service.dart';
import '../../../utils/personal_exchange_info_extractor.dart';
import '../../../providers/zoom_provider.dart';
import '../../../ui/mixins/scroll_management_mixin.dart';
import 'teacher_card_grid_constants.dart';
import 'teacher_card_teacher_collector.dart';
import 'teacher_timetable_card.dart';

/// 교사별 시간표 카드를 그리드(Wrap) 형태로 배치합니다.
///
/// 마우스 오른쪽 버튼 드래그로 세로 스크롤이 가능합니다.
/// (교체 관리 화면과 동일한 [ScrollManagementMixin] 사용)
class TeacherCardGridView extends ConsumerStatefulWidget {
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
  ConsumerState<TeacherCardGridView> createState() =>
      _TeacherCardGridViewState();
}

class _TeacherCardGridViewState extends ConsumerState<TeacherCardGridView>
    with ScrollManagementMixin {
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
      return const Center(
        child: Text('표시할 교사가 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }

    final zoomFactor = ref.watch(zoomProvider.select((s) => s.zoomFactor));
    final planData = ref.read(
      substitutionPlanViewModelProvider.select((s) => s.planData),
    );

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
          children:
              widget.targets.map((target) {
                final exchangeInfoList =
                    PersonalExchangeInfoExtractor.extractExchangeInfo(
                      planData: planData,
                      teacherName: target.name,
                      weekDates: widget.weekDates,
                    );

                return TeacherTimetableCard(
                  key: ValueKey(target.name),
                  teacherName: target.name,
                  subject: _findTeacherSubject(
                    widget.timetableData,
                    target.name,
                  ),
                  roleLabel: target.roleLabel,
                  dateStatusMessage: target.dateStatusMessage,
                  timeSlots: widget.timeSlots,
                  weekDates: widget.weekDates,
                  zoomFactor: zoomFactor,
                  exchangeInfoList: exchangeInfoList,
                  isExchangeViewEnabled: widget.isExchangeViewEnabled,
                  isHighlighted: target.isSaved,
                );
              }).toList(),
        ),
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

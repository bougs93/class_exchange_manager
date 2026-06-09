import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/exchange_node.dart';
import '../../../models/exchange_path.dart';
import '../../../models/supplement_exchange_path.dart';
import '../../../models/time_slot.dart';
import '../../../providers/cell_selection_provider.dart';
import '../../../providers/exchange_screen_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../utils/logger.dart';
import '../../../utils/day_utils.dart';
import '../empty_state_message.dart';
import 'sidebar_color_scheme.dart';
import 'sidebar_constants.dart';
import 'animated_sidebar_node.dart';

/// 보강 모드 사이드바 콘텐츠
///
/// 선택된 결강 셀 정보, 동일 교과목 필터, 보강 가능한 교사 버튼 목록을 표시한다.
/// 동일 교과목 필터 상태(_supplementSubjectFilterEnabled)를 스스로 보유하며,
/// 실제 교체 실행은 부모가 [onExecuteSupplement] 콜백으로 처리한다(실행 로직은
/// 다른 교체 모드와 공유되므로 부모에 둔다).
class SupplementSidebarContent extends ConsumerStatefulWidget {
  final ExchangePathType mode;
  final ExchangePath? selectedPath;
  final bool isLoading;
  final Function(ExchangeNode) getSubjectName;
  final Function(String, String, int)? onSupplementTeacherTap;

  /// 보강 실행(헤더 [보강 실행]·경로 더블클릭과 동일)
  final VoidCallback onExecuteSupplement;

  /// 결강 셀 노드 탭 시 해당 셀로 스크롤
  final void Function(ExchangeNode) onSourceNodeTap;

  const SupplementSidebarContent({
    super.key,
    required this.mode,
    required this.selectedPath,
    required this.isLoading,
    required this.getSubjectName,
    required this.onSupplementTeacherTap,
    required this.onExecuteSupplement,
    required this.onSourceNodeTap,
  });

  @override
  ConsumerState<SupplementSidebarContent> createState() =>
      _SupplementSidebarContentState();
}

class _SupplementSidebarContentState
    extends ConsumerState<SupplementSidebarContent> {
  /// 보강 동일 교과목 필터 활성 여부 (토글, 셀 변경 시에도 유지)
  bool _supplementSubjectFilterEnabled = false;

  @override
  Widget build(BuildContext context) => _buildSupplementContent();

  /// 보강 실행 가능 여부 (셀이 교체된 셀이 아니고, 보강 경로가 선택된 상태)
  bool _canExecuteSupplement() {
    if (widget.selectedPath is! SupplementExchangePath || widget.isLoading) {
      return false;
    }
    return !ref.read(cellSelectionProvider).isFromExchangedCell;
  }

  Widget _buildSupplementContent() {
    return Consumer(
      builder: (context, ref, child) {
        // 선택된 셀 정보 가져오기
        final cellSelectionState = ref.watch(cellSelectionProvider);
        final hasSelectedCell =
            cellSelectionState.selectedTeacher != null &&
            cellSelectionState.selectedDay != null &&
            cellSelectionState.selectedPeriod != null;

        if (hasSelectedCell) {
          // 선택된 셀이 있는 경우: 셀 정보와 보강 가능한 교사 버튼 표시
          return Padding(
            padding: const EdgeInsets.only(top: 16.0), // 헤더와 노드 사각형 사이 간격
            child: Column(
              children: [
                // 선택된 셀 정보
                _buildSelectedCellInfo(cellSelectionState),

                const SizedBox(height: 8),

                // 동일 교과목 필터 (보강 가능한 교사 목록 위)
                _buildSupplementSubjectFilter(cellSelectionState),

                const SizedBox(height: 8),

                // 보강 가능한 교사 버튼 섹션
                Expanded(
                  child: _buildSupplementTeacherButtons(cellSelectionState),
                ),
              ],
            ),
          );
        } else {
          // 셀 선택이 해제된 경우에만 필터 상태 초기화
          _supplementSubjectFilterEnabled = false;

          // 선택된 셀이 없는 경우: 안내 메시지 표시 (상단 간격 추가)
          return Padding(
            padding: const EdgeInsets.only(top: 16.0), // 헤더와 안내 메시지 사이 간격
            child: _buildSupplementGuide(),
          );
        }
      },
    );
  }

  /// 보강 선택 안내 메시지
  Widget _buildSupplementGuide() {
    return EmptyStateMessage(
      icon: Icons.info_outline,
      iconColor: Colors.blue.shade400,
      message: '보강을 위해 빈 셀을 선택하거나\n교사명을 클릭해주세요',
      messageColor: Colors.blue.shade600,
      messageFontSize: SidebarFontSizes.emptyMessage,
      messageFontWeight: FontWeight.w500,
    );
  }

  /// 선택된 셀 정보 표시 (1:1 교체와 동일한 디자인)
  Widget _buildSelectedCellInfo(CellSelectionState cellSelectionState) {
    final canExecute = _canExecuteSupplement();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          // 2개 노드를 감싸는 박스 — 더블클릭 시 [보강 실행]과 동일
          // (다른 교체 경로와 동일하게 onTap + onDoubleTap 병행)
          InkWell(
            onTap: () {},
            onDoubleTap: canExecute ? widget.onExecuteSupplement : null,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      PathColorScheme.getScheme(
                        ExchangePathType.supplement,
                      ).primary,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        PathColorScheme.getScheme(
                          ExchangePathType.supplement,
                        ).shadow,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    // 상단: 보강할 교사(빈 수업) 또는 대기 문구
                    _buildSupplementTopNode(),

                    // 화살표 (순환교체와 동일한 아래 방향, 단계 번호 없음)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      child: Icon(
                        Icons.arrow_downward,
                        color:
                            widget.selectedPath is SupplementExchangePath
                                ? PathColorScheme.getScheme(
                                  ExchangePathType.supplement,
                                ).primary
                                : Colors.grey.shade500,
                        size: 12,
                      ),
                    ),

                    // 하단: 결강(보강 대상) 수업 셀
                    _buildSupplementBottomNode(cellSelectionState),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// 보강 상단 노드 — 보강할 교사(빈수업) 또는 [빈 수업 대기]
  Widget _buildSupplementTopNode() {
    final path = widget.selectedPath;
    final colorScheme = PathColorScheme.getScheme(ExchangePathType.supplement);

    if (path is SupplementExchangePath) {
      return Consumer(
        builder: (context, ref, child) {
          final timetableData = ref.watch(exchangeScreenProvider).timetableData;
          final target = path.targetNode;
          final label = _formatSupplementNodeLabel(
            target,
            isSubstituteSlot: true,
            subject: _getSupplementTeacherDisplaySubject(
              target,
              timetableData?.timeSlots ?? [],
            ),
          );

          return _buildSupplementTextBox(
            label,
            colorScheme: colorScheme,
            isSelected: true,
            isHighlighted: true,
          );
        },
      );
    }

    return _buildSupplementTextBox(
      '빈 수업 대기',
      colorScheme: colorScheme,
      isPlaceholder: true,
    );
  }

  /// 보강 하단 노드 — 결강(보강 대상) 수업 셀
  Widget _buildSupplementBottomNode(CellSelectionState cellSelectionState) {
    return Consumer(
      builder: (context, ref, child) {
        // 시간표 데이터에서 선택된 셀의 상세 정보 가져오기
        final timetableData = ref.watch(exchangeScreenProvider).timetableData;

        if (timetableData == null) {
          return _buildEmptyNode('시간표 데이터 없음');
        }

        // 선택된 셀의 TimeSlot 찾기
        final selectedSlot = timetableData.timeSlots.firstWhere(
          (slot) =>
              slot.teacher == cellSelectionState.selectedTeacher &&
              slot.dayOfWeek ==
                  DayUtils.getDayNumber(cellSelectionState.selectedDay!) &&
              slot.period == cellSelectionState.selectedPeriod &&
              slot.isNotEmpty,
          orElse: () => TimeSlot(),
        );

        // ExchangeNode 생성 (1:1 교체와 동일한 형식)
        final node = ExchangeNode(
          teacherName: cellSelectionState.selectedTeacher!,
          day: cellSelectionState.selectedDay!,
          period: cellSelectionState.selectedPeriod!,
          className: selectedSlot.className ?? '',
          subjectName: selectedSlot.subject ?? '',
        );

        final colorScheme = PathColorScheme.getScheme(
          ExchangePathType.supplement,
        );

        return AnimatedSidebarNode(
          node: node,
          isSelected: true,
          colorScheme: colorScheme,
          label: _formatSupplementNodeLabel(
            node,
            isSubstituteSlot: false,
            subject:
                node.subjectName.isNotEmpty
                    ? node.subjectName
                    : widget.getSubjectName(node),
          ),
          onTap: () => widget.onSourceNodeTap(node),
        );
      },
    );
  }

  /// 보강 교사 표시용 과목명 (해당 교시가 비어 있어도 담당 과목 표시)
  String _getSupplementTeacherDisplaySubject(
    ExchangeNode node,
    List<TimeSlot> timeSlots,
  ) {
    for (final slot in timeSlots) {
      if (slot.teacher == node.teacherName &&
          slot.isNotEmpty &&
          slot.subject != null &&
          slot.subject!.isNotEmpty) {
        return slot.subject!;
      }
    }
    return widget.getSubjectName(node);
  }

  /// 보강 노드 라벨: 요일교시|학급|교사|과목
  String _formatSupplementNodeLabel(
    ExchangeNode node, {
    required bool isSubstituteSlot,
    String? subject,
  }) {
    final classLabel =
        isSubstituteSlot && node.className.isEmpty ? '빈수업' : node.className;
    final subjectLabel = subject ?? widget.getSubjectName(node);
    return '${node.day}${node.period}|$classLabel|${node.teacherName}|$subjectLabel';
  }

  /// 보강 전용 텍스트 박스 (대기 문구·보강 교사 라벨)
  Widget _buildSupplementTextBox(
    String label, {
    required PathColorScheme colorScheme,
    bool isSelected = false,
    bool isHighlighted = false,
    bool isPlaceholder = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color:
            isPlaceholder
                ? Colors.grey.shade100
                : colorScheme.backgroundFor(isSelected, false, isHighlighted),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color:
              isPlaceholder
                  ? Colors.grey.shade300
                  : colorScheme.borderFor(isSelected, false, isHighlighted),
          width: isSelected && !isPlaceholder ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected && !isPlaceholder)
            BoxShadow(
              color: colorScheme.shadow,
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: SidebarFontSizes.nodeText,
          fontWeight: FontWeight.w500,
          color:
              isPlaceholder
                  ? Colors.grey.shade600
                  : colorScheme.textFor(isSelected, false, isHighlighted),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 선택된 결강 셀의 교과목 (없으면 null)
  String? _getSelectedCellSubject(
    CellSelectionState state,
    List<TimeSlot> timeSlots,
  ) {
    if (state.selectedTeacher == null ||
        state.selectedDay == null ||
        state.selectedPeriod == null) {
      return null;
    }

    TimeSlot? selectedSlot;
    for (final slot in timeSlots) {
      if (slot.teacher == state.selectedTeacher &&
          slot.dayOfWeek == DayUtils.getDayNumber(state.selectedDay!) &&
          slot.period == state.selectedPeriod &&
          slot.isNotEmpty) {
        selectedSlot = slot;
        break;
      }
    }

    if (selectedSlot == null) return null;

    final subject = selectedSlot.subject?.trim();
    if (subject == null || subject.isEmpty) return null;
    return subject;
  }

  /// 보강 동일 교과목 필터 버튼 — ExchangeFilterWidget 요일/단계 버튼과 동일한 칩 형태
  Widget _buildSupplementSubjectFilterButton({
    required String label,
    required bool isEnabled,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final scheme = PathColorScheme.getScheme(ExchangePathType.supplement);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color:
              !isEnabled
                  ? Colors.grey.shade100
                  : isSelected
                  ? scheme.nodeBackground
                  : Colors.grey.shade100,
          border: Border.all(
            color:
                !isEnabled
                    ? Colors.grey.shade300
                    : isSelected
                    ? scheme.nodeBorder
                    : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color:
                !isEnabled
                    ? Colors.grey.shade400
                    : isSelected
                    ? scheme.nodeText
                    : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  /// 동일 교과목 필터 — 다른 교체 모드 검색 필터 헤더와 동일한 1줄 레이아웃
  /// [아이콘] [필터] [기가 (1명) 버튼]
  Widget _buildSupplementSubjectFilter(CellSelectionState cellSelectionState) {
    return Consumer(
      builder: (context, ref, child) {
        final timetableData = ref.watch(exchangeScreenProvider).timetableData;
        if (timetableData == null) {
          return const SizedBox.shrink();
        }

        final exchangeService = ref.watch(exchangeServiceProvider);

        final subject = _getSelectedCellSubject(
          cellSelectionState,
          timetableData.timeSlots,
        );
        final isEnabled = subject != null;

        final matchCount =
            subject == null
                ? 0
                : exchangeService
                    .getSupplementTeachers(
                      timetableData.timeSlots,
                      timetableData.teachers,
                      subjectFilter: subject,
                    )
                    .length;

        // 필터 ON 상태는 셀 변경 후에도 유지 (과목 없는 셀에서는 비활성 표시만)
        final isFilterActive = _supplementSubjectFilterEnabled && isEnabled;
        final subjectBadge = isEnabled ? '$subject ($matchCount명)' : '과목 없음';

        // ExchangeFilterWidget 헤더와 동일한 컨테이너 스타일
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.filter_list, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                '필터',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              // 동일 교과목 필터 토글 버튼
              _buildSupplementSubjectFilterButton(
                label: subjectBadge,
                isEnabled: isEnabled,
                isSelected: isFilterActive,
                onTap:
                    isEnabled
                        ? () {
                          setState(() {
                            _supplementSubjectFilterEnabled =
                                !_supplementSubjectFilterEnabled;
                          });
                        }
                        : null,
              ),
            ],
          ),
        );
      },
    );
  }

  /// 보강 가능한 교사 버튼 섹션
  Widget _buildSupplementTeacherButtons(CellSelectionState cellSelectionState) {
    return Consumer(
      builder: (context, ref, child) {
        // ExchangeService에서 보강 가능한 교사 목록 가져오기
        final exchangeService = ref.watch(exchangeServiceProvider);
        final timetableData = ref.watch(exchangeScreenProvider).timetableData;

        if (timetableData == null) {
          return _buildNoDataMessage();
        }

        final subject = _getSelectedCellSubject(
          cellSelectionState,
          timetableData.timeSlots,
        );

        // 보강 가능 교사 목록 (필터 ON 상태는 셀 변경 후에도 유지)
        final teachersToShow = exchangeService.getSupplementTeachers(
          timetableData.timeSlots,
          timetableData.teachers,
          subjectFilter: _supplementSubjectFilterEnabled ? subject : null,
        );

        if (teachersToShow.isEmpty) {
          return _buildNoAvailableTeachersMessage();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 섹션 헤더
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text(
                '보강 가능한 교사',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 8),

            // 교사 버튼 목록
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: teachersToShow.length,
                itemBuilder: (context, index) {
                  final teacher = teachersToShow[index];
                  return _buildTeacherButton(teacher, index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 보강 경로의 대상 교사 버튼인지 확인
  bool _isSupplementTeacherButtonSelected(
    String teacherName,
    String day,
    int period,
  ) {
    final path = widget.selectedPath;
    if (path is! SupplementExchangePath) return false;
    final target = path.targetNode;
    return target.teacherName == teacherName &&
        target.day == day &&
        target.period == period;
  }

  /// 교사 버튼 구성
  Widget _buildTeacherButton(Map<String, dynamic> teacher, int index) {
    final teacherName = teacher['teacherName'] as String;
    final day = teacher['day'] as String;
    final period = teacher['period'] as int;
    final subject = teacher['subject'] as String;
    final isSelected = _isSupplementTeacherButtonSelected(
      teacherName,
      day,
      period,
    );
    final accentColor =
        isSelected ? Colors.teal.shade700 : Colors.teal.shade600;
    final nameColor = isSelected ? Colors.teal.shade800 : Colors.teal.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _onTeacherButtonTap(teacherName, day, period),
        onDoubleTap:
            isSelected && _canExecuteSupplement()
                ? widget.onExecuteSupplement
                : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? PathColorScheme.pathBackground(
                      ExchangePathType.supplement,
                    )
                    : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  isSelected
                      ? PathColorScheme.pathBorder(ExchangePathType.supplement)
                      : Colors.teal.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: PathColorScheme.pathShadow(
                    ExchangePathType.supplement,
                  ),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                )
              else
                BoxShadow(
                  color: Colors.teal.shade100,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            children: [
              // 시간 정보 (월1)
              Expanded(
                flex: 1,
                child: Text(
                  '$day$period',
                  style: TextStyle(
                    fontSize: SidebarFontSizes.nodeText - 1,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // 구분선
              Container(
                width: 1,
                height: 16,
                color: isSelected ? Colors.teal.shade300 : Colors.teal.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),

              // 교사 이름 (강조)
              Expanded(
                flex: 2,
                child: Text(
                  teacherName,
                  style: TextStyle(
                    fontSize: SidebarFontSizes.nodeText,
                    fontWeight: FontWeight.w600,
                    color: nameColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // 구분선
              Container(
                width: 1,
                height: 16,
                color: isSelected ? Colors.teal.shade300 : Colors.teal.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),

              // 과목 정보
              Expanded(
                flex: 2,
                child: Text(
                  subject,
                  style: TextStyle(
                    fontSize: SidebarFontSizes.nodeText - 1,
                    color: accentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 교사 버튼 탭 처리
  void _onTeacherButtonTap(String teacherName, String day, int period) {
    // 이미 선택된 교사 재클릭 무시 (더블클릭 시 onTap 2회 방지)
    if (_isSupplementTeacherButtonSelected(teacherName, day, period)) {
      return;
    }

    AppLogger.exchangeDebug('보강 가능한 교사 버튼 클릭: $teacherName ($day $period교시)');

    // 보강 모드이고 콜백이 제공된 경우 경로 미리보기
    if (widget.mode == ExchangePathType.supplement &&
        widget.onSupplementTeacherTap != null) {
      widget.onSupplementTeacherTap!(teacherName, day, period);
    }
  }

  /// 데이터 없음 메시지
  Widget _buildNoDataMessage() {
    return EmptyStateMessage(
      icon: Icons.error_outline,
      iconSize: 48,
      iconSpacing: 8,
      message: '시간표 데이터가 없습니다',
      messageFontSize: SidebarFontSizes.emptyMessage - 2,
    );
  }

  /// 보강 가능한 교사 없음 메시지
  Widget _buildNoAvailableTeachersMessage() {
    return EmptyStateMessage(
      icon: Icons.person_off,
      iconSize: 48,
      iconSpacing: 8,
      message: '보강 가능한 교사가 없습니다',
      messageFontSize: SidebarFontSizes.emptyMessage - 2,
      subMessage: '같은 반을 가르치는 교사 중\n빈 시간이 있는 교사가 없습니다',
      subMessageSpacing: 4,
      subMessageFontSize: SidebarFontSizes.emptyMessage - 4,
    );
  }

  /// 빈 노드 생성 (에러 처리용)
  Widget _buildEmptyNode(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: SidebarFontSizes.nodeText,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../models/exchange_node.dart';
import '../../../models/exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/dual_exchange_path.dart';
import '../../../models/supplement_exchange_path.dart';
import '../../../models/exchange_history_item.dart';
import '../../../models/print_profile.dart';
import '../../../models/usage_event.dart';
import '../../../models/exchange_clear_snapshot.dart';
import '../../../constants/korean_fonts.dart';
import '../../../utils/logger.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/timetable_data_source.dart';
import '../../../providers/cell_selection_provider.dart';
import '../../../providers/state_reset_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/exchange_view_provider.dart';
import '../../../providers/exchange_screen_provider.dart';
import '../../../providers/selected_week_provider.dart';
import '../../../providers/print_profile_provider.dart';
import '../../../providers/substitution_plan_provider.dart';
import '../../../providers/timetable_registry_provider.dart';
import '../../../providers/web_services_provider.dart';
import '../../../utils/day_utils.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/exchange_cell_dates.dart';
import '../../../utils/exchange_dependency_checker.dart';
import '../../../utils/node_date_seed.dart';
import '../../../providers/show_week_header_provider.dart';
import '../../screens/personal_schedule_screen/exchange_week_collector.dart';

/// 교체 실행 관리 클래스
class ExchangeExecutor {
  final WidgetRef ref;
  final TimetableDataSource? dataSource;
  final VoidCallback? onEnableExchangeView; // 교체 뷰 활성화 콜백

  ExchangeExecutor({
    required this.ref,
    required this.dataSource,
    this.onEnableExchangeView,
  });

  /// 공통 후처리 로직
  /// 모든 교체 작업(실행, 삭제, 되돌리기) 후 반복되는 로직을 통합
  void _executeCommonPostProcess({
    required BuildContext context,
    required VoidCallback onInternalPathClear,
    required String message,
    Color? snackBarColor,
    String? undoButtonLabel,
    VoidCallback? onUndoPressed,
  }) {
    final historyService = ref.read(exchangeHistoryServiceProvider);

    // 1. 콘솔 출력
    historyService.printExchangeList();
    historyService.printUndoHistory();

    // 2. 교체된 셀 상태 업데이트
    _updateExchangedCells();

    // 3. 교체 뷰 활성화 여부 검사
    _checkExchangeViewStatus();

    // 4. 캐시 강제 무효화 및 UI 업데이트
    ref.read(stateResetProvider.notifier).resetExchangeStates(reason: message);

    // 5. 내부 선택된 경로 초기화
    onInternalPathClear();

    // 6. UI 업데이트
    dataSource?.notifyDataChanged();

    // 7. 사용자 피드백
    _showSnackBar(
      context,
      message,
      snackBarColor ?? Colors.blue,
      undoButtonLabel,
      onUndoPressed,
    );
  }

  /// SnackBar 표시 헬퍼
  void _showSnackBar(
    BuildContext context,
    String message,
    Color backgroundColor,
    String? actionLabel,
    VoidCallback? onActionPressed,
  ) {
    SnackBarHelper.showWithAction(
      context,
      message,
      backgroundColor: backgroundColor,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  /// 특정 요일(node.day)에 해당하는 실제 날짜를 계산합니다.
  ///
  /// [selectedWeekProvider]가 가리키는 주(週)의 월요일에 요일 오프셋을 더합니다.
  /// 날짜 반영 OFF에서는 그 값이 항상 이번 주이므로, 새 교체는 이번 주 날짜로 저장된다.
  DateTime _dateForNode(DateTime weekMonday, ExchangeNode node) {
    final dayNumber = DayUtils.getDayNumber(node.day); // 1=월 ~ 5=금
    return weekMonday.add(Duration(days: dayNumber - 1));
  }

  /// ExchangePath에서 결강일·교체일을 계산합니다 (§10.4 날짜 선행 확정).
  ///
  /// 결강 기준 노드(비게 되는 수업)와 교체 기준 노드(보강/이동되는 수업)는
  /// 경로 타입마다 다르므로, 스낵바 메시지를 만들 때 쓰는 것과 같은
  /// "대표 노드 2개" 선택 규칙을 그대로 따릅니다.
  ({DateTime absenceDate, DateTime substitutionDate, DateTime weekMonday})
  _computeExchangeDates(ExchangePath exchangePath) {
    final weekMonday = ref.read(selectedWeekProvider);

    final ExchangeNode absenceNode;
    final ExchangeNode substitutionNode;
    if (exchangePath is OneToOneExchangePath) {
      absenceNode = exchangePath.sourceNode;
      substitutionNode = exchangePath.targetNode;
    } else if (exchangePath is DualExchangePath) {
      absenceNode = exchangePath.nodeA;
      substitutionNode = exchangePath.nodeB;
    } else if (exchangePath is CircularExchangePath) {
      absenceNode = exchangePath.nodes.first;
      substitutionNode =
          exchangePath.nodes.length > 1
              ? exchangePath.nodes[1]
              : exchangePath.nodes.first;
    } else if (exchangePath is SupplementExchangePath) {
      absenceNode = exchangePath.sourceNode;
      substitutionNode = exchangePath.targetNode;
    } else {
      throw ArgumentError(
        '알 수 없는 ExchangePath 타입: ${exchangePath.runtimeType}',
      );
    }

    return (
      absenceDate: _dateForNode(weekMonday, absenceNode),
      substitutionDate: _dateForNode(weekMonday, substitutionNode),
      weekMonday: weekMonday,
    );
  }

  /// 교체 노드를 "교사명 요일N교시" 형식으로 표시합니다.
  String _formatExchangeNodeSlot(ExchangeNode node) {
    return '${node.teacherName} ${node.day}${node.period}교시';
  }

  /// 양쪽 교사·교시와 교체 유형을 포함한 완료 메시지를 생성합니다.
  String _buildExchangePairMessage(
    ExchangeNode left,
    ExchangeNode right,
    String exchangeTypeLabel,
  ) {
    return '${_formatExchangeNodeSlot(left)} ↔ '
        '${_formatExchangeNodeSlot(right)} $exchangeTypeLabel 교체가 완료되었습니다.';
  }

  /// 교체 완료 스낵바 메시지 생성
  String _buildExchangeCompleteMessage(ExchangePath exchangePath) {
    if (exchangePath is OneToOneExchangePath) {
      return _buildExchangePairMessage(
        exchangePath.sourceNode,
        exchangePath.targetNode,
        '1:1',
      );
    }
    if (exchangePath is DualExchangePath) {
      // 목표 교체(nodeA ↔ nodeB)를 스낵바에 표시
      return _buildExchangePairMessage(
        exchangePath.nodeA,
        exchangePath.nodeB,
        '2중',
      );
    }
    if (exchangePath is CircularExchangePath) {
      final nodes = exchangePath.nodes;
      if (nodes.length >= 2) {
        return _buildExchangePairMessage(nodes[0], nodes[1], '순환');
      }
      return '순환 교체가 완료되었습니다.';
    }
    return '${exchangePath.displayTitle}가 완료되었습니다.';
  }

  /// 교체 실행 후 계획서 자동 생성 중 여부 (연속 실행 시 중복 생성 방지)
  bool _isCreatingPlan = false;

  /// 교체 실행 후 계획서가 하나도 없으면 자동 생성한다 (최초 교체 시점).
  ///
  /// 이름은 결강일 기준 "결보강 YY.MM.DD", 귀속 교사는 준비 교사를 우선하고
  /// 없으면 결강 노드의 교사를 쓴다. 교체 건→계획서 지정은 기존 흐름
  /// (결보강 일정의 계획서 적용)이 담당하므로 여기서는 생성만 한다.
  /// 실패해도 교체 실행 자체에는 영향을 주지 않는다.
  Future<void> _ensurePlanExistsAfterExecution({
    required DateTime absenceDate,
    required String fallbackTeacher,
  }) async {
    try {
      if (_isCreatingPlan) return;
      final store = ref.read(printProfileStoreProvider);
      if (store.profiles.isNotEmpty) return;

      var teacher = ref.read(activeTeacherNameProvider).trim();
      if (teacher.isEmpty) teacher = fallbackTeacher.trim();
      if (teacher.isEmpty) {
        AppLogger.warning('계획서 자동 생성 생략: 교사명이 없습니다');
        return;
      }

      _isCreatingPlan = true;
      try {
        // 비동기 사이 다른 경로로 생성됐으면 중복 생성하지 않음
        final current = ref.read(printProfileStoreProvider);
        if (current.profiles.isNotEmpty) return;

        final profile = PrintProfile(
          id: PrintProfile.generateId(),
          name: DateFormatUtils.toSubstitutionPlanName(absenceDate),
          teacherName: teacher,
          templateIndex: 0,
          fontSize: 10.0,
          remarksFontSize: 7.0,
          selectedFont: KoreanFontConstants.defaultFont,
          includeRemarks: false,
          additionalFields: {'teacherName': teacher},
        );
        final ok = await ref
            .read(printProfileStoreProvider.notifier)
            .saveProfile(profile);
        if (!ok) return;
        await ref
            .read(printProfileStoreProvider.notifier)
            .setLastUsedProfile(profile.id);
        ref.read(usageStatsServiceProvider).record(UsageEvent.planCreate);
        AppLogger.info("계획서 자동 생성(교체 실행): '${profile.name}' ($teacher)");
      } finally {
        _isCreatingPlan = false;
      }
    } catch (e) {
      AppLogger.error('계획서 자동 생성 실패 (교체 실행에는 영향 없음): $e', e);
    }
  }

  /// 교체 실행 기능
  void executeExchange(
    ExchangePath exchangePath,
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) {
    final historyService = ref.read(exchangeHistoryServiceProvider);

    // 교체 실행 - 순환교체의 경우 단계 수 전달
    int? stepCount;
    if (exchangePath is CircularExchangePath) {
      stepCount = exchangePath.nodes.length; // 노드 수 = 단계 수
    }

    final dates = _computeExchangeDates(exchangePath);

    // S5.6.7: 순환·2중은 실행 시점에 이미 각 노드의 실제 날짜를 알고 있다
    // (바로 위 dates가 나온 것과 같은 selectedWeek 기준 계산) — 나중에
    // 계획서에서 "추정"으로 다시 유도하는 대신, 지금 그 사실을 그대로
    // 기록해 둔다. 1:1·보강이면 빈 맵을 반환한다(기존과 동일).
    final nodeDates = seedNodeDatesForWeek(exchangePath, dates.weekMonday);

    historyService.executeExchange(
      exchangePath,
      absenceDate: dates.absenceDate,
      substitutionDate: dates.substitutionDate,
      customDescription: '교체 실행: ${exchangePath.displayTitle}',
      additionalMetadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'manual',
        'source': 'timetable_grid_section',
      },
      stepCount: stepCount,
      nodeDates: nodeDates,
    );

    // 최초 교체 시 계획서가 없으면 자동 생성 (실패해도 교체에는 영향 없음)
    String absenceTeacher = '';
    if (exchangePath is OneToOneExchangePath) {
      absenceTeacher = exchangePath.sourceNode.teacherName;
    } else if (exchangePath is DualExchangePath) {
      absenceTeacher = exchangePath.nodeA.teacherName;
    } else if (exchangePath is CircularExchangePath &&
        exchangePath.nodes.isNotEmpty) {
      absenceTeacher = exchangePath.nodes.first.teacherName;
    }
    unawaited(
      _ensurePlanExistsAfterExecution(
        absenceDate: dates.absenceDate,
        fallbackTeacher: absenceTeacher,
      ),
    );

    // 공통 후처리
    _executeCommonPostProcess(
      context: context,
      onInternalPathClear: onInternalPathClear,
      message: _buildExchangeCompleteMessage(exchangePath),
      snackBarColor: Colors.blue,
      undoButtonLabel: '되돌리기',
      onUndoPressed: () => undoLastExchange(context, onInternalPathClear),
    );
  }

  /// 보강 실행 기능
  void executeSupplementExchange(
    String sourceTeacher,
    String sourceDay,
    int sourcePeriod,
    String targetTeacherName,
    String className,
    String subject,
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) {
    final historyService = ref.read(exchangeHistoryServiceProvider);

    // 보강 경로 생성
    final supplementPath = SupplementExchangePath.simple(
      id: 'supplement_${sourceTeacher}_${sourceDay}_$sourcePeriod',
      sourceTeacher: sourceTeacher,
      sourceDay: sourceDay,
      sourcePeriod: sourcePeriod,
      targetTeacher: targetTeacherName,
      targetDay: sourceDay,
      targetPeriod: sourcePeriod,
      className: className,
      subject: subject,
    );

    // 교체 실행
    final dates = _computeExchangeDates(supplementPath);

    historyService.executeExchange(
      supplementPath,
      absenceDate: dates.absenceDate,
      substitutionDate: dates.substitutionDate,
      customDescription:
          '보강 예약: $targetTeacherName → $sourceTeacher($sourceDay$sourcePeriod교시)',
      additionalMetadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'supplement_reservation',
        'source': 'timetable_grid_section',
      },
    );

    // 최초 교체 시 계획서가 없으면 자동 생성 (실패해도 교체에는 영향 없음)
    unawaited(
      _ensurePlanExistsAfterExecution(
        absenceDate: dates.absenceDate,
        fallbackTeacher: sourceTeacher,
      ),
    );

    // 공통 후처리
    _executeCommonPostProcess(
      context: context,
      onInternalPathClear: onInternalPathClear,
      message: '보강 계획이 저장되었습니다: $targetTeacherName $sourceDay$sourcePeriod교시',
      snackBarColor: Colors.green,
      undoButtonLabel: '되돌리기',
      onUndoPressed: () => undoLastExchange(context, onInternalPathClear),
    );
  }

  /// 교체 리스트에서 삭제 기능
  /// 교체 뷰가 활성화된 경우 내부적으로 비활성화 → 삭제 → 재활성화 수행
  Future<void> deleteFromExchangeList(
    ExchangePath exchangePath,
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) async {
    final historyService = ref.read(exchangeHistoryServiceProvider);

    // 교체 뷰 활성화 상태 확인
    final isExchangeViewEnabled = ref.read(isExchangeViewEnabledProvider);
    bool wasExchangeViewEnabled = false;

    if (isExchangeViewEnabled) {
      AppLogger.exchangeDebug(
        '[ExchangeExecutor] 교체 뷰가 활성화된 상태에서 삭제 요청 - 내부적으로 비활성화 후 삭제 실행',
      );
      wasExchangeViewEnabled = true;

      // 교체 뷰 비활성화
      final exchangeViewNotifier = ref.read(exchangeViewProvider.notifier);
      final screenState = ref.read(exchangeScreenProvider);

      if (screenState.timetableData != null && dataSource != null) {
        await exchangeViewNotifier.disableExchangeView(
          timeSlots: screenState.timetableData!.timeSlots,
          teachers: screenState.timetableData!.teachers,
          dataSource: dataSource!,
        );
        AppLogger.exchangeDebug('[ExchangeExecutor] 교체 뷰 비활성화 완료 - 삭제 실행 준비');
      }
    }

    // 1. 교체 리스트에서 찾아서 삭제 (중복 실행된 동일 경로는 활성·최신 우선)
    final targetItem = historyService.findDeletableItem(exchangePath.id);
    if (targetItem == null) {
      throw StateError('해당 교체 경로를 교체 리스트에서 찾을 수 없습니다');
    }

    historyService.removeFromExchangeList(targetItem.id);

    // 2. 교체된 셀 목록 강제 업데이트
    // _exchangeList가 변경되었으므로 UI 업데이트만 필요

    // 3. 콘솔 출력
    historyService.printExchangeList();
    historyService.printUndoHistory();

    // 4. 교체된 셀 상태 업데이트
    _updateExchangedCells();

    // 5. 캐시 강제 무효화 및 UI 업데이트
    ref
        .read(stateResetProvider.notifier)
        .resetExchangeStates(reason: '교체 삭제 - 선택 상태 초기화');

    // 6. 내부 선택된 경로 초기화
    onInternalPathClear();

    // 7. UI 업데이트 (최적화됨 - 특정 셀만 업데이트하여 스크롤 위치 보존)
    dataSource?.notifyDataChanged();

    // 8. 교체 뷰가 원래 활성화되어 있었다면 다시 활성화
    if (wasExchangeViewEnabled) {
      AppLogger.exchangeDebug('[ExchangeExecutor] 삭제 완료 - 교체 뷰 재활성화 시작');

      final exchangeViewNotifier = ref.read(exchangeViewProvider.notifier);
      final screenState = ref.read(exchangeScreenProvider);

      if (screenState.timetableData != null && dataSource != null) {
        await exchangeViewNotifier.enableExchangeView(
          timeSlots: screenState.timetableData!.timeSlots,
          teachers: screenState.timetableData!.teachers,
          dataSource: dataSource!,
        );
        AppLogger.exchangeDebug('[ExchangeExecutor] 교체 뷰 재활성화 완료');
      }
    }
  }

  /// 결보강 전체 삭제 직전 상태(계획서·보강 과목) 스냅샷.
  ///
  /// 전체 삭제 시 `clearExchangeList(bulkExtra:)`에 넘겨 두면, 되돌리기 한 번에
  /// 교체 목록과 함께 이 상태도 복원된다.
  ExchangeClearSnapshot captureClearSnapshot() {
    return ExchangeClearSnapshot.capture(
      store: ref.read(printProfileStoreProvider),
      supplementSubjects:
          ref.read(substitutionPlanProvider).savedSupplementSubjects,
    );
  }

  /// 되돌리기 기능
  Future<void> undoLastExchange(
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) async {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final result = historyService.undoLastExchange();

    if (result == null || result.items.isEmpty) {
      SnackBarHelper.showWithAction(
        context,
        '되돌릴 교체가 없습니다',
        backgroundColor: Colors.grey,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final items = result.items;
    final item = items.first;

    // 전체 삭제 되돌리기면 함께 지워졌던 계획서·보강 과목도 복원한다.
    // 아래 계획서 선택 복원이 대상 계획서를 찾을 수 있도록 먼저 한다.
    final snapshot = result.bulkExtra;
    if (result.wasBulk && snapshot is ExchangeClearSnapshot) {
      ref
          .read(substitutionPlanProvider.notifier)
          .restoreSupplementSubjects(snapshot.supplementSubjects);
      await ref
          .read(printProfileStoreProvider.notifier)
          .restoreProfiles(
            snapshot.profiles,
            lastUsedProfileId: snapshot.lastUsedProfileId,
            lastSelectedTeacher: snapshot.lastSelectedTeacher,
          );
    }

    // 묶음이면 전원 같은 주일 때만 그 주로 이동한다 — 주가 엇갈리면
    // 어느 주로 가야 할지 하나로 정할 수 없으므로 제자리에 둔다.
    // 단일이면 항상 전원(1건) 같은 주라 기존 동작과 같다.
    final jumpWeek =
        items.every(
              (e) => ExchangeWeekCollector.isSameWeek(
                e.weekMonday,
                item.weekMonday,
              ),
            )
            ? item.weekMonday
            : null;
    // §10.5 확정: 되돌리기는 '전체 최근 1건'을 되돌리되, 그 교체가 속한 주로
    // 화면을 자동 이동한다. 다른 주의 교체를 되돌리면 화면이 점프하므로
    // 안내가 필수다 — 없으면 "버튼을 눌렀더니 화면이 멋대로 바뀌었다"가 된다.
    //
    // 날짜 반영 OFF에서는 이동하지 않는다 — OFF는 "선택 주 = 항상 이번 주"
    // 불변 조건을 지켜야 한다(주가 화면에 안 보이는데 몰래 바뀌면, 다음 교체가
    // 엉뚱한 주 날짜로 저장된다). `ExchangeWeekBar._setShowWeekHeader` 참고.
    final jumpedToOtherWeek =
        jumpWeek != null &&
        ref.read(showWeekHeaderProvider) &&
        !ExchangeWeekCollector.isSameWeek(
          ref.read(selectedWeekProvider),
          jumpWeek,
        );
    if (jumpedToOtherWeek) {
      ref.read(selectedWeekProvider.notifier).state = jumpWeek;
    }

    _applyExchangeStateAfterHistoryChange(item);

    // 삭제 되돌리기 등으로 목록에 다시 보이면 계획서 체크도 선택으로 맞춘다.
    // hydrate보다 먼저 끝나야 선택이 다시 꺼지지 않는다.
    // 묶음 복원이면 복원된 것 중 활성(되돌려 두지 않은) 항목만 선택한다 —
    // 전체 삭제 전에 이미 되돌려 둔 교체는 목록에 보이지 않기 때문이다.
    if (_isActiveAfterHistoryChange(
      wasDelete: result.wasDelete,
      isRedo: false,
    )) {
      for (final restored in items.where((e) => !e.isReverted)) {
        await _selectRestoredExchangeInPlans(restored);
      }
    }

    historyService.printExchangeList();
    historyService.printUndoHistory();
    historyService.printRedoHistory();

    ref
        .read(stateResetProvider.notifier)
        .resetExchangeStates(reason: '되돌리기 - 선택 상태 초기화');

    dataSource?.notifyDataChanged();

    // S5.4 (D6/OQ-2): 되돌리기는 그대로 수행하되, 이후 교체가 이 교체의
    // 결과를 전제로 하고 있으면 안내만 덧붙인다 — 막지 않는다.
    // 묶음이면 복원된 전체의 의존을 합친다(중복 제거). 함께 복원된 교체끼리의
    // 의존은 모두 충족된 상태이므로 세지 않는다.
    final allEvents = historyService.getExchangeList();
    final restoredIds = items.map((e) => e.id).toSet();
    final dependentIds = <String>{};
    for (final restored in items) {
      for (final dependent in findDependentExchanges(
        target: restored,
        allEventsInOrder: allEvents,
      )) {
        if (!restoredIds.contains(dependent.id)) {
          dependentIds.add(dependent.id);
        }
      }
    }

    final weekLabel = ExchangeWeekCollector.monthWeekLabel(item.weekMonday);
    final baseMessage =
        result.wasBulk
            ? '삭제된 교체 ${items.length}건이 복원되었습니다'
            : result.wasDelete
            ? '삭제된 교체 "${item.description}"가 복원되었습니다'
            : jumpedToOtherWeek
            ? '$weekLabel의 교체를 되돌렸습니다'
            : '교체 "${item.description}"가 되돌려졌습니다';
    final message =
        dependentIds.isEmpty
            ? baseMessage
            : '$baseMessage (참고: 이후 교체 ${dependentIds.length}건이 이 교체를 전제로 합니다)';

    if (!context.mounted) return;
    SnackBarHelper.showWithAction(
      context,
      message,
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 2),
    );
  }

  /// 다시 실행 기능 (되돌리기 후 1단계 복구)
  Future<void> redoLastExchange(BuildContext context) async {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    // 전체 삭제를 다시 적용할 때는 재삭제 직전 상태로 스냅샷을 다시 떠서,
    // 복원 후 고친 계획서·보강 과목이 다음 되돌리기에서 사라지지 않게 한다.
    final result = historyService.redoLastExchange(
      recaptureBulkExtra:
          (previous) =>
              previous is ExchangeClearSnapshot
                  ? previous.recapture(
                    store: ref.read(printProfileStoreProvider),
                    supplementSubjects:
                        ref
                            .read(substitutionPlanProvider)
                            .savedSupplementSubjects,
                  )
                  : previous,
    );

    if (result == null || result.items.isEmpty) {
      SnackBarHelper.showWithAction(
        context,
        '다시 실행할 교체가 없습니다',
        backgroundColor: Colors.grey,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    final items = result.items;
    final item = items.first;

    // 전체 삭제 재적용이면 되돌리기 때 함께 복원했던 계획서·보강 과목도 지운다.
    final snapshot = result.bulkExtra;
    if (result.wasBulk && snapshot is ExchangeClearSnapshot) {
      ref
          .read(substitutionPlanProvider.notifier)
          .removeSupplementSubjects(snapshot.supplementSubjects.keys);
      await ref
          .read(printProfileStoreProvider.notifier)
          .removeProfiles(snapshot.profileIds);
    }

    _applyExchangeStateAfterHistoryChange(item, isRedo: true);

    // 교체 다시실행으로 목록에 다시 보이면 계획서 체크도 선택으로 맞춘다.
    if (_isActiveAfterHistoryChange(
      wasDelete: result.wasDelete,
      isRedo: true,
    )) {
      for (final restored in items) {
        await _selectRestoredExchangeInPlans(restored);
      }
    }

    historyService.printExchangeList();
    historyService.printUndoHistory();
    historyService.printRedoHistory();

    ref
        .read(stateResetProvider.notifier)
        .resetExchangeStates(reason: '다시 실행 - 선택 상태 초기화');

    dataSource?.notifyDataChanged();

    if (!context.mounted) return;
    SnackBarHelper.showWithAction(
      context,
      result.wasBulk
          ? '교체 ${items.length}건 삭제가 다시 적용되었습니다'
          : result.wasDelete
          ? '교체 "${item.description}" 삭제가 다시 적용되었습니다'
          : '교체 "${item.description}"가 다시 실행되었습니다',
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    );
  }

  /// 되돌리기/다시실행 결과로 해당 교체가 활성 목록에 보이는지.
  ///
  /// - 삭제 되돌리기 / 교체 다시실행 → 활성(복원)
  /// - 교체 되돌리기 / 삭제 다시실행 → 비활성
  bool _isActiveAfterHistoryChange({
    required bool wasDelete,
    required bool isRedo,
  }) {
    return wasDelete != isRedo;
  }

  /// 복원된 교체를 계획서 제외 목록에서 빼 선택 상태로 저장한다.
  ///
  /// 교체 화면에서 undo/redo 해도 결보강 일정 체크가 풀리지 않게 한다.
  /// 메모리를 먼저 갱신하므로 직후 hydrate가 선택을 다시 끄지 않는다.
  Future<void> _selectRestoredExchangeInPlans(ExchangeHistoryItem item) async {
    try {
      final exchangeId = item.id;
      if (exchangeId.isEmpty) return;

      final store = ref.read(printProfileStoreProvider);
      final targetIds = <String>{};
      final assigned = item.profileId?.trim() ?? '';
      if (assigned.isNotEmpty) targetIds.add(assigned);
      final lastUsed = store.lastUsedProfileId;
      if (lastUsed != null && lastUsed != '__default__') {
        targetIds.add(lastUsed);
      }
      // 배정·최근 사용이 없으면 열린 계획서 전부에 반영해 선택 복원을 놓치지 않는다.
      if (targetIds.isEmpty) {
        targetIds.addAll(store.profiles.map((p) => p.id));
      }
      if (targetIds.isEmpty) return;

      await ref
          .read(printProfileStoreProvider.notifier)
          .markGroupsSelected(groupIds: {exchangeId}, profileIds: targetIds);
    } catch (e) {
      AppLogger.warning('복원 교체 계획서 선택 반영 실패(무시): $e');
    }
  }

  /// 되돌리기/다시 실행 후 시간표·셀 스타일 동기화
  ///
  /// §10.2.1 전환 후에는 교체 유형별 특수 처리가 필요 없다. 되돌린 항목은
  /// `isReverted`가 true가 되어 [ResolvedWeek] 합성에서 자동으로 빠지므로,
  /// "현재 보고 있는 주를 다시 합성해 그린다" 하나로 모든 유형이 처리된다.
  /// (기존의 보강 전용 undo/redo 경로는 이 때문에 제거했다.)
  void _applyExchangeStateAfterHistoryChange(
    ExchangeHistoryItem item, {
    bool isRedo = false,
  }) {
    _refreshExchangeView();
    _updateExchangedCells();
  }

  /// 교체 뷰가 켜져 있으면 현재 주 기준으로 다시 합성해 그린다.
  ///
  /// **원본**(`timetableData.timeSlots`)을 넘긴다 — `dataSource`가 든 것은
  /// 합성본이라 그것을 base로 쓰면 교체가 이중 적용된다(§10.2.1).
  void _refreshExchangeView() {
    final screenState = ref.read(exchangeScreenProvider);
    if (screenState.timetableData == null || dataSource == null) return;

    ref
        .read(exchangeViewProvider.notifier)
        .refreshIfEnabled(
          timeSlots: screenState.timetableData!.timeSlots,
          teachers: screenState.timetableData!.teachers,
          dataSource: dataSource!,
        );
    dataSource?.notifyDataChanged();
  }

  /// 교체 뷰 활성화 여부 검사 및 처리 (공통 메서드)
  /// 각 교체 모드의 마지막 단계에서 호출되어 교체 뷰가 활성화되어 있으면 enableExchangeView 실행
  void _checkExchangeViewStatus() {
    // 교체 뷰가 활성화되어 있는지 검사
    final isExchangeViewEnabled = ref.read(isExchangeViewEnabledProvider);

    if (isExchangeViewEnabled) {
      AppLogger.exchangeDebug(
        '[ExchangeExecutor] 교체 뷰가 활성화되어 있음 - _enableExchangeView() 실행',
      );

      // 교체 뷰 활성화 콜백 호출
      if (onEnableExchangeView != null) {
        onEnableExchangeView!();
        AppLogger.exchangeDebug(
          '[ExchangeExecutor] _enableExchangeView() 실행 완료',
        );
      } else {
        AppLogger.exchangeDebug('[ExchangeExecutor] 교체 뷰 활성화 콜백이 설정되지 않음');
      }
    } else {
      AppLogger.exchangeDebug(
        '[ExchangeExecutor] 교체 뷰가 비활성화되어 있음 - 교체는 리스트에만 저장됨',
      );
    }
  }

  /// 교체된 셀 상태 업데이트 (공통 메서드)
  ///
  /// 내부에서만 사용되는 private 메서드입니다.
  /// 외부에서 호출하려면 `updateExchangedCells()` public 메서드를 사용하세요.
  void _updateExchangedCells() {
    final cellNotifier = ref.read(cellSelectionProvider.notifier);

    // 교체된 셀 정보 추출
    final exchangedCells = _extractExchangedCells();
    final destinationCells = _extractDestinationCells();

    AppLogger.exchangeDebug('🔄 [ExchangeExecutor] 교체된 셀 정보 업데이트:');
    AppLogger.exchangeDebug(
      '  - 소스 셀: ${exchangedCells.length}개 - $exchangedCells',
    );
    AppLogger.exchangeDebug(
      '  - 목적지 셀: ${destinationCells.length}개 - $destinationCells',
    );

    // 교체된 소스 셀(교체 전 원본 수업이 있던 셀)의 테두리 스타일 업데이트
    cellNotifier.updateExchangedCells(exchangedCells);
    // 교체된 목적지 셀(교체 후 새 교사가 배정된 셀)의 배경색 업데이트
    cellNotifier.updateExchangedDestinationCells(destinationCells);

    AppLogger.exchangeDebug('✅ [ExchangeExecutor] 교체된 셀 상태 업데이트 완료');
  }

  /// 교체된 셀 상태 업데이트 (외부 호출용 public 메서드)
  ///
  /// 현재 교체 리스트를 읽어서 교체된 셀의 시각적 스타일을 업데이트합니다.
  /// 교체 리스트 전체 삭제 등에서 사용할 수 있습니다.
  void updateExchangedCells() {
    _updateExchangedCells();
  }

  /// 교체된 셀 상태 복원 (프로그램 시작 시 호출)
  ///
  /// 저장된 교체 리스트에서 교체된 셀 정보를 추출하여 CellSelectionProvider에 복원합니다.
  /// 교체 리스트가 비어있으면 모든 교체된 셀 스타일을 제거합니다.
  static void restoreExchangedCells(WidgetRef ref) {
    try {
      final historyService = ref.read(exchangeHistoryServiceProvider);
      final activeItems = historyService.getActiveExchangeList();

      if (activeItems.isEmpty) {
        AppLogger.info('교체 리스트가 비어있어 모든 교체된 셀 스타일을 제거합니다.');
      } else {
        AppLogger.info('교체된 셀 테마 복원 시작: ${activeItems.length}개 교체 항목');
      }

      // 교체된 셀 정보 추출 (S1.9: 날짜표시 ON이면 주별 스코프, 빈 리스트도 처리)
      final keys = _computeCellKeys(ref, activeItems);
      AppLogger.info(
        '교체된 셀 정보 추출 완료: 소스 ${keys.source.length}개, 목적지 ${keys.destination.length}개',
      );

      // CellSelectionProvider에 복원/업데이트 (빈 리스트도 업데이트하여 스타일 제거)
      final cellNotifier = ref.read(cellSelectionProvider.notifier);
      cellNotifier.updateExchangedCells(keys.source);
      cellNotifier.updateExchangedDestinationCells(keys.destination);

      AppLogger.info('✅ 교체된 셀 테마 복원 완료');
    } catch (e) {
      AppLogger.error('교체된 셀 테마 복원 중 오류: $e', e);
    }
  }

  /// 교체된 소스 셀(빠진 수업) 키 목록 추출 (S1.9: 날짜표시 ON이면 주별 스코프)
  List<String> _extractExchangedCells() {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    return _computeCellKeys(ref, historyService.getActiveExchangeList()).source;
  }

  /// 교체된 목적지 셀(맡은 수업) 키 목록 추출 (S1.9: 날짜표시 ON이면 주별 스코프)
  List<String> _extractDestinationCells() {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    return _computeCellKeys(
      ref,
      historyService.getActiveExchangeList(),
    ).destination;
  }

  /// 활성 이벤트 목록으로부터 소스·목적지 셀 키를 계산한다 (S1.9).
  ///
  /// 날짜표시 스위치가 OFF면 기존 방식(요일·교시 키, 어느 주를 보든 항상 표시)을
  /// 그대로 쓴다 — 회귀 안전성의 핵심. ON이면 [ExchangeCellDates.forWeek]로
  /// 실제 날짜 기준 주별 스코프를 적용한다. `restoreExchangedCells`(정적 메서드)도
  /// 같은 로직을 타야 하므로 정적 메서드로 둔다.
  static ({List<String> source, List<String> destination}) _computeCellKeys(
    WidgetRef ref,
    List<ExchangeHistoryItem> activeItems,
  ) {
    if (ref.read(showWeekHeaderProvider)) {
      final scoped = ExchangeCellDates.forWeek(
        activeItems,
        ref.read(selectedWeekProvider),
      );
      return (
        source: scoped.sourceKeys.toList(),
        destination: scoped.destinationKeys.toList(),
      );
    }

    final source = <String>[];
    final destination = <String>[];
    for (final item in activeItems) {
      source.addAll(ExchangeCellDates.legacySourceKeys(item.originalPath));
      destination.addAll(
        ExchangeCellDates.legacyDestinationKeys(item.originalPath),
      );
    }
    return (source: source, destination: destination);
  }
}

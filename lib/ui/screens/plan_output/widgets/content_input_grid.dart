import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../constants/korean_fonts.dart';
import '../../../../constants/screen_usage_hints.dart';
import 'package:flutter/services.dart';
import '../../../../models/plan_output_menu.dart';
import '../../../../models/print_profile.dart';
import '../../../../providers/plan_crud_actions_provider.dart';
import '../../../../providers/plan_output_menu_provider.dart';
import '../../../../providers/print_profile_provider.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../providers/services_provider.dart';
import '../../../../providers/state_reset_provider.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../ui/widgets/content_toolbar_layout.dart';
import '../../../../ui/widgets/content_usage_hint_bar.dart';
import '../../../../ui/widgets/timetable_grid/exchange_executor.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/snackbar_helper.dart';
import '../../../../utils/dialog_helper.dart';
import '../../../mixins/scroll_management_mixin.dart';
import 'content_input/content_input_data_grid.dart';
import 'content_input/content_input_grid_action_toolbar.dart';
import 'content_input/content_input_grid_states.dart';
import 'content_input_grid_helpers.dart';
import 'content_input_grid_plan_ops.dart';

/// 보강계획서 그리드 위젯 (리팩토링 버전)
class ContentInputGrid extends ConsumerStatefulWidget {
  const ContentInputGrid({super.key});

  @override
  ConsumerState<ContentInputGrid> createState() => _ContentInputGridState();
}

class _ContentInputGridState extends ConsumerState<ContentInputGrid>
    with ScrollManagementMixin {
  /// 결보강 출력 대상 선택 상태 (그룹 = 교체 건 ID 기준)
  ///
  /// 기본은 전체 선택. 변경 시 현재 계획서의 deselectedGroupIds에 즉시 저장합니다.
  final Set<String> _checkedGroupIds = {};
  String? _selectedPlanId;

  /// 체크 UI를 계획서에서 한 번 이상 맞췄는지 (초기 전체선택 동기화용)
  bool _selectionHydrated = false;

  /// 2열 헤더 CRUD 버튼 콜백 Provider의 notifier.
  ///
  /// dispose()에서 콜백을 해제할 때 `ref.read`를 다시 호출하면 안 된다 —
  /// Flutter는 `StatefulElement.unmount()`에서 위젯/컨텍스트를 먼저 비운
  /// 뒤에 `state.dispose()`를 호출하므로, dispose() 안에서의 `ref.read`는
  /// 항상 `Cannot use "ref" after the widget was disposed` 오류를 던진다.
  /// initState에서 미리 읽어 둔 notifier 인스턴스를 그대로 쓰면 이 문제를
  /// 피할 수 있다(Provider 컨테이너 자체는 아직 살아있으므로 안전하다).
  late final StateController<PlanCrudActions?> _planCrudActionsNotifier;

  @override
  void initState() {
    super.initState();
    _planCrudActionsNotifier = ref.read(planCrudActionsProvider.notifier);
    // 공통 스크롤 관리 믹신 초기화
    initializeScrollControllers();
  }

  @override
  void dispose() {
    // 2열 헤더 CRUD 버튼 콜백 해제
    _planCrudActionsNotifier.state = null;
    // 공통 스크롤 관리 믹신 해제
    disposeScrollControllers();
    super.dispose();
  }

  /// 2열 헤더용 CRUD 액션을 Provider에 등록한다.
  void _publishCrudActions(List<SubstitutionPlanData> planData) {
    final store = ref.read(printProfileStoreProvider);
    final selectedId = _resolveSelectedPlanId(store, planData);
    final selectedProfile = store.getById(selectedId);
    final actions = PlanCrudActions(
      onCreate: () => unawaited(_createPlanFromFirstRow(planData)),
      onRename: () {
        final id = selectedProfile?.id;
        if (id == null) return;
        unawaited(_renamePlan(id, planData));
      },
      onDelete: () {
        final id = selectedProfile?.id;
        if (id == null) return;
        unawaited(_deletePlan(id));
      },
      canCreate: planData.isNotEmpty,
      canModify: selectedProfile != null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(planCrudActionsProvider.notifier).state = actions;
    });
  }

  /// 그룹(교체 건)의 지정 계획서 ID 조회 (삭제된 계획서면 null → 미지정)
  String? _selectedProfileIdForGroup(String groupId) {
    return ContentInputGridPlanOps.selectedProfileIdForGroup(ref, groupId);
  }

  /// 행 교사의 계획서 목록
  List<PrintProfile> _profileOptionsForTeacher(String teacher) {
    return ContentInputGridPlanOps.profileOptionsForTeacher(ref, teacher);
  }

  /// 그룹 선택 토글 — 즉시 현재 계획서 파일에 저장
  void _toggleGroupSelection(String groupId) {
    setState(() {
      if (_checkedGroupIds.contains(groupId)) {
        _checkedGroupIds.remove(groupId);
      } else {
        _checkedGroupIds.add(groupId);
      }
    });
    unawaited(_persistSelectionToCurrentPlan());
  }

  /// 전체 선택/해제 토글 — 즉시 저장
  void _toggleSelectAll(List<SubstitutionPlanData> planData) {
    final allGroupIds = _allGroupIds(planData);

    setState(() {
      if (_checkedGroupIds.containsAll(allGroupIds) && allGroupIds.isNotEmpty) {
        _checkedGroupIds.clear();
      } else {
        _checkedGroupIds
          ..clear()
          ..addAll(allGroupIds);
      }
    });
    unawaited(_persistSelectionToCurrentPlan());
  }

  Set<String> _allGroupIds(List<SubstitutionPlanData> planData) {
    return ContentInputGridPlanOps.allGroupIds(planData);
  }

  /// 상단 드롭다운에 표시할 현재 계획서 ID (저장된 계획서만, 없으면 null)
  String? _resolveSelectedPlanId(
    PrintProfileStore store,
    List<SubstitutionPlanData> planData,
  ) {
    return ContentInputGridPlanOps.resolveSelectedPlanId(
      store: store,
      planData: planData,
      selectedPlanId: _selectedPlanId,
    );
  }

  PrintProfile? _currentProfile(PrintProfileStore store) {
    return ContentInputGridPlanOps.currentProfile(store, _selectedPlanId);
  }

  /// 계획서의 제외 목록 → 체크 UI 반영 (기본: 모두 선택)
  void _hydrateSelectionFromPlan(
    PrintProfileStore store,
    List<SubstitutionPlanData> planData,
  ) {
    _selectionHydrated = ContentInputGridPlanOps.hydrateSelectionFromPlan(
      store: store,
      planData: planData,
      selectedPlanId: _selectedPlanId,
      checkedGroupIds: _checkedGroupIds,
      selectionHydrated: _selectionHydrated,
    );
  }

  /// 체크 상태를 현재 계획서에 저장 (없으면 준비 교사 기준으로 계획서 생성)
  Future<void> _persistSelectionToCurrentPlan() async {
    final planData = ref.read(substitutionPlanViewModelProvider).planData;
    final allIds = _allGroupIds(planData);
    final deselected =
        allIds.where((id) => !_checkedGroupIds.contains(id)).toList()..sort();

    var store = ref.read(printProfileStoreProvider);
    var profile = _currentProfile(store);

    // 계획서가 없으면 선택 저장을 위해 하나 만듦
    if (profile == null) {
      profile = await _ensurePlanExists(planData, nameHint: null);
      if (profile == null) return;
      store = ref.read(printProfileStoreProvider);
    }

    // 내용이 같으면 디스크 쓰기 생략
    if (_listEquals(profile.deselectedGroupIds, deselected)) return;

    await ref
        .read(printProfileStoreProvider.notifier)
        .saveProfile(profile.copyWith(deselectedGroupIds: deselected));
  }

  bool _listEquals(List<String> a, List<String> b) {
    return ContentInputGridPlanOps.listEquals(a, b);
  }

  /// 현재 계획서가 없으면 생성하고, 있으면 그대로 반환
  ///
  /// 교사명은 준비 화면 교사를 우선합니다. 기존 계획서의 teacherName이
  /// 비어 있거나 다르면 준비 교사로 맞춰 결보강 출력 목록에 보이게 합니다.
  Future<PrintProfile?> _ensurePlanExists(
    List<SubstitutionPlanData> planData, {
    String? nameHint,
  }) async {
    final store = ref.read(printProfileStoreProvider);
    final existing = _currentProfile(store);
    final teacher = _resolvePlanTeacherName(planData);
    if (teacher.isEmpty) {
      AppLogger.warning('계획서 생성 실패: 교사명이 없습니다');
      return null;
    }

    if (existing != null) {
      // 교사 귀속이 비어 있거나 준비 교사와 다르면 맞춤 (목록 누락 방지)
      if (existing.teacherName.trim() != teacher) {
        final fixed = existing.copyWith(teacherName: teacher);
        final ok = await ref
            .read(printProfileStoreProvider.notifier)
            .saveProfile(fixed);
        if (!ok) return existing;
        AppLogger.info(
          "계획서 '${existing.name}' 교사 귀속 보정: "
          "'${existing.teacherName}' → '$teacher'",
        );
        return fixed;
      }
      return existing;
    }

    final name =
        nameHint ??
        (planData.isNotEmpty &&
                planData.first.absenceDate.isNotEmpty &&
                planData.first.absenceDate != '선택'
            ? DateFormatUtils.toSubstitutionPlanNameFromStored(
              planData.first.absenceDate,
            )
            : '결보강');

    final allIds = _allGroupIds(planData);
    final deselected =
        allIds.where((id) => !_checkedGroupIds.contains(id)).toList()..sort();

    final profile = PrintProfile(
      id: PrintProfile.generateId(),
      name: name,
      teacherName: teacher,
      templateIndex: 0,
      fontSize: 10.0,
      remarksFontSize: 7.0,
      selectedFont: KoreanFontConstants.defaultFont,
      includeRemarks: false,
      additionalFields: {'teacherName': teacher},
      deselectedGroupIds: deselected,
    );

    final ok = await ref
        .read(printProfileStoreProvider.notifier)
        .saveProfile(profile);
    if (!ok) return null;

    setState(() => _selectedPlanId = profile.id);
    _applyPlanToAllRows(profile.id, planData);
    await ref
        .read(printProfileStoreProvider.notifier)
        .setLastUsedProfile(profile.id);
    return profile;
  }

  /// 계획서에 귀속시킬 교사명 (준비 교사 → 없으면 첫 행 결강 교사)
  String _resolvePlanTeacherName(List<SubstitutionPlanData> planData) {
    return ContentInputGridPlanOps.resolvePlanTeacherName(ref, planData);
  }

  /// 결강일 선택 시 현재 계획서 이름을 "결보강 YY.MM.DD"로 변경
  Future<void> _renameSelectedPlanToAbsenceDate(
    DateTime date,
    List<SubstitutionPlanData> planData,
  ) async {
    final name = DateFormatUtils.toSubstitutionPlanName(date);
    final profile = await _ensurePlanExists(planData, nameHint: name);
    if (profile == null) return;

    if (profile.name != name) {
      await ref
          .read(printProfileStoreProvider.notifier)
          .renameProfile(profile.id, name);
    }
    if (!mounted) return;
    setState(() => _selectedPlanId = profile.id);
  }

  /// 행 드롭다운에서 새 계획서 만들기
  ///
  /// 계획서가 0개인 교사 행에서 결보강 출력 탭까지 왕복하지 않도록,
  /// 그 자리에서 만들고 해당 행에 즉시 지정합니다(문서 §3④).
  Future<void> _createProfileForRow(
    String groupId,
    String teacher, {
    String? initialName,
  }) async {
    if (teacher.isEmpty) return;

    final store = ref.read(printProfileStoreProvider);
    final defaultName =
        initialName ?? '계획서${store.byTeacher(teacher).length + 1}';
    final controller = TextEditingController(text: defaultName);

    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("'$teacher'의 새 계획서"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '계획서 이름',
              hintText: '예: 계획서1',
            ),
            onSubmitted:
                (value) => Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed:
                  () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('만들기'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty || !mounted) return;

    // 기본값으로 생성 — 세부 설정은 결보강 출력 탭에서 편집한다
    final profile = PrintProfile(
      id: PrintProfile.generateId(),
      name: name,
      teacherName: teacher,
      templateIndex: 0,
      fontSize: 10.0,
      remarksFontSize: 7.0,
      selectedFont: KoreanFontConstants.defaultFont,
      includeRemarks: false,
      additionalFields: {'teacherName': teacher},
    );

    final success = await ref
        .read(printProfileStoreProvider.notifier)
        .saveProfile(profile);
    if (!mounted) return;

    if (success) {
      _onGroupProfileChanged(groupId, profile.id);
      SnackBarHelper.showSuccess(context, "계획서 '$name'을(를) 만들어 지정했습니다.");
    } else {
      SnackBarHelper.showError(context, '계획서 생성에 실패했습니다.');
    }
  }

  /// 계획서 지정 변경 → 교체 건에 즉시 저장
  void _onGroupProfileChanged(String groupId, String? profileId) {
    ref.read(exchangeHistoryServiceProvider).assignProfile(groupId, profileId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Riverpod select 패턴 사용 - 필요한 상태만 구독
    final planData = ref.watch(
      substitutionPlanViewModelProvider.select((state) => state.planData),
    );
    final isLoading = ref.watch(
      substitutionPlanViewModelProvider.select((state) => state.isLoading),
    );
    final store = ref.watch(printProfileStoreProvider);
    final viewModel = ref.read(substitutionPlanViewModelProvider.notifier);

    // 마지막 사용 계획서·저장된 체크 상태를 UI에 맞춤 (기본: 모두 선택)
    final resolvedId = _resolveSelectedPlanId(store, planData);
    if (resolvedId != _selectedPlanId) {
      _selectedPlanId = resolvedId;
    }
    _hydrateSelectionFromPlan(store, planData);

    // [새계획][수정][삭제]는 2열 헤더(PlanContextHeaderBar)로 이동
    _publishCrudActions(planData);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionToolbar(context, ref, viewModel, planData),
          ContentToolbarLayout.hintToToolbarSpacer,
          ContentUsageHintBar(
            message: ScreenUsageHints.contentInput,
            accentColor:
                context.tokens.monochromeMenuAccents
                    ? context.tokens.primary
                    : PlanOutputMenu.contentInput.color,
          ),
          const SizedBox(height: 10),
          _buildDataGrid(context, ref, planData, isLoading, viewModel),
        ],
      ),
    );
  }

  String _defaultPlanName(List<SubstitutionPlanData> planData) {
    return ContentInputGridPlanOps.defaultPlanName(planData);
  }

  void _applyPlanToAllRows(
    String profileId,
    List<SubstitutionPlanData> planData,
  ) {
    final history = ref.read(exchangeHistoryServiceProvider);
    for (final row in planData) {
      final groupId = row.groupId;
      if (groupId != null && groupId.isNotEmpty) {
        history.assignProfile(groupId, profileId);
      }
    }
    unawaited(
      ref
          .read(printProfileStoreProvider.notifier)
          .setLastUsedProfile(profileId),
    );
    setState(() {});
  }

  Future<void> _createPlanFromFirstRow(
    List<SubstitutionPlanData> planData,
  ) async {
    final first = planData.firstWhere(
      (row) => row.groupId != null && row.groupId!.isNotEmpty,
      orElse: () => planData.first,
    );
    if (first.groupId == null || first.groupId!.isEmpty) return;
    final planName = _defaultPlanName(planData);
    await _createProfileForRow(
      first.groupId!,
      first.teacher,
      initialName: planName,
    );
    final created =
        ref
            .read(printProfileStoreProvider)
            .profiles
            .where(
              (profile) =>
                  profile.name == planName &&
                  profile.teacherName == first.teacher,
            )
            .lastOrNull;
    if (created != null) {
      _selectedPlanId = created.id;
      _applyPlanToAllRows(created.id, planData);
    }
  }

  Future<void> _renamePlan(
    String profileId,
    List<SubstitutionPlanData> planData,
  ) async {
    final profile = ref.read(printProfileStoreProvider).getById(profileId);
    if (profile == null) {
      if (profileId == '__default__') {
        await _createPlanFromFirstRow(planData);
      }
      return;
    }
    if (!mounted) return;
    final controller = TextEditingController(text: profile.name);
    final name = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('계획서 이름 수정'),
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('저장'),
              ),
            ],
          ),
    );
    if (name == null || name.isEmpty) return;
    await ref
        .read(printProfileStoreProvider.notifier)
        .renameProfile(profileId, name);
  }

  Future<void> _deletePlan(String profileId) async {
    if (profileId == '__default__') {
      SnackBarHelper.showError(context, '저장된 계획서가 없습니다.');
      return;
    }
    final confirmed = await DialogHelper.showConfirmDialog(
      context,
      title: '계획서 삭제',
      message:
          '선택한 계획서와 여기 연결된 결보강 내역(교체 기록)이 모두 삭제됩니다.\n'
          '이 작업은 되돌릴 수 없습니다. 삭제하시겠습니까?',
      confirmText: '삭제',
      isDangerous: true,
    );
    if (confirmed != true) return;
    await ref.read(printProfileStoreProvider.notifier).deleteProfile(profileId);
    // 계획서는 특정 결보강 내역 묶음을 대표한다 — 계획서를 지우면 거기
    // 연결된 교체 건도 함께 지워야 결보강 출력·교체 화면과 어긋나지 않는다.
    ref
        .read(exchangeHistoryServiceProvider)
        .removeExchangeItemsByProfile(profileId);
    ExchangeExecutor.restoreExchangedCells(ref);
    if (mounted) setState(() => _selectedPlanId = null);
  }

  Widget _buildActionToolbar(
    BuildContext context,
    WidgetRef ref,
    SubstitutionPlanViewModel viewModel,
    List<SubstitutionPlanData> planData,
  ) {
    // 교체 화면과 동일 스택 — 버전 변경 시 되돌리기/다시실행 활성 갱신
    ref.watch(exchangeListVersionProvider);
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final canUndo = historyService.canUndo;
    final canRedo = historyService.canRedo;

    final allIds = _allGroupIds(planData);
    final allSelected =
        allIds.isNotEmpty && _checkedGroupIds.containsAll(allIds);
    final hasSelection = _checkedGroupIds.isNotEmpty;

    return PlanGridActionToolbar(
      allSelected: allSelected,
      hasAnyGroup: allIds.isNotEmpty,
      hasSelection: hasSelection,
      canUndo: canUndo,
      canRedo: canRedo,
      onRefresh: () async {
        await viewModel.loadPlanData();
        if (!context.mounted) return;
        final currentPlanData = ref.read(
          substitutionPlanViewModelProvider.select((s) => s.planData),
        );
        ContentInputGridDebugger.printTable(currentPlanData);
        SnackBarHelper.showInfo(context, '표를 새로고침했습니다.');
      },
      onToggleSelectAll: () => _toggleSelectAll(planData),
      onDeleteSelected: () => _deleteSelectedExchanges(context, ref),
      onUndo: () => _runHistoryUndo(context, ref),
      onRedo: () => _runHistoryRedo(context, ref),
      onCopyTable: () => _copyTableToClipboard(context, ref),
      onPrint: () async {
        // 체크 상태가 디스크에 반영된 뒤 이동 (미리보기와 선택 일치 보장)
        await _persistSelectionToCurrentPlan();
        if (!context.mounted) return;
        navigateToPlanSubstitutionOutput(ref);
      },
    );
  }

  /// 교체 화면과 동일한 ExchangeExecutor 경로 (dataSource 없이도 셀·목록 동기화)
  ExchangeExecutor _historyExecutor(WidgetRef ref) {
    return ExchangeExecutor(ref: ref, dataSource: null);
  }

  /// 활성 교체에 없는 체크는 제거해 삭제·결보강 출력 오동작을 막는다
  void _pruneCheckedSelection(WidgetRef ref) {
    final activeIds =
        ref
            .read(exchangeHistoryServiceProvider)
            .getActiveExchangeList()
            .map((e) => e.id)
            .toSet();
    if (!mounted) return;
    setState(() {
      _checkedGroupIds.removeWhere((id) => !activeIds.contains(id));
    });
    unawaited(_persistSelectionToCurrentPlan());
  }

  Set<String> _activeExchangeIds(WidgetRef ref) {
    return ref
        .read(exchangeHistoryServiceProvider)
        .getActiveExchangeList()
        .map((e) => e.id)
        .toSet();
  }

  /// 되돌리기/다시실행 후: 복원된 행은 선택, 빠진 행은 선택 해제 후 계획서에 저장
  void _syncCheckedAfterHistory(
    WidgetRef ref, {
    required Set<String> activeBefore,
  }) {
    final activeAfter = _activeExchangeIds(ref);
    if (!mounted) return;
    setState(() {
      ContentInputGridPlanOps.syncCheckedWithActiveChange(
        checkedGroupIds: _checkedGroupIds,
        activeBefore: activeBefore,
        activeAfter: activeAfter,
      );
    });
    unawaited(_persistSelectionToCurrentPlan());
  }

  Future<void> _runHistoryUndo(BuildContext context, WidgetRef ref) async {
    final activeBefore = _activeExchangeIds(ref);
    await _historyExecutor(ref).undoLastExchange(context, () {});
    if (!mounted) return;
    _syncCheckedAfterHistory(ref, activeBefore: activeBefore);
  }

  Future<void> _runHistoryRedo(BuildContext context, WidgetRef ref) async {
    final activeBefore = _activeExchangeIds(ref);
    await _historyExecutor(ref).redoLastExchange(context);
    if (!mounted) return;
    _syncCheckedAfterHistory(ref, activeBefore: activeBefore);
  }

  /// 체크된 교체 건만 삭제 (계획서는 유지)
  ///
  /// 교체 화면의 선택 삭제와 동일하게 [removeFromExchangeList]만 호출한다.
  /// 보강 과목은 지우지 않는다 — 되돌리기로 항목이 복원될 때 입력값이 남아야 한다.
  /// 여러 건이면 undo 스택에 건별로 쌓이므로 되돌리기는 1건씩이다.
  Future<void> _deleteSelectedExchanges(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ids = _checkedGroupIds.toList();
    if (ids.isEmpty) return;

    final historyService = ref.read(exchangeHistoryServiceProvider);
    final activeIds =
        historyService.getActiveExchangeList().map((e) => e.id).toSet();
    final deletableIds = ids.where(activeIds.contains).toList();
    if (deletableIds.isEmpty) {
      if (context.mounted) {
        SnackBarHelper.showInfo(context, '삭제할 활성 교체가 없습니다.');
      }
      _pruneCheckedSelection(ref);
      return;
    }

    final confirmed = await DialogHelper.showConfirmDialog(
      context,
      title: '선택 삭제',
      message:
          '선택한 교체 ${deletableIds.length}건을 삭제하겠습니까?\n'
          '계획서는 그대로 둡니다.\n'
          '되돌리기로 1건씩 복원할 수 있습니다.',
      confirmText: '삭제',
      isDangerous: true,
    );
    if (confirmed != true || !context.mounted) return;

    // 교체 화면 deleteFromExchangeList와 동일한 서비스 API
    for (final id in deletableIds) {
      historyService.removeFromExchangeList(id);
    }

    ExchangeExecutor.restoreExchangedCells(ref);
    ref
        .read(stateResetProvider.notifier)
        .resetExchangeStates(reason: '선택 교체 삭제');

    if (!mounted) return;
    setState(() {
      _checkedGroupIds.clear();
      _selectionHydrated = false;
    });
    unawaited(_persistSelectionToCurrentPlan());

    if (context.mounted) {
      SnackBarHelper.showSuccess(
        context,
        '선택한 교체 ${deletableIds.length}건을 삭제했습니다.',
      );
    }
  }

  Widget _buildDataGrid(
    BuildContext context,
    WidgetRef ref,
    List<SubstitutionPlanData> planData,
    bool isLoading,
    SubstitutionPlanViewModel viewModel,
  ) {
    if (isLoading) {
      return const PlanGridLoadingIndicator();
    }

    if (planData.isEmpty) {
      return const PlanGridEmptyState();
    }

    return PlanGridDataTable(
      planData: planData,
      viewModel: viewModel,
      isGroupSelected: (groupId) => _checkedGroupIds.contains(groupId),
      onToggleGroupSelection: _toggleGroupSelection,
      profileOptionsForTeacher: _profileOptionsForTeacher,
      onCreateProfile: _createProfileForRow,
      selectedProfileIdForGroup: _selectedProfileIdForGroup,
      onProfileChanged: _onGroupProfileChanged,
      onAbsenceDateSelected: (date, planData) async {
        if (!mounted) return;
        await _renameSelectedPlanToAbsenceDate(date, planData);
      },
      horizontalScrollController: horizontalScrollController,
      verticalScrollController: verticalScrollController,
      wrapWithDragScroll: wrapWithDragScroll,
    );
  }

  /// 테이블 데이터를 엑셀 형식으로 클립보드에 복사
  ///
  /// 탭(\t)으로 구분하여 엑셀에서 붙여넣기 시 각 셀에 데이터가 자동으로 분리됩니다.
  Future<void> _copyTableToClipboard(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final planData = ref.read(
        substitutionPlanViewModelProvider.select((state) => state.planData),
      );

      if (planData.isEmpty) {
        if (context.mounted) {
          SnackBarHelper.showWarning(context, '복사할 데이터가 없습니다.');
        }
        return;
      }

      // 테이블 내용을 텍스트로 변환
      final tableText = _generateTableText(planData);

      // 클립보드에 복사
      await Clipboard.setData(ClipboardData(text: tableText));

      if (context.mounted) {
        SnackBarHelper.showSuccess(
          context,
          '${planData.length}개 행의 데이터가 클립보드에 복사되었습니다.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.showError(context, '복사 중 오류가 발생했습니다: $e');
      }
    }
  }

  /// 테이블 내용을 탭 구분 텍스트로 변환
  ///
  /// 엑셀에서 붙여넣기 시 각 셀에 자동으로 데이터가 분리됩니다.
  String _generateTableText(List<SubstitutionPlanData> data) {
    return ContentInputGridPlanOps.generateTableText(data);
  }
}

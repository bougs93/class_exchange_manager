import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../constants/korean_fonts.dart';
import '../../../../constants/screen_usage_hints.dart';
import 'package:flutter/services.dart';
import '../../../../models/plan_output_menu.dart';
import '../../../../models/print_profile.dart';
import '../../../../providers/plan_crud_actions_provider.dart';
import '../../../../providers/plan_output_menu_provider.dart';
import '../../../../providers/print_profile_provider.dart';
import '../../../../providers/selected_week_provider.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../../providers/services_provider.dart';
import '../../../../providers/state_reset_provider.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../ui/widgets/content_toolbar_layout.dart';
import '../../../../ui/widgets/content_usage_hint_bar.dart';
import '../../../../ui/widgets/empty_state_message.dart';
import '../../../../ui/widgets/timetable_grid/exchange_executor.dart';
import '../../../../ui/widgets/timetable_grid/grid_header_widgets.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/day_utils.dart';
import '../../../../utils/snackbar_helper.dart';
import '../../../../utils/dialog_helper.dart';
import '../../../mixins/scroll_management_mixin.dart';
import 'content_input_grid_helpers.dart';
import 'content_input_grid_plan_ops.dart';
import 'plan_date_picker_dialog.dart';
import 'substitution_plan_data_source.dart';

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

  @override
  void initState() {
    super.initState();
    // 공통 스크롤 관리 믹신 초기화
    initializeScrollControllers();
  }

  @override
  void dispose() {
    // 2열 헤더 CRUD 버튼 콜백 해제
    ref.read(planCrudActionsProvider.notifier).state = null;
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
          _buildActionButtons(context, ref, viewModel, planData),
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

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    SubstitutionPlanViewModel viewModel,
    List<SubstitutionPlanData> planData,
  ) {
    const buttonHeight = ContentToolbarLayout.buttonHeight;
    final tokens = context.tokens;
    // 교체 화면과 동일 스택 — 버전 변경 시 되돌리기/다시실행 활성 갱신
    ref.watch(exchangeListVersionProvider);
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final canUndo = historyService.canUndo;
    final canRedo = historyService.canRedo;

    final allIds = _allGroupIds(planData);
    final allSelected =
        allIds.isNotEmpty && _checkedGroupIds.containsAll(allIds);
    final hasSelection = _checkedGroupIds.isNotEmpty;

    return Row(
      children: [
        // 왼쪽: 새로고침 · 선택 · 삭제 · 되돌리기 · 다시실행
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                CompactToolbarIconButton(
                  onPressed: () async {
                    await viewModel.loadPlanData();
                    if (!context.mounted) return;
                    final currentPlanData = ref.read(
                      substitutionPlanViewModelProvider.select(
                        (s) => s.planData,
                      ),
                    );
                    ContentInputGridDebugger.printTable(currentPlanData);
                    SnackBarHelper.showInfo(context, '표를 새로고침했습니다.');
                  },
                  icon: Icons.refresh,
                  tooltip: '표 새로고침',
                  backgroundColor: ContentToolbarLayout.neutralButtonBackground(
                    tokens,
                  ),
                  foregroundColor: ContentToolbarLayout.neutralButtonForeground(
                    tokens,
                  ),
                  borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
                  iconSize: ContentToolbarLayout.buttonIconSize,
                  size: buttonHeight,
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                CompactToolbarLabelButton(
                  onPressed:
                      allIds.isEmpty ? null : () => _toggleSelectAll(planData),
                  icon: Icons.checklist,
                  label: allSelected ? '선택 해제' : '모두 선택',
                  tooltip: '결보강 출력에 포함할 교체 건을 선택/해제합니다',
                  backgroundColor: ContentToolbarLayout.neutralButtonBackground(
                    tokens,
                  ),
                  foregroundColor: ContentToolbarLayout.neutralButtonForeground(
                    tokens,
                  ),
                  borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
                  height: buttonHeight,
                  fontSize: ContentToolbarLayout.buttonFontSize,
                  iconSize: ContentToolbarLayout.buttonIconSize,
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                CompactToolbarLabelButton(
                  onPressed:
                      hasSelection
                          ? () => _deleteSelectedExchanges(context, ref)
                          : null,
                  icon: Icons.delete_outline,
                  label: '선택 삭제',
                  tooltip: '선택한 교체 건만 삭제합니다. 되돌리기로 1건씩 복원할 수 있습니다.',
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  borderColor: Colors.red.shade300,
                  height: buttonHeight,
                  fontSize: ContentToolbarLayout.buttonFontSize,
                  iconSize: ContentToolbarLayout.buttonIconSize,
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                CompactToolbarLabelButton(
                  onPressed:
                      canUndo ? () => _runHistoryUndo(context, ref) : null,
                  icon: Icons.undo,
                  label: '되돌리기',
                  tooltip: canUndo ? '되돌리기 (교체와 동일)' : '되돌리기 (불가)',
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.orange.shade700,
                  borderColor: Colors.orange.shade300,
                  height: buttonHeight,
                  fontSize: ContentToolbarLayout.buttonFontSize,
                  iconSize: ContentToolbarLayout.buttonIconSize,
                ),
                const SizedBox(width: ContentToolbarLayout.buttonGap),
                CompactToolbarLabelButton(
                  onPressed:
                      canRedo ? () => _runHistoryRedo(context, ref) : null,
                  icon: Icons.redo,
                  label: '다시실행',
                  tooltip: canRedo ? '다시 실행 (교체와 동일)' : '다시 실행 (불가)',
                  backgroundColor: Colors.purple.shade100,
                  foregroundColor: Colors.purple.shade700,
                  borderColor: Colors.purple.shade300,
                  height: buttonHeight,
                  fontSize: ContentToolbarLayout.buttonFontSize,
                  iconSize: ContentToolbarLayout.buttonIconSize,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: ContentToolbarLayout.buttonGap),
        // 오른쪽: 엑셀 복사 → 결보강 출력(맨 끝)
        CompactToolbarLabelButton(
          onPressed: () => _copyTableToClipboard(context, ref),
          icon: Icons.copy,
          label: '엑셀서식 복사',
          tooltip: '엑셀서식 복사',
          backgroundColor: ContentToolbarLayout.neutralButtonBackground(tokens),
          foregroundColor: ContentToolbarLayout.neutralButtonForeground(tokens),
          borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
          height: buttonHeight,
          fontSize: ContentToolbarLayout.buttonFontSize,
          iconSize: ContentToolbarLayout.buttonIconSize,
        ),
        const SizedBox(width: ContentToolbarLayout.buttonGap),
        CompactToolbarLabelButton(
          onPressed: () async {
            // 체크 상태가 디스크에 반영된 뒤 이동 (미리보기와 선택 일치 보장)
            await _persistSelectionToCurrentPlan();
            if (!context.mounted) return;
            navigateToPlanSubstitutionOutput(ref);
          },
          icon: Icons.print,
          label: '결보강 출력',
          tooltip: '체크한 교체 건만 결보강 출력에서 PDF 미리보기·인쇄',
          backgroundColor: Colors.purple.shade50,
          foregroundColor: Colors.purple.shade600,
          borderColor: Colors.purple.shade600,
          height: buttonHeight,
          fontSize: ContentToolbarLayout.buttonFontSize,
          iconSize: ContentToolbarLayout.buttonIconSize,
        ),
      ],
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

  void _runHistoryUndo(BuildContext context, WidgetRef ref) {
    _historyExecutor(ref).undoLastExchange(context, () {});
    _pruneCheckedSelection(ref);
  }

  void _runHistoryRedo(BuildContext context, WidgetRef ref) {
    _historyExecutor(ref).redoLastExchange(context);
    _pruneCheckedSelection(ref);
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
      return _buildLoadingIndicator();
    }

    if (planData.isEmpty) {
      return _buildEmptyState();
    }

    final dataSource = SubstitutionPlanDataSource(
      planData,
      onDateCellTap:
          (exchangeId, columnName) => _showDatePicker(
            context,
            ref,
            viewModel,
            exchangeId,
            columnName,
            planData,
          ),
      onSupplementSubjectTap:
          (exchangeId) => _showSubjectPickerDialog(
            context,
            ref,
            viewModel,
            exchangeId,
            planData,
          ),
      isSelected: (groupId) => _checkedGroupIds.contains(groupId),
      onToggleSelect: _toggleGroupSelection,
      profileOptions: _profileOptionsForTeacher,
      onCreateProfile: _createProfileForRow,
      selectedProfileId: _selectedProfileIdForGroup,
      onProfileChanged: _onGroupProfileChanged,
      groupWeeks: _buildGroupWeeks(ref),
    );

    return Expanded(
      child: wrapWithDragScroll(
        SfDataGrid(
          source: dataSource,
          columns: ContentInputGridConfig.getColumns(context.tokens),
          stackedHeaderRows: ContentInputGridConfig.getStackedHeaders(
            context.tokens,
          ),
          allowColumnsResizing: true,
          columnResizeMode: ColumnResizeMode.onResize,
          gridLinesVisibility: GridLinesVisibility.both,
          // 헤더 가로선은 컬럼 Container 테두리로만 표시 (비고 1·2행 사이 선 제거)
          headerGridLinesVisibility: GridLinesVisibility.vertical,
          selectionMode: SelectionMode.single,
          headerRowHeight: ContentInputGridConfig.headerRowHeight,
          rowHeight: 28,
          allowEditing: false,
          // 주차 그룹핑 (§10.8 6단계) — 캡션에는 _weekKey 값(원본 문자열)만 전달
          allowExpandCollapseGroup: true,
          groupCaptionTitleFormat: '{Key}',
          // 교체 관리 시간표와 동일한 스크롤 컨트롤러 적용 (공통 믹신 사용)
          horizontalScrollController: horizontalScrollController,
          verticalScrollController: verticalScrollController,
        ),
      ),
    );
  }

  /// 교체 건(groupId) → 소속 주(週)의 월요일. 그 주 안에서 반복 조회하지
  /// 않도록 그리드 빌드 시점에 한 번만 만든다.
  Map<String, DateTime> _buildGroupWeeks(WidgetRef ref) {
    final history = ref.read(exchangeHistoryServiceProvider).getExchangeList();
    return {for (final item in history) item.id: item.weekMonday};
  }

  Widget _buildLoadingIndicator() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.tokens.cardBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.tokens.cardBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: EmptyStateMessage(
            icon: Icons.description_outlined,
            iconSize: 50,
            message: '교체 기록이 없습니다',
            messageFontSize: 18,
            messageFontWeight: FontWeight.w500,
            subMessage: '교체를 실행하면 여기에 기록이 표시됩니다',
            expand: false,
          ),
        ),
      ),
    );
  }

  /// 과목 선택 다이얼로그 표시
  Future<void> _showSubjectPickerDialog(
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

  Future<void> _showDatePicker(
    BuildContext context,
    WidgetRef ref,
    SubstitutionPlanViewModel viewModel,
    String exchangeId,
    String columnName,
    List<SubstitutionPlanData> planData,
  ) async {
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
          columnName == 'absenceDate'
              ? data.absenceDate
              : data.substitutionDate;
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
            !_isTargetWeekday(selectedDate, targetWeekday)) {
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
        final saved = await _applyDateSelection(
          context,
          data,
          columnName,
          selectedDate,
        );
        if (!saved) return;

        // 결강일 선택 → 현재 계획서 이름을 "결보강 YY.MM.DD"로 (여러 건이면 마지막 선택이 기준)
        if (columnName == 'absenceDate' && mounted) {
          await _renameSelectedPlanToAbsenceDate(selectedDate, planData);
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
  Future<bool> _applyDateSelection(
    BuildContext context,
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

  bool _isTargetWeekday(DateTime date, String targetWeekday) {
    return ContentInputGridPlanOps.isTargetWeekday(date, targetWeekday);
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

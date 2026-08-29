import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../constants/korean_fonts.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/services.dart';
import '../../../../constants/screen_usage_hints.dart';
import '../../../../models/plan_output_menu.dart';
import '../../../../models/print_profile.dart';
import '../../../../providers/plan_output_menu_provider.dart';
import '../../../../providers/print_profile_provider.dart';
import '../../../../providers/substitution_plan_provider.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../../providers/services_provider.dart';
import '../../../../providers/state_reset_provider.dart';
import '../../../../providers/timetable_registry_provider.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../ui/widgets/content_toolbar_layout.dart';
import '../../../../ui/widgets/content_usage_hint_bar.dart';
import '../../../../ui/widgets/empty_state_message.dart';
import '../../../../ui/widgets/timetable_grid/exchange_executor.dart';
import '../../../../ui/widgets/timetable_grid/grid_header_widgets.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/snackbar_helper.dart';
import '../../../../utils/dialog_helper.dart';
import '../../../mixins/scroll_management_mixin.dart';
import 'content_input_grid_helpers.dart';

/// 보강계획서 데이터 소스
class SubstitutionPlanDataSource extends DataGridSource {
  final List<SubstitutionPlanData> planData;
  final Function(String, String)? onDateCellTap;
  final Function(String)? onSupplementSubjectTap;

  /// 그룹(교체 건) 선택 상태 조회
  final bool Function(String groupId)? isSelected;

  /// 그룹 선택 토글
  final ValueChanged<String>? onToggleSelect;

  /// 행 교사의 계획서 목록 조회
  final List<PrintProfile> Function(String teacher)? profileOptions;

  /// 행 드롭다운의 '＋ 새 계획서…' 선택 콜백
  final void Function(String groupId, String teacher)? onCreateProfile;

  /// 그룹의 지정 계획서 ID 조회
  final String? Function(String groupId)? selectedProfileId;

  /// 계획서 지정 변경
  final Function(String groupId, String? profileId)? onProfileChanged;

  SubstitutionPlanDataSource(
    this.planData, {
    this.onDateCellTap,
    this.onSupplementSubjectTap,
    this.isSelected,
    this.onToggleSelect,
    this.profileOptions,
    this.onCreateProfile,
    this.selectedProfileId,
    this.onProfileChanged,
  });

  @override
  List<DataGridRow> get rows =>
      planData.map<DataGridRow>((data) {
        return DataGridRow(
          cells: [
            // exchangeId를 첫 번째 숨김 컬럼으로 추가
            DataGridCell<String>(
              columnName: '_exchangeId',
              value: data.exchangeId,
            ),
            // groupId (교체 건 ID) 숨김 컬럼 — 선택·계획서 지정은 그룹 단위
            DataGridCell<String>(
              columnName: '_groupId',
              value: data.groupId ?? '',
            ),
            DataGridCell<String>(
              columnName: 'absenceDate',
              value: data.absenceDate,
            ),
            DataGridCell<String>(
              columnName: 'absenceDay',
              value: data.absenceDay,
            ),
            DataGridCell<String>(columnName: 'period', value: data.period),
            DataGridCell<String>(columnName: 'grade', value: data.grade),
            DataGridCell<String>(
              columnName: 'className',
              value: data.className,
            ),
            DataGridCell<String>(columnName: 'subject', value: data.subject),
            DataGridCell<String>(columnName: 'teacher', value: data.teacher),
            DataGridCell<String>(
              columnName: 'supplementSubject',
              value: data.supplementSubject,
            ),
            DataGridCell<String>(
              columnName: 'supplementTeacher',
              value: data.supplementTeacher,
            ),
            DataGridCell<String>(
              columnName: 'substitutionDate',
              value: data.substitutionDate,
            ),
            DataGridCell<String>(
              columnName: 'substitutionDay',
              value: data.substitutionDay,
            ),
            DataGridCell<String>(
              columnName: 'substitutionPeriod',
              value: data.substitutionPeriod,
            ),
            DataGridCell<String>(
              columnName: 'substitutionSubject',
              value: data.substitutionSubject,
            ),
            DataGridCell<String>(
              columnName: 'substitutionTeacher',
              value: data.substitutionTeacher,
            ),
            DataGridCell<String>(columnName: 'remarks', value: data.remarks),
          ],
        );
      }).toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final selectCell = CellRendererFactory.build(
      row.getCells().firstWhere(
        (c) => c.columnName == 'select',
        orElse:
            () => const DataGridCell<String>(columnName: 'select', value: ''),
      ),
      row,
      isSelected: isSelected,
      onToggleSelect: onToggleSelect,
      profileOptions: profileOptions,
      onCreateProfile: onCreateProfile,
      selectedProfileId: selectedProfileId,
      onProfileChanged: onProfileChanged,
    );

    // exchangeId·groupId 컬럼을 제외한 나머지 셀들만 렌더링
    final cells =
        row
            .getCells()
            .where(
              (cell) =>
                  cell.columnName != '_exchangeId' &&
                  cell.columnName != '_groupId' &&
                  cell.columnName != 'select' &&
                  cell.columnName != 'profile',
            )
            .map<Widget>((cell) {
              return CellRendererFactory.build(
                cell,
                row,
                onDateCellTap: onDateCellTap,
                onSupplementSubjectTap: onSupplementSubjectTap,
              );
            })
            .toList();

    return DataGridRowAdapter(cells: [selectCell, ...cells]);
  }
}

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
    // 공통 스크롤 관리 믹신 해제
    disposeScrollControllers();
    super.dispose();
  }

  /// 그룹(교체 건)의 지정 계획서 ID 조회 (삭제된 계획서면 null → 미지정)
  String? _selectedProfileIdForGroup(String groupId) {
    final item =
        ref
            .read(exchangeHistoryServiceProvider)
            .getExchangeList()
            .where((h) => h.id == groupId)
            .firstOrNull;
    if (item == null) return null;
    final store = ref.read(printProfileStoreProvider);
    return store.getById(item.profileId)?.id;
  }

  /// 행 교사의 계획서 목록
  List<PrintProfile> _profileOptionsForTeacher(String teacher) {
    return ref.read(printProfileStoreProvider).byTeacher(teacher);
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
    return planData
        .map((d) => d.groupId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// 상단 드롭다운에 표시할 현재 계획서 ID (저장된 계획서만, 없으면 null)
  String? _resolveSelectedPlanId(
    PrintProfileStore store,
    List<SubstitutionPlanData> planData,
  ) {
    // 삭제된 ID가 _selectedPlanId에 남아 있으면 무시
    if (_selectedPlanId != null &&
        _selectedPlanId != '__default__' &&
        store.profiles.any((p) => p.id == _selectedPlanId)) {
      return _selectedPlanId;
    }
    if (store.profiles.any((p) => p.id == store.lastUsedProfileId)) {
      return store.lastUsedProfileId;
    }
    if (store.profiles.isNotEmpty) return store.profiles.first.id;
    // 저장된 계획서가 없으면 null — 결강일 기반 임시 이름을 계획서처럼 보여주지 않음
    return null;
  }

  PrintProfile? _currentProfile(PrintProfileStore store) {
    final id = _selectedPlanId ?? store.lastUsedProfileId;
    if (id == null || id == '__default__') return null;
    return store.getById(id);
  }

  /// 계획서의 제외 목록 → 체크 UI 반영 (기본: 모두 선택)
  void _hydrateSelectionFromPlan(
    PrintProfileStore store,
    List<SubstitutionPlanData> planData,
  ) {
    final allIds = _allGroupIds(planData);
    final profile = _currentProfile(store);
    final deselected = profile?.deselectedGroupIds.toSet() ?? const <String>{};

    final next = allIds.where((id) => !deselected.contains(id)).toSet();
    final same =
        next.length == _checkedGroupIds.length &&
        next.containsAll(_checkedGroupIds);
    if (same && _selectionHydrated) return;

    _checkedGroupIds
      ..clear()
      ..addAll(next);
    _selectionHydrated = true;
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
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
    final prepared = ref.read(activeTeacherNameProvider).trim();
    if (prepared.isNotEmpty) return prepared;
    if (planData.isNotEmpty && planData.first.teacher.trim().isNotEmpty) {
      return planData.first.teacher.trim();
    }
    return '';
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
    // 이름만 바꾼 뒤에도 교사 귀속을 한 번 더 맞춤
    final synced = await _ensurePlanExists(planData, nameHint: name);
    if (!mounted) return;
    setState(() => _selectedPlanId = (synced ?? profile).id);
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
    if (resolvedId != null &&
        resolvedId != '__default__' &&
        _selectedPlanId != resolvedId &&
        _selectedPlanId == null) {
      _selectedPlanId = resolvedId;
    }
    _hydrateSelectionFromPlan(store, planData);

    // 현재 계획서 교사 귀속이 준비 교사와 다르면 보정 (결보강 출력 목록 누락 방지)
    ref.listen<String>(activeTeacherNameProvider, (previous, next) {
      if (next.trim().isEmpty || next == previous) return;
      unawaited(_ensurePlanExists(planData));
    });

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentUsageHintBar(
            message: ScreenUsageHints.contentInput,
            accentColor:
                context.tokens.monochromeMenuAccents
                    ? context.tokens.primary
                    : PlanOutputMenu.contentInput.color,
          ),
          ContentToolbarLayout.hintToToolbarSpacer,
          _buildPlanManagementBar(planData),
          const SizedBox(height: 8),
          _buildActionButtons(context, ref, viewModel, planData),
          const SizedBox(height: 10),
          _buildDataGrid(context, ref, planData, isLoading, viewModel),
        ],
      ),
    );
  }

  Widget _buildPlanManagementBar(List<SubstitutionPlanData> planData) {
    final store = ref.watch(printProfileStoreProvider);
    final profiles = store.profiles;
    final selectedId = _resolveSelectedPlanId(store, planData);
    final selectedProfile = store.getById(selectedId);
    final hasSavedPlans = profiles.isNotEmpty;

    return Row(
      children: [
        const Text('계획서 이름 :', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        SizedBox(
          width: 190,
          height: 34,
          // 항목 0개인 DropdownButtonFormField는 레이아웃 예외를 낼 수 있어
          // 저장된 계획서가 없을 때는 단순 표시 위젯을 씁니다.
          child:
              hasSavedPlans
                  ? DropdownButtonFormField<String>(
                    key: ValueKey(
                      'plan-dd-${selectedId ?? 'none'}-${selectedProfile?.name ?? 'empty'}-${profiles.length}',
                    ),
                    initialValue: selectedId,
                    isDense: true,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    items: [
                      for (final profile in profiles)
                        DropdownMenuItem<String>(
                          value: profile.id,
                          child: Text(
                            profile.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      setState(() {
                        _selectedPlanId = id;
                        _selectionHydrated = false;
                      });
                      _applyPlanToAllRows(id, planData);
                      unawaited(
                        ref
                            .read(printProfileStoreProvider.notifier)
                            .setLastUsedProfile(id),
                      );
                      _hydrateSelectionFromPlan(
                        ref.read(printProfileStoreProvider),
                        planData,
                      );
                      setState(() {});
                    },
                  )
                  : InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      '계획서 없음',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.tokens.textMuted,
                      ),
                    ),
                  ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed:
              planData.isEmpty ? null : () => _createPlanFromFirstRow(planData),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('새 계획서'),
        ),
        TextButton(
          onPressed:
              selectedProfile == null
                  ? null
                  : () => _renamePlan(selectedProfile.id, planData),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('수정'),
        ),
        TextButton(
          onPressed:
              selectedProfile == null
                  ? null
                  : () => _deletePlan(selectedProfile.id),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('삭제'),
        ),
      ],
    );
  }

  String _defaultPlanName(List<SubstitutionPlanData> planData) {
    if (planData.isEmpty ||
        planData.first.absenceDate.isEmpty ||
        planData.first.absenceDate == '선택') {
      return '결보강';
    }
    return DateFormatUtils.toSubstitutionPlanNameFromStored(
      planData.first.absenceDate,
    );
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
      ref.read(printProfileStoreProvider.notifier).setLastUsedProfile(profileId),
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
      message: '선택한 계획서를 삭제하시겠습니까?',
      confirmText: '삭제',
      isDangerous: true,
    );
    if (confirmed != true) return;
    await ref.read(printProfileStoreProvider.notifier).deleteProfile(profileId);
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

    return Row(
      children: [
        // 왼쪽: 새로고침·초기화 버튼 (가로 스크롤 가능)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                CompactToolbarIconButton(
                  onPressed: () async {
                    await viewModel.loadPlanData();
                    final currentPlanData = ref.read(
                      substitutionPlanViewModelProvider.select(
                        (state) => state.planData,
                      ),
                    );
                    ContentInputGridDebugger.printTable(currentPlanData);
                  },
                  icon: Icons.refresh,
                  tooltip: '새로고침',
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
                  onPressed: () => _toggleSelectAll(planData),
                  icon: Icons.checklist,
                  label: _checkedGroupIds.isNotEmpty ? '선택 해제' : '전체선택',
                  tooltip: '일괄 출력 대상 전체 선택/해제',
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
                  onPressed: () => _clearAllDates(context, viewModel),
                  icon: Icons.clear,
                  label: '날짜 초기화',
                  tooltip: '날짜 초기화',
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
                  onPressed: () => _showDeleteConfirmDialog(context, ref),
                  icon: Icons.clear,
                  label: '결보강 초기화',
                  tooltip: '결보강 전체 초기화',
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
              ],
            ),
          ),
        ),
        const SizedBox(width: ContentToolbarLayout.buttonGap),
        // 오른쪽: 결보강 출력 이동 + 엑셀서식 복사
        CompactToolbarLabelButton(
          onPressed: () => navigateToPlanSubstitutionOutput(ref),
          icon: Icons.print,
          label: '결보강 출력',
          tooltip: '결보강 출력으로 이동하여 PDF 미리보기·인쇄',
          backgroundColor: Colors.purple.shade50,
          foregroundColor: Colors.purple.shade600,
          borderColor: Colors.purple.shade600,
          height: buttonHeight,
          fontSize: ContentToolbarLayout.buttonFontSize,
          iconSize: ContentToolbarLayout.buttonIconSize,
        ),
        const SizedBox(width: ContentToolbarLayout.buttonGap),
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
      ],
    );
  }

  /// 삭제 확인 다이얼로그 표시
  ///
  /// 사용자에게 삭제 확인을 받고, 확인 시 교체 리스트를 삭제합니다.
  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await DialogHelper.showConfirmDialog(
      context,
      title: '결보강 전체 초기화',
      message: '결보강을 전체 초기화하겠습니까?\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '초기화',
      isDangerous: true,
    );

    if (confirmed == true && context.mounted) {
      _deleteExchangeList(context, ref);
    }
  }

  /// 교체 리스트 삭제 실행
  ///
  /// ExchangeHistoryService를 통해 전체 교체 리스트를 삭제하고,
  /// UI 상태를 초기화합니다.
  ///
  /// 주의: 교체 뷰 상태는 유지됩니다 (비활성화하지 않음).
  void _deleteExchangeList(BuildContext context, WidgetRef ref) {
    try {
      // 1. 교체 리스트 전체 삭제
      final historyService = ref.read(exchangeHistoryServiceProvider);
      historyService.clearExchangeList();

      // 2. 저장된 결강일·교체일·보강 과목 정보 삭제
      ref.read(substitutionPlanProvider.notifier).clearAllDates();

      // 3. 교체된 셀 상태 업데이트 (빈 리스트로 갱신하여 교체된 셀 스타일 제거)
      ExchangeExecutor.restoreExchangedCells(ref);

      // 4. UI 상태 초기화 (선택된 경로, 캐시, 화살표 등)
      ref
          .read(stateResetProvider.notifier)
          .resetExchangeStates(reason: '교체목록 전체 초기화');

      // 5. 선택 상태 초기화 (삭제된 교체 건 참조 제거)
      _checkedGroupIds.clear();
      _selectionHydrated = false;

      // 6. 보강계획서 데이터 자동 새로고침
      final viewModel = ref.read(substitutionPlanViewModelProvider.notifier);
      viewModel.loadPlanData();

      // 7. 성공 메시지 표시
      SnackBarHelper.showSuccess(context, '교체목록이 초기화되었습니다.');
    } catch (e) {
      // 오류 메시지 표시
      SnackBarHelper.showError(context, '초기화 중 오류가 발생했습니다: $e');
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
          // 교체 관리 시간표와 동일한 스크롤 컨트롤러 적용 (공통 믹신 사용)
          horizontalScrollController: horizontalScrollController,
          verticalScrollController: verticalScrollController,
        ),
      ),
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('행 정보를 찾을 수 없습니다.')));
      return;
    }

    final String teacherName =
        (rowData.supplementTeacher.isNotEmpty)
            ? rowData.supplementTeacher
            : rowData.teacher;

    if (teacherName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('교사 정보를 찾을 수 없습니다.')));
      return;
    }

    // 2) 전역 시간표에서 해당 교사가 실제로 가르친 과목 목록 추출
    final timetableData = ref.read(exchangeScreenProvider).timetableData;
    if (timetableData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시간표 데이터가 없어 과목을 불러올 수 없습니다.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('교사 "$teacherName"의 과목 정보를 찾지 못했습니다.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('보강 과목이 "$selected"(으)로 설정되었습니다.')),
      );
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

      // 날짜 선택기 표시
      final selectedDates = await showCalendarDatePicker2Dialog(
        context: context,
        config: CalendarDatePicker2WithActionButtonsConfig(
          calendarType: CalendarDatePicker2Type.single,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          currentDate: initialDate,
          weekdayLabels: ['일', '월', '화', '수', '목', '금', '토'],
          selectableDayPredicate:
              targetWeekday.isNotEmpty
                  ? (date) => _isTargetWeekday(date, targetWeekday)
                  : null,
          selectedDayHighlightColor: context.tokens.primary,
          okButton: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.tokens.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('확인', style: TextStyle(color: Colors.white)),
          ),
          cancelButton: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.tokens.cardBorder,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '취소',
              style: TextStyle(color: context.tokens.textSecondary),
            ),
          ),
        ),
        dialogSize: const Size(350, 360),
        borderRadius: BorderRadius.circular(5),
        value: [initialDate],
      );

      AppLogger.exchangeDebug('선택 결과: $selectedDates');

      final selectedDate =
          selectedDates?.isNotEmpty == true ? selectedDates!.first : null;

      if (selectedDate != null) {
        if (targetWeekday.isNotEmpty &&
            !_isTargetWeekday(selectedDate, targetWeekday)) {
          AppLogger.warning(
            '요일 불일치 - 선택: ${selectedDate.weekday}, 대상: $targetWeekday',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$targetWeekday요일이 아닌 날짜는 선택할 수 없습니다.'),
                backgroundColor: Colors.red.shade600,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // 년.월.일 형식으로 저장 (내부 저장용)
        final formattedDate = DateFormatUtils.toYearMonthDay(selectedDate);
        AppLogger.exchangeInfo('날짜 업데이트: $formattedDate');
        viewModel.updateDate(exchangeId, columnName, formattedDate);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('날짜 선택 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  bool _isTargetWeekday(DateTime date, String targetWeekday) {
    const weekdayMap = {'일': 0, '월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6};
    final targetWeekdayNumber = weekdayMap[targetWeekday];
    if (targetWeekdayNumber == null) return true;

    final dateWeekday = date.weekday == 7 ? 0 : date.weekday;
    return dateWeekday == targetWeekdayNumber;
  }

  Future<void> _clearAllDates(
    BuildContext context,
    SubstitutionPlanViewModel viewModel,
  ) async {
    final confirmed = await DialogHelper.showConfirmDialog(
      context,
      title: '날짜 초기화',
      message: '입력한 모든 날짜 정보와 과목 선택을 초기화하겠습니까?\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '초기화',
      isDangerous: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        viewModel.clearAllDates();
        if (context.mounted) {
          SnackBarHelper.showSuccess(context, '모든 날짜 정보와 과목 선택이 초기화되었습니다.');
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarHelper.showError(context, '초기화 중 오류가 발생했습니다: $e');
        }
      }
    }
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('복사할 데이터가 없습니다.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 테이블 내용을 텍스트로 변환
      final tableText = _generateTableText(planData);

      // 클립보드에 복사
      await Clipboard.setData(ClipboardData(text: tableText));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${planData.length}개 행의 데이터가 클립보드에 복사되었습니다.'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('복사 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 테이블 내용을 탭 구분 텍스트로 변환
  ///
  /// 엑셀에서 붙여넣기 시 각 셀에 자동으로 데이터가 분리됩니다.
  String _generateTableText(List<SubstitutionPlanData> data) {
    final buffer = StringBuffer();

    // 헤더 행 (탭으로 구분)
    const headers = [
      '결강일',
      '교시',
      '학년',
      '반',
      '과목',
      '교사',
      '보강/수업변경 과목',
      '보강/수업변경 성명',
      '교체일',
      '교체 교시',
      '교체 과목',
      '교체 교사',
      '비고',
    ];
    buffer.writeln(headers.join('\t'));

    // 데이터 행
    for (final row in data) {
      final cells = [
        '${DateFormatUtils.toMonthDay(row.absenceDate)}(${row.absenceDay})', // 결강일(요일) - 월.일 형식
        row.period, // 교시
        row.grade, // 학년
        row.className, // 반
        row.subject, // 과목 (결강)
        row.teacher, // 교사 (결강)
        row.supplementSubject, // 보강/수업변경 과목
        row.supplementTeacher, // 보강/수업변경 성명
        '${DateFormatUtils.toMonthDay(row.substitutionDate)}(${row.substitutionDay})', // 교체일(교체 요일) - 월.일 형식
        row.substitutionPeriod, // 교체 교시
        row.substitutionSubject, // 교체 과목
        row.substitutionTeacher, // 교체 교사
        row.remarks, // 비고
      ];
      buffer.writeln(cells.join('\t'));
    }

    return buffer.toString();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../constants/korean_fonts.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/services.dart';
import '../../../../constants/screen_usage_hints.dart';
import '../../../../models/plan_output_menu.dart';
import '../../../../models/print_profile.dart';
import '../../../../providers/print_profile_provider.dart';
import '../../../../providers/substitution_plan_provider.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../../providers/services_provider.dart';
import '../../../../providers/state_reset_provider.dart';
import '../../../../services/batch_pdf_export_service.dart';
import 'batch_export_progress_dialog.dart';
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
  /// 일괄 출력 선택 상태 (그룹 = 교체 건 ID 기준)
  final Set<String> _checkedGroupIds = {};
  String? _selectedPlanId;

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

  /// 그룹 선택 토글
  void _toggleGroupSelection(String groupId) {
    setState(() {
      if (_checkedGroupIds.contains(groupId)) {
        _checkedGroupIds.remove(groupId);
      } else {
        _checkedGroupIds.add(groupId);
      }
    });
  }

  /// 전체 선택/해제 토글
  void _toggleSelectAll(List<SubstitutionPlanData> planData) {
    final allGroupIds =
        planData
            .map((d) => d.groupId)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();

    setState(() {
      if (_checkedGroupIds.containsAll(allGroupIds) && allGroupIds.isNotEmpty) {
        _checkedGroupIds.clear();
      } else {
        _checkedGroupIds.addAll(allGroupIds);
      }
    });
  }

  /// 행 드롭다운에서 새 계획서 만들기
  ///
  /// 계획서가 0개인 교사 행에서 결보강 출력 탭까지 왕복하지 않도록,
  /// 그 자리에서 만들고 해당 행에 즉시 지정합니다(문서 §3④).
  Future<void> _createProfileForRow(String groupId, String teacher) async {
    if (teacher.isEmpty) return;

    final store = ref.read(printProfileStoreProvider);
    final defaultName = '계획서${store.byTeacher(teacher).length + 1}';
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

  /// 현재 planData에 실제로 존재하는 선택 그룹 수 (삭제된 그룹 카운트 제외)
  int _validCheckedCount(List<SubstitutionPlanData> planData) {
    final validGroupIds =
        planData.map((d) => d.groupId).whereType<String>().toSet();
    return _checkedGroupIds.where(validGroupIds.contains).length;
  }

  /// 선택 건 일괄 출력
  Future<void> _batchPrint(
    BuildContext context,
    WidgetRef ref,
    List<SubstitutionPlanData> planData,
  ) async {
    if (_checkedGroupIds.isEmpty) {
      SnackBarHelper.showError(context, '출력할 교체 건을 선택하세요.');
      return;
    }

    // 1. 요청 구성 (그룹별 행 수집 + 지정 계획서 조회)
    final history = ref.read(exchangeHistoryServiceProvider).getExchangeList();
    final store = ref.read(printProfileStoreProvider);
    final items = <BatchExportItem>[];

    for (final groupId in _checkedGroupIds) {
      final rows = planData.where((d) => d.groupId == groupId).toList();
      if (rows.isEmpty) continue;

      final exchangeItem = history.where((h) => h.id == groupId).firstOrNull;
      final profile = store.getById(exchangeItem?.profileId);

      items.add(BatchExportItem(itemId: groupId, rows: rows, profile: profile));
    }

    if (items.isEmpty) {
      SnackBarHelper.showError(context, '출력 가능한 교체 건이 없습니다.');
      return;
    }

    // 2. 저장 폴더 선택 (1회)
    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: 'PDF 저장 폴더 선택',
    );
    if (directory == null || !context.mounted) return;

    // 3. 일괄 출력 실행 (진행률 + 취소)
    final progressController =
        StreamController<BatchExportProgress>.broadcast();
    bool cancelRequested = false;

    // ignore: use_build_context_synchronously
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => BatchExportProgressDialog(
              initialTotal: items.length,
              progressStream: progressController.stream,
              onCancel: () => cancelRequested = true,
            ),
      ),
    );

    BatchPdfExportResult result;
    try {
      result = await BatchPdfExportService().exportAll(
        items: items,
        outputDirectory: directory,
        onProgress: (done, total, fileName) {
          if (!progressController.isClosed) {
            progressController.add(
              BatchExportProgress(done: done, total: total, fileName: fileName),
            );
          }
        },
        isCancelled: () => cancelRequested,
      );
    } catch (e) {
      // 설정 로드 등에서 실패해도 진행 다이얼로그가 남지 않도록 한다
      AppLogger.error('일괄 출력 중 오류: $e', e);
      result = BatchPdfExportResult(
        successCount: 0,
        totalCount: items.length,
        errors: ['일괄 출력을 시작하지 못했습니다: $e'],
      );
    } finally {
      await progressController.close();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!context.mounted) return;

    // 4. 결과 다이얼로그
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('일괄 출력 완료'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.allSucceeded
                      ? '${result.successCount}/${result.totalCount}건 출력 성공'
                      : [
                        '${result.successCount}/${result.totalCount}건 성공',
                        if (result.errors.isNotEmpty)
                          '${result.errors.length}건 실패',
                        if (result.cancelledCount > 0)
                          '${result.cancelledCount}건 취소됨',
                      ].join(', '),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: result.allSucceeded ? Colors.green : Colors.orange,
                  ),
                ),
                if (result.errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('실패 내역:', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            result.errors
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      e,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
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
    final viewModel = ref.read(substitutionPlanViewModelProvider.notifier);

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
    final selectedId = profiles.any((p) => p.id == _selectedPlanId)
        ? _selectedPlanId
        : (profiles.any((p) => p.id == store.lastUsedProfileId)
            ? store.lastUsedProfileId
            : null);
    final defaultName = _defaultPlanName(planData);

    return Row(
      children: [
        const Text('계획서 이름 :', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            value: selectedId,
            isDense: true,
            decoration: InputDecoration(
              hintText: defaultName,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final profile in profiles)
                DropdownMenuItem<String>(
                  value: profile.id,
                  child: Text(profile.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              setState(() => _selectedPlanId = id);
              _applyPlanToAllRows(id, planData);
            },
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: planData.isEmpty
              ? null
              : () => _createPlanFromFirstRow(planData),
          child: const Text('새 계획서'),
        ),
        TextButton(
          onPressed: selectedId == null ? null : () => _renamePlan(selectedId),
          child: const Text('수정'),
        ),
        TextButton(
          onPressed: selectedId == null ? null : () => _deletePlan(selectedId),
          child: const Text('삭제'),
        ),
      ],
    );
  }

  String _defaultPlanName(List<SubstitutionPlanData> planData) {
    if (planData.isEmpty || planData.first.absenceDate.isEmpty) {
      return '계획서';
    }
    final date = planData.first.absenceDate.replaceAll('-', '.');
    return date.split('.').length == 2
        ? '${DateTime.now().year.toString().substring(2)}.$date'
        : date;
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
    await _createProfileForRow(first.groupId!, first.teacher);
  }

  Future<void> _renamePlan(String profileId) async {
    final profile = ref.read(printProfileStoreProvider).getById(profileId);
    if (profile == null || !mounted) return;
    final controller = TextEditingController(text: profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('계획서 이름 수정'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(printProfileStoreProvider.notifier).renameProfile(profileId, name);
  }

  Future<void> _deletePlan(String profileId) async {
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
        // 오른쪽: 일괄 출력 + 엑셀서식 복사
        CompactToolbarLabelButton(
          onPressed:
              _checkedGroupIds.isEmpty
                  ? null
                  : () => _batchPrint(context, ref, planData),
          icon: Icons.print,
          label: '${_validCheckedCount(planData)}건 일괄 출력',
          tooltip: '선택한 교체 건을 지정된 계획서로 일괄 PDF 출력',
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

      // 5. 일괄 출력 선택 상태 초기화 (삭제된 교체 건 참조 제거)
      _checkedGroupIds.clear();

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

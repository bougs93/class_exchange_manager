import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../constants/screen_usage_hints.dart';
import '../../../../models/plan_output_menu.dart';
import '../../../../models/print_profile.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../../providers/plan_output_menu_provider.dart';
import '../../../../providers/print_profile_provider.dart';
import '../../../../providers/services_provider.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../providers/timetable_registry_provider.dart';
import '../../../../services/substitution_backup_service.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../utils/dialog_helper.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/snackbar_helper.dart';
import '../../../widgets/content_toolbar_layout.dart';
import '../../../widgets/content_usage_hint_bar.dart';
import '../../../widgets/timetable_grid/exchange_executor.dart';
import '../../../widgets/timetable_grid/grid_header_widgets.dart';
import 'plan_backup/backup_plan_list_pane.dart';
import 'plan_backup/backup_teacher_list_pane.dart';
import 'plan_backup/plan_backup_io.dart';

/// 계획서 > 백업 — 결강 교사 · 계획서 선택 후 내보내기/가져오기
class PlanBackupScreen extends ConsumerStatefulWidget {
  const PlanBackupScreen({super.key});

  @override
  ConsumerState<PlanBackupScreen> createState() => _PlanBackupScreenState();
}

class _PlanBackupScreenState extends ConsumerState<PlanBackupScreen> {
  String? _selectedTeacher;
  String? _selectedProfileId;

  /// planData의 결강 교사명만 (중복 제거 · 가나다순)
  List<String> _absenceTeachers(List<SubstitutionPlanData> planData) {
    final names =
        planData
            .map((row) => row.teacher.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return names;
  }

  void _ensureSelection(List<String> teachers, PrintProfileStore store) {
    if (teachers.isEmpty) {
      if (_selectedTeacher != null || _selectedProfileId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _selectedTeacher = null;
            _selectedProfileId = null;
          });
        });
      }
      return;
    }

    var teacher = _selectedTeacher;
    if (teacher == null || !teachers.contains(teacher)) {
      final lastUsed = store.getById(store.lastUsedProfileId);
      final lastTeacher = lastUsed?.teacherName.trim();
      teacher =
          (lastTeacher != null && teachers.contains(lastTeacher))
              ? lastTeacher
              : teachers.first;
    }

    final profiles = store.byTeacher(teacher);
    String? profileId = _selectedProfileId;
    if (profileId == null || !profiles.any((p) => p.id == profileId)) {
      final lastUsed = store.getById(store.lastUsedProfileId);
      profileId =
          (lastUsed != null && profiles.any((p) => p.id == lastUsed.id))
              ? lastUsed.id
              : (profiles.isNotEmpty ? profiles.first.id : null);
    }

    if (teacher == _selectedTeacher && profileId == _selectedProfileId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedTeacher = teacher;
        _selectedProfileId = profileId;
      });
    });
  }

  Future<void> _selectTeacher(String teacher) async {
    final store = ref.read(printProfileStoreProvider);
    final profiles = store.byTeacher(teacher);
    final lastUsed = store.getById(store.lastUsedProfileId);
    final profileId =
        (lastUsed != null && profiles.any((p) => p.id == lastUsed.id))
            ? lastUsed.id
            : (profiles.isNotEmpty ? profiles.first.id : null);

    setState(() {
      _selectedTeacher = teacher;
      _selectedProfileId = profileId;
    });

    await ref
        .read(printProfileStoreProvider.notifier)
        .setLastSelectedTeacher(teacher);
    if (profileId != null) {
      await ref
          .read(printProfileStoreProvider.notifier)
          .setLastUsedProfile(profileId);
    }
  }

  Future<void> _selectProfile(PrintProfile profile) async {
    setState(() {
      _selectedTeacher = profile.teacherName.trim();
      _selectedProfileId = profile.id;
    });
    await ref
        .read(printProfileStoreProvider.notifier)
        .setLastSelectedTeacher(profile.teacherName);
    await ref
        .read(printProfileStoreProvider.notifier)
        .setLastUsedProfile(profile.id);
  }

  /// 선택한 계획서 삭제 (연결된 결보강 내역도 함께 — 결보강 출력과 동일)
  Future<void> _deleteSelectedProfile(PrintProfile profile) async {
    final confirmed = await DialogHelper.showConfirmDialog(
      context,
      title: '계획서 삭제',
      message:
          "'${profile.name}' 계획서와 여기 연결된 결보강 내역(교체 기록)이 모두 삭제됩니다.\n"
          '이 작업은 되돌릴 수 없습니다. 삭제하시겠습니까?',
      confirmText: '삭제',
      isDangerous: true,
    );
    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(printProfileStoreProvider.notifier)
        .deleteProfile(profile.id);
    if (!mounted) return;

    if (!success) {
      SnackBarHelper.showError(context, '계획서 삭제에 실패했습니다.');
      return;
    }

    ref
        .read(exchangeHistoryServiceProvider)
        .removeExchangeItemsByProfile(profile.id);
    ExchangeExecutor.restoreExchangedCells(ref);

    final teacher = profile.teacherName.trim();
    final remaining = ref.read(printProfileStoreProvider).byTeacher(teacher);
    final nextId = remaining.isNotEmpty ? remaining.first.id : null;

    setState(() {
      _selectedTeacher = teacher.isEmpty ? _selectedTeacher : teacher;
      _selectedProfileId = nextId;
    });
    if (nextId != null) {
      await ref
          .read(printProfileStoreProvider.notifier)
          .setLastUsedProfile(nextId);
    }

    if (mounted) {
      SnackBarHelper.showSuccess(context, "'${profile.name}' 계획서를 삭제했습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final planData = ref.watch(
      substitutionPlanViewModelProvider.select((s) => s.planData),
    );
    final store = ref.watch(printProfileStoreProvider);
    final teachers = _absenceTeachers(planData);
    _ensureSelection(teachers, store);

    final teacher = _selectedTeacher;
    final profiles =
        teacher != null ? store.byTeacher(teacher) : const <PrintProfile>[];
    final selectedProfile = store.getById(_selectedProfileId);
    final accent =
        tokens.monochromeMenuAccents
            ? tokens.primary
            : PlanOutputMenu.backup.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContentUsageHintBar(
            message: ScreenUsageHints.planBackup,
            accentColor: accent,
          ),
          ContentToolbarLayout.hintToToolbarSpacer,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 200,
                  child: BackupTeacherListPane(
                    teachers: teachers,
                    selectedTeacher: teacher,
                    store: store,
                    accent: accent,
                    tokens: tokens,
                    onSelect: _selectTeacher,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BackupPlanListPane(
                    teacher: teacher,
                    profiles: profiles,
                    selectedProfileId: selectedProfile?.id,
                    accent: accent,
                    tokens: tokens,
                    onSelect: _selectProfile,
                    onOpenContentEdit: () async {
                      // 2열에서 고른 계획서를 전역 선택에 맞춘 뒤 결보강 일정으로 이동
                      final profile = selectedProfile;
                      if (profile != null) {
                        await ref
                            .read(printProfileStoreProvider.notifier)
                            .setLastUsedProfile(profile.id);
                      }
                      navigateToPlanDateSelection(ref);
                    },
                    onDeleteSelected:
                        selectedProfile == null
                            ? null
                            : () => _deleteSelectedProfile(selectedProfile),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildBackupActions(
            tokens: tokens,
            canExport: selectedProfile != null,
          ),
        ],
      ),
    );
  }

  Widget _buildBackupActions({
    required DesignTokens tokens,
    required bool canExport,
  }) {
    return Row(
      children: [
        Text('결보강 백업', style: TextStyle(fontSize: 13, color: tokens.textMuted)),
        const SizedBox(width: 10),
        CompactToolbarLabelButton(
          onPressed: canExport ? _handleExportBackup : null,
          icon: Icons.upload_outlined,
          label: '내보내기',
          tooltip:
              canExport
                  ? '선택한 계획서 1건을 파일로 저장 (다른 PC로 옮길 때 사용)'
                  : '계획서를 선택한 뒤에만 내보낼 수 있습니다',
          backgroundColor: ContentToolbarLayout.neutralButtonBackground(tokens),
          foregroundColor: ContentToolbarLayout.neutralButtonForeground(tokens),
          borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
          height: ContentToolbarLayout.buttonHeight,
          fontSize: ContentToolbarLayout.buttonFontSize,
          iconSize: ContentToolbarLayout.buttonIconSize,
        ),
        const SizedBox(width: ContentToolbarLayout.buttonGap),
        CompactToolbarLabelButton(
          onPressed: _handleImportBackup,
          icon: Icons.download_outlined,
          label: '가져오기',
          tooltip: '백업 파일에서 복원합니다 (계획서 미선택 시 새 계획서로 복원)',
          backgroundColor: ContentToolbarLayout.neutralButtonBackground(tokens),
          foregroundColor: ContentToolbarLayout.neutralButtonForeground(tokens),
          borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
          height: ContentToolbarLayout.buttonHeight,
          fontSize: ContentToolbarLayout.buttonFontSize,
          iconSize: ContentToolbarLayout.buttonIconSize,
        ),
      ],
    );
  }

  Future<void> _handleExportBackup() async {
    final profileStore = ref.read(printProfileStoreProvider);
    final selected = profileStore.getById(_selectedProfileId);
    if (selected == null) {
      if (mounted) {
        SnackBarHelper.showInfo(context, '백업할 계획서를 먼저 선택하세요.');
      }
      return;
    }

    final historyService = ref.read(exchangeHistoryServiceProvider);
    final items = PlanBackupIo.itemsForPlanBackup(
      historyService.getExchangeList(),
      selected.id,
    );
    if (items.isEmpty) {
      if (mounted) {
        SnackBarHelper.showInfo(context, '내보낼 결보강 내역이 없습니다.');
      }
      return;
    }

    final activeEntry = ref.read(activeTimetableEntryProvider);
    final bundled =
        items
            .map(
              (e) =>
                  e.profileId == selected.id
                      ? e
                      : e.copyWithProfileId(selected.id),
            )
            .toList();

    final bundle = SubstitutionBackupBundle(
      timetableName: activeEntry?.name,
      teacherName: activeEntry?.teacherName,
      schoolName: activeEntry?.schoolName,
      exchangeItems: bundled,
      printProfiles: [selected],
    );
    final jsonString = const SubstitutionBackupService().encode(bundle);
    final fileName =
        '${PlanBackupIo.buildBackupFileName(teacherName: selected.teacherName, profileName: selected.name, now: DateTime.now())}.json';

    if (kIsWeb) {
      try {
        await FilePicker.saveFile(
          dialogTitle: '결보강 내보내기',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['json'],
          bytes: Uint8List.fromList(utf8.encode(jsonString)),
        );
        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            "계획서 '${selected.name}' ${items.length}건을 내보냈습니다.",
          );
        }
      } catch (e) {
        AppLogger.error('결보강 내역 내보내기 실패: $e', e);
        if (mounted) {
          SnackBarHelper.showError(context, '내보내기에 실패했습니다: $e');
        }
      }
      return;
    }

    String? outputPath;
    try {
      outputPath = await FilePicker.saveFile(
        dialogTitle: '결보강 내보내기',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
    } catch (e) {
      AppLogger.error('결보강 내역 저장 대화상자 실패: $e', e);
    }
    if (outputPath == null || outputPath.isEmpty) return;

    final path =
        outputPath.toLowerCase().endsWith('.json')
            ? outputPath
            : '$outputPath.json';

    try {
      await File(path).writeAsString(jsonString);
      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          "계획서 '${selected.name}' ${items.length}건을 내보냈습니다.",
        );
      }
    } catch (e) {
      AppLogger.error('결보강 내역 내보내기 실패: $e', e);
      if (mounted) {
        SnackBarHelper.showError(context, '내보내기에 실패했습니다: $e');
      }
    }
  }

  Future<void> _handleImportBackup() async {
    final profileStore = ref.read(printProfileStoreProvider);
    final selected = profileStore.getById(_selectedProfileId);

    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        dialogTitle: '결보강 가져오기',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
        withData: kIsWeb,
      );
    } catch (e) {
      AppLogger.error('결보강 가져오기 대화상자 실패: $e', e);
    }
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;

    const backupService = SubstitutionBackupService();
    final SubstitutionBackupBundle bundle;
    try {
      final String content;
      if (kIsWeb) {
        final bytes = picked.bytes;
        if (bytes == null || bytes.isEmpty) {
          if (mounted) {
            SnackBarHelper.showError(context, '올바른 결보강 백업 파일이 아닙니다.');
          }
          return;
        }
        content = utf8.decode(bytes);
      } else {
        final path = picked.path;
        if (path == null) return;
        content = await File(path).readAsString();
      }
      bundle = backupService.decode(content);
    } catch (e) {
      AppLogger.error('결보강 가져오기 실패(파일 읽기/형식): $e', e);
      if (mounted) {
        SnackBarHelper.showError(context, '올바른 결보강 백업 파일이 아닙니다.');
      }
      return;
    }

    if (bundle.exchangeItems.isEmpty) {
      if (mounted) {
        SnackBarHelper.showInfo(context, '가져올 결보강 내역이 없습니다.');
      }
      return;
    }

    final currentTimeSlots =
        ref.read(
          exchangeScreenProvider.select(
            (state) => state.timetableData?.timeSlots,
          ),
        ) ??
        const [];

    final matches = backupService.matchesCurrentTimetable(
      bundle.exchangeItems,
      currentTimeSlots,
    );
    if (!mounted) return;
    if (!matches) {
      final proceed = await _showBackupConfirmDialog(
        title: '다른 시간표일 수 있습니다',
        message:
            '가져올 파일의 교체 내역이 지금 이 시간표와 일치하지 않습니다'
            '(다른 시간표이거나, 그 사이 시간표가 바뀌었을 수 있습니다).\n\n'
            '그래도 가져오시겠습니까?',
        confirmLabel: '그래도 가져오기',
      );
      if (proceed != true) return;
    }

    final String? selectedId = selected?.id;
    final String? selectedName = selected?.name;
    final retargeted =
        selectedId == null
            ? bundle.exchangeItems
            : bundle.exchangeItems
                .map((e) => e.copyWithProfileId(selectedId))
                .toList();

    final historyService = ref.read(exchangeHistoryServiceProvider);
    final existingItems =
        selectedId == null
            ? historyService.getExchangeList()
            : historyService
                .getExchangeList()
                .where((e) => e.profileId == selectedId)
                .toList();
    final hasConflict = backupService.hasDateConflict(
      retargeted,
      existingItems,
    );

    if (hasConflict) {
      if (!mounted) return;
      final proceed = await _showBackupConfirmDialog(
        title: '날짜가 겹칩니다',
        message:
            selectedName == null
                ? '가져올 결보강 내역이 기존 내역과 날짜가 겹칩니다.\n'
                    '계속하면 가져온 내용을 기존 내역 뒤에 추가합니다.\n\n'
                    '계속하시겠습니까?'
                : "가져올 결보강 내역이 계획서 '$selectedName'의 기존 내역과 "
                    '날짜가 겹칩니다.\n'
                    '계속하면 현재 계획서의 기존 내역을 모두 지우고 가져온 내용으로 교체합니다.\n\n'
                    '계속하시겠습니까?',
        confirmLabel: selectedName == null ? '추가하기' : '지우고 가져오기',
      );
      if (proceed != true) return;
      if (selectedId != null) {
        historyService.removeExchangeItemsByProfile(selectedId);
      }
    }

    historyService.importExchangeItems(retargeted, overwrite: false);
    ExchangeExecutor.restoreExchangedCells(ref);

    if (selected != null) {
      if (bundle.printProfiles.isNotEmpty) {
        final src = bundle.printProfiles.first;
        final updated = selected.copyWith(
          templateIndex: src.templateIndex,
          fontSize: src.fontSize,
          remarksFontSize: src.remarksFontSize,
          selectedFont: src.selectedFont,
          includeRemarks: src.includeRemarks,
          additionalFields: Map<String, String>.from(src.additionalFields),
          selectedTemplateFilePath: src.selectedTemplateFilePath,
          clearTemplateFilePath: src.selectedTemplateFilePath == null,
          deselectedGroupIds: List<String>.from(src.deselectedGroupIds),
        );
        await ref.read(printProfileStoreProvider.notifier).saveProfile(updated);
      }

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          hasConflict
              ? "계획서 '$selectedName'의 기존 내역을 지우고 가져왔습니다."
              : "계획서 '$selectedName'에 ${retargeted.length}건을 가져왔습니다.",
        );
      }
      return;
    }

    if (bundle.printProfiles.isNotEmpty) {
      final profileNotifier = ref.read(printProfileStoreProvider.notifier);
      final currentStore = ref.read(printProfileStoreProvider);
      PrintProfile? firstRestored;
      for (final profile in bundle.printProfiles) {
        if (currentStore.getById(profile.id) == null) {
          await profileNotifier.saveProfile(profile);
          firstRestored ??= profile;
        }
      }

      final toSelect = firstRestored ?? bundle.printProfiles.first;
      if (mounted) {
        setState(() {
          _selectedTeacher = toSelect.teacherName.trim();
          _selectedProfileId = toSelect.id;
        });
        await profileNotifier.setLastSelectedTeacher(toSelect.teacherName);
        await profileNotifier.setLastUsedProfile(toSelect.id);
      }
    }

    if (mounted) {
      SnackBarHelper.showSuccess(context, '${retargeted.length}건을 가져왔습니다.');
    }
  }

  Future<bool?> _showBackupConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
  }
}

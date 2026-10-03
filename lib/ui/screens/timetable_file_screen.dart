import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dated_timetable.dart';
import '../../models/timetable_registry.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/timetable_registry_provider.dart';
import '../../providers/timetable_repository_provider.dart';
import '../../providers/timetable_summary_provider.dart';
import '../../providers/timetable_teachers_provider.dart';
import '../../services/semester_timetable_generator.dart';
import '../../theme/design_tokens.dart';
import '../../utils/logger.dart';
import '../../utils/snackbar_helper.dart';
import 'exchange_screen/exchange_screen_state_proxy.dart';
import 'exchange_screen/managers/exchange_operation_manager.dart';
import 'timetable_file/timetable_file_card.dart';
import 'timetable_file/timetable_file_dialogs.dart';
import 'timetable_file/timetable_file_empty_state.dart';
import 'timetable_file_register_dialog.dart';

/// 시간표(학기) 관리 화면
///
/// 등록된 시간표 목록을 관리합니다.
/// - 시간표 추가 (엑셀 파일 선택 → 이름·학기 확인 → 등록)
/// - 활성 시간표 전환 (교체 목록·계획서 등 스코프 데이터 함께 전환)
/// - 이름 변경 / 삭제
class TimetableFileScreen extends ConsumerStatefulWidget {
  const TimetableFileScreen({super.key, this.autoStartAdd = false});

  /// 진입 즉시 시간표 추가(파일 선택) 흐름을 시작할지 여부
  ///
  /// 홈 카드의 [＋ 시간표 추가]에서 진입할 때 사용합니다.
  final bool autoStartAdd;

  @override
  ConsumerState<TimetableFileScreen> createState() =>
      _TimetableFileScreenState();
}

class _TimetableFileScreenState extends ConsumerState<TimetableFileScreen> {
  // 엑셀 파일 선택 관련 상태 관리
  ExchangeScreenStateProxy? _stateProxy;
  ExchangeOperationManager? _operationManager;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();

    // StateProxy 초기화
    _stateProxy = ExchangeScreenStateProxy(ref);

    // Manager 초기화 (엑셀 파일 처리 및 상태 관리)
    _operationManager = ExchangeOperationManager(
      context: context,
      ref: ref,
      stateProxy: _stateProxy!,
      onCreateSyncfusionGridData: () {
        if (mounted) setState(() {});
      },
      onClearAllExchangeStates: () {
        if (mounted) setState(() {});
      },
      onRefreshHeaderTheme: () {
        if (mounted) setState(() {});
      },
    );

    // 홈에서 [＋ 시간표 추가]로 진입한 경우 즉시 파일 선택 시작
    if (widget.autoStartAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addTimetable();
      });
    }
  }

  /// 시간표 추가: 엑셀 파일 선택 → 파싱/저장 → 이름 지정 → 레지스트리 등록 → 활성 전환
  ///
  /// 동일 파일 경로의 항목이 이미 있으면 새 항목을 만들지 않고 그 항목을
  /// 갱신(내용 변경 시 스코프 교체 데이터 정리)한 뒤 전환합니다.
  Future<void> _addTimetable() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);

    try {
      // 1. 파일 선택 + 파싱 + 저장 + 화면 적용 (기존 흐름)
      final fileSelected = await _operationManager!.selectExcelFile();
      if (!fileSelected || !mounted) return;

      // 2. 방금 저장된 시간표 해시 정보로 레지스트리 처리
      final hashes = _operationManager!.lastSavedTimetableHashes;
      final selectedFile = _stateProxy?.selectedFile;
      if (hashes == null || selectedFile == null) {
        _showSnackBar('시간표 저장 정보를 확인할 수 없습니다.', isError: true);
        return;
      }

      final filePath = selectedFile.path;
      final fileName = filePath.split(Platform.pathSeparator).last;
      final hash = hashes.hash;
      final contentHash = hashes.contentHash;

      // 3. 동일 파일 경로의 기존 항목 확인 → 있으면 갱신 후 전환
      final registry = ref.read(timetableRegistryProvider).valueOrNull;
      final existing =
          registry?.timetables
              .where((e) => e.filePath == filePath && filePath.isNotEmpty)
              .firstOrNull;

      if (existing != null) {
        // 내용이 바뀌면 교체 목록·결보강이 새 시간표와 맞지 않아 정리해야 한다.
        // 사용자 눈에는 "같은 파일을 다시 골랐을 뿐"이므로 지우기 전에 반드시 확인.
        final contentChanged =
            existing.contentHash.isNotEmpty &&
            existing.contentHash != contentHash;

        if (contentChanged) {
          final summary = await ref.read(
            timetableSummaryProvider(existing.id).future,
          );
          if (!mounted) return;

          final proceed = await showConfirmContentChangeDialog(
            context,
            existing,
            summary,
          );
          if (proceed != true) {
            // 취소: 이미 메모리에 올라온 새 파일 내용을 버리고 원래 상태로 복구
            await ref.read(timetableRegistryProvider.notifier).reloadActive();
            if (mounted) _showSnackBar('갱신을 취소했습니다.');
            return;
          }
        }

        final updated = await ref
            .read(timetableRegistryProvider.notifier)
            .updateTimetableSource(
              existing.id,
              fileName: fileName,
              filePath: filePath,
              hash: hash,
              contentHash: contentHash,
            );
        if (!mounted) return;
        _showSnackBar(
          updated ? "시간표 '${existing.name}'이(가) 갱신되었습니다." : '시간표 갱신에 실패했습니다.',
          isError: !updated,
        );
        return;
      }

      // 4. 신규 등록: 이름·학기를 한 창에서 확인 (기본 이름은 파일명)
      // 학기는 오늘 날짜가 속한 1·2학기가 미리 선택되어 있다.
      final defaultName = fileName.replaceAll(
        RegExp(r'\.[^.]+$', caseSensitive: false),
        '',
      );
      final registration = await showRegisterTimetableDialog(
        context,
        initialName: defaultName,
      );
      if (!mounted) return;
      if (registration == null) {
        await ref.read(timetableRegistryProvider.notifier).reloadActive();
        if (mounted) _showSnackBar('등록을 취소했습니다.');
        return;
      }

      // 교사·학교명 자동 추정: 직전 시간표 값이 새 시간표에도 있으면 그대로 사용
      final inferred = _inferTeacherAndSchool(registry);
      final semester = registration.semester;

      final entry = await ref
          .read(timetableRegistryProvider.notifier)
          .registerTimetable(
            name:
                registration.name.isNotEmpty ? registration.name : defaultName,
            fileName: fileName,
            filePath: filePath,
            hash: hash,
            contentHash: contentHash,
            teacherName: inferred.teacher,
            schoolName: inferred.school,
            semesterStart: semester.startDate,
            semesterEnd: semester.endDate,
          );

      if (entry == null) {
        if (mounted) {
          _showSnackBar('시간표 등록에 실패했습니다.', isError: true);
        }
        return;
      }

      // 4.5. 날짜별 시간표 생성·저장 (S3, 부가 기능)
      //
      // 기존 주 단위 등록(위 3~4단계)과 완전히 병행한다 — 이 블록이 실패해도
      // 이미 완료된 등록 자체(레지스트리·JSON 저장)에는 영향을 주지 않는다.
      // 기간은 등록 창에서 확인한 학년도·학기·시작일·종료일을 그대로 쓴다.
      final datedTimetableData = _stateProxy?.timetableData;
      if (datedTimetableData != null) {
        try {
          final lessons = SemesterTimetableGenerator.generate(
            timetableId: entry.id,
            timeSlots: datedTimetableData.timeSlots,
            semester: semester,
          );
          final repository = await ref.read(timetableRepositoryProvider.future);
          await repository.insertTimetable(
            DatedTimetable(
              id: entry.id,
              name: entry.name,
              semester: semester,
              teacherName: entry.teacherName,
              schoolName: entry.schoolName,
              registeredAt: entry.registeredAt,
            ),
          );
          await repository.insertLessons(lessons);
          await repository.insertSnapshot(lessons);
          AppLogger.info(
            '[S3] 날짜별 시간표 생성 완료: ${entry.id}, ${lessons.length}개 수업, $semester',
          );
        } catch (e) {
          AppLogger.error('[S3] 날짜별 시간표 생성 실패 (기존 등록에는 영향 없음): $e', e);
        }
      }

      // 5. 방금 추가한 시간표를 활성으로 전환 (첫 시간표면 이미 활성)
      await ref.read(timetableRegistryProvider.notifier).switchActive(entry.id);

      if (mounted) {
        _showSnackBar(
          inferred.teacher != null
              ? "'${entry.name}' 등록 완료 · 교사를 '${inferred.teacher}'로 자동 설정했습니다."
              : "'${entry.name}' 등록 완료 · 홈에서 교사를 선택하세요.",
        );
      }
    } catch (e) {
      AppLogger.error('시간표 추가 실패: $e', e);
      if (mounted) {
        _showSnackBar('시간표 추가 중 오류가 발생했습니다: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  /// 교사·학교명 자동 추정
  ///
  /// 직전에 사용하던 시간표의 교사가 새로 파싱된 교사 목록에도 있으면 그대로 씁니다.
  /// 같은 학교의 1·2학기를 등록하는 일반적인 경우 사용자가 손댈 것이 없고,
  /// 다른 학교일 때만 미지정으로 남겨 홈 카드에서 고르게 합니다(문서 §4).
  ({String? teacher, String? school}) _inferTeacherAndSchool(
    TimetableRegistry? registry,
  ) {
    final previous =
        registry?.activeEntry ??
        (registry != null && registry.timetables.isNotEmpty
            ? registry.timetables.last
            : null);
    if (previous == null) {
      return (teacher: null, school: null);
    }

    final teachers = ref.read(activeTimetableTeachersProvider);
    final candidate = previous.teacherName;
    final teacher =
        (candidate != null && teachers.contains(candidate)) ? candidate : null;

    return (teacher: teacher, school: previous.schoolName);
  }

  /// 시간표 전환
  Future<void> _switchTimetable(TimetableRegistryEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("'${entry.name}'(으)로 전환"),
          content: const Text(
            '현재 시간표의 교체 목록은 그대로 저장되며,\n'
            '전환 후 해당 시간표의 데이터를 불러옵니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('전환'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    final success = await ref
        .read(timetableRegistryProvider.notifier)
        .switchActive(entry.id);

    if (mounted) {
      _showSnackBar(
        success ? "'${entry.name}'(으)로 전환되었습니다." : '전환에 실패했습니다.',
        isError: !success,
      );
    }
  }

  /// 시간표 이름 변경
  Future<void> _renameTimetable(TimetableRegistryEntry entry) async {
    final newName = await showTimetableNameDialog(
      context,
      title: '시간표 이름 변경',
      initialValue: entry.name,
    );
    if (newName == null || newName.isEmpty || newName == entry.name) return;

    final success = await ref
        .read(timetableRegistryProvider.notifier)
        .renameTimetable(entry.id, newName);

    if (mounted) {
      _showSnackBar(
        success ? '이름이 변경되었습니다.' : '이름 변경에 실패했습니다.',
        isError: !success,
      );
    }
  }

  /// 시간표 삭제
  ///
  /// 무엇이 함께 사라지는지(건수)와, 활성 시간표였다면 어디로 전환되는지를
  /// 미리 알려준 뒤에만 진행합니다.
  Future<void> _deleteTimetable(TimetableRegistryEntry entry) async {
    final summary = await ref.read(timetableSummaryProvider(entry.id).future);
    if (!mounted) return;

    final registry = ref.read(timetableRegistryProvider).valueOrNull;
    final isActive = registry?.activeId == entry.id;
    final remaining =
        registry?.timetables.where((e) => e.id != entry.id).toList() ??
        const <TimetableRegistryEntry>[];
    final nextEntry = isActive && remaining.isNotEmpty ? remaining.first : null;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('시간표 삭제')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("'${entry.name}'을(를) 삭제하시겠습니까?"),
              const SizedBox(height: 12),
              Text(
                summary.isEmpty
                    ? '이 시간표에 저장된 데이터는 없습니다.'
                    : '${summary.description}이(가) 함께 삭제되며 되돌릴 수 없습니다.',
                style: const TextStyle(fontSize: 13),
              ),
              if (isActive) ...[
                const SizedBox(height: 12),
                Text(
                  nextEntry != null
                      ? "삭제 후 '${nextEntry.name}'(으)로 전환됩니다."
                      : '삭제 후 사용할 시간표가 없어집니다.',
                  style: const TextStyle(fontSize: 12.5, color: Colors.orange),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    final success = await ref
        .read(timetableRegistryProvider.notifier)
        .removeTimetable(entry.id);

    if (mounted) {
      _showSnackBar(
        success ? "시간표 '${entry.name}'이(가) 삭제되었습니다." : '삭제에 실패했습니다.',
        isError: !success,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (isError) {
      SnackBarHelper.showError(
        context,
        message,
        duration: const Duration(seconds: 2),
      );
    } else {
      SnackBarHelper.showInfo(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final registryAsync = ref.watch(timetableRegistryProvider);
    final activeEntry = ref.watch(activeTimetableEntryProvider);
    final screenState = ref.watch(exchangeScreenProvider);
    final isLoading = screenState.isLoading || _isAdding;

    return Scaffold(
      // 뒤로가기 버튼이 있는 상단 바 (메인 화면 복귀 경로)
      appBar: AppBar(title: const Text('시간표 관리')),
      body: Container(
        color: tokens.sectionBackground,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 시간표 추가 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _addTimetable,
                  icon:
                      _isAdding
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Icon(Icons.add),
                  label: Text(
                    _isAdding ? '시간표 불러오는 중...' : '시간표 추가',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 등록된 시간표 목록
              registryAsync.when(
                loading:
                    () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                error:
                    (error, _) => Text(
                      '시간표 목록을 불러올 수 없습니다: $error',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                data: (registry) {
                  if (registry.timetables.isEmpty) {
                    return const TimetableFileEmptyState();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '등록된 시간표 (${registry.timetables.length}개)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...registry.timetables.map(
                        (entry) => TimetableFileCard(
                          entry: entry,
                          isActive: entry.id == activeEntry?.id,
                          onSwitch: () => _switchTimetable(entry),
                          onRename: () => _renameTimetable(entry),
                          onDelete: () => _deleteTimetable(entry),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ⓘ 원본 엑셀 파일을 이동/삭제해도 저장된 시간표는 유지됩니다.',
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

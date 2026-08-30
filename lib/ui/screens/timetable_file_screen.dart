import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/print_profile.dart';
import '../../models/timetable_registry.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/print_profile_provider.dart';
import '../../providers/timetable_registry_provider.dart';
import '../../providers/timetable_summary_provider.dart';
import '../../providers/timetable_teachers_provider.dart';
import '../../theme/design_tokens.dart';
import '../../utils/logger.dart';
import 'exchange_screen/exchange_screen_state_proxy.dart';
import 'exchange_screen/managers/exchange_operation_manager.dart';

/// 시간표(학기) 관리 화면
///
/// 등록된 시간표 목록을 관리합니다.
/// - 시간표 추가 (엑셀 파일 선택 → 이름 지정 → 등록)
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
      final existing = registry?.timetables
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

          final proceed = await _confirmContentChange(existing, summary);
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
          updated
              ? "시간표 '${existing.name}'이(가) 갱신되었습니다."
              : '시간표 갱신에 실패했습니다.',
          isError: !updated,
        );
        return;
      }

      // 4. 신규 등록: 이름 지정 (기본값: 파일명, 취소 없음 — 등록이 필수)
      final defaultName = fileName.replaceAll(RegExp(r'\.(xlsx|xls)$'), '');
      final name = await _showNameDialog(
        title: '시간표 이름',
        initialValue: defaultName,
        showCancel: false,
      );
      if (!mounted) return;

      // 교사·학교명 자동 추정: 직전 시간표 값이 새 시간표에도 있으면 그대로 사용
      final inferred = _inferTeacherAndSchool(registry);

      // 학기 기간 입력 (§10.6 — 결보강 날짜의 연도 추정에 사용. 건너뛰기 가능)
      final semesterRange = await _showSemesterRangeDialog();
      if (!mounted) return;

      final entry = await ref
          .read(timetableRegistryProvider.notifier)
          .registerTimetable(
            name: (name != null && name.isNotEmpty) ? name : defaultName,
            fileName: fileName,
            filePath: filePath,
            hash: hash,
            contentHash: contentHash,
            teacherName: inferred.teacher,
            schoolName: inferred.school,
            semesterStart: semesterRange.start,
            semesterEnd: semesterRange.end,
          );

      if (entry == null) {
        if (mounted) {
          _showSnackBar('시간표 등록에 실패했습니다.', isError: true);
        }
        return;
      }

      // 5. 방금 추가한 시간표를 활성으로 전환 (첫 시간표면 이미 활성)
      await ref
          .read(timetableRegistryProvider.notifier)
          .switchActive(entry.id);

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

  /// 시간표 이름 입력 다이얼로그
  ///
  /// [showCancel]이 true면 취소 버튼을 표시하고 취소 시 null을 반환합니다.
  Future<String?> _showNameDialog({
    required String title,
    required String initialValue,
    bool showCancel = true,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '예: 월계중1학기',
              labelText: '시간표 이름',
            ),
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            if (showCancel)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('취소'),
              ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 학기 시작일·종료일 입력 다이얼로그
  ///
  /// §10.6: 이 값은 결보강 날짜("8.27" 같은 연도 없는 문자열)의 연도를
  /// 추정할 때 쓰인다. 필수 입력이 아니다 — [건너뛰기]를 누르면 둘 다
  /// null로 등록되며, 이 경우 연도 추정은 기존 방식(오늘 연도 기준)으로
  /// 폴백한다(§10.9 리스크 2).
  Future<({DateTime? start, DateTime? end})> _showSemesterRangeDialog() async {
    DateTime? start;
    DateTime? end;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String formatDate(DateTime? d) =>
                d == null ? '선택 안 함' : '${d.year}.${d.month}.${d.day}';

            Future<void> pickStart() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: start ?? DateTime.now(),
                firstDate: DateTime(DateTime.now().year - 5),
                lastDate: DateTime(DateTime.now().year + 5),
              );
              if (picked != null) {
                setDialogState(() {
                  start = picked;
                  if (end != null && end!.isBefore(start!)) end = null;
                });
              }
            }

            Future<void> pickEnd() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: start != null && start!.isAfter(DateTime.now())
                    ? start!
                    : (end ?? DateTime.now()),
                firstDate: start ?? DateTime(DateTime.now().year - 5),
                lastDate: DateTime(DateTime.now().year + 5),
              );
              if (picked != null) {
                setDialogState(() => end = picked);
              }
            }

            return AlertDialog(
              title: const Text('학기 기간'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '결보강 날짜의 연도를 정확히 계산하는 데 사용됩니다.\n'
                    '지금 입력하지 않아도 나중에 다시 등록할 수 있습니다.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('시작일'),
                    subtitle: Text(formatDate(start)),
                    onTap: pickStart,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_busy_outlined),
                    title: const Text('종료일'),
                    subtitle: Text(formatDate(end)),
                    onTap: pickEnd,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('건너뛰기'),
                ),
                ElevatedButton(
                  onPressed: (start != null && end != null)
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return (start: null, end: null);
    }
    return (start: start, end: end);
  }

  /// 교사·학교명 자동 추정
  ///
  /// 직전에 사용하던 시간표의 교사가 새로 파싱된 교사 목록에도 있으면 그대로 씁니다.
  /// 같은 학교의 1·2학기를 등록하는 일반적인 경우 사용자가 손댈 것이 없고,
  /// 다른 학교일 때만 미지정으로 남겨 홈 카드에서 고르게 합니다(문서 §4).
  ({String? teacher, String? school}) _inferTeacherAndSchool(
    TimetableRegistry? registry,
  ) {
    final previous = registry?.activeEntry ??
        (registry != null && registry.timetables.isNotEmpty
            ? registry.timetables.last
            : null);
    if (previous == null) {
      return (teacher: null, school: null);
    }

    final teachers = ref.read(activeTimetableTeachersProvider);
    final candidate = previous.teacherName;
    final teacher = (candidate != null && teachers.contains(candidate))
        ? candidate
        : null;

    return (teacher: teacher, school: previous.schoolName);
  }

  /// 원본 내용 변경 확인 다이얼로그
  ///
  /// 무엇이 지워지고 무엇이 남는지 건수로 보여준 뒤에만 진행합니다.
  Future<bool?> _confirmContentChange(
    TimetableRegistryEntry entry,
    TimetableSummary summary,
  ) {
    final removed = <String>[
      if (summary.exchangeCount > 0) '교체 ${summary.exchangeCount}건',
      if (summary.planEntryCount > 0) '결보강 입력 ${summary.planEntryCount}건',
    ];

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 26,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('시간표 내용이 변경되었습니다')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "'${entry.name}'의 원본 파일 내용이 이전과 다릅니다.\n"
                '기존 교체 결과는 새 시간표와 맞지 않아 초기화해야 합니다.',
              ),
              const SizedBox(height: 14),
              _confirmLine(
                icon: Icons.delete_outline,
                color: Colors.red,
                label: '삭제됨',
                value: removed.isEmpty ? '없음' : removed.join(' · '),
              ),
              const SizedBox(height: 6),
              _confirmLine(
                icon: Icons.check_circle_outline,
                color: Colors.green,
                label: '유지됨',
                value: summary.profileCount > 0
                    ? '계획서 ${summary.profileCount}개'
                    : '없음',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('갱신'),
            ),
          ],
        );
      },
    );
  }

  /// 확인 다이얼로그의 "삭제됨 / 유지됨" 한 줄
  Widget _confirmLine({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
      ],
    );
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
    final newName = await _showNameDialog(
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
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
                icon: _isAdding
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
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Text(
                '시간표 목록을 불러올 수 없습니다: $error',
                style: TextStyle(color: tokens.textSecondary),
              ),
              data: (registry) {
                if (registry.timetables.isEmpty) {
                  return _buildEmptyState(context, tokens);
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
                      (entry) => _buildTimetableCard(
                        context,
                        theme,
                        entry,
                        isActive: entry.id == activeEntry?.id,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ⓘ 원본 엑셀 파일을 이동/삭제해도 저장된 시간표는 유지됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textMuted,
                      ),
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

  /// 빈 상태 안내
  Widget _buildEmptyState(BuildContext context, DesignTokens tokens) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.table_chart_outlined,
            size: 48,
            color: tokens.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            '등록된 시간표가 없습니다',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '상단의 [시간표 추가] 버튼으로\n엑셀 시간표를 등록하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }

  /// 시간표 카드 1건
  ///
  /// 활성 항목만 계층 트리(교사 → 계획서)를 펼치고, 비활성 항목은 한 줄로 접습니다.
  /// 교체·결보강 건수는 교사가 아니라 **시간표 아래**에 표시해, 교체 상태가
  /// 교사와 무관하게 공유된다는 원칙을 배치로 드러냅니다(문서 §3①).
  Widget _buildTimetableCard(
    BuildContext context,
    ThemeData theme,
    TimetableRegistryEntry entry, {
    required bool isActive,
  }) {
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? theme.primaryColor.withValues(alpha: 0.5)
              : tokens.cardBorder,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitleRow(theme, tokens, entry, isActive: isActive),
          const SizedBox(height: 6),
          _buildCardSourceLine(tokens, entry),
          if (isActive)
            _buildActiveCardBody(tokens, entry)
          else
            _buildCollapsedCardBody(tokens, entry),
          const SizedBox(height: 10),
          _buildCardActions(entry, isActive: isActive),
        ],
      ),
    );
  }

  /// 카드 제목 줄 (선택 표시 + 이름 + '사용 중' 배지)
  Widget _buildCardTitleRow(
    ThemeData theme,
    DesignTokens tokens,
    TimetableRegistryEntry entry, {
    required bool isActive,
  }) {
    return Row(
      children: [
        Icon(
          isActive ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 20,
          color: isActive ? theme.primaryColor : tokens.textMuted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '사용 중',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  /// 원본 파일·학교명·등록일 한 줄
  Widget _buildCardSourceLine(
    DesignTokens tokens,
    TimetableRegistryEntry entry,
  ) {
    final parts = <String>[
      if (entry.schoolName != null) entry.schoolName!,
      entry.fileName.isEmpty ? '원본 정보 없음' : entry.fileName,
      '${entry.registeredAt.month}/${entry.registeredAt.day} 등록',
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 28),
      child: Row(
        children: [
          Icon(Icons.school_outlined, size: 13, color: tokens.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 활성 시간표: 교사 → 계획서 트리 + 시간표 단위 건수
  Widget _buildActiveCardBody(
    DesignTokens tokens,
    TimetableRegistryEntry entry,
  ) {
    final store = ref.watch(printProfileStoreProvider);
    final summary = ref.watch(timetableSummaryProvider(entry.id)).valueOrNull;

    // 계획서를 가진 교사 목록. 지정 교사는 계획서가 없어도 항상 맨 앞에 보인다
    final teachers = <String>[
      if (entry.hasTeacher) entry.teacherName!,
      ...store.teacherNames.where((t) => t != entry.teacherName),
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                entry.hasTeacher
                    ? Icons.person_outline
                    : Icons.warning_amber_rounded,
                size: 14,
                color: entry.hasTeacher ? tokens.textSecondary : Colors.orange,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entry.hasTeacher
                      ? '교사: ${entry.teacherName}'
                      : '교사 미지정 — 홈 화면에서 선택하세요',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: entry.hasTeacher
                        ? tokens.textSecondary
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < teachers.length; i++)
            _buildTeacherTreeRow(
              tokens,
              teachers[i],
              store.byTeacher(teachers[i]),
              isLast: i == teachers.length - 1,
            ),
          const SizedBox(height: 6),
          Text(
            summary == null
                ? '데이터 확인 중…'
                : '${summary.description}  (시간표 전체가 공유)',
            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }

  /// 트리 한 줄 (교사 → 그 교사의 계획서들)
  Widget _buildTeacherTreeRow(
    DesignTokens tokens,
    String teacher,
    List<PrintProfile> profiles, {
    required bool isLast,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLast ? '└─ ' : '├─ ',
            style: TextStyle(fontSize: 12, color: tokens.textMuted),
          ),
          Text(
            teacher,
            style: TextStyle(fontSize: 12.5, color: tokens.textPrimary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              profiles.isEmpty
                  ? '계획서 없음'
                  : profiles.map((p) => p.name).join(' · '),
              style: TextStyle(
                fontSize: 12,
                color: profiles.isEmpty ? tokens.textMuted : tokens.textPrimary,
                fontStyle: profiles.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 비활성 시간표: 교사·계획서·교체 건수를 한 줄 요약으로 접는다
  Widget _buildCollapsedCardBody(
    DesignTokens tokens,
    TimetableRegistryEntry entry,
  ) {
    final summary = ref.watch(timetableSummaryProvider(entry.id)).valueOrNull;
    final hasTeacher = entry.hasTeacher;

    final parts = <String>[
      hasTeacher ? entry.teacherName! : '교사 미지정',
      if (summary != null) summary.description,
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 4),
      child: Row(
        children: [
          Icon(
            hasTeacher ? Icons.person_outline : Icons.warning_amber_rounded,
            size: 13,
            color: hasTeacher ? tokens.textMuted : Colors.orange,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: TextStyle(
                fontSize: 12,
                color: hasTeacher ? tokens.textMuted : Colors.orange,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 카드 하단 액션 버튼들
  Widget _buildCardActions(
    TimetableRegistryEntry entry, {
    required bool isActive,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!isActive)
          TextButton.icon(
            onPressed: () => _switchTimetable(entry),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('전환'),
          ),
        TextButton.icon(
          onPressed: () => _renameTimetable(entry),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('이름 변경'),
        ),
        TextButton.icon(
          onPressed: () => _deleteTimetable(entry),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('삭제'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
      ],
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/timetable_registry.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/timetable_registry_provider.dart';
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
  const TimetableFileScreen({super.key});

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

      final entry = await ref
          .read(timetableRegistryProvider.notifier)
          .registerTimetable(
            name: (name != null && name.isNotEmpty) ? name : defaultName,
            fileName: fileName,
            filePath: filePath,
            hash: hash,
            contentHash: contentHash,
          );

      if (entry == null) {
        _showSnackBar('시간표 등록에 실패했습니다.', isError: true);
        return;
      }

      // 5. 방금 추가한 시간표를 활성으로 전환 (첫 시간표면 이미 활성)
      await ref
          .read(timetableRegistryProvider.notifier)
          .switchActive(entry.id);

      if (mounted) {
        _showSnackBar("시간표 '${entry.name}'이(가) 등록되었습니다.");
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
  Future<void> _deleteTimetable(TimetableRegistryEntry entry) async {
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
          content: Text(
            "'${entry.name}'을(를) 삭제하시겠습니까?\n\n"
            '해당 시간표의 교체 목록과 계획서도 함께 삭제되며 되돌릴 수 없습니다.',
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

    return Container(
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
          Row(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              '원본: ${entry.fileName.isEmpty ? '정보 없음' : entry.fileName}',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
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
                icon: Icon(Icons.delete_outline, size: 18),
                label: const Text('삭제'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

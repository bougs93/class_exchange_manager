import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/timetable_database.dart';
import '../../../models/dated_timetable.dart';
import '../../../providers/node_date_edit_provider.dart';
import '../../../providers/timetable_registry_provider.dart';
import '../../../providers/timetable_repository_provider.dart';
import '../../../repositories/timetable_repository.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/logger.dart';
import '../../../providers/week_lessons_cache_provider.dart';

/// "준비 > 기타 설정"의 날짜 기반 데이터 확인 패널 (S4.0)
///
/// SQLite에 저장된 날짜 기반 데이터(lessons·lesson_snapshots)를 **읽기 전용**으로
/// 보여준다. 쓰기 버튼은 없다 — 값을 고치려면 [SemesterPeriodSection]을 쓴다.
/// 목적은 개발/운영 중 "실제로 날짜별 데이터가 잘 쌓이고 있는가"를 눈으로 확인하는 것.
class DatedDataInspectorSection extends ConsumerStatefulWidget {
  const DatedDataInspectorSection({super.key});

  @override
  ConsumerState<DatedDataInspectorSection> createState() =>
      _DatedDataInspectorSectionState();
}

class _DatedDataInspectorSectionState
    extends ConsumerState<DatedDataInspectorSection> {
  String? _selectedTimetableId;

  bool _isLoading = false;
  String? _errorMessage;
  DatedTimetable? _timetable;
  LessonStats? _stats;
  String? _dbPath;

  Future<void> _load() async {
    final timetableId = _selectedTimetableId;
    if (timetableId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = await ref.read(timetableRepositoryProvider.future);
      final timetable = await repo.getTimetable(timetableId);
      final stats = await repo.getLessonStats(timetableId);
      final dbPath = await TimetableDatabase.defaultDatabasePath();
      if (!mounted) return;

      setState(() {
        _timetable = timetable;
        _stats = stats;
        _dbPath = dbPath;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('날짜 기반 데이터 확인 실패: $e', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '데이터를 불러오지 못했습니다.';
      });
    }
  }

  void _onSelectTimetable(String? id) {
    if (id == null || id == _selectedTimetableId) return;
    setState(() {
      _selectedTimetableId = id;
    });
    _load();
  }

  Future<void> _copyDbPath() async {
    final path = _dbPath;
    if (path == null) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('DB 경로를 복사했습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final registryAsync = ref.watch(timetableRegistryProvider);
    final registry = registryAsync.valueOrNull;
    final entries = registry?.timetables ?? const [];

    if (entries.isEmpty) {
      return _buildCard(
        tokens: tokens,
        child: Text(
          '등록된 시간표가 없습니다. 시간표를 먼저 등록하면 여기서 저장된 날짜별 데이터를 확인할 수 있습니다.',
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
      );
    }

    if (_selectedTimetableId == null ||
        !entries.any((e) => e.id == _selectedTimetableId)) {
      _selectedTimetableId = registry?.activeId ?? entries.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    return _buildCard(
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '날짜 기반 데이터 확인 (읽기 전용)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'SQLite에 저장된 날짜별 수업 데이터를 확인합니다. 여기서는 값을 수정할 수 없습니다.',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          _buildTimetableDropdown(entries),
          const SizedBox(height: 8),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            )
          else if (_timetable == null)
            Text(
              '이 시간표는 날짜별 데이터가 없습니다(등록 시 생성되지 않았거나 이전 버전에서 등록됨).',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            )
          else ...[
            _buildTimetableInfo(tokens, _timetable!),
            const SizedBox(height: 8),
            _buildStatsInfo(tokens, _stats!),
            if (_selectedTimetableId == registry?.activeId) ...[
              const SizedBox(height: 8),
              _buildLessonReadPathToggle(tokens),
              const SizedBox(height: 8),
              _buildNodeDateEditToggle(tokens),
            ],
            const SizedBox(height: 8),
            _buildDbPathRow(tokens),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({required DesignTokens tokens, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildTimetableDropdown(List<dynamic> entries) {
    return DropdownButton<String>(
      value: _selectedTimetableId,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      items: [
        for (final entry in entries)
          DropdownMenuItem(
            value: entry.id as String,
            child: Text(entry.name as String, style: const TextStyle(fontSize: 12)),
          ),
      ],
      onChanged: _onSelectTimetable,
    );
  }

  Widget _buildTimetableInfo(DesignTokens tokens, DatedTimetable timetable) {
    String format(DateTime date) {
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
          '${date.day.toString().padLeft(2, '0')}';
    }

    return _buildInfoBlock(tokens, title: '시간표', rows: [
      '이름: ${timetable.name}',
      '학년도·학기: ${timetable.semester.schoolYear}년 ${timetable.semester.semester}학기',
      '기간: ${format(timetable.semester.startDate)} ~ ${format(timetable.semester.endDate)}',
      if (timetable.teacherName != null) '교사명: ${timetable.teacherName}',
      if (timetable.schoolName != null) '학교명: ${timetable.schoolName}',
      '등록 시각: ${timetable.registeredAt}',
    ]);
  }

  Widget _buildStatsInfo(DesignTokens tokens, LessonStats stats) {
    String formatDate(DateTime? date) {
      if (date == null) return '-';
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
          '${date.day.toString().padLeft(2, '0')}';
    }

    return _buildInfoBlock(tokens, title: '저장된 수업 데이터', rows: [
      '전체: ${stats.totalCount}건',
      '활성: ${stats.activeCount}건 · 보관: ${stats.inactiveCount}건',
      '원본 스냅샷: ${stats.snapshotCount}건',
      '날짜 범위: ${formatDate(stats.earliestDate)} ~ ${formatDate(stats.latestDate)}',
    ]);
  }

  Widget _buildInfoBlock(
    DesignTokens tokens, {
    required String title,
    required List<String> rows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          for (final row in rows)
            Text(row, style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
        ],
      ),
    );
  }

  /// 조회 경로 전환 스위치 (S5.5.4/S5.5.5, S5.5.5부터 기본 켜짐).
  ///
  /// 켜져 있으면(기본값) 날짜표시 ON 모드의 그리드 표시·검증이 SQLite
  /// `lessons`를 읽는다(캐시가 아직 준비되지 않은 프레임은 자동으로 기존
  /// 방식으로 폴백한다 — 항상 켜져 있는 2단계 안전장치). 날짜표시 OFF
  /// 모드는 이 스위치와 무관하게 항상 기존 방식을 쓴다(설계상 SQLite를
  /// 절대 읽지 않음). 문제가 있으면 꺼서 재빌드 없이 즉시 예전 방식으로
  /// 되돌릴 수 있다 — 껐다고 SQLite에 쌓인 데이터가 지워지지는 않는다.
  Widget _buildLessonReadPathToggle(DesignTokens tokens) {
    final enabled = ref.watch(lessonReadPathEnabledProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        // 기본값(켜짐)은 평범한 상태이므로 강조하지 않는다 — 꺼서 예전 방식
        // (JSON 합성)으로 되돌린 경우에만 눈에 띄게 표시한다.
        border: Border.all(
          color: enabled ? tokens.cardBorder : Colors.orange.shade700,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SQLite 조회 경로 사용 (S5.5)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: enabled ? tokens.textPrimary : Colors.orange.shade700,
                  ),
                ),
                Text(
                  '"실제 날짜" ON 모드에서만 적용됩니다. 이상이 있으면 꺼서'
                  ' 예전 방식으로 되돌릴 수 있습니다.',
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged:
                (value) =>
                    ref.read(lessonReadPathEnabledProvider.notifier).state =
                        value,
          ),
        ],
      ),
    );
  }

  /// 순환·2중 교체 노드별 날짜 확정 스위치 (S5.6, S5.6.8부터 기본 켜짐).
  ///
  /// 켜져 있으면(기본값) 교체 실행 시점에 참여 노드 전부의 날짜가 즉시
  /// 확정되고("?" 없이 바로 날짜 표시, S5.6.7), 계획서 화면의 순환·2중 행이
  /// 노드(요일·교시) 기준으로 정확한 날짜를 보여주며, 날짜 선택기로 지정한
  /// 날짜가 그 행이 가리키는 노드 하나에만 저장돼 "교체" 화면(날짜표시 ON)
  /// 에도 반영된다. 1:1·보강은 이 스위치와 무관하게 항상 기존 방식 그대로다.
  /// 문제가 있으면 꺼서 S5.6 이전 방식(순환·2중은 항상 "?")으로 재빌드 없이
  /// 즉시 되돌릴 수 있다 — 껐다고 이미 확정된 날짜가 지워지지는 않는다.
  Widget _buildNodeDateEditToggle(DesignTokens tokens) {
    final enabled = ref.watch(nodeDateEditEnabledProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        // 기본값(켜짐)은 평범한 상태이므로 강조하지 않는다 — 꺼서 예전 방식
        // (항상 "?")으로 되돌린 경우에만 눈에 띄게 표시한다.
        border: Border.all(
          color: enabled ? tokens.cardBorder : Colors.orange.shade700,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '순환·2중 교체 노드별 날짜 확정 (S5.6)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: enabled ? tokens.textPrimary : Colors.orange.shade700,
                  ),
                ),
                Text(
                  '교체 실행 시 참여 칸 날짜가 즉시 확정되고, 계획서에서 결강일/교체일을'
                  ' 수정하면 그 칸(노드)에만 반영되어 "교체" 화면 날짜표시에도 나타납니다.'
                  ' 1:1·보강은 영향받지 않습니다. 문제가 있으면 꺼서 예전 방식(항상 "?")으로'
                  ' 되돌릴 수 있습니다.',
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged:
                (value) =>
                    ref.read(nodeDateEditEnabledProvider.notifier).state = value,
          ),
        ],
      ),
    );
  }

  Widget _buildDbPathRow(DesignTokens tokens) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'DB 경로: ${_dbPath ?? '-'}',
            style: TextStyle(fontSize: 11, color: tokens.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: '경로 복사',
          onPressed: _dbPath == null ? null : _copyDbPath,
        ),
      ],
    );
  }
}

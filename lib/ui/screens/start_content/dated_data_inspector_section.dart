import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/timetable_database.dart';
import '../../../models/dated_timetable.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/timetable_registry_provider.dart';
import '../../../providers/timetable_repository_provider.dart';
import '../../../repositories/timetable_repository.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/logger.dart';

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

  /// SQLite exchange_events 저널의 활성(비되돌림) 건수 (S5.2).
  /// JSON 쪽 건수처럼 실시간 반응하지 않고 [_load]/[_refreshDrift] 호출
  /// 시점에만 다시 센다 — 미러 쓰기가 비동기 큐라 정확히 같은 프레임에
  /// 맞춰 갱신할 수 없기 때문에, 대신 새로고침 버튼으로 명시적으로 다시 센다.
  int? _sqliteEventCount;

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
      final events = await repo.getExchangeEvents(timetableId);
      final dbPath = await TimetableDatabase.defaultDatabasePath();
      if (!mounted) return;

      setState(() {
        _timetable = timetable;
        _stats = stats;
        _sqliteEventCount = events.where((e) => !e.isReverted).length;
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
    setState(() => _selectedTimetableId = id);
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
              _buildDriftNotice(tokens),
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

  /// 표시값-SQLite 드리프트 안내 (S4.4, S5.2에서 실제 비교로 확장)
  ///
  /// S5.1부터 교체 실행·삭제·되돌리기가 SQLite `exchange_events`에도 부가
  /// 기록되지만(JSON이 여전히 진실 원본), 이 저널 쓰기는 비동기 큐라
  /// "지금 이 순간" 완전히 일치한다는 보장이 없다. 그래서 JSON 쪽 활성
  /// 건수는 실시간으로(버전 watch) 보여주고, SQLite 쪽은 [_load]/새로고침
  /// 시점의 스냅샷을 보여준다 — 두 값이 다르면 아직 큐가 비워지지 않았거나
  /// 실제 드리프트가 있다는 뜻이므로 새로고침 버튼으로 다시 확인하게 한다.
  /// 위에서 확인하는 시간표가 **활성** 시간표일 때만 표시한다(다른 시간표는
  /// 비교 대상이 아니다).
  Widget _buildDriftNotice(DesignTokens tokens) {
    ref.watch(exchangeListVersionProvider);
    final jsonCount =
        ref.read(exchangeHistoryServiceProvider).getActiveExchangeList().length;
    final sqliteCount = _sqliteEventCount;
    final mismatch = sqliteCount != null && sqliteCount != jsonCount;
    final color = mismatch ? Colors.orange.shade700 : tokens.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border.all(
          color: mismatch ? Colors.orange.shade700 : tokens.cardBorder,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              sqliteCount == null
                  ? '교체 이력: JSON $jsonCount건 (SQLite 확인 중...)'
                  : '교체 이력: JSON $jsonCount건 · SQLite 저널 $sqliteCount건'
                      '${mismatch ? ' · 불일치 ${(jsonCount - sqliteCount).abs()}건' : ' · 일치'}',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: mismatch ? FontWeight.w600 : null,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 14),
            tooltip: '다시 확인',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 6),
            onPressed: _isLoading ? null : _load,
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

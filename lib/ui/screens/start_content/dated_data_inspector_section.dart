import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/timetable_database.dart';
import '../../../models/dated_timetable.dart';
import '../../../providers/exchange_screen_provider.dart';
import '../../../providers/node_date_edit_provider.dart';
import '../../../providers/selected_week_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/show_week_header_provider.dart';
import '../../../providers/timetable_registry_provider.dart';
import '../../../providers/timetable_repository_provider.dart';
import '../../../repositories/timetable_repository.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/logger.dart';
import '../../../utils/resolved_week.dart';
import '../../../utils/week_date_calculator.dart';
import '../../../providers/week_lessons_cache_provider.dart';

/// [DatedDataInspectorSection._runShadowComparison]의 결과 한 칸 (S5.5.2).
class _ShadowComparisonResult {
  final int screenNonEmptyCount;
  final int sqliteNonEmptyCount;
  final int mismatchCount;
  final int weekCount;

  const _ShadowComparisonResult({
    required this.screenNonEmptyCount,
    required this.sqliteNonEmptyCount,
    required this.mismatchCount,
    required this.weekCount,
  });
}

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

  /// S5.5.2 섀도우 비교 상태 — 버튼을 눌러야만 계산한다(자동 실행 아님).
  bool _isComparing = false;
  String? _comparisonError;
  _ShadowComparisonResult? _comparisonResult;

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
    setState(() {
      _selectedTimetableId = id;
      _comparisonResult = null;
      _comparisonError = null;
    });
    _load();
  }

  /// "화면 합성" 대 "SQLite `lessons`" 정합성을 직접 비교한다 (S5.5.2).
  ///
  /// 아직 어떤 화면도 SQLite 읽기 경로로 전환되지 않았으므로(S5.5.4 이전),
  /// 여기서 계산하는 값은 **"만약 지금 전환한다면 어떻게 보일지"**를
  /// 미리 확인하는 용도다. 반드시 이 결과가 "불일치 0칸"으로 나오는 것을
  /// 여러 교체 유형·여러 주에서 사용자가 직접 확인해야 S5.5.3(실제 전환
  /// 준비)으로 진행할 수 있다 — S5.5 설계 검토의 필수 게이트.
  ///
  /// 비교 대상 시간표는 **활성 시간표이면서 지금 교체 화면에 열려 있는
  /// 시간표**로 제한한다 — "화면 합성"은 `exchangeScreenProvider`가 들고
  /// 있는 실제 `TimeSlot` 원본이 있어야 재현할 수 있기 때문이다.
  ///
  /// 비교할 주는 (1) 지금 교체 화면에서 보고 있는 주, (2) 활성 교체 이벤트
  /// 각각의 결강일·교체일이 속한 주를 모두 모은 것이다 — 실제로 무언가
  /// 달라질 가능성이 있는 주만 모아 "여러 주"를 자동으로 확보한다.
  Future<void> _runShadowComparison() async {
    final timetableId = _selectedTimetableId;
    if (timetableId == null) return;

    setState(() {
      _isComparing = true;
      _comparisonError = null;
    });

    try {
      final timetableData = ref.read(
        exchangeScreenProvider.select((state) => state.timetableData),
      );
      if (timetableData == null) {
        setState(() {
          _isComparing = false;
          _comparisonError = '교체 화면에서 이 시간표를 먼저 연 뒤 다시 확인하세요.';
        });
        return;
      }

      final base = timetableData.timeSlots;
      final events =
          ref.read(exchangeHistoryServiceProvider).getActiveExchangeList();
      final showWeekHeader = ref.read(showWeekHeaderProvider);
      final selectedWeek = ref.read(selectedWeekProvider);

      final weeks = <DateTime>{WeekDateCalculator.getWeekMonday(selectedWeek)};
      for (final event in events) {
        weeks.add(WeekDateCalculator.getWeekMonday(event.absenceDate));
        weeks.add(WeekDateCalculator.getWeekMonday(event.substitutionDate));
      }

      final repo = await ref.read(timetableRepositoryProvider.future);
      // 비교 직전에 재생을 맞춰 둔다 — lessons는 파생 뷰이므로 새로고침은
      // 안전하다(진실 원본인 exchange_events·JSON은 건드리지 않는다).
      await repo.replayInto(timetableId);

      var screenNonEmptyCount = 0;
      var sqliteNonEmptyCount = 0;
      var mismatchCount = 0;

      for (final weekMonday in weeks) {
        final screenSlots =
            (showWeekHeader
                    ? ResolvedWeek.dateAware(
                      base: base,
                      events: events,
                      weekMonday: weekMonday,
                    )
                    : ResolvedWeek.of(
                      base: base,
                      events: events,
                      weekMonday: weekMonday,
                    ))
                .toTimeSlots(base);

        final touchedLessons = await repo.getTouchedLessonsForWeek(
          timetableId,
          weekMonday,
        );
        final sqliteSlots =
            ResolvedWeek.fromLessons(
              base: base,
              touchedLessons: touchedLessons,
              weekMonday: weekMonday,
            ).toTimeSlots(base);

        for (var i = 0; i < base.length; i++) {
          final screenSlot = screenSlots[i];
          final sqliteSlot = sqliteSlots[i];
          if (screenSlot.isNotEmpty) screenNonEmptyCount++;
          if (sqliteSlot.isNotEmpty) sqliteNonEmptyCount++;
          if (screenSlot.subject != sqliteSlot.subject ||
              screenSlot.className != sqliteSlot.className) {
            mismatchCount++;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isComparing = false;
        _comparisonResult = _ShadowComparisonResult(
          screenNonEmptyCount: screenNonEmptyCount,
          sqliteNonEmptyCount: sqliteNonEmptyCount,
          mismatchCount: mismatchCount,
          weekCount: weeks.length,
        );
      });
    } catch (e) {
      AppLogger.error('섀도우 비교 실패: $e', e);
      if (!mounted) return;
      setState(() {
        _isComparing = false;
        _comparisonError = '비교 중 오류가 발생했습니다.';
      });
    }
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
              const SizedBox(height: 8),
              _buildShadowComparisonPanel(tokens),
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

  /// "화면 합성 N칸 · SQLite M칸 · 불일치 K칸" 섀도우 비교 패널 (S5.5.2).
  ///
  /// 자동으로 실행하지 않는다 — 버튼을 눌러야 계산한다(여러 주를 순회하며
  /// SQLite 쿼리를 여러 번 실행하므로, 패널을 열 때마다 매번 돌릴 필요는
  /// 없다). 이 값 자체는 어떤 화면 동작에도 영향을 주지 않는다(읽기 전용).
  Widget _buildShadowComparisonPanel(DesignTokens tokens) {
    final result = _comparisonResult;
    final mismatch = result != null && result.mismatchCount > 0;
    final borderColor =
        mismatch ? Colors.orange.shade700 : tokens.cardBorder;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '화면 표시 vs SQLite 정합성 확인 (S5.5.2, 실험용)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isComparing ? null : _runShadowComparison,
                child: Text(
                  _isComparing ? '확인 중...' : '지금 확인',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          if (_comparisonError != null)
            Text(
              _comparisonError!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            )
          else if (result != null)
            Text(
              '화면 합성 ${result.screenNonEmptyCount}칸 · '
              'SQLite ${result.sqliteNonEmptyCount}칸 · '
              '불일치 ${result.mismatchCount}칸 '
              '(비교한 주: ${result.weekCount}개)',
              style: TextStyle(
                fontSize: 11,
                color: mismatch ? Colors.orange.shade700 : tokens.textMuted,
                fontWeight: mismatch ? FontWeight.w600 : null,
              ),
            ),
        ],
      ),
    );
  }

  /// 조회 경로 전환 스위치 (S5.5.4/S5.5.5 — 3단계 롤백 중 1단계).
  ///
  /// 켜면 날짜표시 ON 모드의 그리드 표시·검증이 SQLite `lessons`를 읽기
  /// 시작한다(캐시가 아직 준비되지 않은 프레임은 자동으로 기존 방식으로
  /// 폴백한다 — 항상 켜져 있는 2단계 안전장치). 날짜표시 OFF 모드는 이
  /// 스위치와 무관하게 항상 기존 방식을 쓴다(설계상 SQLite를 절대 읽지
  /// 않음). 기본값은 꺼짐이며, 재빌드 없이 즉시 되돌릴 수 있다.
  Widget _buildLessonReadPathToggle(DesignTokens tokens) {
    final enabled = ref.watch(lessonReadPathEnabledProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border.all(
          color: enabled ? Colors.orange.shade700 : tokens.cardBorder,
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
                  'SQLite 조회 경로 사용 (S5.5.4, 실험적)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.orange.shade700 : tokens.textPrimary,
                  ),
                ),
                Text(
                  '날짜표시 ON 모드에서만 적용됩니다. 이상이 있으면 바로 꺼서'
                  ' 기존 방식으로 되돌릴 수 있습니다.',
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

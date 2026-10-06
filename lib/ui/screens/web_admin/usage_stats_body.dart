import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/nav_indices.dart';
import '../../../models/usage_event.dart';
import '../../../providers/web_services_provider.dart';
import '../../../utils/logger.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/usage_stats_aggregator.dart';

/// 웹 사용 통계 본문 (Scaffold 없음).
///
/// `UsageStatsScreen`의 껍데기 안에 그대로 들어가고, 접속 설정 4탭 개편의
/// 통계 탭에도 같은 위젯을 임베드한다. 로직·문구·확인 다이얼로그는 이동 전과
/// 동일하다. 탭을 오갔다 돌아와도 재조회하지 않게 keep-alive를 켠다.
class UsageStatsBody extends ConsumerStatefulWidget {
  const UsageStatsBody({super.key});

  @override
  ConsumerState<UsageStatsBody> createState() => _UsageStatsBodyState();
}

enum _Preset { week, month, last30, custom }

class _UsageStatsBodyState extends ConsumerState<UsageStatsBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  UsagePeriodUnit _unit = UsagePeriodUnit.day;
  _Preset _preset = _Preset.last30;
  late DateTime _from;
  late DateTime _to;

  UsageSummary? _summary;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  /// 마지막으로 불러온 시각 (새로고침 표시용).
  DateTime? _refreshedAt;

  /// 교사 표 정렬 (열 인덱스, 오름차순 여부)
  int _sortColumn = 1;
  bool _sortAscending = false;

  /// 가로로 긴 표(추이·교사별)용 스크롤 컨트롤러 — 스크롤바와 공유해
  /// 잘린 쪽이 있음을 항상 드러낸다.
  final _trendScrollController = ScrollController();
  final _teacherScrollController = ScrollController();

  @override
  void dispose() {
    _trendScrollController.dispose();
    _teacherScrollController.dispose();
    super.dispose();
  }

  /// 추이 표·교사 표 공통 열: (제목, 카운터 키).
  /// 교사 표의 0열(교사명)·마지막 열(마지막 사용일)은 별도.
  static final List<(String, String)> _teacherCols = [
    ('접속', UsageKeys.visits),
    // 페이지별 진입 횟수 (상단 탭 이동 기준)
    for (final i in const [
      NavIndices.exchange,
      NavIndices.planOutput,
      NavIndices.notice,
      NavIndices.personalSchedule,
    ])
      (UsageKeys.tabLabels[i], UsageKeys.tab(i)),
    ('생성', UsageKeys.planCreate),
    ('계획서 출력', UsageKeys.planOutput),
    ('학급 출력', UsageKeys.classOutput),
    ('계획서 PDF 저장', UsageKeys.planPdfSave),
    ('학급 PDF 저장', UsageKeys.classPdfSave),
  ];

  @override
  void initState() {
    super.initState();
    final today = _today();
    _to = today;
    _from = today.subtract(const Duration(days: 29));
    _load();
  }

  /// KST 기준 오늘 (시각 없는 날짜).
  static DateTime _today() => DateTime.parse(UsageStatsAggregator.todayKstId());

  void _applyPreset(_Preset preset) {
    final today = _today();
    setState(() {
      _preset = preset;
      _to = today;
      switch (preset) {
        case _Preset.week:
          _from = today.subtract(Duration(days: today.weekday - 1));
        case _Preset.month:
          _from = DateTime(today.year, today.month, 1);
        case _Preset.last30:
          _from = today.subtract(const Duration(days: 29));
        case _Preset.custom:
          break;
      }
    });
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: _today().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: '통계 기간 선택',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preset = _Preset.custom;
      _from = picked.start;
      _to = picked.end;
    });
    _load();
  }

  /// 조회 순번 — 기간을 연달아 바꾸면 늦게 도착한 옛 응답이 새 결과를
  /// 덮어쓰지 않게 마지막 요청만 반영한다.
  int _loadSeq = 0;

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final days = await ref
          .read(usageStatsServiceProvider)
          .fetchRange(_from, _to);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _summary = UsageStatsAggregator.aggregate(days, _unit);
        _loading = false;
        _refreshedAt = DateTime.now();
      });
    } catch (e) {
      AppLogger.warning('사용 통계 조회 실패: $e');
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = '통계를 불러오지 못했습니다. 네트워크와 Firestore 규칙을 확인하세요.';
        _loading = false;
      });
    }
  }

  void _changeUnit(UsagePeriodUnit unit) {
    if (unit == _unit) return;
    setState(() {
      _unit = unit;
    });
    _load();
  }

  Future<void> _delete({required bool all}) async {
    if (_busy) return;
    final service = ref.read(usageStatsServiceProvider);
    setState(() => _busy = true);
    try {
      final count =
          all
              ? await service.countRange()
              : await service.countRange(from: _from, to: _to);
      if (!mounted) return;
      if (count == 0) {
        SnackBarHelper.showInfo(context, '삭제할 통계가 없습니다.');
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(all ? '전체 초기화' : '기간 통계 삭제'),
              content: Text(
                all
                    ? '저장된 모든 사용 통계(일별 문서 $count개)를 삭제합니다.\n'
                        '되돌릴 수 없습니다.'
                    : '${_fmt(_from)} ~ ${_fmt(_to)}의 사용 통계'
                        '(일별 문서 $count개)를 삭제합니다.\n되돌릴 수 없습니다.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('삭제'),
                ),
              ],
            ),
      );
      if (confirm != true || !mounted) return;
      final deleted =
          all
              ? await service.deleteRange()
              : await service.deleteRange(from: _from, to: _to);
      if (!mounted) return;
      SnackBarHelper.showSuccess(context, '통계 문서 $deleted개를 삭제했습니다.');
      await _load();
    } catch (e) {
      AppLogger.warning('사용 통계 삭제 실패: $e');
      if (mounted) SnackBarHelper.showError(context, '삭제에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 해당 교사의 선택 기간 통계만 삭제한다 (합계도 함께 차감).
  Future<void> _deleteTeacher(String name) async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('교사 통계 삭제'),
            content: Text(
              "'$name'의 ${_fmt(_from)} ~ ${_fmt(_to)} 통계를 삭제합니다.\n"
              '합계에서도 함께 빠집니다. 되돌릴 수 없습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final touched = await ref
          .read(usageStatsServiceProvider)
          .deleteTeacher(from: _from, to: _to, teacher: name);
      if (!mounted) return;
      if (touched == 0) {
        SnackBarHelper.showInfo(context, '삭제할 통계가 없습니다.');
      } else {
        SnackBarHelper.showSuccess(context, "'$name' 통계를 삭제했습니다.");
      }
      await _load();
    } catch (e) {
      AppLogger.warning('교사 통계 삭제 실패: $e');
      if (mounted) SnackBarHelper.showError(context, '삭제에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _fmt(DateTime d) => UsageStatsAggregator.dateId(d);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildControls(),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red))
        else if (_summary != null)
          ..._buildBody(_summary!),
        const Divider(height: 32),
        _buildReset(),
      ],
    );
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('보기 단위', style: TextStyle(fontSize: 12)),
            SegmentedButton<UsagePeriodUnit>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: UsagePeriodUnit.day, label: Text('일')),
                ButtonSegment(value: UsagePeriodUnit.week, label: Text('주')),
                ButtonSegment(value: UsagePeriodUnit.month, label: Text('월')),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => _changeUnit(s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _presetChip('이번 주', _Preset.week),
            _presetChip('이번 달', _Preset.month),
            _presetChip('최근 30일', _Preset.last30),
            ChoiceChip(
              label: const Text('직접 지정'),
              selected: _preset == _Preset.custom,
              onSelected: (_) => _pickRange(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '기간: ${_fmt(_from)} ~ ${_fmt(_to)}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Row(
          children: [
            if (_refreshedAt != null)
              Expanded(
                child: Text(
                  '업데이트: ${_two(_refreshedAt!.hour)}:${_two(_refreshedAt!.minute)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              )
            else
              const Spacer(),
            TextButton.icon(
              onPressed: (_loading || _busy) ? null : _load,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
            ),
          ],
        ),
      ],
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  Widget _presetChip(String label, _Preset preset) => ChoiceChip(
    label: Text(label),
    selected: _preset == preset,
    onSelected: (_) => _applyPreset(preset),
  );

  List<Widget> _buildBody(UsageSummary s) {
    return [
      _sectionTitle('기간 합계'),
      _statLine([
        ('접속', s.count(UsageKeys.visits)),
        ('고유 접속자', s.uniqueVisitors),
        ('사용 교사', s.activeTeachers),
        ('계획서 생성', s.count(UsageKeys.planCreate)),
        ('계획서 출력', s.count(UsageKeys.planOutput)),
        ('학급 출력', s.count(UsageKeys.classOutput)),
        ('계획서 PDF', s.count(UsageKeys.planPdfSave)),
        ('학급 PDF', s.count(UsageKeys.classPdfSave)),
      ]),
      const SizedBox(height: 20),
      _sectionTitle(switch (_unit) {
        UsagePeriodUnit.day => '일별 추이',
        UsagePeriodUnit.week => '주별 추이 (월요일 시작)',
        UsagePeriodUnit.month => '월별 추이',
      }),
      _buildTrend(s),
      const SizedBox(height: 20),
      _sectionTitle('탭별 사용 (진입 횟수)'),
      _buildTabBars(s),
      const SizedBox(height: 20),
      _sectionTitle('교사별 사용'),
      const Text(
        '교사 이름이 그대로 저장됩니다. 이름을 설정하지 않은 사용은 '
        "'$kUsageUnnamedTeacher'으로, 관리자로 로그인한 사용은 "
        "'$kUsageAdminBucket'로 묶입니다.",
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      const SizedBox(height: 6),
      _buildTeacherTable(s),
    ];
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );

  /// 기간 합계 칩 한 줄: `[라벨 숫자]` 작은 칩 (폭이 좁을 때만 칩 단위로 줄바꿈).
  Widget _statLine(List<(String, int)> items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (label, value) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$label ',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$value',
                  key: ValueKey('usage-stat-$label'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 가로로 긴 표 감싸기 — 스크롤바를 항상 보여줘 잘린 열이
  /// 있음을 드러낸다 (스크롤바 없이는 잘린 쪽이 있는지 알 수 없다).
  Widget _hScroll(Widget child, ScrollController controller) {
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: controller,
        child: child,
      ),
    );
  }

  Widget _buildTrend(UsageSummary s) {
    if (s.buckets.isEmpty) return const Text('기록이 없습니다.');
    return _hScroll(
      DataTable(
        columnSpacing: 10,
        headingRowHeight: 30,
        dataRowMinHeight: 26,
        dataRowMaxHeight: 28,
        headingTextStyle: const TextStyle(fontSize: 11),
        dataTextStyle: const TextStyle(fontSize: 11),
        columns: [
          const DataColumn(label: Text('기간')),
          for (final c in _teacherCols)
            DataColumn(label: Text(c.$1), numeric: true),
        ],
        rows: [
          for (final b in s.buckets)
            DataRow(
              cells: [
                DataCell(Text(b.label)),
                for (final c in _teacherCols)
                  DataCell(Text('${b.count(c.$2)}')),
              ],
            ),
        ],
      ),
      _trendScrollController,
    );
  }

  Widget _buildTabBars(UsageSummary s) {
    final counts = [for (final k in UsageKeys.tabKeys) s.count(k)];
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    // 표들과 균형을 맞추려고 막대 영역 폭을 제한한다 (전체 폭을 쓰면
    // 듬성듬성해 보인다).
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
      children: [
        for (var i = 0; i < counts.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    UsageKeys.tabLabels[i],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w =
                          maxCount == 0
                              ? 0.0
                              : c.maxWidth * counts[i] / maxCount;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: w,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade400,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${counts[i]}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTeacherTable(UsageSummary s) {
    if (s.teachers.isEmpty) return const Text('기록이 없습니다.');
    final rows = [...s.teachers];
    final lastCol = _teacherCols.length + 1;
    int cmp(TeacherUsage a, TeacherUsage b) {
      if (_sortColumn == 0) return a.name.compareTo(b.name);
      if (_sortColumn == lastCol) return a.lastSeen.compareTo(b.lastSeen);
      final key = _teacherCols[_sortColumn - 1].$2;
      return a.count(key).compareTo(b.count(key));
    }

    rows.sort((a, b) => _sortAscending ? cmp(a, b) : cmp(b, a));

    void onSort(int col, bool asc) => setState(() {
      _sortColumn = col;
      _sortAscending = asc;
    });

    return _hScroll(
      DataTable(
        sortColumnIndex: _sortColumn,
        sortAscending: _sortAscending,
        columnSpacing: 10,
        headingRowHeight: 30,
        dataRowMinHeight: 26,
        dataRowMaxHeight: 28,
        headingTextStyle: const TextStyle(fontSize: 11),
        dataTextStyle: const TextStyle(fontSize: 11),
        columns: [
          DataColumn(label: const Text('교사'), onSort: onSort),
          for (final c in _teacherCols)
            DataColumn(label: Text(c.$1), numeric: true, onSort: onSort),
          DataColumn(label: const Text('마지막 사용일'), onSort: onSort),
          const DataColumn(label: Text('관리')),
        ],
        rows: [
          for (final t in rows)
            DataRow(
              cells: [
                DataCell(Text(t.name)),
                for (final c in _teacherCols)
                  DataCell(Text('${t.count(c.$2)}')),
                DataCell(Text(t.lastSeen)),
                DataCell(
                  IconButton(
                    tooltip: "'${t.name}' 통계 삭제",
                    icon: const Icon(Icons.delete_outline, size: 16),
                    onPressed: _busy ? null : () => _deleteTeacher(t.name),
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      _teacherScrollController,
    );
  }

  Widget _buildReset() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('초기화'),
        const Text(
          '삭제한 통계는 되돌릴 수 없습니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => _delete(all: false),
              child: const Text('선택한 기간 삭제'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _delete(all: true),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('전체 초기화'),
            ),
          ],
        ),
      ],
    );
  }
}

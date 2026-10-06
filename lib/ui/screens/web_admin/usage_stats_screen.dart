import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/nav_indices.dart';
import '../../../models/usage_event.dart';
import '../../../providers/web_services_provider.dart';
import '../../../utils/logger.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/usage_stats_aggregator.dart';

/// 관리자 전용 웹 사용 통계 화면.
///
/// 일별 문서를 기간 단위로 읽어 일/주/월로 합산해 보여 주고, 기간 삭제·전체
/// 초기화를 제공한다. 진입은 `WebAdminSettingsScreen`(관리자 인증 후)에서만 한다.
class UsageStatsScreen extends ConsumerStatefulWidget {
  const UsageStatsScreen({super.key});

  @override
  ConsumerState<UsageStatsScreen> createState() => _UsageStatsScreenState();
}

enum _Preset { week, month, last30, custom }

class _UsageStatsScreenState extends ConsumerState<UsageStatsScreen> {
  UsagePeriodUnit _unit = UsagePeriodUnit.day;
  _Preset _preset = _Preset.last30;
  late DateTime _from;
  late DateTime _to;

  UsageSummary? _summary;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  /// 교사 표 정렬 (열 인덱스, 오름차순 여부)
  int _sortColumn = 1;
  bool _sortAscending = false;

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final days = await ref
          .read(usageStatsServiceProvider)
          .fetchRange(_from, _to);
      if (!mounted) return;
      setState(() {
        _summary = UsageStatsAggregator.aggregate(days, _unit);
        _loading = false;
      });
    } catch (e) {
      AppLogger.warning('사용 통계 조회 실패: $e');
      if (!mounted) return;
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

  static String _fmt(DateTime d) => UsageStatsAggregator.dateId(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용 통계')),
      body: SafeArea(
        child: ListView(
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
        ),
      ),
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
      ],
    );
  }

  Widget _presetChip(String label, _Preset preset) => ChoiceChip(
    label: Text(label),
    selected: _preset == preset,
    onSelected: (_) => _applyPreset(preset),
  );

  List<Widget> _buildBody(UsageSummary s) {
    return [
      _sectionTitle('기간 합계'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _card('접속 수', s.count(UsageKeys.visits)),
          _card('고유 접속자', s.uniqueVisitors),
          _card('사용 교사 수', s.activeTeachers),
          _card('계획서 생성', s.count(UsageKeys.planCreate)),
          _card('계획서 출력', s.count(UsageKeys.planOutput)),
          _card('학급 출력', s.count(UsageKeys.classOutput)),
          _card('계획서 PDF 저장', s.count(UsageKeys.planPdfSave)),
          _card('학급 PDF 저장', s.count(UsageKeys.classPdfSave)),
        ],
      ),
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

  Widget _card(String label, int value) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            '$value',
            key: ValueKey('usage-card-$label'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildTrend(UsageSummary s) {
    if (s.buckets.isEmpty) return const Text('기록이 없습니다.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
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
    );
  }

  Widget _buildTabBars(UsageSummary s) {
    final counts = [for (final k in UsageKeys.tabKeys) s.count(k)];
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sortColumn,
        sortAscending: _sortAscending,
        columnSpacing: 20,
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        columns: [
          DataColumn(label: const Text('교사'), onSort: onSort),
          for (final c in _teacherCols)
            DataColumn(label: Text(c.$1), numeric: true, onSort: onSort),
          DataColumn(label: const Text('마지막 사용일'), onSort: onSort),
        ],
        rows: [
          for (final t in rows)
            DataRow(
              cells: [
                DataCell(Text(t.name)),
                for (final c in _teacherCols)
                  DataCell(Text('${t.count(c.$2)}')),
                DataCell(Text(t.lastSeen)),
              ],
            ),
        ],
      ),
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

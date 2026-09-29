import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/school_semester.dart';
import '../../../models/timetable_registry.dart';
import '../../../providers/timetable_registry_provider.dart';
import '../../../providers/timetable_repository_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/logger.dart';

/// "준비 > 기타 설정"의 학기 기간 반영 섹션 (S3a)
///
/// 등록된 시간표별로 SQLite에 저장된 날짜 기반 학기 범위(S2·S3)를 확인하고
/// 고칠 수 있다. 여러 시간표 중 하나를 선택해서 편집하며, **선택한 시간표만**
/// 바뀐다(다른 시간표를 일괄 변경하지 않는다). 입력 중인 값(초안)과 실제
/// 적용된 값을 분리한다 — "반영"을 눌러야만 실제로 저장·재생성된다.
class SemesterPeriodSection extends ConsumerStatefulWidget {
  const SemesterPeriodSection({super.key});

  @override
  ConsumerState<SemesterPeriodSection> createState() =>
      _SemesterPeriodSectionState();
}

class _SemesterPeriodSectionState extends ConsumerState<SemesterPeriodSection> {
  String? _selectedTimetableId;

  // 최초 렌더 시 아직 _loadAppliedForSelected()가 끝나기 전에 _draftYear/
  // _draftSemesterNumber가 null인 채로 편집기(SegmentedButton 포함)를 그리면
  // "selected.length > 0" assertion이 터진다 — 기본값을 true로 두어 첫 프레임은
  // 항상 로딩 표시부터 시작한다.
  bool _isLoadingApplied = true;
  bool _hasNoDatedData = false;

  int? _draftYear;
  int? _draftSemesterNumber;
  DateTime? _draftStart;
  DateTime? _draftEnd;

  bool _isApplying = false;
  String? _errorMessage;

  Future<void> _loadAppliedForSelected() async {
    final timetableId = _selectedTimetableId;
    if (timetableId == null) return;

    setState(() {
      _isLoadingApplied = true;
      _hasNoDatedData = false;
      _errorMessage = null;
    });

    try {
      final repo = await ref.read(timetableRepositoryProvider.future);
      final applied = await repo.getTimetable(timetableId);
      if (!mounted) return;

      setState(() {
        _hasNoDatedData = applied == null;
        if (applied != null) {
          _draftYear = applied.semester.schoolYear;
          _draftSemesterNumber = applied.semester.semester;
          _draftStart = applied.semester.startDate;
          _draftEnd = applied.semester.endDate;
        }
        _isLoadingApplied = false;
      });
    } catch (e) {
      AppLogger.error('학기 기간 조회 실패: $e', e);
      if (!mounted) return;
      setState(() {
        _isLoadingApplied = false;
        _errorMessage = '저장된 학기 정보를 불러오지 못했습니다.';
      });
    }
  }

  void _onSelectTimetable(String? id) {
    if (id == null || id == _selectedTimetableId) return;
    setState(() => _selectedTimetableId = id);
    _loadAppliedForSelected();
  }

  void _onYearOrSemesterChanged({int? year, int? semesterNumber}) {
    final newYear = year ?? _draftYear;
    final newSemesterNumber = semesterNumber ?? _draftSemesterNumber;
    if (newYear == null || newSemesterNumber == null) return;

    // 학년도·학기를 바꾸면 그 조합의 기본 기간으로 자동 채운다(계획서 §4.1).
    final def = SchoolSemester.defaultFor(
      schoolYear: newYear,
      semester: newSemesterNumber,
    );
    setState(() {
      _draftYear = newYear;
      _draftSemesterNumber = newSemesterNumber;
      _draftStart = def.startDate;
      _draftEnd = def.endDate;
    });
  }

  void _restoreDefaults() {
    if (_draftYear == null || _draftSemesterNumber == null) return;
    final def = SchoolSemester.defaultFor(
      schoolYear: _draftYear!,
      semester: _draftSemesterNumber!,
    );
    setState(() {
      _draftStart = def.startDate;
      _draftEnd = def.endDate;
      _errorMessage = null;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _draftStart : _draftEnd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _draftStart = picked;
      } else {
        _draftEnd = picked;
      }
      _errorMessage = null;
    });
  }

  Future<void> _apply() async {
    final timetableId = _selectedTimetableId;
    final year = _draftYear;
    final semesterNumber = _draftSemesterNumber;
    final start = _draftStart;
    final end = _draftEnd;
    if (timetableId == null ||
        year == null ||
        semesterNumber == null ||
        start == null ||
        end == null) {
      return;
    }

    if (end.isBefore(start)) {
      setState(() => _errorMessage = '종료일이 시작일보다 빠를 수 없습니다.');
      return;
    }

    setState(() {
      _isApplying = true;
      _errorMessage = null;
    });

    try {
      final repo = await ref.read(timetableRepositoryProvider.future);
      final newSemester = SchoolSemester(
        schoolYear: year,
        semester: semesterNumber,
        startDate: start,
        endDate: end,
      );
      final result = await repo.applyPeriodChange(
        timetableId: timetableId,
        newSemester: newSemester,
      );

      if (!mounted) return;
      await _loadAppliedForSelected();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '학기 기간을 반영했습니다. '
            '추가 ${result.addedCount}건 · 재활성화 ${result.reactivatedCount}건 · '
            '보관 처리 ${result.deactivatedCount}건',
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('학기 기간 반영 실패: $e', e);
      if (!mounted) return;
      setState(() => _errorMessage = '반영 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
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
          '등록된 시간표가 없습니다. 시간표를 먼저 등록하면 여기서 학기 기간을 확인·수정할 수 있습니다.',
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
      );
    }

    if (_selectedTimetableId == null ||
        !entries.any((e) => e.id == _selectedTimetableId)) {
      _selectedTimetableId = registry?.activeId ?? entries.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAppliedForSelected();
      });
    }

    return _buildCard(
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '학기 기간',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '엑셀 등록 시 자동으로 추정된 학기 범위를 여기서 확인·수정할 수 있습니다. '
            '선택한 시간표에만 적용되며, 다른 시간표는 바뀌지 않습니다.',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          _buildTimetableDropdown(entries),
          const SizedBox(height: 8),
          if (_isLoadingApplied)
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
          else if (_hasNoDatedData)
            Text(
              '이 시간표는 날짜별 데이터가 없습니다(등록 시 생성되지 않았거나 이전 버전에서 '
              '등록됨). 기간을 여기서 새로 지정할 수 없습니다 — 시간표를 다시 등록해 주세요.',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            )
          else ...[
            _buildYearSemesterRow(tokens),
            const SizedBox(height: 8),
            _buildDateRow(tokens),
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
            const SizedBox(height: 10),
            _buildActionButtons(),
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

  Widget _buildTimetableDropdown(List<TimetableRegistryEntry> entries) {
    return DropdownButton<String>(
      value: _selectedTimetableId,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      items: [
        for (final entry in entries)
          DropdownMenuItem(
            value: entry.id,
            child: Text(entry.name, style: const TextStyle(fontSize: 12)),
          ),
      ],
      onChanged: _onSelectTimetable,
    );
  }

  Widget _buildYearSemesterRow(DesignTokens tokens) {
    final currentYear = DateTime.now().year;
    final years = {
      currentYear - 1,
      currentYear,
      currentYear + 1,
      currentYear + 2,
      if (_draftYear != null) _draftYear!,
    }.toList()..sort();

    return Row(
      children: [
        Text(
          '학년도',
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: _draftYear,
          underline: const SizedBox.shrink(),
          items: [
            for (final year in years)
              DropdownMenuItem(
                value: year,
                child: Text('$year', style: const TextStyle(fontSize: 12)),
              ),
          ],
          onChanged: (year) => _onYearOrSemesterChanged(year: year),
        ),
        const SizedBox(width: 16),
        Text(
          '학기',
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
        const SizedBox(width: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1학기')),
            ButtonSegment(value: 2, label: Text('2학기')),
          ],
          selected: {if (_draftSemesterNumber != null) _draftSemesterNumber!},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            _onYearOrSemesterChanged(semesterNumber: selection.first);
          },
        ),
      ],
    );
  }

  Widget _buildDateRow(DesignTokens tokens) {
    String format(DateTime? date) {
      if (date == null) return '-';
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
          '${date.day.toString().padLeft(2, '0')}';
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () => _pickDate(isStart: true),
          child: Text('시작일 ${format(_draftStart)}'),
        ),
        Text('~', style: TextStyle(color: tokens.textSecondary)),
        OutlinedButton(
          onPressed: () => _pickDate(isStart: false),
          child: Text('종료일 ${format(_draftEnd)}'),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        TextButton(
          onPressed: _isApplying ? null : _restoreDefaults,
          child: const Text('기본값으로 복원'),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _isApplying ? null : _apply,
          child:
              _isApplying
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('반영'),
        ),
      ],
    );
  }
}

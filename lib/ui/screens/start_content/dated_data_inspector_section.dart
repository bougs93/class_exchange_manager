import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/dated_timetable.dart';
import '../../../providers/combined_view_switch_provider.dart';
import '../../../providers/exchange_screen_provider.dart';
import '../../../providers/node_date_edit_provider.dart';
import '../../../providers/timetable_registry_provider.dart';
import '../../../providers/timetable_repository_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/snackbar_helper.dart';
import '../../widgets/app_switch.dart';
import '../../../utils/logger.dart';
import '../../../providers/week_lessons_cache_provider.dart';

/// "준비 > 기타 설정"의 날짜 기반 기능 설정 패널 (S4.0)
///
/// S5.5/S5.6 검증이 끝나 데이터 확인용 정보 블록(시간표 정보, 저장된 수업
/// 데이터, DB 경로)은 삭제했다(2026-09-30) — 이제 실제로 쓰는 롤백 스위치·
/// 사용자 설정 토글만 남긴다.
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
  bool _isCreating = false;
  String? _errorMessage;
  DatedTimetable? _timetable;

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
      if (!mounted) return;

      setState(() {
        _timetable = timetable;
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

  /// "지금 만들기" — 등록은 돼 있는데 SQLite 날짜 데이터만 없는 시간표를
  /// (예: "모든 데이터 삭제" 후 레지스트리 항목만 남은 경우) 그 자리에서
  /// 즉시 복구한다.
  ///
  /// `TimetableRepository.ensureDatedBackfill`을 그대로 재사용한다 — S3
  /// 이전 시간표(레지스트리는 있는데 SQLite `timetables` 행이 없는 경우)를
  /// 자동 복구하려고 만든 것과 정확히 같은 상황이다(`week_lessons_cache_provider.dart`
  /// 참고). 원본 시간표 데이터(TimeSlot 목록)가 필요해서, 지금 화면에 열려
  /// 있는(활성) 시간표일 때만 이 버튼을 보여준다.
  Future<void> _createDatedData() async {
    final timetableId = _selectedTimetableId;
    final registry = ref.read(timetableRegistryProvider).valueOrNull;
    final entry = timetableId == null ? null : registry?.getById(timetableId);
    final timeSlots = ref.read(
      exchangeScreenProvider.select((state) => state.timetableData?.timeSlots),
    );

    if (entry == null || timeSlots == null || timeSlots.isEmpty) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          '지금 열려 있는 시간표 데이터를 찾을 수 없습니다. 시간표를 다시 불러온 뒤 시도해 주세요.',
        );
      }
      return;
    }

    setState(() => _isCreating = true);
    try {
      final repo = await ref.read(timetableRepositoryProvider.future);
      await repo.ensureDatedBackfill(
        timetableId: entry.id,
        base: timeSlots,
        registeredAt: entry.registeredAt,
        name: entry.name,
        teacherName: entry.teacherName,
        schoolName: entry.schoolName,
      );
      if (!mounted) return;
      setState(() => _isCreating = false);
      if (mounted) {
        SnackBarHelper.showSuccess(context, '날짜별 데이터를 생성했습니다.');
      }
      await _load();
    } catch (e) {
      AppLogger.error('날짜별 데이터 생성 실패: $e', e);
      if (!mounted) return;
      setState(() => _isCreating = false);
      if (mounted) {
        SnackBarHelper.showError(context, '날짜별 데이터 생성에 실패했습니다: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final registryAsync = ref.watch(timetableRegistryProvider);
    final registry = registryAsync.valueOrNull;
    final entries = registry?.timetables ?? const [];

    // 등록된 시간표가 없으면 카드 자체를 안 그린다 — 같은 화면의
    // SemesterPeriodSection이 이미 "등록된 시간표가 없습니다" 안내를
    // 보여주므로, 여기서 또 띄우면 똑같은 문구가 중복돼 보인다(2026-09-30).
    if (entries.isEmpty) {
      return const SizedBox.shrink();
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
            '날짜 기반 기능 설정',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
          else if (_timetable == null) ...[
            Text(
              '이 시간표는 날짜별 데이터가 없습니다(등록 시 생성되지 않았거나, "모든 데이터'
              ' 삭제" 후 다시 생성되지 않았거나, 이전 버전에서 등록됨).',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            if (_selectedTimetableId == registry?.activeId) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isCreating ? null : _createDatedData,
                  child:
                      _isCreating
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('지금 만들기'),
                ),
              ),
            ],
          ]
          else if (_selectedTimetableId != registry?.activeId)
            Text(
              '활성 시간표가 아닙니다. 설정은 활성 시간표에서만 적용됩니다.',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            )
          else ...[
            _buildLessonReadPathToggle(tokens),
            const SizedBox(height: 8),
            _buildNodeDateEditToggle(tokens),
            const SizedBox(height: 8),
            _buildCombinedViewSwitchToggle(tokens),
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
                  '"날짜 반영" ON 모드에서만 적용됩니다. 이상이 있으면 꺼서'
                  ' 예전 방식으로 되돌릴 수 있습니다.',
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          AppSwitch(
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
          AppSwitch(
            value: enabled,
            onChanged:
                (value) =>
                    ref.read(nodeDateEditEnabledProvider.notifier).state = value,
          ),
        ],
      ),
    );
  }

  /// "날짜 반영"·"교체" 스위치 통합 여부 설정 (2026-09-30, 기본 켜짐).
  ///
  /// 켜져 있으면(기본값) 교체 화면 주차 바에 두 스위치를 합친 스위치 하나만
  /// 보인다 — 켜면 "날짜 반영"·"교체"가 동시에 켜지고, 끄면 동시에 꺼진다.
  /// 꺼져 있으면 두 스위치를 예전처럼 각각 따로 켜고 끌 수 있다(둘 중
  /// 하나만 켜야 하는 경우가 실제로 있다는 사용자 확인에 따라 남겨둔 선택지).
  Widget _buildCombinedViewSwitchToggle(DesignTokens tokens) {
    final combined = ref.watch(combinedViewSwitchProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '날짜 반영·교체 스위치 통합',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  '교체 화면에서 "날짜 반영"·"교체"를 하나의 스위치로 합쳐서'
                  ' 보여줍니다. 꺼면 두 스위치를 각각 따로 켜고 끌 수 있습니다.',
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          AppSwitch(
            value: combined,
            onChanged:
                (value) =>
                    ref.read(combinedViewSwitchProvider.notifier).state =
                        value,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/dated_timetable.dart';
import '../../../providers/combined_view_switch_provider.dart';
import '../../../providers/exchange_screen_provider.dart';
import '../../../providers/timetable_registry_provider.dart';
import '../../../providers/timetable_repository_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/snackbar_helper.dart';
import '../../widgets/app_switch.dart';
import '../../../utils/logger.dart';

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
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;
  DatedTimetable? _timetable;
  String? _loadedForTimetableId;

  /// "날짜 반영·교체 스위치 통합" 토글은 전역 설정이고, "지금 만들기"는
  /// 활성 시간표의 데이터로만 복구할 수 있다 — 둘 다 "어느 시간표를
  /// 볼지 고르는" 드롭다운이 필요 없다. 항상 활성 시간표만 본다
  /// (2026-09-30, 드롭다운 삭제).
  Future<void> _load(String timetableId) async {
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
        _loadedForTimetableId = timetableId;
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

  /// "지금 만들기" — 등록은 돼 있는데 SQLite 날짜 데이터만 없는 활성
  /// 시간표를(예: "모든 데이터 삭제" 후 레지스트리 항목만 남은 경우) 그
  /// 자리에서 즉시 복구한다.
  ///
  /// `TimetableRepository.ensureDatedBackfill`을 그대로 재사용한다 — S3
  /// 이전 시간표(레지스트리는 있는데 SQLite `timetables` 행이 없는 경우)를
  /// 자동 복구하려고 만든 것과 정확히 같은 상황이다(`week_lessons_cache_provider.dart`
  /// 참고).
  Future<void> _createDatedData(String timetableId) async {
    final registry = ref.read(timetableRegistryProvider).valueOrNull;
    final entry = registry?.getById(timetableId);
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
      await _load(timetableId);
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
    final activeId = registryAsync.valueOrNull?.activeId;

    // 활성 시간표가 없으면 카드 자체를 안 그린다 — 같은 화면의
    // SemesterPeriodSection이 이미 "등록된 시간표가 없습니다" 안내를
    // 보여주므로, 여기서 또 띄우면 똑같은 문구가 중복돼 보인다(2026-09-30).
    if (activeId == null) {
      return const SizedBox.shrink();
    }

    if (_loadedForTimetableId != activeId && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(activeId);
      });
    }

    // 별도 제목·외곽 카드 없이, 아래 각 상태의 위젯을 그대로 노출한다
    // (2026-09-30 — 토글이 자체 박스를 가지고 있어 이중 카드가 불필요했다).
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_errorMessage != null) {
      return Text(
        _errorMessage!,
        style: const TextStyle(fontSize: 12, color: Colors.red),
      );
    }
    if (_timetable == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이 시간표는 날짜별 데이터가 없습니다(등록 시 생성되지 않았거나, "모든 데이터'
            ' 삭제" 후 다시 생성되지 않았거나, 이전 버전에서 등록됨).',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed:
                  _isCreating ? null : () => _createDatedData(activeId),
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
      );
    }
    return _buildCombinedViewSwitchToggle(tokens);
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

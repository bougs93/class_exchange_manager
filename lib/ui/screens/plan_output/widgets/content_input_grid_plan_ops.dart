import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/print_profile.dart';
import '../../../../providers/print_profile_provider.dart';
import '../../../../providers/services_provider.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../providers/timetable_registry_provider.dart';
import '../../../../utils/date_format_utils.dart';

/// `_ContentInputGridState`의 계획서(PrintProfile) 조회·선택 상태 관련
/// 순수 로직(계획서 생성/수정 등 `setState`·`BuildContext` 의존 로직 제외)을
/// 모아둔 헬퍼.
///
/// `setState`를 직접 호출하지 않는 메서드만 이곳으로 옮겼다 — CRUD(생성/이름
/// 변경/삭제)처럼 다이얼로그 표시와 `setState` 호출이 뒤섞인 메서드는 State
/// 클래스에 그대로 남겨, 동작(호출 순서·await 시점)이 바뀌지 않도록 했다.
class ContentInputGridPlanOps {
  ContentInputGridPlanOps._();

  /// planData에서 비어있지 않은 groupId 집합을 추출
  static Set<String> allGroupIds(List<SubstitutionPlanData> planData) {
    return planData
        .map((d) => d.groupId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static bool listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 상단 드롭다운에 표시할 현재 계획서 ID (저장된 계획서만, 없으면 null)
  static String? resolveSelectedPlanId({
    required PrintProfileStore store,
    required List<SubstitutionPlanData> planData,
    required String? selectedPlanId,
  }) {
    // 전역 lastUsed 우선 — 백업·상단 칩·2열 헤더와 동일 계획서를 본다.
    // (로컬 selectedPlanId만 우선하면 백업에서 고른 뒤 상단 수정/삭제가
    // 이전 계획서를 건드리는 어긋남이 난다.)
    final lastUsed = store.lastUsedProfileId;
    if (lastUsed != null &&
        lastUsed != '__default__' &&
        store.profiles.any((p) => p.id == lastUsed)) {
      return lastUsed;
    }
    if (selectedPlanId != null &&
        selectedPlanId != '__default__' &&
        store.profiles.any((p) => p.id == selectedPlanId)) {
      return selectedPlanId;
    }
    if (store.profiles.isNotEmpty) return store.profiles.first.id;
    // 저장된 계획서가 없으면 null — 결강일 기반 임시 이름을 계획서처럼 보여주지 않음
    return null;
  }

  static PrintProfile? currentProfile(
    PrintProfileStore store,
    String? selectedPlanId,
  ) {
    final id = selectedPlanId ?? store.lastUsedProfileId;
    if (id == null || id == '__default__') return null;
    return store.getById(id);
  }

  /// 계획서의 제외 목록 → 체크 UI 반영 (기본: 모두 선택)
  ///
  /// [checkedGroupIds]는 그대로(참조) 변경되며, 반환값은 새로운
  /// `_selectionHydrated` 값이다(호출측에서 필드에 대입해야 한다).
  static bool hydrateSelectionFromPlan({
    required PrintProfileStore store,
    required List<SubstitutionPlanData> planData,
    required String? selectedPlanId,
    required Set<String> checkedGroupIds,
    required bool selectionHydrated,
  }) {
    final allIds = allGroupIds(planData);
    final profile = currentProfile(store, selectedPlanId);
    final deselected = profile?.deselectedGroupIds.toSet() ?? const <String>{};

    final next = allIds.where((id) => !deselected.contains(id)).toSet();
    final same =
        next.length == checkedGroupIds.length &&
        next.containsAll(checkedGroupIds);
    if (same && selectionHydrated) return selectionHydrated;

    checkedGroupIds
      ..clear()
      ..addAll(next);
    return true;
  }

  /// 되돌리기/다시실행 후 체크 집합 갱신.
  ///
  /// 다시 활성이 된 id(복원)는 항상 선택에 넣고, 비활성이 된 id는 선택에서 뺀다.
  static void syncCheckedWithActiveChange({
    required Set<String> checkedGroupIds,
    required Set<String> activeBefore,
    required Set<String> activeAfter,
  }) {
    final restored = activeAfter.difference(activeBefore);
    final removed = activeBefore.difference(activeAfter);
    checkedGroupIds
      ..removeAll(removed)
      ..addAll(restored);
  }

  /// 복원된 교체 id를 제외 목록에서 제거한다 (선택 상태).
  static List<String> deselectedWithoutRestoredIds(
    List<String> deselected,
    Iterable<String> restoredIds,
  ) {
    final drop = restoredIds.toSet();
    if (drop.isEmpty) return List<String>.from(deselected);
    return deselected.where((id) => !drop.contains(id)).toList();
  }

  /// 그룹(교체 건)의 지정 계획서 ID 조회 (삭제된 계획서면 null → 미지정)
  static String? selectedProfileIdForGroup(WidgetRef ref, String groupId) {
    final item =
        ref
            .read(exchangeHistoryServiceProvider)
            .getExchangeList()
            .where((h) => h.id == groupId)
            .firstOrNull;
    if (item == null) return null;
    final store = ref.read(printProfileStoreProvider);
    return store.getById(item.profileId)?.id;
  }

  /// 행 교사의 계획서 목록
  static List<PrintProfile> profileOptionsForTeacher(
    WidgetRef ref,
    String teacher,
  ) {
    return ref.read(printProfileStoreProvider).byTeacher(teacher);
  }

  /// 계획서에 귀속시킬 교사명 (준비 교사 → 없으면 첫 행 결강 교사)
  static String resolvePlanTeacherName(
    WidgetRef ref,
    List<SubstitutionPlanData> planData,
  ) {
    final prepared = ref.read(activeTeacherNameProvider).trim();
    if (prepared.isNotEmpty) return prepared;
    if (planData.isNotEmpty && planData.first.teacher.trim().isNotEmpty) {
      return planData.first.teacher.trim();
    }
    return '';
  }

  /// 계획서 이름이 없거나 결강일이 없을 때 기본으로 쓸 계획서 이름
  static String defaultPlanName(List<SubstitutionPlanData> planData) {
    if (planData.isEmpty ||
        planData.first.absenceDate.isEmpty ||
        planData.first.absenceDate == '선택') {
      return '결보강';
    }
    return DateFormatUtils.toSubstitutionPlanNameFromStored(
      planData.first.absenceDate,
    );
  }

  /// 선택한 날짜가 대상 요일과 일치하는지 (요일 제한 검증)
  static bool isTargetWeekday(DateTime date, String targetWeekday) {
    const weekdayMap = {'일': 0, '월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6};
    final targetWeekdayNumber = weekdayMap[targetWeekday];
    if (targetWeekdayNumber == null) return true;

    final dateWeekday = date.weekday == 7 ? 0 : date.weekday;
    return dateWeekday == targetWeekdayNumber;
  }

  /// 테이블 내용을 탭 구분 텍스트로 변환
  ///
  /// 엑셀에서 붙여넣기 시 각 셀에 자동으로 데이터가 분리됩니다.
  static String generateTableText(List<SubstitutionPlanData> data) {
    final buffer = StringBuffer();

    // 헤더 행 (탭으로 구분)
    const headers = [
      '결강일',
      '교시',
      '학년',
      '반',
      '과목',
      '교사',
      '보강/수업변경 과목',
      '보강/수업변경 성명',
      '교체일',
      '교체 교시',
      '교체 과목',
      '교체 교사',
      '비고',
    ];
    buffer.writeln(headers.join('\t'));

    // 데이터 행
    for (final row in data) {
      final cells = [
        '${DateFormatUtils.toMonthDay(row.absenceDate)}(${row.absenceDay})', // 결강일(요일) - 월.일 형식
        row.period, // 교시
        row.grade, // 학년
        row.className, // 반
        row.subject, // 과목 (결강)
        row.teacher, // 교사 (결강)
        row.supplementSubject, // 보강/수업변경 과목
        row.supplementTeacher, // 보강/수업변경 성명
        '${DateFormatUtils.toMonthDay(row.substitutionDate)}(${row.substitutionDay})', // 교체일(교체 요일) - 월.일 형식
        row.substitutionPeriod, // 교체 교시
        row.substitutionSubject, // 교체 과목
        row.substitutionTeacher, // 교체 교사
        row.remarks, // 비고
      ];
      buffer.writeln(cells.join('\t'));
    }

    return buffer.toString();
  }
}

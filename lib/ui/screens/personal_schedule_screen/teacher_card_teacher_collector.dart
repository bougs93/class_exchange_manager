import '../../../providers/substitution_plan_viewmodel.dart';
import '../../../utils/personal_exchange_info_extractor.dart';

/// 시간표 카드에 표시할 교사 역할
enum TeacherCardRole {
  /// 현재 선택한(저장) 교사
  saved,

  /// 선택 교사의 결보강 계획서 — 결강 교사 (선택 교사가 교체 상대일 때)
  absence,

  /// 결보강 계획서 — 수업 교체 교사
  substitution,

  /// 결보강 계획서 — 보강/수업변경 교사
  supplement,
}

/// 시간표 카드 1장에 대응하는 교사 정보
class TeacherCardTarget {
  final String name;
  final Set<TeacherCardRole> roles;

  /// 결보강 계획서에서 해당 교사와 관련된 날짜가 하나라도 미지정인지
  final bool hasUnspecifiedDate;

  const TeacherCardTarget({
    required this.name,
    required this.roles,
    this.hasUnspecifiedDate = false,
  });

  bool get isSaved => roles.contains(TeacherCardRole.saved);
  bool get isAbsence => roles.contains(TeacherCardRole.absence);
  bool get isSubstitution => roles.contains(TeacherCardRole.substitution);
  bool get isSupplement => roles.contains(TeacherCardRole.supplement);

  /// 카드 헤더에 표시할 역할 라벨 (선택 교사는 강조 테두리로 구분)
  String? get roleLabel {
    if (isSaved) return null;

    final labels = <String>[];
    if (isAbsence) labels.add('결강');
    if (isSubstitution) labels.add('교체');
    if (isSupplement) labels.add('보강');
    return labels.isEmpty ? null : labels.join('·');
  }

  /// 날짜 미지정 시 교사명 옆에 표시할 안내 문구
  String? get dateStatusMessage => hasUnspecifiedDate ? '날짜 미지정' : null;
}

/// 선택 교사 + 그 교사의 교체·보강 상대만 카드 목록으로 모읍니다.
///
/// 계획서 전체의 다른 교사 카드는 넣지 않습니다.
/// (다인 카드가 한꺼번에 그려지면 시간표 화면이 멈출 수 있습니다.)
class TeacherCardTeacherCollector {
  TeacherCardTeacherCollector._();

  /// [savedTeacherName]을 맨 앞에 두고, 그 교사와 연결된 결강·교체·보강 교사만 추가합니다.
  static List<TeacherCardTarget> collect({
    required String? savedTeacherName,
    required List<SubstitutionPlanData> planData,
  }) {
    final order = <String>[];
    final roleMap = <String, Set<TeacherCardRole>>{};

    void addRole(String rawName, TeacherCardRole role) {
      final name = rawName.trim();
      if (name.isEmpty) return;

      roleMap.putIfAbsent(name, () => {}).add(role);
      if (!order.contains(name)) {
        order.add(name);
      }
    }

    final selected = savedTeacherName?.trim() ?? '';
    if (selected.isNotEmpty) {
      addRole(selected, TeacherCardRole.saved);
    }

    // 선택 교사가 들어 있는 행만 사용합니다.
    final relatedPlans = PersonalExchangeInfoExtractor.plansRelatedToTeacher(
      planData,
      selected,
    );

    for (final plan in relatedPlans) {
      // 선택 교사가 교체 상대일 때, 결강 교사 카드도 보여 줍니다.
      addRole(plan.teacher, TeacherCardRole.absence);
      addRole(plan.substitutionTeacher, TeacherCardRole.substitution);
      addRole(plan.supplementTeacher, TeacherCardRole.supplement);
    }

    return order
        .map(
          (name) => TeacherCardTarget(
            name: name,
            roles: Set.unmodifiable(roleMap[name] ?? {}),
            hasUnspecifiedDate: _hasUnspecifiedDate(name, relatedPlans),
          ),
        )
        .toList();
  }

  /// 결보강 계획서 날짜가 비어 있거나 '선택'인지 확인합니다.
  static bool _isUnspecifiedDate(String date) {
    final trimmed = date.trim();
    return trimmed.isEmpty || trimmed == '선택';
  }

  /// 교사와 연결된 결강일·교체일·보강일 중 미지정 항목이 있는지 확인합니다.
  static bool _hasUnspecifiedDate(
    String teacherName,
    List<SubstitutionPlanData> planData,
  ) {
    for (final plan in planData) {
      // 결강 교사 — 결강일
      if (plan.teacher == teacherName && _isUnspecifiedDate(plan.absenceDate)) {
        return true;
      }

      // 교체 교사 — 교체일
      if (plan.substitutionTeacher == teacherName &&
          _isUnspecifiedDate(plan.substitutionDate)) {
        return true;
      }

      // 보강 교사 — 결강일(보강 기준일)
      if (plan.supplementTeacher == teacherName &&
          _isUnspecifiedDate(plan.absenceDate)) {
        return true;
      }
    }
    return false;
  }
}

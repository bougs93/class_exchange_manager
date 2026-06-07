import '../../../providers/substitution_plan_viewmodel.dart';

/// 시간표 카드에 표시할 교사 역할
enum TeacherCardRole {
  /// 설정 기본 정보에 저장된 교사
  saved,

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
  bool get isSubstitution => roles.contains(TeacherCardRole.substitution);
  bool get isSupplement => roles.contains(TeacherCardRole.supplement);

  /// 카드 헤더에 표시할 역할 라벨 (저장 교사는 강조 테두리로 구분)
  String? get roleLabel {
    if (isSaved) return null;

    final labels = <String>[];
    if (isSubstitution) labels.add('교체');
    if (isSupplement) labels.add('보강');
    return labels.isEmpty ? null : labels.join('·');
  }

  /// 날짜 미지정 시 교사명 옆에 표시할 안내 문구
  String? get dateStatusMessage => hasUnspecifiedDate ? '날짜 미지정' : null;
}

/// 저장 교사 + 결보강 계획서의 교체·보강 교사 목록을 수집합니다.
class TeacherCardTeacherCollector {
  TeacherCardTeacherCollector._();

  /// [savedTeacherName]을 먼저, 이후 계획서의 교체·보강 교사를 중복 없이 추가합니다.
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

    if (savedTeacherName != null) {
      addRole(savedTeacherName, TeacherCardRole.saved);
    }

    for (final plan in planData) {
      addRole(plan.substitutionTeacher, TeacherCardRole.substitution);
      addRole(plan.supplementTeacher, TeacherCardRole.supplement);
    }

    return order
        .map(
          (name) => TeacherCardTarget(
            name: name,
            roles: Set.unmodifiable(roleMap[name] ?? {}),
            hasUnspecifiedDate: _hasUnspecifiedDate(
              name,
              planData,
            ),
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
      if (plan.teacher == teacherName &&
          _isUnspecifiedDate(plan.absenceDate)) {
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

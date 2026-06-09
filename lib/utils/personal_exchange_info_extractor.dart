import '../models/time_slot.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/date_format_utils.dart';

/// 교체 정보를 셀 테마에 적용하기 위한 데이터 구조
class ExchangeCellInfo {
  final String teacherName;

  /// 내부 비교용 전체 날짜 (YYYY.MM.DD). UI 헤더는 월.일(6.10)만 표시.
  final String date;

  /// [date]에서 파생한 달력 요일 (월, 화, …)
  final String day;
  final int period;
  final bool isAbsence; // true: 결강(비워짐), false: 수업(채움)
  final String? subject;
  final String? className;

  ExchangeCellInfo({
    required this.teacherName,
    required this.date,
    required this.day,
    required this.period,
    required this.isAbsence,
    this.subject,
    this.className,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExchangeCellInfo &&
        other.teacherName == teacherName &&
        other.date == date &&
        other.period == period &&
        other.isAbsence == isAbsence;
  }

  @override
  int get hashCode => Object.hash(teacherName, date, period, isAbsence);

  /// TimeSlot.displayText 와 동일 — 학급(윗줄)\n과목(아랫줄)
  String get displayText => TimeSlot.formatDisplayText(className, subject);

  @override
  String toString() {
    return 'ExchangeCellInfo(teacher: $teacherName, date: $date, day: $day, period: $period, isAbsence: $isAbsence)';
  }
}

/// 개인 시간표용 교체 정보 추출기
///
/// 결보강 계획서(planData)를 단일 데이터 소스로 사용합니다.
class PersonalExchangeInfoExtractor {
  /// planData에서 특정 교사·현재 주에 해당하는 교체 정보를 추출합니다.
  static List<ExchangeCellInfo> extractExchangeInfo({
    required List<SubstitutionPlanData> planData,
    required String teacherName,
    required List<DateTime> weekDates,
  }) {
    if (planData.isEmpty || weekDates.isEmpty) return [];

    final referenceDate = weekDates.first;
    final weekDateStrings =
        weekDates.map(DateFormatUtils.toYearMonthDay).toSet();
    final result = <ExchangeCellInfo>[];

    for (final plan in planData) {
      result.addAll(_cellsForPlan(plan, teacherName, referenceDate));
    }

    return result.where((info) => weekDateStrings.contains(info.date)).toList();
  }

  /// 교사와 연결된 plan 중 날짜가 하나도 지정되지 않은 항목 수
  static int countUnassignedPlansForTeacher(
    List<SubstitutionPlanData> planData,
    String teacherName,
  ) {
    var count = 0;
    for (final plan in planData) {
      if (!_isRelatedToTeacher(plan, teacherName)) continue;
      if (!_planHasAssignedDate(plan)) count++;
    }
    return count;
  }

  static bool _isRelatedToTeacher(SubstitutionPlanData plan, String teacher) {
    return plan.teacher == teacher ||
        plan.substitutionTeacher == teacher ||
        plan.supplementTeacher == teacher;
  }

  static bool _planHasAssignedDate(SubstitutionPlanData plan) {
    if (plan.substitutionTeacher.isEmpty && plan.supplementTeacher.isNotEmpty) {
      return _isAssigned(plan.absenceDate);
    }
    return _isAssigned(plan.absenceDate) || _isAssigned(plan.substitutionDate);
  }

  static bool _isAssigned(String raw) {
    final trimmed = raw.trim();
    return trimmed.isNotEmpty && trimmed != '선택';
  }

  static List<ExchangeCellInfo> _cellsForPlan(
    SubstitutionPlanData plan,
    String teacherName,
    DateTime referenceDate,
  ) {
    final period = int.tryParse(plan.period) ?? 0;
    if (period <= 0) return [];

    final classLabel = plan.fullClassName;
    final cells = <ExchangeCellInfo>[];
    final isSupplement =
        plan.substitutionTeacher.isEmpty && plan.supplementTeacher.isNotEmpty;

    if (isSupplement) {
      if (plan.teacher == teacherName) {
        _addCell(
          cells,
          teacherName: plan.teacher,
          rawDate: plan.absenceDate,
          period: period,
          isAbsence: true,
          referenceDate: referenceDate,
          subject: plan.subject,
          className: classLabel,
        );
      }
      if (plan.supplementTeacher == teacherName) {
        final subject =
            plan.supplementSubject.isNotEmpty
                ? plan.supplementSubject
                : plan.subject;
        _addCell(
          cells,
          teacherName: plan.supplementTeacher,
          rawDate: plan.absenceDate,
          period: period,
          isAbsence: false,
          referenceDate: referenceDate,
          subject: subject,
          className: classLabel,
        );
      }
      return cells;
    }

    final subPeriod = int.tryParse(plan.substitutionPeriod) ?? 0;
    final subSubject =
        plan.substitutionSubject.isNotEmpty
            ? plan.substitutionSubject
            : plan.subject;

    // 결강 교사
    if (plan.teacher == teacherName) {
      _addCell(
        cells,
        teacherName: plan.teacher,
        rawDate: plan.absenceDate,
        period: period,
        isAbsence: true,
        referenceDate: referenceDate,
        subject: plan.subject,
        className: classLabel,
      );
      if (subPeriod > 0) {
        _addCell(
          cells,
          teacherName: plan.teacher,
          rawDate: plan.substitutionDate,
          period: subPeriod,
          isAbsence: false,
          referenceDate: referenceDate,
          subject: plan.subject,
          className: classLabel,
        );
      }
    }

    // 교체 교사
    if (plan.substitutionTeacher == teacherName && subPeriod > 0) {
      _addCell(
        cells,
        teacherName: plan.substitutionTeacher,
        rawDate: plan.substitutionDate,
        period: subPeriod,
        isAbsence: true,
        referenceDate: referenceDate,
        subject: subSubject,
        className: classLabel,
      );
      _addCell(
        cells,
        teacherName: plan.substitutionTeacher,
        rawDate: plan.absenceDate,
        period: period,
        isAbsence: false,
        referenceDate: referenceDate,
        subject: subSubject,
        className: classLabel,
      );
    }

    return cells;
  }

  static void _addCell(
    List<ExchangeCellInfo> cells, {
    required String teacherName,
    required String rawDate,
    required int period,
    required bool isAbsence,
    required DateTime referenceDate,
    String? subject,
    String? className,
  }) {
    final cell = _makeCell(
      teacherName: teacherName,
      rawDate: rawDate,
      period: period,
      isAbsence: isAbsence,
      referenceDate: referenceDate,
      subject: subject,
      className: className,
    );
    if (cell != null) cells.add(cell);
  }

  static ExchangeCellInfo? _makeCell({
    required String teacherName,
    required String rawDate,
    required int period,
    required bool isAbsence,
    required DateTime referenceDate,
    String? subject,
    String? className,
  }) {
    final date = DateFormatUtils.normalizePlanDate(
      rawDate,
      referenceDate: referenceDate,
    );
    if (date.isEmpty) return null;

    return ExchangeCellInfo(
      teacherName: teacherName,
      date: date,
      day: DateFormatUtils.dayNameFromPlanDate(date),
      period: period,
      isAbsence: isAbsence,
      subject: subject,
      className: className,
    );
  }
}

import '../../../providers/substitution_plan_viewmodel.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/week_date_calculator.dart';

/// 결보강 계획서에서 교체·결강 날짜가 있는 주(월요일) 목록을 수집합니다.
class ExchangeWeekCollector {
  ExchangeWeekCollector._();

  /// 결강일·교체일에서 주차(월요일)를 추출해 정렬·중복 제거합니다.
  ///
  /// [semesterStart]/[semesterEnd]를 넘기면(활성 시간표의 학기 기간, §10.6)
  /// 연도 없는 날짜 문자열의 연도를 그 범위 안에서 정확히 확정합니다.
  static List<DateTime> collectWeekMondays(
    List<SubstitutionPlanData> planData, {
    DateTime? referenceDate,
    DateTime? semesterStart,
    DateTime? semesterEnd,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final mondayKeys = <String, DateTime>{};

    for (final plan in planData) {
      for (final rawDate in [plan.absenceDate, plan.substitutionDate]) {
        final date = _parsePlanDate(
          rawDate,
          referenceDate: ref,
          semesterStart: semesterStart,
          semesterEnd: semesterEnd,
        );
        if (date == null) continue;

        final monday = WeekDateCalculator.getWeekMonday(date);
        final key = _dateKey(monday);
        mondayKeys[key] = _normalizeDate(monday);
      }
    }

    final sorted = mondayKeys.values.toList()..sort((a, b) => a.compareTo(b));
    return sorted;
  }

  /// 칩 라벨 맵 생성 — 해당 월의 몇 번째 월요일 주인지 표시 (예: 6월1주, 6월5주)
  static Map<String, String> buildChipLabels(
    List<DateTime> sortedExchangeWeeks,
  ) {
    final labels = <String, String>{};
    for (final week in sortedExchangeWeeks) {
      final normalized = _normalizeDate(week);
      labels[_dateKey(normalized)] = monthWeekLabel(normalized);
    }
    return labels;
  }

  /// 해당 월에서 몇 번째 월요일인지 (1~5) — "6월5주" 등 라벨용
  static int mondayIndexInMonth(DateTime weekMonday) {
    final normalized = _normalizeDate(weekMonday);
    var index = 0;
    for (int day = 1; day <= normalized.day; day++) {
      if (DateTime(normalized.year, normalized.month, day).weekday ==
          DateTime.monday) {
        index++;
      }
    }
    return index;
  }

  /// "6월1주" 형식 라벨 (월요일 기준 주의 달·주차)
  static String monthWeekLabel(DateTime weekMonday) {
    final normalized = _normalizeDate(weekMonday);
    return '${normalized.month}월${mondayIndexInMonth(normalized)}주';
  }

  /// 현재 주 바로 이전 교체 주
  static DateTime? findPreviousWeek(
    DateTime currentWeekMonday,
    List<DateTime> sortedExchangeWeeks,
  ) {
    final current = _normalizeDate(currentWeekMonday);
    DateTime? previous;

    for (final week in sortedExchangeWeeks) {
      final normalized = _normalizeDate(week);
      if (normalized.isBefore(current)) {
        previous = normalized;
      } else {
        break;
      }
    }
    return previous;
  }

  /// 현재 주 바로 다음 교체 주
  static DateTime? findNextWeek(
    DateTime currentWeekMonday,
    List<DateTime> sortedExchangeWeeks,
  ) {
    final current = _normalizeDate(currentWeekMonday);

    for (final week in sortedExchangeWeeks) {
      final normalized = _normalizeDate(week);
      if (normalized.isAfter(current)) {
        return normalized;
      }
    }
    return null;
  }

  static bool isSameWeek(DateTime a, DateTime b) {
    return weekKey(a) == weekKey(b);
  }

  /// 결강일·교체일 변경 감지용 지문
  static String planDatesFingerprint(List<SubstitutionPlanData> planData) {
    if (planData.isEmpty) return '';

    final parts =
        planData
            .map(
              (plan) =>
                  '${plan.exchangeId}|${plan.absenceDate}|${plan.substitutionDate}',
            )
            .toList()
          ..sort();
    return parts.join(';');
  }

  /// planData 기준 표시할 주(월요일): 교체 주 첫 번째, 없으면 이번 주
  static DateTime defaultWeekMonday(
    List<SubstitutionPlanData> planData, {
    DateTime? referenceDate,
    DateTime? semesterStart,
    DateTime? semesterEnd,
  }) {
    final weeks = collectWeekMondays(
      planData,
      referenceDate: referenceDate,
      semesterStart: semesterStart,
      semesterEnd: semesterEnd,
    );
    if (weeks.isNotEmpty) {
      final first = weeks.first;
      return DateTime(first.year, first.month, first.day);
    }
    return WeekDateCalculator.getThisWeekMonday();
  }

  /// 주(월요일) DateTime을 맵 키 문자열로 변환
  static String weekKey(DateTime date) => _dateKey(date);

  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _dateKey(DateTime date) {
    final d = _normalizeDate(date);
    return '${d.year}-${d.month}-${d.day}';
  }

  /// 계획서 날짜 문자열 → DateTime (년.월.일 / 월.일 형식 지원)
  ///
  /// [semesterStart]/[semesterEnd]가 있으면 연도 추정에 그 범위를 우선 사용한다
  /// (§10.6 — `DateFormatUtils.normalizePlanDate` 참조).
  static DateTime? _parsePlanDate(
    String raw, {
    required DateTime referenceDate,
    DateTime? semesterStart,
    DateTime? semesterEnd,
  }) {
    final normalized = DateFormatUtils.normalizePlanDate(
      raw,
      referenceDate: referenceDate,
      semesterStart: semesterStart,
      semesterEnd: semesterEnd,
    );
    return DateFormatUtils.parseYearMonthDay(normalized);
  }
}

import '../../../providers/substitution_plan_viewmodel.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/week_date_calculator.dart';

/// 결보강 계획서에서 교체·결강 날짜가 있는 주(월요일) 목록을 수집합니다.
class ExchangeWeekCollector {
  ExchangeWeekCollector._();

  /// 결강일·교체일에서 주차(월요일)를 추출해 정렬·중복 제거합니다.
  static List<DateTime> collectWeekMondays(
    List<SubstitutionPlanData> planData, {
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final mondayKeys = <String, DateTime>{};

    for (final plan in planData) {
      for (final rawDate in [plan.absenceDate, plan.substitutionDate]) {
        final date = _parsePlanDate(rawDate, referenceDate: ref);
        if (date == null) continue;

        final monday = WeekDateCalculator.getWeekMonday(date);
        final key = _dateKey(monday);
        mondayKeys[key] = _normalizeDate(monday);
      }
    }

    final sorted = mondayKeys.values.toList()
      ..sort((a, b) => a.compareTo(b));
    return sorted;
  }

  /// 칩 라벨 맵 생성 — 같은 달 교체 주 순서로 "6월1주", "6월2주" …
  static Map<String, String> buildChipLabels(List<DateTime> sortedExchangeWeeks) {
    final labels = <String, String>{};
    final monthOrdinal = <String, int>{};

    for (final week in sortedExchangeWeeks) {
      final normalized = _normalizeDate(week);
      final monthKey = '${normalized.year}-${normalized.month}';
      monthOrdinal[monthKey] = (monthOrdinal[monthKey] ?? 0) + 1;
      labels[_dateKey(normalized)] =
          '${normalized.month}월${monthOrdinal[monthKey]}주';
    }
    return labels;
  }

  /// 칩 라벨 — [sortedExchangeWeeks]에서 같은 달 몇 번째 교체 주인지 표시
  static String chipLabel(
    DateTime weekMonday,
    List<DateTime> sortedExchangeWeeks,
  ) {
    final labels = buildChipLabels(sortedExchangeWeeks);
    final key = _dateKey(weekMonday);
    if (labels.containsKey(key)) {
      return labels[key]!;
    }

    // 교체 주 목록에 없을 때 — 해당 월의 몇 번째 월요일인지로 계산
    final normalized = _normalizeDate(weekMonday);
    var weekNumber = 0;
    for (int day = 1; day <= normalized.day; day++) {
      if (DateTime(normalized.year, normalized.month, day).weekday ==
          DateTime.monday) {
        weekNumber++;
      }
    }
    return '${normalized.month}월$weekNumber주';
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
  static DateTime? _parsePlanDate(
    String raw, {
    required DateTime referenceDate,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '선택') return null;

    final parsed = DateFormatUtils.parseYearMonthDay(trimmed);
    if (parsed != null) return parsed;

    final withYear = DateFormatUtils.toYearMonthDayFromMonthDay(
      trimmed,
      referenceDate: referenceDate,
    );
    return DateFormatUtils.parseYearMonthDay(withYear);
  }
}

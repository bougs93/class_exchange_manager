import 'day_utils.dart';

/// 날짜 포맷 변환 유틸리티
///
/// 결보강 계획서의 날짜 포맷 변환을 담당합니다.
/// - 내부 저장: 년.월.일 형식 (예: "2025.11.24")
/// - UI 표시/출력: 월.일 형식 (예: "11.24")
class DateFormatUtils {
  /// DateTime을 결보강 계획서 이름 형식으로 변환
  ///
  /// 예: DateTime(2026, 8, 31) → "결보강 26.08.31"
  static String toSubstitutionPlanName(DateTime date) {
    final yy = (date.year % 100).toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '결보강 $yy.$mm.$dd';
  }

  /// 년.월.일 문자열을 결보강 계획서 이름으로 변환
  ///
  /// 예: "2026.08.31" → "결보강 26.08.31"
  static String toSubstitutionPlanNameFromStored(String yearMonthDay) {
    final parsed = parseYearMonthDay(normalizePlanDate(yearMonthDay));
    if (parsed == null) return '결보강';
    return toSubstitutionPlanName(parsed);
  }

  /// DateTime을 년.월.일 형식으로 변환
  ///
  /// 예: DateTime(2025, 11, 24) → "2025.11.24"
  static String toYearMonthDay(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  /// 년.월.일 형식 문자열을 월.일 형식으로 변환
  ///
  /// 입력: "2025.11.24" 또는 "2025.1.5"
  /// 출력: "11.24" 또는 "1.5"
  ///
  /// 만약 입력이 이미 월.일 형식이거나 유효하지 않은 형식이면 원본을 반환합니다.
  static String toMonthDay(String yearMonthDay) {
    // "선택"이나 빈 문자열인 경우 그대로 반환
    if (yearMonthDay.isEmpty || yearMonthDay == '선택') {
      return yearMonthDay;
    }

    // 년.월.일 형식인지 확인 (예: "2025.11.24")
    final parts = yearMonthDay.split('.');
    if (parts.length == 3) {
      // 년.월.일 형식 → 월.일 형식으로 변환
      final year = parts[0];
      final month = parts[1];
      final day = parts[2];

      // 년도가 4자리 숫자인지 확인
      if (year.length == 4 && int.tryParse(year) != null) {
        return '$month.$day';
      }
    }

    // 이미 월.일 형식이거나 다른 형식인 경우 원본 반환
    return yearMonthDay;
  }

  /// 월.일 형식 문자열을 년.월.일 형식으로 변환
  ///
  /// 입력: "11.24" (현재 년도 사용)
  /// 출력: "2025.11.24"
  ///
  /// 만약 입력이 이미 년.월.일 형식이면 그대로 반환합니다.
  static String toYearMonthDayFromMonthDay(
    String monthDay, {
    DateTime? referenceDate,
  }) {
    // "선택"이나 빈 문자열인 경우 그대로 반환
    if (monthDay.isEmpty || monthDay == '선택') {
      return monthDay;
    }

    final refDate = referenceDate ?? DateTime.now();
    final currentYear = refDate.year;

    // 이미 년.월.일 형식인지 확인 (예: "2025.11.24")
    final parts = monthDay.split('.');
    if (parts.length == 3) {
      final year = parts[0];
      // 년도가 4자리 숫자이면 이미 년.월.일 형식
      if (year.length == 4 && int.tryParse(year) != null) {
        return monthDay;
      }
    }

    // 월.일 형식인 경우 (예: "11.24")
    if (parts.length == 2) {
      final month = parts[0];
      final day = parts[1];
      return '$currentYear.$month.$day';
    }

    // 파싱 실패 시 원본 반환
    return monthDay;
  }

  /// 년.월.일 형식 문자열을 DateTime으로 파싱
  ///
  /// 입력: "2025.11.24"
  /// 출력: DateTime(2025, 11, 24)
  ///
  /// 파싱 실패 시 null 반환
  static DateTime? parseYearMonthDay(String dateString) {
    if (dateString.isEmpty || dateString == '선택') {
      return null;
    }

    final parts = dateString.split('.');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);

      if (year != null && month != null && day != null) {
        try {
          return DateTime(year, month, day);
        } catch (e) {
          return null;
        }
      }
    }

    return null;
  }

  /// 결보강 계획서 날짜를 내부 비교용 YYYY.MM.DD 형식으로 통일합니다.
  ///
  /// UI에는 `6.10`처럼 월.일만 표시되지만, 매칭·필터는 이 메서드 결과를 사용합니다.
  ///
  /// [semesterStart]/[semesterEnd]를 모두 넘기면(§10.6 `TimetableRegistryEntry`
  /// 학기 기간) 연도 없는 "월.일" 문자열의 연도를 그 범위 안에서 확정한다 —
  /// "오늘 연도"로 찍는 기존 방식보다 정확하다(§10.3 P6: 1학기 시간표를
  /// 12월에 열면 "3.5"가 엉뚱한 해로 붙는 문제). 둘 중 하나라도 없으면
  /// [referenceDate] 기준(기존 방식)으로 폴백한다 — 학기 기간을 아직
  /// 입력하지 않은 시간표에서도 계속 동작해야 하기 때문이다.
  static String normalizePlanDate(
    String raw, {
    DateTime? referenceDate,
    DateTime? semesterStart,
    DateTime? semesterEnd,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '선택') return '';

    if (trimmed.contains('-')) {
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return toYearMonthDay(parsed);
    }

    final direct = parseYearMonthDay(trimmed);
    if (direct != null) return toYearMonthDay(direct);

    if (semesterStart != null && semesterEnd != null) {
      final inRange = resolveMonthDayInRange(
        trimmed,
        rangeStart: semesterStart,
        rangeEnd: semesterEnd,
      );
      if (inRange != null) return toYearMonthDay(inRange);
    }

    final withYear = toYearMonthDayFromMonthDay(
      trimmed,
      referenceDate: referenceDate ?? DateTime.now(),
    );
    final resolved = parseYearMonthDay(withYear);
    return resolved != null ? toYearMonthDay(resolved) : '';
  }

  /// "월.일" 문자열의 연도를 [rangeStart]~[rangeEnd] 범위 안에서 확정합니다.
  ///
  /// 학기가 연말을 넘기는 경우(예: 2학기 9월~다음해 2월)를 대비해 시작
  /// 연도와 종료 연도 둘 다 시도합니다. 어느 쪽도 범위에 들어맞지 않으면
  /// null을 반환합니다 — 호출부는 이 경우 기존 방식으로 폴백해야 합니다.
  static DateTime? resolveMonthDayInRange(
    String monthDay, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final parts = monthDay.split('.');
    if (parts.length != 2) return null; // "월.일" 형식이 아니면 대상 아님

    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    if (month == null || day == null) return null;

    final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    for (final year in {start.year, end.year}) {
      try {
        final candidate = DateTime(year, month, day);
        if (candidate.month != month || candidate.day != day) {
          continue; // DateTime이 초과 일자를 다음 달로 넘겨버린 경우(예: 2.30)
        }
        if (!candidate.isBefore(start) && !candidate.isAfter(end)) {
          return candidate;
        }
      } catch (_) {
        // 유효하지 않은 날짜 — 다음 후보 연도로 계속
      }
    }
    return null;
  }

  /// 정규화된 날짜(YYYY.MM.DD)에서 요일명(월~일)을 반환합니다.
  static String dayNameFromPlanDate(String normalizedDate) {
    final parsed = parseYearMonthDay(normalizedDate);
    if (parsed == null) return '';
    return DayUtils.getDayName(parsed.weekday);
  }

  /// 날짜 문자열이 유효한 날짜 형식인지 확인
  ///
  /// 년.월.일 또는 월.일 형식 모두 유효하다고 판단합니다.
  static bool isValidDateString(String dateString) {
    if (dateString.isEmpty || dateString == '선택') {
      return false;
    }

    final parts = dateString.split('.');
    if (parts.length == 2 || parts.length == 3) {
      // 모든 부분이 숫자인지 확인
      return parts.every((part) => int.tryParse(part) != null);
    }

    return false;
  }

  /// 결강기간 계산 (최소 날짜와 최대 날짜 추출)
  ///
  /// [absenceDates] 결강일 문자열 리스트 (년.월.일 형식 또는 "선택", 빈 문자열)
  ///
  /// Returns:
  /// - 날짜가 2개 이상: "2025.11.03. - 2025.11.18." (각 날짜 끝에 마침표 추가)
  /// - 날짜가 1개: "2025.11.03." (날짜 끝에 마침표 추가)
  /// - 날짜가 없으면: 빈 문자열
  static String calculateAbsencePeriod(List<String> absenceDates) {
    // 유효한 날짜만 추출 (년.월.일 형식만, "선택"과 빈 문자열 제외)
    final validDates =
        absenceDates
            .where((date) => date.isNotEmpty && date != '선택')
            .map((date) => parseYearMonthDay(date))
            .where((date) => date != null)
            .cast<DateTime>()
            .toList();

    if (validDates.isEmpty) {
      return '';
    }

    // 날짜 정렬
    validDates.sort((a, b) => a.compareTo(b));

    final minDate = validDates.first;
    final maxDate = validDates.last;

    // 날짜 형식: "년.월.일." (끝에 마침표 추가)
    final minDateStr = '${toYearMonthDay(minDate)}.';

    // 날짜가 1개인 경우
    if (minDate == maxDate) {
      return minDateStr;
    }

    // 날짜가 2개 이상인 경우: "최소날짜. - 최대날짜."
    final maxDateStr = '${toYearMonthDay(maxDate)}.';
    return '$minDateStr - $maxDateStr';
  }
}

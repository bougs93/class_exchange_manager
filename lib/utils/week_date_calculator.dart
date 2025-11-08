import '../models/time_slot.dart';

/// 주 날짜 계산 유틸리티
/// 
/// 개인 시간표에서 주 단위로 날짜를 계산하는 기능을 제공합니다.
/// 월요일을 주의 시작으로 간주합니다.
class WeekDateCalculator {
  /// 오늘 날짜 기준으로 이번 주의 월요일 날짜 계산
  /// 
  /// 반환값: 이번 주 월요일의 DateTime
  static DateTime getThisWeekMonday() {
    final today = DateTime.now();
    return getWeekMonday(today);
  }

  /// 특정 날짜가 속한 주의 월요일 날짜 계산
  /// 
  /// 매개변수:
  /// - [date]: 기준 날짜
  /// 
  /// 반환값: 해당 주의 월요일 DateTime
  static DateTime getWeekMonday(DateTime date) {
    // DateTime.weekday는 1(월요일) ~ 7(일요일)
    // 월요일이면 0일 전으로 이동, 일요일이면 6일 전으로 이동
    final daysToMonday = (date.weekday - 1) % 7;
    return date.subtract(Duration(days: daysToMonday));
  }

  /// 주 단위 이동 (이전 주 또는 다음 주)
  /// 
  /// 매개변수:
  /// - [currentWeekMonday]: 현재 주의 월요일 날짜
  /// - [weeksOffset]: 이동할 주 수 (음수: 이전 주, 양수: 다음 주)
  /// 
  /// 반환값: 이동된 주의 월요일 DateTime
  static DateTime moveWeek(DateTime currentWeekMonday, int weeksOffset) {
    return currentWeekMonday.add(Duration(days: weeksOffset * 7));
  }

  /// 주의 각 요일 날짜 리스트 계산
  /// 
  /// 매개변수:
  /// - [weekMonday]: 주의 월요일 날짜
  /// 
  /// 반환값: [월, 화, 수, 목, 금] 순서의 날짜 리스트
  static List<DateTime> getWeekDates(DateTime weekMonday) {
    return [
      weekMonday,                    // 월요일
      weekMonday.add(const Duration(days: 1)), // 화요일
      weekMonday.add(const Duration(days: 2)), // 수요일
      weekMonday.add(const Duration(days: 3)), // 목요일
      weekMonday.add(const Duration(days: 4)), // 금요일
    ];
  }

  /// 전체 시간표 데이터를 기반으로 실제 존재하는 요일만 포함한 날짜 리스트 계산
  /// 
  /// 매개변수:
  /// - [weekMonday]: 주의 월요일 날짜
  /// - [allTimeSlots]: 전체 시간표 데이터 (TimeSlot 리스트)
  /// 
  /// 반환값: 실제 존재하는 요일의 날짜 리스트 (요일 순서대로 정렬)
  static List<DateTime> getWeekDatesWithAvailableDays(
    DateTime weekMonday,
    List<TimeSlot> allTimeSlots,
  ) {
    // 전체 시간표에서 실제로 존재하는 요일 추출 (dayOfWeek: 1=월, 2=화, ..., 7=일)
    final availableDayOfWeeks = <int>{};
    for (final slot in allTimeSlots) {
      // TimeSlot 객체의 dayOfWeek 속성 확인
      if (slot.dayOfWeek != null) {
        availableDayOfWeeks.add(slot.dayOfWeek!);
      }
    }

    // 요일이 없으면 기본값(월~금) 반환
    if (availableDayOfWeeks.isEmpty) {
      return getWeekDates(weekMonday);
    }

    // 존재하는 요일만 날짜 리스트로 변환 (요일 순서대로 정렬)
    final weekDates = <DateTime>[];
    for (int dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++) {
      if (availableDayOfWeeks.contains(dayOfWeek)) {
        // dayOfWeek가 1(월)이면 0일 추가, 2(화)면 1일 추가, ..., 7(일)이면 6일 추가
        final daysToAdd = dayOfWeek - 1;
        weekDates.add(weekMonday.add(Duration(days: daysToAdd)));
      }
    }

    return weekDates;
  }

  /// 날짜를 "월.일" 형식으로 포맷
  /// 
  /// 매개변수:
  /// - [date]: 포맷할 날짜
  /// 
  /// 반환값: "11.03" 형식의 문자열
  static String formatDateShort(DateTime date) {
    return '${date.month}.${date.day.toString().padLeft(2, '0')}';
  }

  /// 요일명과 날짜를 결합한 문자열 생성
  /// 
  /// 매개변수:
  /// - [dayName]: 요일명 ('월', '화', '수', '목', '금')
  /// - [date]: 날짜
  /// 
  /// 반환값: "월 (11.03)" 형식의 문자열
  static String formatDayWithDate(String dayName, DateTime date) {
    return '$dayName (${formatDateShort(date)})';
  }

  /// 주 범위 문자열 생성
  /// 
  /// 매개변수:
  /// - [weekMonday]: 주의 월요일 날짜
  /// 
  /// 반환값: "2025.11.03 ~ 2025.11.07" 형식의 문자열
  static String formatWeekRange(DateTime weekMonday) {
    final friday = weekMonday.add(const Duration(days: 4));
    return '${weekMonday.year}.${weekMonday.month.toString().padLeft(2, '0')}.${weekMonday.day.toString().padLeft(2, '0')} ~ '
           '${friday.year}.${friday.month.toString().padLeft(2, '0')}.${friday.day.toString().padLeft(2, '0')}';
  }
}


import 'package:class_exchange_manager/utils/week_date_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('시각이 붙은 날짜도 자정 월요일을 돌려준다', () {
    final monday = WeekDateCalculator.getWeekMonday(
      DateTime(2026, 9, 30, 15, 28, 7),
    );

    expect(monday, DateTime(2026, 9, 28));
  });

  test('앱 시작 시 이번 주 값과 주차 칩 값이 같다', () {
    final thisWeek = WeekDateCalculator.getThisWeekMonday();
    final chipWeek = DateTime(thisWeek.year, thisWeek.month, thisWeek.day);

    expect(thisWeek, chipWeek);
  });

  test('월을 넘는 주도 월요일로 맞춘다', () {
    expect(
      WeekDateCalculator.getWeekMonday(DateTime(2026, 10, 1, 9)),
      DateTime(2026, 9, 28),
    );
    expect(
      WeekDateCalculator.getWeekMonday(DateTime(2026, 10, 4, 23, 59)),
      DateTime(2026, 9, 28),
    );
  });
}

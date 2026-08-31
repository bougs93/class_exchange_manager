import '../models/time_slot.dart';
import '../services/non_exchangeable_data_storage_service.dart';
import '../ui/screens/personal_schedule_screen/exchange_week_collector.dart';
import 'week_date_calculator.dart';

/// 날짜가 지정된 교체불가 셀을 그 주에만 적용한다 (§10.6).
///
/// [slots]는 절대 변경하지 않는다 — 적용 대상 셀만 새 [TimeSlot]으로 교체한
/// 새 리스트를 반환한다([ResolvedWeek]와 동일한 불변 원칙).
///
/// [datedCells] 중 [weekMonday]가 속한 주와 같은 주의 항목만 적용된다.
/// `isRecurring`(매주 반복) 셀은 이미 원본 시간표에 구워져 있으므로 여기서는
/// 다루지 않는다 — 호출부가 날짜 있는 셀만 걸러 넘겨야 한다.
List<TimeSlot> applyDatedNonExchangeable(
  List<TimeSlot> slots,
  List<NonExchangeableCell> datedCells,
  DateTime weekMonday,
) {
  final thisWeekCells =
      datedCells.where((cell) {
        final date = cell.date;
        if (date == null) return false; // 매주 반복은 대상 아님
        // isSameWeek는 두 날짜가 "같은 달력 날짜"인지만 비교하므로(§10.5 A안과
        // 동일 관례), 셀 날짜를 먼저 그 주의 월요일로 정규화한 뒤 비교해야 한다.
        final cellWeekMonday = WeekDateCalculator.getWeekMonday(date);
        return ExchangeWeekCollector.isSameWeek(cellWeekMonday, weekMonday);
      }).toList();

  if (thisWeekCells.isEmpty) return slots;

  // (teacher, dayOfWeek, period) → 적용할 날짜 지정 셀
  final targets = <String, NonExchangeableCell>{
    for (final cell in thisWeekCells)
      '${cell.teacher}|${cell.dayOfWeek}|${cell.period}': cell,
  };

  return slots.map((slot) {
    final teacher = slot.teacher;
    final day = slot.dayOfWeek;
    final period = slot.period;
    if (teacher == null || day == null || period == null) return slot;

    final matched = targets['$teacher|$day|$period'];
    if (matched == null) return slot;

    return TimeSlot(
      teacher: slot.teacher,
      subject: slot.subject,
      className: slot.className,
      dayOfWeek: slot.dayOfWeek,
      period: slot.period,
      isExchangeable: false,
      exchangeReason: '교체불가',
    );
  }).toList();
}

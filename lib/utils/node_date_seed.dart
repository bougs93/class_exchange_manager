import '../models/circular_exchange_path.dart';
import '../models/dual_exchange_path.dart';
import '../models/exchange_path.dart';
import 'day_utils.dart';
import 'exchange_node_slot.dart';
import 'week_date_calculator.dart';

/// 교체 **실행 시점**에 순환·2중 교체의 참여 노드(슬롯)별 날짜를 확정한다
/// (S5.6.7).
///
/// **이 값은 추정이 아니라 실행 시점에 이미 확정된 사실이다.** 사용자가
/// "몇 주를 보고 있는지"를 이미 선택한 상태에서 교체를 실행하므로
/// (`ExchangeExecutor._dateForNode`가 정확히 같은 방식으로
/// `selectedWeek + (요일 오프셋)`을 계산해 `absenceDate`/`substitutionDate`
/// 자체를 만든다), 이 함수가 계산하는 값은 그 실행 시점에 이미 알고 있던
/// 값을 그대로 기록하는 것뿐이다 — [resolveEventDates](`event_date_resolver.dart`)
/// 의 OQ-1 "추정" 폴백과 수식은 같지만, 나중에 다시 추측하는 게 아니라
/// **원본 시점에 사실로 기록**한다는 점이 다르다(2026-09-29 "억지로 추정하지
/// 않는다" 결정과 충돌하지 않는다 — 그 결정은 "모르는 값을 지어내지 말라"는
/// 것이었지, "아는 값을 기록하지 말라"는 것이 아니었다).
///
/// 1:1·보강은 [supportsNodeDates]가 false라 이 함수를 호출할 필요가 없다
/// (빈 맵을 반환하긴 하지만, 호출부가 애초에 순환·2중일 때만 부르는 것을
/// 전제로 한다).
///
/// **알려진 한계(OQ-11)**: 키가 교사 없이 `'요일|교시'`뿐이라, (요일·교시)가
/// 같고 교사만 다른 두 노드(2중 교체에서 실제로 발생 가능)는 같은 키를
/// 공유한다. 이번 함수 자체는 두 노드 모두 같은 날짜로 시드하므로 무해하지만,
/// 나중에 계획서에서 한쪽을 고치면 다른 쪽도 같이 바뀐다 — 이는
/// [nodeSlotKey] 설계(S5.6.0)가 이미 의도적으로 감수한 트레이드오프다.
Map<String, DateTime> seedNodeDatesForWeek(ExchangePath path, DateTime weekMonday) {
  if (path is! CircularExchangePath && path is! DualExchangePath) {
    return const {};
  }

  final monday = WeekDateCalculator.getWeekMonday(weekMonday);
  final seeded = <String, DateTime>{};
  for (final node in path.nodes) {
    final dayNumber = DayUtils.getDayNumber(node.day);
    if (dayNumber < 1 || dayNumber > 5) continue; // 방어적 — 잘못된 값을 저장하지 않는다
    seeded[nodeSlotKey(node.day, node.period)] = monday.add(Duration(days: dayNumber - 1));
  }
  return seeded;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/screens/personal_schedule_screen/exchange_week_collector.dart';
import '../utils/lesson_projection.dart';
import '../utils/week_date_calculator.dart';
import 'services_provider.dart';

/// 교체가 존재하는 주(월요일)와 그 주의 교체 건수
///
/// §10.5 확정(A안): **결강일이 속한 주에만 1건**으로 센다. 주 경계를 넘는
/// 교체(결강 금요일 → 보강 다음 주 월요일)도 결강일 주에서만 세므로,
/// 칩 숫자의 합이 실제 교체 건수와 일치한다.
///
/// 화면에 무엇이 보이는지는 규칙이 다르다 — `ResolvedWeek`는 결강일·교체일 중
/// 하나라도 그 주에 걸리면 반영한다. "세는 것"과 "보이는 것"의 기준이 다르다는
/// 점에 주의(§10.5 표 참조).
final exchangeWeekCountsProvider = Provider<Map<DateTime, int>>((ref) {
  // 교체가 추가·삭제·되돌려지면 다시 계산
  ref.watch(exchangeListVersionProvider);

  final events = ref.read(exchangeHistoryServiceProvider).getActiveExchangeList();

  final counts = <DateTime, int>{};
  for (final event in events) {
    final week = event.weekMonday;
    counts[week] = (counts[week] ?? 0) + 1;
  }
  return counts;
});

/// 교체가 있는 주 목록 (오름차순 정렬) — **결강일 기준만** (§10.5 A안).
/// 주차 바 칩 목록에는 이 목록 대신 [exchangeVisibleWeeksProvider]를 쓴다
/// (아래 설명 참조). 이 provider는 "칩 숫자의 합 = 실제 교체 건수"가 필요한
/// 곳(집계용)에만 쓴다.
final exchangeWeeksProvider = Provider<List<DateTime>>((ref) {
  final counts = ref.watch(exchangeWeekCountsProvider);
  final weeks = counts.keys.toList()..sort((a, b) => a.compareTo(b));
  return weeks;
});

/// 주차 바에 "칩"으로 띄울 주 목록 — 결강일 주뿐 아니라 **교체일이 다른
/// 주로 넘어간 경우 그 주까지 포함**한다 (2026-09-30 버그 수정).
///
/// 문제: 주차 바 칩은 기존에 [exchangeWeeksProvider](결강일 기준, A안)만
/// 썼다. 하지만 그리드 화면은 `ResolvedWeek`가 "결강일·교체일 중 하나라도
/// 그 주에 걸리면 반영"하는 규칙을 쓴다(§10.5 표) — 즉 교체일만 다른 주에
/// 있는 경우에도 그 주 그리드에는 실제로 교체 결과가 보인다. 그런데 그
/// 주는 칩 목록에 없어서, 사용자가 그 주를 보고 있다가 다른 칩을 누르면
/// (그 주는 "지금 선택된 주라서" 임시로만 떠 있던 칩이었으므로) 칩이
/// 통째로 사라지고 `◀ ▶`로만 되돌아갈 수 있었다.
///
/// 수정: [touchedCellsFor]로 각 이벤트가 실제로 건드리는 모든 칸의 날짜를
/// 구해 그 주들을 전부 모은다 — 순환·2중 교체(참여 노드가 여러 주로 갈릴
/// 수 있음, S5.6 R7)도 정확히 포함된다. 배지 숫자([exchangeWeekCountsProvider])는
/// 그대로 결강일 기준을 유지한다 — "합계 = 실제 건수" 불변 조건은 안 건드리고,
/// 교체일만 걸리는 주는 배지 없이(0건 표시) 칩만 유지되는 식이다.
final exchangeVisibleWeeksProvider = Provider<List<DateTime>>((ref) {
  ref.watch(exchangeListVersionProvider);
  final events = ref.read(exchangeHistoryServiceProvider).getActiveExchangeList();

  final weeks = <DateTime>{};
  for (final event in events) {
    for (final cell in touchedCellsFor(event)) {
      weeks.add(WeekDateCalculator.getWeekMonday(cell.date));
    }
  }
  final sorted = weeks.toList()..sort((a, b) => a.compareTo(b));
  return sorted;
});

/// 현재 선택된 주에 속한 교체 건수 (결강일 기준)
int exchangeCountForWeek(Map<DateTime, int> counts, DateTime weekMonday) {
  for (final entry in counts.entries) {
    if (ExchangeWeekCollector.isSameWeek(entry.key, weekMonday)) {
      return entry.value;
    }
  }
  return 0;
}

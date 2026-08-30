import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/screens/personal_schedule_screen/exchange_week_collector.dart';
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

/// 교체가 있는 주 목록 (오름차순 정렬)
final exchangeWeeksProvider = Provider<List<DateTime>>((ref) {
  final counts = ref.watch(exchangeWeekCountsProvider);
  final weeks = counts.keys.toList()..sort((a, b) => a.compareTo(b));
  return weeks;
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

import '../models/exchange_history_item.dart';
import 'exchange_cell_dates.dart';

/// 되돌리려는 교체 건([target])이 만든 칸(목적지)을, [target] 이후에 실행된
/// **활성** 교체 건이 source 또는 destination으로 쓰고 있는지 판정한다
/// (S5.4 — D6/OQ-2).
///
/// 순수 판정 로직이며 **되돌리기 자체를 막지 않는다** — 반환된 목록은 사용자
/// 안내(스낵바 경고)에만 쓴다. 투영(`lesson_projection.dart`)은 활성 이벤트를
/// 순서대로 재생하므로 되돌린 뒤의 최종 상태는 항상 결정적이고 모순이 없다.
/// 이 함수는 "그래도 사용자가 알아두면 좋은 관계"를 알려줄 뿐이다.
///
/// 좌표는 요일·교시 기준(날짜 무관, [ExchangeCellDates.legacySourceKeys]/
/// [legacyDestinationKeys]와 동일 — `isCellExchanged` 등 기존 판정과 같은
/// 기준)을 쓴다. 실제 캘린더 날짜까지 정확히 구분하지 않으므로 다른 주의
/// 같은 요일·교시를 우연히 겹친 것도 "의존"으로 잡을 수 있다 — 이 함수의
/// 결과가 차단이 아니라 안내일 뿐이므로 과대 감지 쪽이 안전하다(놓치는 것보다
/// 낫다).
///
/// [allEventsInOrder]는 실행 순서(= `ExchangeHistoryService.getExchangeList()`
/// 순서)로 넘겨야 한다. [target]을 찾지 못하거나 목적지 칸이 없으면(예:
/// 알 수 없는 경로 타입) 빈 목록을 반환한다.
List<ExchangeHistoryItem> findDependentExchanges({
  required ExchangeHistoryItem target,
  required List<ExchangeHistoryItem> allEventsInOrder,
}) {
  final targetIndex = allEventsInOrder.indexWhere((e) => e.id == target.id);
  if (targetIndex == -1) return const [];

  final createdCellKeys = ExchangeCellDates.legacyDestinationKeys(
    target.originalPath,
  ).toSet();
  if (createdCellKeys.isEmpty) return const [];

  final dependents = <ExchangeHistoryItem>[];
  for (var i = targetIndex + 1; i < allEventsInOrder.length; i++) {
    final candidate = allEventsInOrder[i];
    if (candidate.isReverted) continue;

    final candidateKeys = {
      ...ExchangeCellDates.legacySourceKeys(candidate.originalPath),
      ...ExchangeCellDates.legacyDestinationKeys(candidate.originalPath),
    };
    if (candidateKeys.intersection(createdCellKeys).isNotEmpty) {
      dependents.add(candidate);
    }
  }
  return dependents;
}

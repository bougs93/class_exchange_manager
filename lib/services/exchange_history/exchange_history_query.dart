import '../../models/exchange_history_item.dart';
import '../../models/exchange_path.dart';

/// 교체 리스트에 대한 순수 조회(검색·필터·통계) 연산 모음.
///
/// [ExchangeHistoryService]가 보관하는 교체 리스트(`List<ExchangeHistoryItem>`)를
/// 그대로 받아서 읽기만 하는 정적 메서드들이다 — 상태를 갖지 않으므로
/// 순서나 사이드이펙트를 걱정할 필요 없이 자유롭게 이동/테스트할 수 있다.
class ExchangeHistoryQuery {
  ExchangeHistoryQuery._();

  /// 교체 리스트에서 특정 항목 조회
  static ExchangeHistoryItem? getExchangeItem(
    List<ExchangeHistoryItem> exchangeList,
    String itemId,
  ) {
    try {
      return exchangeList.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  /// 삭제 대상 조회 — 경로 ID 기준.
  ///
  /// 같은 경로를 여러 번 실행하면 `originalPath.id`가 중복될 수 있다
  /// (실행→되돌리기→재실행 등). 이때 무조건 첫 항목을 지우면(`firstWhere`)
  /// 엉뚱한 교체가 삭제된다. 선택된 셀이 보여주는 것은 가장 최근 상태이므로,
  /// 활성(`!isReverted`) 항목 중 가장 최근 것을 우선하고, 없으면 전체 중
  /// 가장 최근 것을 반환한다. 없으면 null.
  static ExchangeHistoryItem? findDeletableItem(
    List<ExchangeHistoryItem> exchangeList,
    String pathId,
  ) {
    final candidates =
        exchangeList.where((item) => item.originalPath.id == pathId).toList();
    if (candidates.isEmpty) return null;
    for (var i = candidates.length - 1; i >= 0; i--) {
      if (!candidates[i].isReverted) return candidates[i];
    }
    return candidates.last;
  }

  /// 교체 리스트에서 설명으로 검색
  static List<ExchangeHistoryItem> searchByDescription(
    List<ExchangeHistoryItem> exchangeList,
    String query,
  ) {
    if (query.isEmpty) return List.from(exchangeList);

    return exchangeList
        .where(
          (item) =>
              item.description.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  /// 교체 리스트에서 날짜별 필터링
  static List<ExchangeHistoryItem> filterByDate(
    List<ExchangeHistoryItem> exchangeList,
    DateTime start,
    DateTime end,
  ) {
    return exchangeList
        .where(
          (item) =>
              item.timestamp.isAfter(start) && item.timestamp.isBefore(end),
        )
        .toList();
  }

  /// 교체 리스트에서 타입별 필터링
  static List<ExchangeHistoryItem> filterByType(
    List<ExchangeHistoryItem> exchangeList,
    ExchangePathType type,
  ) {
    return exchangeList.where((item) => item.type == type).toList();
  }

  /// 교체 리스트에서 태그별 필터링
  static List<ExchangeHistoryItem> filterByTags(
    List<ExchangeHistoryItem> exchangeList,
    List<String> tags,
  ) {
    return exchangeList
        .where((item) => tags.any((tag) => item.tags.contains(tag)))
        .toList();
  }

  /// 교체 리스트 통계 정보
  static Map<String, dynamic> getExchangeListStats(
    List<ExchangeHistoryItem> exchangeList,
  ) {
    final total = exchangeList.length;
    final reverted = exchangeList.where((item) => item.isReverted).length;
    final active = total - reverted;

    final typeStats = <ExchangePathType, int>{};
    for (final item in exchangeList) {
      typeStats[item.type] = (typeStats[item.type] ?? 0) + 1;
    }

    return {
      'total': total,
      'active': active,
      'reverted': reverted,
      'typeStats': typeStats,
      'lastExchange':
          exchangeList.isNotEmpty ? exchangeList.last.timestamp : null,
    };
  }
}

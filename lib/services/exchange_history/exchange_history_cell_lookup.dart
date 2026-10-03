import 'dart:developer' as developer;

import '../../models/exchange_history_item.dart';
import '../../models/exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/dual_exchange_path.dart';
import '../../models/supplement_exchange_path.dart';

/// 특정 시간표 셀이 교체 리스트의 어떤 경로에 포함되는지 찾는 순수 조회 모음.
///
/// [ExchangeHistoryService]의 교체 리스트(`List<ExchangeHistoryItem>`)를
/// 받아서 읽기만 한다 — 상태를 갖지 않는다.
class ExchangeHistoryCellLookup {
  ExchangeHistoryCellLookup._();

  /// 특정 셀이 교체된 셀인지 확인 (활성 교체만)
  static bool isCellExchanged(
    List<ExchangeHistoryItem> exchangeList,
    String teacherName,
    String day,
    int period,
  ) {
    for (final item in exchangeList) {
      if (item.isReverted) continue;
      if (_isCellInExchangePath(item.originalPath, teacherName, day, period)) {
        return true;
      }
    }
    return false;
  }

  /// 교체된 셀에 해당하는 교체 경로 찾기 (활성 교체만)
  static ExchangePath? findExchangePathByCell(
    List<ExchangeHistoryItem> exchangeList,
    String teacherName,
    String day,
    int period,
  ) {
    for (final item in exchangeList) {
      if (item.isReverted) continue;
      if (_isCellInExchangePath(item.originalPath, teacherName, day, period)) {
        return item.originalPath;
      }
    }
    return null;
  }

  /// ExchangePath에서 특정 셀이 포함되어 있는지 확인
  static bool _isCellInExchangePath(
    ExchangePath path,
    String teacherName,
    String day,
    int period,
  ) {
    try {
      final nodes = _getNodesFromPath(path);
      return nodes.any(
        (node) =>
            node.teacherName == teacherName &&
            node.day == day &&
            node.period == period,
      );
    } catch (e) {
      developer.log('셀 확인 중 오류 발생: $e');
      return false;
    }
  }

  /// ExchangePath에서 노드 리스트 추출
  static List<dynamic> _getNodesFromPath(ExchangePath path) {
    if (path is OneToOneExchangePath) {
      return [path.sourceNode, path.targetNode];
    } else if (path is CircularExchangePath) {
      return path.nodes;
    } else if (path is DualExchangePath) {
      return [path.nodeA, path.nodeB, path.node1, path.node2];
    } else if (path is SupplementExchangePath) {
      return [path.sourceNode, path.targetNode];
    }
    return [];
  }
}

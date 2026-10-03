import 'dart:developer' as developer;

import '../../models/exchange_history_item.dart';
import '../../models/exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/dual_exchange_path.dart';
import '../../models/supplement_exchange_path.dart';
import '../../utils/logger.dart';

/// 교체 히스토리를 콘솔(디버그 로그)에 출력하는 전용 모음.
///
/// [ExchangeHistoryService]의 상태를 전혀 보유하지 않는다 — 출력할
/// 리스트/통계를 매번 인자로 받아 로깅만 수행하는 순수 디버그 유틸리티다.
class ExchangeHistoryDebugPrinter {
  ExchangeHistoryDebugPrinter._();

  /// 교체 리스트를 콘솔에 출력
  static void printExchangeList(List<ExchangeHistoryItem> exchangeList) {
    _printList('[교체 리스트]', exchangeList);
  }

  /// 되돌리기 히스토리를 콘솔에 출력
  static void printUndoHistory(List<ExchangeHistoryItem> undoStack) {
    _printList('[되돌리기 히스토리]', undoStack);
  }

  /// 다시 실행 히스토리를 콘솔에 출력
  static void printRedoHistory(List<ExchangeHistoryItem> redoStack) {
    _printList('[다시 실행 히스토리]', redoStack);
  }

  /// 공통 리스트 출력 메서드
  static void _printList(String title, List<ExchangeHistoryItem> list) {
    AppLogger.exchangeInfo('$title 총 ${list.length}개');
    if (list.isEmpty) {
      AppLogger.exchangeInfo('  비어있습니다.');
    } else {
      for (int i = 0; i < list.length; i++) {
        final item = list[i];
        AppLogger.exchangeInfo(
          '  ${i + 1} Type: ${item.type.displayName} - ${_getNodeInfo(item.originalPath)}',
        );
      }
    }
  }

  /// 전체 히스토리 통계를 콘솔에 출력
  static void printHistoryStats(
    Map<String, dynamic> stats, {
    required int undoCount,
    required int redoCount,
  }) {
    AppLogger.exchangeInfo('\n=== 교체 히스토리 통계 ===');
    AppLogger.exchangeInfo('전체 교체: ${stats['total']}개');
    AppLogger.exchangeInfo('활성 교체: ${stats['active']}개');
    AppLogger.exchangeInfo('되돌린 교체: ${stats['reverted']}개');
    AppLogger.exchangeInfo('되돌리기 가능: $undoCount개');
    AppLogger.exchangeInfo('다시 실행 가능: $redoCount개');

    final typeStats = stats['typeStats'] as Map<ExchangePathType, int>;
    AppLogger.exchangeInfo('\n교체 타입별 통계:');
    typeStats.forEach((type, count) {
      AppLogger.exchangeInfo('  ${type.displayName}: $count개');
    });

    if (stats['lastExchange'] != null) {
      AppLogger.exchangeInfo('\n마지막 교체: ${stats['lastExchange']}');
    }
    AppLogger.exchangeInfo('========================\n');
  }

  /// ExchangePath에서 노드 정보를 요약해서 반환
  static String _getNodeInfo(ExchangePath path) {
    try {
      if (path is OneToOneExchangePath) {
        return _formatNodes([path.sourceNode, path.targetNode]);
      } else if (path is CircularExchangePath) {
        return _formatNodes(path.nodes);
      } else if (path is DualExchangePath) {
        // 2중교체: 4개 노드 모두 출력 (node1, node2, nodeA, nodeB)
        return _formatNodes([path.node1, path.node2, path.nodeA, path.nodeB]);
      } else if (path is SupplementExchangePath) {
        return _formatNodes([path.sourceNode, path.targetNode]);
      }
    } catch (e) {
      developer.log('노드 정보 추출 실패: $e');
    }
    return path.displayTitle;
  }

  /// 노드 리스트를 포맷팅
  static String _formatNodes(List<dynamic> nodes) {
    return nodes
        .asMap()
        .entries
        .map((entry) {
          final node = entry.value;
          return '[${entry.key}]${node.day}|${node.period}|${node.className}|${node.teacherName}|${node.subjectName}';
        })
        .join(', ');
  }
}

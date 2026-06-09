import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exchange_node.dart';
import '../utils/logger.dart';

/// 노드 스크롤 상태를 관리하는 Provider
/// 사이드바에서 노드를 클릭했을 때 해당 셀로 스크롤하는 기능을 제공
class NodeScrollNotifier extends StateNotifier<ExchangeNode?> {
  NodeScrollNotifier() : super(null);

  /// 특정 노드로 스크롤 요청
  ///
  /// [node] 스크롤할 교체 경로의 노드
  void requestScrollToNode(ExchangeNode node) {
    try {
      AppLogger.exchangeDebug(
        '🎯 [노드 스크롤] 스크롤 요청: ${node.teacherName} | ${node.day}요일 ${node.period}교시',
      );

      // 상태 업데이트로 스크롤 요청 전달
      state = node;

      AppLogger.exchangeDebug('✅ [노드 스크롤] 스크롤 요청 상태 업데이트 완료');
    } catch (e) {
      AppLogger.exchangeDebug('❌ [노드 스크롤] 스크롤 요청 실패: $e');
    }
  }

  /// 스크롤 요청 완료 처리
  /// 스크롤이 완료된 후 호출하여 상태 초기화
  void clearScrollRequest() {
    state = null;
    AppLogger.exchangeDebug('🔄 [노드 스크롤] 스크롤 요청 상태 초기화');
  }
}

/// 노드 스크롤 Provider
final nodeScrollProvider =
    StateNotifierProvider<NodeScrollNotifier, ExchangeNode?>((ref) {
      return NodeScrollNotifier();
    });

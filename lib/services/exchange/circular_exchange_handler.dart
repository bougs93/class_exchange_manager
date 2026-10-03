import '../../models/exchange_node.dart';
import '../../models/time_slot.dart';
import '../../utils/logger.dart';
import '../base_exchange_service.dart';

/// 순환 교체 처리 담당
///
/// `exchange_service.dart`에서 분리된 부분으로, 2~5명 교사 간 순환 교체
/// 실행([performCircularExchange])과 검증을 담당한다.
class CircularExchangeHandler {
  CircularExchangeHandler(this._context);

  final BaseExchangeService _context;

  /// 순환 교체 실행
  ///
  /// 매개변수:
  /// - `timeSlots`: 현재 시간표 데이터
  /// - `nodes`: 순환 교체에 참여하는 노드들 (순서대로)
  ///
  /// 반환값:
  /// - `bool`: 교체 성공 여부
  bool performCircularExchange(
    List<TimeSlot> timeSlots,
    List<ExchangeNode> nodes,
  ) {
    try {
      if (nodes.length < 3) {
        AppLogger.exchangeDebug(
          '순환 교체 실패: 최소 3개 노드가 필요합니다 (현재: ${nodes.length}개)',
        );
        return false;
      }

      AppLogger.exchangeInfo('순환 교체 시작: ${nodes.length}개 노드');

      // 1. 교체 가능성 검증
      if (!_validateCircularExchange(timeSlots, nodes)) {
        AppLogger.exchangeDebug('순환 교체 검증 실패');
        return false;
      }

      AppLogger.exchangeDebug(
        '[wg]순환 교체 노드: ${nodes.map((node) => node.displayText).join(' → ')}',
      );

      // 3. 순환 교체 실행 (마지막 노드는 제외) - 각 노드가 다음 노드의 위치로 이동
      for (int i = 0; i < nodes.length - 1; i++) {
        final currentNode = nodes[i];
        final nextNode = nodes[i + 1];

        // 현재 노드의 원본 TimeSlot 찾기
        final currentSlot = _context.findTimeSlot(
          currentNode.teacherName,
          currentNode.day,
          currentNode.period,
          timeSlots,
        );
        if (currentSlot == null) {
          AppLogger.exchangeDebug(
            '순환 교체 실패: ${currentNode.teacherName}의 ${currentNode.day}${currentNode.period}교시 TimeSlot을 찾을 수 없습니다',
          );
          return false;
        }

        // 현재 노드가 이동할 목적지 TimeSlot 찾기 (다음 노드의 위치에 있는 현재 노드의 TimeSlot)
        final targetSlot = _context.findTimeSlot(
          currentNode.teacherName,
          nextNode.day,
          nextNode.period,
          timeSlots,
        );
        if (targetSlot == null) {
          AppLogger.exchangeDebug(
            '순환 교체 실패: ${currentNode.teacherName}의 ${nextNode.day}${nextNode.period}교시 TimeSlot을 찾을 수 없습니다',
          );
          return false;
        }

        // TimeSlot.moveTime() 방식으로 교체 수행
        bool moveSuccess = TimeSlot.moveTime(currentSlot, targetSlot);

        if (!moveSuccess) {
          AppLogger.exchangeDebug(
            '순환 교체 실패: ${currentNode.teacherName} → ${nextNode.day}${nextNode.period}교시 이동 실패',
          );
          return false;
        }
      }

      AppLogger.exchangeInfo('순환 교체 완료: ${nodes.length}개 노드 [교체 성공]');
      return true;
    } catch (e) {
      AppLogger.exchangeDebug('순환 교체 중 오류 발생: $e');
      return false;
    }
  }

  /// 순환 교체 검증 (단순화된 버전)
  bool _validateCircularExchange(
    List<TimeSlot> timeSlots,
    List<ExchangeNode> nodes,
  ) {
    try {
      // 모든 노드의 TimeSlot 존재 확인만 수행
      for (final node in nodes) {
        final slot = _context.findTimeSlot(
          node.teacherName,
          node.day,
          node.period,
          timeSlots,
        );
        if (slot == null) {
          AppLogger.exchangeDebug(
            '순환 교체 검증 실패: ${node.teacherName}의 ${node.day}${node.period}교시 TimeSlot을 찾을 수 없습니다',
          );
          return false;
        }
      }

      AppLogger.exchangeDebug('순환 교체 검증 통과: ${nodes.length}개 노드');
      return true;
    } catch (e) {
      AppLogger.exchangeDebug('순환 교체 검증 중 오류 발생: $e');
      return false;
    }
  }
}

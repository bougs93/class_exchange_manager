import '../models/exchange_history_item.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../services/exchange_service.dart';
import '../services/excel_service.dart';
import '../utils/timetable_data_source.dart';
import '../utils/logger.dart';

/// 개인 시간표 전용 교체 뷰 관리자
/// 
/// 필터링된 교체 리스트를 사용하여 개인 시간표에 교체 뷰를 적용합니다.
/// ExchangeViewProvider의 로직을 참조하되, 필터링 기능을 추가했습니다.
class PersonalExchangeViewManager {
  /// 필터링된 교체 리스트로 교체 뷰 활성화
  /// 
  /// 매개변수:
  /// - `List<ExchangeHistoryItem>` filteredExchanges: 필터링된 교체 리스트
  /// - `List<TimeSlot>` timeSlots: 시간표 데이터 (수정됨)
  /// - `List<Teacher>` teachers: 교사 리스트
  /// - `PersonalTimetableDataSource` dataSource: DataSource (UI 업데이트용)
  /// 
  /// 반환값: 적용된 교체 개수
  static Future<int> enableExchangeView({
    required List<ExchangeHistoryItem> filteredExchanges,
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
    required dynamic dataSource, // PersonalTimetableDataSource 또는 TimetableDataSource
  }) async {
    if (filteredExchanges.isEmpty) {
      AppLogger.exchangeInfo('[PersonalExchangeViewManager] 필터링된 교체 리스트가 비어있습니다');
      return 0;
    }

    AppLogger.exchangeInfo('[PersonalExchangeViewManager] 교체 뷰 활성화 시작: ${filteredExchanges.length}개 교체');

    int successCount = 0;

    // 각 교체를 실행
    for (final item in filteredExchanges) {
      if (_executeExchangeFromHistory(item, timeSlots, teachers)) {
        successCount++;
      }
    }

    // UI 업데이트 (교체 성공 시에만)
    if (successCount > 0) {
      // PersonalTimetableDataSource는 updateData 메서드가 없으므로 notifyListeners만 호출
      if (dataSource is TimetableDataSource) {
        dataSource.updateData(timeSlots, teachers);
      } else {
        dataSource.notifyListeners();
      }
      AppLogger.exchangeInfo('[PersonalExchangeViewManager] 교체 뷰 활성화 완료 - $successCount/${filteredExchanges.length}개 적용');
    }

    return successCount;
  }

  /// 필터링된 교체 리스트로 교체 뷰 비활성화 (복원)
  /// 
  /// 주의: 개인 시간표에서는 교체 뷰 비활성화 시 원래 상태로 복원하려면
  /// 전체 시간표 데이터를 다시 로드해야 합니다.
  /// 현재는 필터링된 교체만 적용하므로, 비활성화 시 전체 데이터 재로드가 필요합니다.
  static Future<void> disableExchangeView({
    required TimetableData originalTimetableData,
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
    required dynamic dataSource, // PersonalTimetableDataSource 또는 TimetableDataSource
  }) async {
    AppLogger.exchangeInfo('[PersonalExchangeViewManager] 교체 뷰 비활성화 시작');

    // 원본 데이터로 복원 (전체 시간표 데이터 재로드)
    // ExchangeScreenProvider에서 원본 데이터를 가져와서 복원
    timeSlots.clear();
    timeSlots.addAll(originalTimetableData.timeSlots);

    // UI 업데이트
    if (dataSource is TimetableDataSource) {
      dataSource.updateData(timeSlots, teachers);
    } else {
      dataSource.notifyListeners();
    }
    AppLogger.exchangeInfo('[PersonalExchangeViewManager] 교체 뷰 비활성화 완료 - 원본 데이터로 복원');
  }

  /// 교체 히스토리에서 교체 실행
  static bool _executeExchangeFromHistory(
    ExchangeHistoryItem item,
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    try {
      final exchangePath = item.originalPath;
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 교체 실행: ${exchangePath.type}');

      // 교체 타입에 따라 다르게 처리
      if (exchangePath is OneToOneExchangePath) {
        return _executeOneToOneExchange(exchangePath, timeSlots);
      } else if (exchangePath is CircularExchangePath) {
        return _executeCircularExchange(exchangePath, timeSlots);
      } else if (exchangePath is ChainExchangePath) {
        return _executeChainExchange(exchangePath, timeSlots);
      } else if (exchangePath is SupplementExchangePath) {
        return _executeSupplementExchange(exchangePath, timeSlots);
      }

      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 지원하지 않는 교체 타입: ${exchangePath.type}');
      return false;
    } catch (e) {
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 교체 실행 중 오류: $e');
      return false;
    }
  }

  /// 1:1 교체 실행
  static bool _executeOneToOneExchange(
    OneToOneExchangePath exchangePath,
    List<TimeSlot> timeSlots,
  ) {
    try {
      final sourceNode = exchangePath.sourceNode;
      final targetNode = exchangePath.targetNode;

      final exchangeService = ExchangeService();
      return exchangeService.performOneToOneExchange(
        timeSlots,
        sourceNode.teacherName,
        sourceNode.day,
        sourceNode.period,
        targetNode.teacherName,
        targetNode.day,
        targetNode.period,
      );
    } catch (e) {
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 1:1 교체 실행 중 오류: $e');
      return false;
    }
  }

  /// 순환 교체 실행
  static bool _executeCircularExchange(
    CircularExchangePath exchangePath,
    List<TimeSlot> timeSlots,
  ) {
    try {
      final exchangeService = ExchangeService();
      return exchangeService.performCircularExchange(
        timeSlots,
        exchangePath.nodes,
      );
    } catch (e) {
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 순환 교체 실행 중 오류: $e');
      return false;
    }
  }

  /// 연쇄 교체 실행
  static bool _executeChainExchange(
    ChainExchangePath exchangePath,
    List<TimeSlot> timeSlots,
  ) {
    try {
      final exchangeService = ExchangeService();
      
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 연쇄 교체 실행: A(${exchangePath.nodeA.displayText}) ↔ B(${exchangePath.nodeB.displayText})');
      
      // 연쇄 교체는 두 단계로 이루어짐:
      // 1단계: node1 ↔ node2 교체 (node2를 비우기 위해)
      // 2단계: nodeA ↔ nodeB 교체 (최종 교체)
      
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 연쇄 교체 1단계: ${exchangePath.node1.displayText} ↔ ${exchangePath.node2.displayText}');
      
      // 1단계: node1 ↔ node2 교체
      bool step1Success = exchangeService.performOneToOneExchange(
        timeSlots,
        exchangePath.node1.teacherName,
        exchangePath.node1.day,
        exchangePath.node1.period,
        exchangePath.node2.teacherName,
        exchangePath.node2.day,
        exchangePath.node2.period,
      );
      
      if (!step1Success) {
        AppLogger.exchangeDebug('[PersonalExchangeViewManager] 연쇄 교체 1단계 실패');
        return false;
      }
      
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 연쇄 교체 2단계: ${exchangePath.nodeA.displayText} ↔ ${exchangePath.nodeB.displayText}');
      
      // 2단계: nodeA ↔ nodeB 교체
      bool step2Success = exchangeService.performOneToOneExchange(
        timeSlots,
        exchangePath.nodeA.teacherName,
        exchangePath.nodeA.day,
        exchangePath.nodeA.period,
        exchangePath.nodeB.teacherName,
        exchangePath.nodeB.day,
        exchangePath.nodeB.period,
      );
      
      if (!step2Success) {
        AppLogger.exchangeDebug('[PersonalExchangeViewManager] 연쇄 교체 2단계 실패');
        return false;
      }
      
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 연쇄 교체 완료: 2단계 모두 성공');
      return true;
    } catch (e) {
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 연쇄 교체 실행 중 오류: $e');
      return false;
    }
  }

  /// 보강 교체 실행
  static bool _executeSupplementExchange(
    SupplementExchangePath exchangePath,
    List<TimeSlot> timeSlots,
  ) {
    try {
      final exchangeService = ExchangeService();
      final sourceNode = exchangePath.sourceNode;
      final targetNode = exchangePath.targetNode;
      
      // 다른 경로와 다른 방식 : 타켓(2번째 클릭) -> 소스(1번째 클릭)
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 보강 교체 실행: ${targetNode.displayText} → ${sourceNode.displayText}');
      
      return exchangeService.performSupplementExchange(
        timeSlots,
        sourceNode.teacherName,
        sourceNode.day,
        sourceNode.period,
        targetNode.teacherName,
        targetNode.day,
        targetNode.period,
      );
    } catch (e) {
      AppLogger.exchangeDebug('[PersonalExchangeViewManager] 보강 교체 실행 중 오류: $e');
      return false;
    }
  }
}


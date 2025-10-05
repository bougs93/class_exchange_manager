import '../models/exchange_path.dart';
import '../models/exchange_history_item.dart';
import 'exchange_history_service.dart';
import 'dart:developer' as developer;

/// 교체 히스토리 통합 관리 클래스
/// 되돌리기와 교체 리스트를 통합적으로 관리
class ExchangeHistoryManager {
  final ExchangeHistoryService _historyService = ExchangeHistoryService();

  /// 교체 실행 시 히스토리에 추가
  /// 교체 버튼 클릭 시 호출
  void executeExchange(ExchangePath path, {
    String? customDescription,
    Map<String, dynamic>? additionalMetadata,
    String? notes,
    List<String>? tags,
  }) {
    // 교체 실행 (실제 교체 로직은 별도 구현 필요)
    _performExchange(path);
    
    // 히스토리에 추가 (되돌리기 스택 + 교체 리스트에 동시 저장)
    _historyService.addExchange(
      path,
      customDescription: customDescription,
      additionalMetadata: additionalMetadata,
      notes: notes,
      tags: tags,
    );
  }

  /// 교체 리스트에서 특정 항목 삭제
  /// 삭제 버튼 클릭 시 호출
  void removeFromExchangeList(String itemId) {
    _historyService.removeFromExchangeList(itemId);
  }

  /// 교체 리스트 전체 조회
  List<ExchangeHistoryItem> getExchangeList() {
    return _historyService.getExchangeList();
  }

  /// 교체 리스트 전체 삭제
  void clearExchangeList() {
    _historyService.clearExchangeList();
  }

  /// 되돌리기 스택 조회
  List<ExchangeHistoryItem> getUndoStack() {
    return _historyService.getUndoStack();
  }

  /// 가장 최근 교체 작업 되돌리기
  /// 되돌리기 버튼 클릭 시 호출
  ExchangeHistoryItem? undoLastExchange() {
    final item = _historyService.undoLastExchange();
    if (item != null) {
      // 실제 되돌리기 로직 실행 (별도 구현 필요)
      _revertExchange(item);
    }
    return item;
  }

  /// 교체 리스트에서 특정 항목 조회
  ExchangeHistoryItem? getExchangeItem(String itemId) {
    return _historyService.getExchangeItem(itemId);
  }

  /// 교체 리스트에서 설명으로 검색
  List<ExchangeHistoryItem> searchByDescription(String query) {
    return _historyService.searchByDescription(query);
  }

  /// 교체 리스트에서 날짜별 필터링
  List<ExchangeHistoryItem> filterByDate(DateTime start, DateTime end) {
    return _historyService.filterByDate(start, end);
  }

  /// 교체 리스트에서 타입별 필터링
  List<ExchangeHistoryItem> filterByType(ExchangePathType type) {
    return _historyService.filterByType(type);
  }

  /// 교체 리스트에서 태그별 필터링
  List<ExchangeHistoryItem> filterByTags(List<String> tags) {
    return _historyService.filterByTags(tags);
  }

  /// 교체 리스트 항목 수정 (메모, 태그)
  void updateExchangeItem(String itemId, {
    String? notes,
    List<String>? tags,
    Map<String, dynamic>? additionalMetadata,
  }) {
    _historyService.updateExchangeItem(
      itemId,
      notes: notes,
      tags: tags,
      additionalMetadata: additionalMetadata,
    );
  }

  /// 교체 리스트 통계 정보
  Map<String, dynamic> getExchangeListStats() {
    return _historyService.getExchangeListStats();
  }

  /// 앱 시작 시 로컬 저장소에서 데이터 로드
  Future<void> loadFromLocalStorage() async {
    await _historyService.loadFromLocalStorage();
  }

  // ========== 디버그 콘솔 출력 메서드들 ==========

  /// 교체 리스트를 콘솔에 출력
  void printExchangeList() {
    _historyService.printExchangeList();
  }

  /// 되돌리기 히스토리를 콘솔에 출력
  void printUndoHistory() {
    _historyService.printUndoHistory();
  }

  /// 전체 히스토리 통계를 콘솔에 출력
  void printHistoryStats() {
    _historyService.printHistoryStats();
  }

  // ========== 실제 교체/되돌리기 로직 (별도 구현 필요) ==========

  /// 실제 교체 실행 로직
  /// TODO: TimetableDataSource와 연동하여 실제 교체 구현
  void _performExchange(ExchangePath path) {
    // TODO: 실제 교체 로직 구현
    developer.log('[교체 실행] ${path.displayTitle}');
  }

  /// 실제 되돌리기 실행 로직
  /// TODO: TimetableDataSource와 연동하여 실제 되돌리기 구현
  void _revertExchange(ExchangeHistoryItem item) {
    // TODO: 실제 되돌리기 로직 구현
    developer.log('[되돌리기 실행] ${item.description}');
  }

  /// 교체된 셀 목록 가져오기
  List<String> getExchangedCellKeys() {
    return _historyService.getExchangedCellKeys();
  }
  
  /// 교체된 셀 목록 업데이트
  void updateExchangedCells() {
    _historyService.updateExchangedCells();
  }
  
  /// 교체된 셀에 해당하는 교체 경로 찾기
  ExchangePath? findExchangePathByCell(String teacherName, String day, int period) {
    return _historyService.findExchangePathByCell(teacherName, day, period);
  }

  @override
  String toString() {
    return 'ExchangeHistoryManager(${_historyService.toString()})';
  }
}

import '../models/exchange_history_item.dart';
import '../models/exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../utils/logger.dart';
import 'dart:developer' as developer;

/// 교체 히스토리를 관리하는 서비스 클래스
/// 교체 실행, 되돌리기, 교체 리스트 관리를 담당
class ExchangeHistoryService {
  // 싱글톤 인스턴스
  static final ExchangeHistoryService _instance = ExchangeHistoryService._internal();
  
  // 싱글톤 생성자
  factory ExchangeHistoryService() => _instance;
  
  // 내부 생성자
  ExchangeHistoryService._internal();
  
  // 되돌리기용 스택 (메모리 저장, 최근 10개)
  final List<ExchangeHistoryItem> _undoStack = [];
  
  // 교체 리스트용 아카이브 (로컬 저장소, 모든 교체 보관)
  final List<ExchangeHistoryItem> _exchangeList = [];
  
  // 교체된 셀 관리는 _exchangeList를 통해 직접 확인
  
  // 최대 되돌리기 항목 수
  static const int maxUndoItems = 10;

  /// 교체 실행 및 히스토리에 추가 (통합 메서드)
  /// 교체 버튼 클릭 시 호출
  void executeExchange(ExchangePath path, {
    String? customDescription,
    Map<String, dynamic>? additionalMetadata,
    String? notes,
    List<String>? tags,
  }) {
    // 실제 교체 실행 (TimetableDataSource 업데이트는 외부에서 처리)
    AppLogger.exchangeInfo('[교체 실행] ${path.displayTitle}');

    // 히스토리에 추가
    addExchange(
      path,
      customDescription: customDescription,
      additionalMetadata: additionalMetadata,
      notes: notes,
      tags: tags,
    );
  }

  /// 교체 실행 시 히스토리에 추가 (내부 메서드)
  void addExchange(ExchangePath path, {
    String? customDescription,
    Map<String, dynamic>? additionalMetadata,
    String? notes,
    List<String>? tags,
  }) {
    // ExchangeHistoryItem 생성
    final item = ExchangeHistoryItem.fromExchangePath(
      path,
      customDescription: customDescription,
      additionalMetadata: additionalMetadata,
      notes: notes,
      tags: tags,
    );

    // 교체 리스트에 추가 (영구 보관)
    _exchangeList.add(item);
    _saveToLocalStorage(item);

    // 되돌리기 스택에 추가 (최근 10개만)
    _undoStack.add(item);
    if (_undoStack.length > maxUndoItems) {
      _undoStack.removeAt(0);
      // 메모리에서만 제거, 로컬 저장소는 유지
    }
  }

  /// 교체 리스트에서 특정 항목 삭제
  /// 삭제 버튼 클릭 시 호출
  void removeFromExchangeList(String itemId) {
    // 교체 리스트에서 제거
    _exchangeList.removeWhere((item) => item.id == itemId);
    
    // 로컬 저장소에서도 제거
    _removeFromLocalStorage(itemId);
  }

  /// 교체 리스트 전체 조회
  List<ExchangeHistoryItem> getExchangeList() {
    return List.from(_exchangeList);
  }

  /// 교체 리스트 전체 삭제
  void clearExchangeList() {
    _exchangeList.clear();
    _clearLocalStorage();
  }

  /// 되돌리기 스택 조회
  List<ExchangeHistoryItem> getUndoStack() {
    return List.from(_undoStack);
  }

  /// 가장 최근 교체 작업 되돌리기
  /// 되돌리기 버튼 클릭 시 호출
  ExchangeHistoryItem? undoLastExchange() {
    if (_undoStack.isEmpty) return null;
    
    final item = _undoStack.removeLast();
    
    // 되돌리기 상태로 변경
    final revertedItem = item.copyWithReverted(true);
    
    // 교체 리스트에서도 되돌리기 상태 업데이트
    final index = _exchangeList.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _exchangeList[index] = revertedItem;
      _updateInLocalStorage(revertedItem);
    }
    
    return item;
  }

  /// 되돌리기 스택 초기화
  void clearUndoStack() {
    _undoStack.clear();
  }

  /// 교체 리스트에서 특정 항목 조회
  ExchangeHistoryItem? getExchangeItem(String itemId) {
    try {
      return _exchangeList.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  /// 교체 리스트에서 설명으로 검색
  List<ExchangeHistoryItem> searchByDescription(String query) {
    if (query.isEmpty) return getExchangeList();
    
    return _exchangeList.where((item) => 
      item.description.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  /// 교체 리스트에서 날짜별 필터링
  List<ExchangeHistoryItem> filterByDate(DateTime start, DateTime end) {
    return _exchangeList.where((item) => 
      item.timestamp.isAfter(start) && item.timestamp.isBefore(end)
    ).toList();
  }

  /// 교체 리스트에서 타입별 필터링
  List<ExchangeHistoryItem> filterByType(ExchangePathType type) {
    return _exchangeList.where((item) => item.type == type).toList();
  }

  /// 교체 리스트에서 태그별 필터링
  List<ExchangeHistoryItem> filterByTags(List<String> tags) {
    return _exchangeList.where((item) => 
      tags.any((tag) => item.tags.contains(tag))
    ).toList();
  }

  /// 교체 리스트 항목 수정 (메모, 태그)
  void updateExchangeItem(String itemId, {
    String? notes,
    List<String>? tags,
    Map<String, dynamic>? additionalMetadata,
  }) {
    final index = _exchangeList.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    ExchangeHistoryItem updatedItem = _exchangeList[index];
    
    if (notes != null) {
      updatedItem = updatedItem.copyWithNotes(notes);
    }
    
    if (tags != null) {
      updatedItem = updatedItem.copyWithTags(tags);
    }
    
    if (additionalMetadata != null) {
      updatedItem = updatedItem.copyWithMetadata(additionalMetadata);
    }

    _exchangeList[index] = updatedItem;
    _updateInLocalStorage(updatedItem);
  }

  /// 교체 리스트 통계 정보
  Map<String, dynamic> getExchangeListStats() {
    final total = _exchangeList.length;
    final reverted = _exchangeList.where((item) => item.isReverted).length;
    final active = total - reverted;
    
    final typeStats = <ExchangePathType, int>{};
    for (final item in _exchangeList) {
      typeStats[item.type] = (typeStats[item.type] ?? 0) + 1;
    }

    return {
      'total': total,
      'active': active,
      'reverted': reverted,
      'typeStats': typeStats,
      'lastExchange': _exchangeList.isNotEmpty ? _exchangeList.last.timestamp : null,
    };
  }

  // ========== 로컬 저장소 관련 메서드들 (현재는 메모리만 사용) ==========

  void _saveToLocalStorage(ExchangeHistoryItem item) {
    // 메모리만 사용 (로컬 저장소 기능 추후 구현 시 확장)
  }

  void _removeFromLocalStorage(String itemId) {
    // 메모리만 사용 (로컬 저장소 기능 추후 구현 시 확장)
  }

  void _updateInLocalStorage(ExchangeHistoryItem item) {
    // 메모리만 사용 (로컬 저장소 기능 추후 구현 시 확장)
  }

  void _clearLocalStorage() {
    // 메모리만 사용 (로컬 저장소 기능 추후 구현 시 확장)
  }

  Future<void> loadFromLocalStorage() async {
    // 메모리만 사용 (로컬 저장소 기능 추후 구현 시 확장)
  }

  // ========== 디버그 콘솔 출력 메서드들 ==========

  /// 교체 리스트를 콘솔에 출력
  void printExchangeList() {
    _printList('[교체 리스트]', _exchangeList);
  }

  /// 되돌리기 히스토리를 콘솔에 출력
  void printUndoHistory() {
    _printList('[되돌리기 히스토리]', _undoStack);
  }

  /// 공통 리스트 출력 메서드
  void _printList(String title, List<ExchangeHistoryItem> list) {
    AppLogger.exchangeInfo('$title 총 ${list.length}개');
    if (list.isEmpty) {
      AppLogger.exchangeInfo('  비어있습니다.');
    } else {
      for (int i = 0; i < list.length; i++) {
        final item = list[i];
        AppLogger.exchangeInfo('  ${i + 1} Type: ${item.type.displayName} - ${_getNodeInfo(item.originalPath)}');
      }
    }
  }

  /// 전체 히스토리 통계를 콘솔에 출력
  void printHistoryStats() {
    final stats = getExchangeListStats();
    AppLogger.exchangeInfo('\n=== 교체 히스토리 통계 ===');
    AppLogger.exchangeInfo('전체 교체: ${stats['total']}개');
    AppLogger.exchangeInfo('활성 교체: ${stats['active']}개');
    AppLogger.exchangeInfo('되돌린 교체: ${stats['reverted']}개');
    AppLogger.exchangeInfo('되돌리기 가능: ${_undoStack.length}개');
    
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
  String _getNodeInfo(ExchangePath path) {
    try {
      if (path is OneToOneExchangePath) {
        return _formatNodes([path.sourceNode, path.targetNode]);
      } else if (path is CircularExchangePath) {
        return _formatNodes(path.nodes);
      } else if (path is ChainExchangePath) {
        return _formatNodes([path.node1, path.node2]);
      }
    } catch (e) {
      developer.log('노드 정보 추출 실패: $e');
    }
    return path.displayTitle;
  }

  /// 노드 리스트를 포맷팅
  String _formatNodes(List<dynamic> nodes) {
    return nodes.asMap().entries.map((entry) {
      final node = entry.value;
      return '[${entry.key}]${node.day}|${node.period}|${node.className}|${node.teacherName}|${node.subjectName}';
    }).join(', ');
  }
  
  /// 특정 셀이 교체된 셀인지 확인 (_exchangeList 기반)
  bool isCellExchanged(String teacherName, String day, int period) {
    for (final item in _exchangeList) {
      if (_isCellInExchangePath(item.originalPath, teacherName, day, period)) {
        return true;
      }
    }
    return false;
  }
  
  /// 교체된 셀에 해당하는 교체 경로 찾기 (_exchangeList 기반)
  ExchangePath? findExchangePathByCell(String teacherName, String day, int period) {
    for (final item in _exchangeList) {
      if (_isCellInExchangePath(item.originalPath, teacherName, day, period)) {
        return item.originalPath;
      }
    }
    return null;
  }
  
  /// ExchangePath에서 특정 셀이 포함되어 있는지 확인
  bool _isCellInExchangePath(ExchangePath path, String teacherName, String day, int period) {
    try {
      final nodes = _getNodesFromPath(path);
      return nodes.any((node) =>
        node.teacherName == teacherName &&
        node.day == day &&
        node.period == period
      );
    } catch (e) {
      developer.log('셀 확인 중 오류 발생: $e');
      return false;
    }
  }

  /// ExchangePath에서 노드 리스트 추출
  List<dynamic> _getNodesFromPath(ExchangePath path) {
    if (path is OneToOneExchangePath) {
      return [path.sourceNode, path.targetNode];
    } else if (path is CircularExchangePath) {
      return path.nodes;
    } else if (path is ChainExchangePath) {
      return [path.nodeA, path.nodeB, path.node1, path.node2];
    }
    return [];
  }
}

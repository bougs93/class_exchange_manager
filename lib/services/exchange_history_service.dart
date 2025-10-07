import '../models/exchange_history_item.dart';
import '../models/exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import 'dart:developer' as developer;

/// 교체 히스토리를 관리하는 서비스 클래스
/// 교체 실행, 되돌리기, 교체 리스트 관리를 담당
class ExchangeHistoryService {
  // 되돌리기용 스택 (메모리 저장, 최근 10개)
  final List<ExchangeHistoryItem> _undoStack = [];
  
  // 교체 리스트용 아카이브 (로컬 저장소, 모든 교체 보관)
  final List<ExchangeHistoryItem> _exchangeList = [];
  
  // 교체된 셀 관리 (셀 키: "교사명_요일_교시" 형식)
  final Set<String> _exchangedCells = {};
  
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
    developer.log('[교체 실행] ${path.displayTitle}');

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

    // 교체된 셀 목록 업데이트
    updateExchangedCells();

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
    
    // 교체된 셀 목록 업데이트
    updateExchangedCells();
    
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
    developer.log('[교체 리스트] 총 ${_exchangeList.length}개');
    if (_exchangeList.isEmpty) {
      developer.log('  교체 리스트가 비어있습니다.');
    } else {
      for (int i = 0; i < _exchangeList.length; i++) {
        final item = _exchangeList[i];
        final nodeInfo = _getNodeInfo(item.originalPath);
        developer.log('  ${i + 1} Type: ${_getPathTypeString(item.type)} - $nodeInfo');
      }
    }
  }

  /// 되돌리기 히스토리를 콘솔에 출력
  void printUndoHistory() {
    developer.log('[되돌리기 히스토리] 총 ${_undoStack.length}개');
    if (_undoStack.isEmpty) {
      developer.log('  되돌리기 히스토리가 비어있습니다.');
    } else {
      for (int i = 0; i < _undoStack.length; i++) {
        final item = _undoStack[i];
        final nodeInfo = _getNodeInfo(item.originalPath);
        developer.log('  ${i + 1} Type: ${_getPathTypeString(item.type)} - $nodeInfo');
      }
    }
  }

  /// 전체 히스토리 통계를 콘솔에 출력
  void printHistoryStats() {
    final stats = getExchangeListStats();
    developer.log('\n=== 교체 히스토리 통계 ===');
    developer.log('전체 교체: ${stats['total']}개');
    developer.log('활성 교체: ${stats['active']}개');
    developer.log('되돌린 교체: ${stats['reverted']}개');
    developer.log('되돌리기 가능: ${_undoStack.length}개');
    
    final typeStats = stats['typeStats'] as Map<ExchangePathType, int>;
    developer.log('\n교체 타입별 통계:');
    typeStats.forEach((type, count) {
      developer.log('  ${type.displayName}: $count개');
    });
    
    if (stats['lastExchange'] != null) {
      developer.log('\n마지막 교체: ${stats['lastExchange']}');
    }
    developer.log('========================\n');
  }

  /// ExchangePath에서 노드 정보를 요약해서 반환
  String _getNodeInfo(ExchangePath path) {
    try {
      // OneToOneExchangePath인지 확인
      if (path is OneToOneExchangePath) {
        final sourceNode = path.sourceNode;
        final targetNode = path.targetNode;
        
        final sourceInfo = '${sourceNode.day}|${sourceNode.period}|${sourceNode.className}|${sourceNode.teacherName}|${sourceNode.subjectName}';
        final targetInfo = '${targetNode.day}|${targetNode.period}|${targetNode.className}|${targetNode.teacherName}|${targetNode.subjectName}';
        
        return '[0]$sourceInfo, [1]$targetInfo';
      } 
      // CircularExchangePath인지 확인
      else if (path is CircularExchangePath) {
        final nodes = path.nodes;
        
        final nodeInfos = <String>[];
        for (int i = 0; i < nodes.length; i++) {
          final node = nodes[i];
          final nodeInfo = '${node.day}|${node.period}|${node.className}|${node.teacherName}|${node.subjectName}';
          nodeInfos.add('[$i]$nodeInfo');
        }
        
        return nodeInfos.join(', ');
      } 
      // ChainExchangePath인지 확인
      else if (path is ChainExchangePath) {
        final node1 = path.node1;
        final node2 = path.node2;
        
        final node1Info = '${node1.day}|${node1.period}|${node1.className}|${node1.teacherName}|${node1.subjectName}';
        final node2Info = '${node2.day}|${node2.period}|${node2.className}|${node2.teacherName}|${node2.subjectName}';
        
        return '[0]$node1Info, [1]$node2Info';
      }
    } catch (e) {
      developer.log('노드 정보 추출 실패: $e');
      return path.displayTitle;
    }
    return path.displayTitle;
  }

  /// ExchangePathType을 문자열로 변환
  String _getPathTypeString(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return 'oneToOne';
      case ExchangePathType.circular:
        return 'circular';
      case ExchangePathType.chain:
        return 'chain';
    }
  }
  
  /// ExchangePath에서 교체된 소스 셀 키 목록 생성
  List<String> _getExchangedSourceCellKeys(ExchangePath path) {
    final cellKeys = <String>[];
    
    try {
      if (path is OneToOneExchangePath) {
        // 1:1 교체의 경우: 원본 수업이 있던 셀들
        final sourceNode = path.sourceNode;
        final targetNode = path.targetNode;
        
        cellKeys.add('${sourceNode.teacherName}_${sourceNode.day}_${sourceNode.period}');
        cellKeys.add('${targetNode.teacherName}_${targetNode.day}_${targetNode.period}');
      } else if (path is CircularExchangePath) {
        // 순환 교체의 경우: 첫 번째 노드는 소스만, 나머지는 이전 노드의 교사가 들어가므로 목적지
        cellKeys.add('${path.nodes.first.teacherName}_${path.nodes.first.day}_${path.nodes.first.period}');
      } else if (path is ChainExchangePath) {
        // 연쇄 교체의 경우: 각 교체 쌍의 첫 번째 노드들
        cellKeys.add('${path.node1.teacherName}_${path.node1.day}_${path.node1.period}');
        cellKeys.add('${path.node2.teacherName}_${path.node2.day}_${path.node2.period}');
      }
    } catch (e) {
      developer.log('교체된 소스 셀 키 생성 실패: $e');
    }
    
    return cellKeys;
  }
  
  /// ExchangePath에서 교체된 목적지 셀 키 목록 생성
  List<String> _getExchangedDestinationCellKeys(ExchangePath path) {
    final cellKeys = <String>[];
    
    try {
      if (path is OneToOneExchangePath) {
        // 1:1 교체의 경우: 각 교사가 이동하는 상대방 위치
        final sourceNode = path.sourceNode;
        final targetNode = path.targetNode;
        
        // targetNode의 교사가 sourceNode 위치로 이동
        cellKeys.add('${targetNode.teacherName}_${sourceNode.day}_${sourceNode.period}');
        // sourceNode의 교사가 targetNode 위치로 이동
        cellKeys.add('${sourceNode.teacherName}_${targetNode.day}_${targetNode.period}');
      } else if (path is CircularExchangePath) {
        // 순환 교체의 경우: 첫 번째 노드 제외한 나머지 노드들
        for (int i = 1; i < path.nodes.length; i++) {
          final node = path.nodes[i];
          cellKeys.add('${node.teacherName}_${node.day}_${node.period}');
        }
      } else if (path is ChainExchangePath) {
        // 연쇄 교체의 경우: 각 교체 쌍의 두 번째 노드들
        cellKeys.add('${path.nodeA.teacherName}_${path.nodeA.day}_${path.nodeA.period}');
        cellKeys.add('${path.nodeB.teacherName}_${path.nodeB.day}_${path.nodeB.period}');
      }
    } catch (e) {
      developer.log('교체된 목적지 셀 키 생성 실패: $e');
    }
    
    return cellKeys;
  }
  
  /// ExchangePath에서 교체된 셀 키 목록 생성 (기존 로직 유지)
  List<String> _getExchangedCellKeys(ExchangePath path) {
    final cellKeys = <String>[];
    
    try {
      if (path is OneToOneExchangePath) {
        // 1:1 교체의 경우
        final sourceNode = path.sourceNode;
        final targetNode = path.targetNode;
        
        cellKeys.add('${sourceNode.teacherName}_${sourceNode.day}_${sourceNode.period}');
        cellKeys.add('${targetNode.teacherName}_${targetNode.day}_${targetNode.period}');
      } else if (path is CircularExchangePath) {
        // 순환 교체의 경우
        for (final node in path.nodes) {
          cellKeys.add('${node.teacherName}_${node.day}_${node.period}');
        }
      } else if (path is ChainExchangePath) {
        // 연쇄 교체의 경우 - 4개의 노드 모두 교체됨
        cellKeys.add('${path.nodeA.teacherName}_${path.nodeA.day}_${path.nodeA.period}');
        cellKeys.add('${path.nodeB.teacherName}_${path.nodeB.day}_${path.nodeB.period}');
        cellKeys.add('${path.node1.teacherName}_${path.node1.day}_${path.node1.period}');
        cellKeys.add('${path.node2.teacherName}_${path.node2.day}_${path.node2.period}');
      }
    } catch (e) {
      developer.log('교체된 셀 키 생성 실패: $e');
    }
    
    return cellKeys;
  }
  
  /// 교체된 셀 목록 업데이트 (교체 리스트 변경 시 호출)
  void updateExchangedCells() {
    _exchangedCells.clear();
    
    // 교체 리스트의 모든 항목에서 셀 키 추출 (기존 로직 유지)
    for (final item in _exchangeList) {
      final cellKeys = _getExchangedCellKeys(item.originalPath);
      _exchangedCells.addAll(cellKeys);
    }
  }
  
  /// 교체된 소스 셀 목록 가져오기
  List<String> getExchangedSourceCellKeys() {
    final sourceCellKeys = <String>[];
    for (final item in _exchangeList) {
      sourceCellKeys.addAll(_getExchangedSourceCellKeys(item.originalPath));
    }
    return sourceCellKeys;
  }
  
  /// 교체된 목적지 셀 목록 가져오기
  List<String> getExchangedDestinationCellKeys() {
    final destinationCellKeys = <String>[];
    for (final item in _exchangeList) {
      destinationCellKeys.addAll(_getExchangedDestinationCellKeys(item.originalPath));
    }
    return destinationCellKeys;
  }
  
  /// 교체된 셀 목록 가져오기
  List<String> getExchangedCellKeys() {
    return _exchangedCells.toList();
  }
  
  /// 특정 셀이 교체된 소스 셀인지 확인 (기존 로직 유지)
  bool isCellExchangedSource(String teacherName, String day, int period) {
    final cellKey = '${teacherName}_${day}_$period';
    return _exchangedCells.contains(cellKey);
  }
  
  /// 교체된 셀에 해당하는 교체 경로 찾기
  /// 교체된 셀을 클릭했을 때 해당 교체 경로를 반환
  ExchangePath? findExchangePathByCell(String teacherName, String day, int period) {
    final cellKey = '${teacherName}_${day}_$period';
    
    // 교체 리스트에서 해당 셀을 포함하는 교체 경로 찾기
    for (final item in _exchangeList) {
      final cellKeys = _getExchangedCellKeys(item.originalPath);
      if (cellKeys.contains(cellKey)) {
        return item.originalPath;
      }
    }
    
    return null;
  }
}

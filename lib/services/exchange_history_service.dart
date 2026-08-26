import '../models/exchange_history_item.dart';
import '../models/exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/dual_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'exchange_list_storage_service.dart';
import 'dart:developer' as developer;

/// 교체 히스토리를 관리하는 서비스 클래스
/// 교체 실행, 되돌리기, 교체 리스트 관리를 담당
class ExchangeHistoryService {
  // 싱글톤 인스턴스
  static final ExchangeHistoryService _instance =
      ExchangeHistoryService._internal();

  // 싱글톤 생성자
  factory ExchangeHistoryService() => _instance;

  // 내부 생성자
  ExchangeHistoryService._internal();

  // 되돌리기용 스택 (메모리 저장, 최근 10개)
  final List<ExchangeHistoryItem> _undoStack = [];

  // 다시 실행용 스택 (되돌리기 후 1단계씩 복구)
  final List<ExchangeHistoryItem> _redoStack = [];

  // 교체 리스트용 아카이브 (로컬 저장소, 모든 교체 보관)
  final List<ExchangeHistoryItem> _exchangeList = [];

  // 교체된 셀 관리는 _exchangeList를 통해 직접 확인

  // 최대 되돌리기 항목 수
  static const int maxUndoItems = 10;

  // 교체 리스트 변경 추적을 위한 버전 카운터
  // 이 값이 변경되면 교체 리스트가 변경된 것으로 간주합니다.
  int _exchangeListVersion = 0;

  /// 현재 스코프 시간표 ID
  ///
  /// null이면 교체 리스트 저장/로드가 건너뛰어집니다 (스코프 필수 정책).
  /// 활성 시간표 전환 시 Provider 계층에서 설정하고 재로드합니다.
  String? timetableId;

  // 버전 변경 콜백 (외부에서 설정하여 버전 변경 시 알림을 받을 수 있음)
  void Function()? _onVersionChanged;

  /// 버전 변경 콜백 설정 (Provider에서 호출)
  void setVersionChangedCallback(void Function()? callback) {
    _onVersionChanged = callback;
  }

  /// 버전 변경 알림 (내부 메서드)
  void _notifyVersionChanged() {
    if (_onVersionChanged != null) {
      _onVersionChanged!();
    }
  }

  /// 교체 실행 및 히스토리에 추가 (통합 메서드)
  /// 교체 버튼 클릭 시 호출
  void executeExchange(
    ExchangePath path, {
    String? customDescription,
    Map<String, dynamic>? additionalMetadata,
    String? notes,
    List<String>? tags,
    int? stepCount, // 순환교체 단계 수 (선택적)
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
      stepCount: stepCount,
    );
  }

  /// 교체 실행 시 히스토리에 추가 (내부 메서드)
  void addExchange(
    ExchangePath path, {
    String? customDescription,
    Map<String, dynamic>? additionalMetadata,
    String? notes,
    List<String>? tags,
    int? stepCount, // 순환교체 단계 수 (선택적)
  }) {
    // ExchangeHistoryItem 생성
    final item = ExchangeHistoryItem.fromExchangePath(
      path,
      customDescription: customDescription,
      additionalMetadata: additionalMetadata,
      notes: notes,
      tags: tags,
      stepCount: stepCount,
    );

    // 교체 리스트에 추가 (영구 보관)
    _exchangeList.add(item);
    _saveToLocalStorage(item);

    // 🔥 교체 리스트 변경 추적: 버전 증가
    _exchangeListVersion++;
    _notifyVersionChanged();

    // 되돌리기 스택에 추가 (최근 10개만)
    _undoStack.add(item);
    if (_undoStack.length > maxUndoItems) {
      _undoStack.removeAt(0);
      // 메모리에서만 제거, 로컬 저장소는 유지
    }

    // 새 교체 실행 시 다시 실행 스택 초기화 (표준 undo/redo 동작)
    _redoStack.clear();
  }

  /// 교체 리스트에서 특정 항목 삭제
  /// 삭제 버튼 클릭 시 호출
  void removeFromExchangeList(String itemId) {
    _exchangeList.removeWhere((item) => item.id == itemId);
    _purgeItemFromStacks(itemId);

    _removeFromLocalStorage(itemId);

    _exchangeListVersion++;
    _notifyVersionChanged();
  }

  /// 교체 리스트 전체 조회
  List<ExchangeHistoryItem> getExchangeList() {
    return List.from(_exchangeList);
  }

  /// 활성(되돌리지 않은) 교체 리스트 조회
  List<ExchangeHistoryItem> getActiveExchangeList() {
    return _exchangeList.where((item) => !item.isReverted).toList();
  }

  /// 교체 리스트 버전 조회 (변경 추적용)
  /// 이 값이 변경되면 교체 리스트가 변경된 것으로 간주됩니다.
  int getExchangeListVersion() {
    return _exchangeListVersion;
  }

  /// 교체 리스트 전체 삭제
  void clearExchangeList() {
    _exchangeList.clear();
    _undoStack.clear();
    _redoStack.clear();
    _clearLocalStorage();

    // 🔥 교체 리스트 변경 추적: 버전 증가
    _exchangeListVersion++;
    _notifyVersionChanged();
  }

  /// 되돌리기 스택 조회
  List<ExchangeHistoryItem> getUndoStack() {
    return List.from(_undoStack);
  }

  /// 되돌리기 가능 여부
  bool get canUndo => _undoStack.isNotEmpty;

  /// 다시 실행 가능 여부 (되돌리기 직후에만)
  bool get canRedo => _redoStack.isNotEmpty;

  /// 다시 실행 스택 조회
  List<ExchangeHistoryItem> getRedoStack() {
    return List.from(_redoStack);
  }

  /// 가장 최근 교체 작업 되돌리기
  /// 되돌리기 버튼 클릭 시 호출
  ExchangeHistoryItem? undoLastExchange() {
    if (_undoStack.isEmpty) return null;

    final item = _undoStack.removeLast();

    final index = _exchangeList.indexWhere((i) => i.id == item.id);
    if (index == -1) {
      _undoStack.add(item);
      return null;
    }

    // 되돌리기 상태로 변경 (리스트에서 제거하지 않음 → 다시 실행 가능)
    final revertedItem = item.copyWithReverted(true);
    _exchangeList[index] = revertedItem;
    _updateInLocalStorage(revertedItem);

    _exchangeListVersion++;
    _notifyVersionChanged();

    // 다시 실행 스택에 추가
    _redoStack.add(item);

    return item;
  }

  /// 되돌리기한 교체 1건 다시 실행
  /// 다시 실행 버튼 클릭 시 호출
  ExchangeHistoryItem? redoLastExchange() {
    if (_redoStack.isEmpty) return null;

    final item = _redoStack.removeLast();

    final index = _exchangeList.indexWhere((i) => i.id == item.id);
    if (index == -1) {
      _redoStack.add(item);
      return null;
    }

    // 활성 상태로 복구
    final restoredItem = item.copyWithReverted(false);
    _exchangeList[index] = restoredItem;
    _updateInLocalStorage(restoredItem);

    // 되돌리기 스택에 다시 추가
    _undoStack.add(item);
    if (_undoStack.length > maxUndoItems) {
      _undoStack.removeAt(0);
    }

    _exchangeListVersion++;
    _notifyVersionChanged();

    return restoredItem;
  }

  /// 되돌리기 스택 초기화
  void clearUndoStack() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// undo/redo 스택에서 특정 항목 제거
  void _purgeItemFromStacks(String itemId) {
    _undoStack.removeWhere((item) => item.id == itemId);
    _redoStack.removeWhere((item) => item.id == itemId);
  }

  /// 단위 테스트용 상태 초기화 (로컬 저장소 I/O 없음)
  @visibleForTesting
  void resetForTesting() {
    _exchangeList.clear();
    _undoStack.clear();
    _redoStack.clear();
    _exchangeListVersion = 0;
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

    return _exchangeList
        .where(
          (item) =>
              item.description.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  /// 교체 리스트에서 날짜별 필터링
  List<ExchangeHistoryItem> filterByDate(DateTime start, DateTime end) {
    return _exchangeList
        .where(
          (item) =>
              item.timestamp.isAfter(start) && item.timestamp.isBefore(end),
        )
        .toList();
  }

  /// 교체 리스트에서 타입별 필터링
  List<ExchangeHistoryItem> filterByType(ExchangePathType type) {
    return _exchangeList.where((item) => item.type == type).toList();
  }

  /// 교체 리스트에서 태그별 필터링
  List<ExchangeHistoryItem> filterByTags(List<String> tags) {
    return _exchangeList
        .where((item) => tags.any((tag) => item.tags.contains(tag)))
        .toList();
  }

  /// 교체 리스트 항목 수정 (메모, 태그)
  void updateExchangeItem(
    String itemId, {
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
      'lastExchange':
          _exchangeList.isNotEmpty ? _exchangeList.last.timestamp : null,
    };
  }

  // ========== 로컬 저장소 관련 메서드들 ==========

  // 교체 리스트 저장 서비스
  final ExchangeListStorageService _storageService =
      ExchangeListStorageService();

  /// 교체 항목을 로컬 저장소에 저장
  ///
  /// 교체 리스트 전체를 다시 저장합니다.
  void _saveToLocalStorage(ExchangeHistoryItem item) async {
    try {
      // 전체 교체 리스트를 저장
      await _storageService.saveExchangeList(
        _exchangeList,
        timetableId: timetableId,
      );
    } catch (e) {
      AppLogger.error('교체 항목 저장 실패: $e', e);
    }
  }

  /// 교체 항목을 로컬 저장소에서 삭제
  ///
  /// 교체 리스트 전체를 다시 저장합니다.
  void _removeFromLocalStorage(String itemId) async {
    try {
      // 전체 교체 리스트를 저장
      await _storageService.saveExchangeList(
        _exchangeList,
        timetableId: timetableId,
      );
    } catch (e) {
      AppLogger.error('교체 항목 삭제 저장 실패: $e', e);
    }
  }

  /// 교체 항목을 로컬 저장소에서 업데이트
  ///
  /// 교체 리스트 전체를 다시 저장합니다.
  void _updateInLocalStorage(ExchangeHistoryItem item) async {
    try {
      // 전체 교체 리스트를 저장
      await _storageService.saveExchangeList(
        _exchangeList,
        timetableId: timetableId,
      );
    } catch (e) {
      AppLogger.error('교체 항목 업데이트 저장 실패: $e', e);
    }
  }

  /// 로컬 저장소에서 교체 리스트 전체 삭제
  void _clearLocalStorage() async {
    try {
      await _storageService.clearExchangeList(timetableId: timetableId);
    } catch (e) {
      AppLogger.error('교체 리스트 삭제 실패: $e', e);
    }
  }

  /// 교체 건에 인쇄 프로파일(계획서) 지정
  ///
  /// 메모리 항목을 갱신하고 로컬 저장소에 즉시 반영합니다.
  /// [profileId]가 null이면 미지정(기본 계획서 사용)으로 해제합니다.
  void assignProfile(String itemId, String? profileId) {
    final index = _exchangeList.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      AppLogger.warning('프로파일 지정 대상 교체 건을 찾을 수 없음: $itemId');
      return;
    }

    _exchangeList[index] = _exchangeList[index].copyWithProfileId(profileId);
    _exchangeListVersion++;
    _notifyVersionChanged();
    _saveToLocalStorage(_exchangeList[index]);
    AppLogger.info('교체 건 프로파일 지정: $itemId → $profileId');
  }

  /// 메모리 상태만 초기화 (파일은 건드리지 않음)
  ///
  /// 활성 시간표가 모두 삭제된 경우 레거시 파일의 고스트 데이터가
  /// 로드되지 않도록 스코프 해제와 함께 사용합니다.
  void resetInMemoryState() {
    _exchangeList.clear();
    _undoStack.clear();
    _redoStack.clear();
    _exchangeListVersion++;
    _notifyVersionChanged();
    AppLogger.info('교체 리스트 메모리 상태 초기화 (파일 미변경)');
  }

  /// 로컬 저장소에서 교체 리스트 로드
  ///
  /// 프로그램 시작 시 호출되어 저장된 교체 리스트를 메모리로 로드합니다.
  /// 시간표 스코프 전환 시에도 호출되므로, 되돌리기/다시실행 스택도 함께
  /// 초기화합니다 (다른 시간표의 셀을 되돌리는 사고 방지).
  Future<void> loadFromLocalStorage() async {
    try {
      // 스코프 전환 대비: 이전 시간표의 undo/redo 스택 초기화
      _undoStack.clear();
      _redoStack.clear();

      final loadedList = await _storageService.loadExchangeList(
        timetableId: timetableId,
      );

      // 메모리 교체 리스트를 로드된 데이터로 교체
      _exchangeList.clear();
      _exchangeList.addAll(loadedList);

      // 버전 증가 (UI 업데이트 트리거)
      _exchangeListVersion++;
      _notifyVersionChanged();

      AppLogger.info('교체 리스트 로드 완료: ${_exchangeList.length}개 항목');
    } catch (e) {
      AppLogger.error('교체 리스트 로드 실패: $e', e);
    }
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

  /// 다시 실행 히스토리를 콘솔에 출력
  void printRedoHistory() {
    _printList('[다시 실행 히스토리]', _redoStack);
  }

  /// 공통 리스트 출력 메서드
  void _printList(String title, List<ExchangeHistoryItem> list) {
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
  void printHistoryStats() {
    final stats = getExchangeListStats();
    AppLogger.exchangeInfo('\n=== 교체 히스토리 통계 ===');
    AppLogger.exchangeInfo('전체 교체: ${stats['total']}개');
    AppLogger.exchangeInfo('활성 교체: ${stats['active']}개');
    AppLogger.exchangeInfo('되돌린 교체: ${stats['reverted']}개');
    AppLogger.exchangeInfo('되돌리기 가능: ${_undoStack.length}개');
    AppLogger.exchangeInfo('다시 실행 가능: ${_redoStack.length}개');

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
  String _formatNodes(List<dynamic> nodes) {
    return nodes
        .asMap()
        .entries
        .map((entry) {
          final node = entry.value;
          return '[${entry.key}]${node.day}|${node.period}|${node.className}|${node.teacherName}|${node.subjectName}';
        })
        .join(', ');
  }

  /// 특정 셀이 교체된 셀인지 확인 (활성 교체만)
  bool isCellExchanged(String teacherName, String day, int period) {
    for (final item in _exchangeList) {
      if (item.isReverted) continue;
      if (_isCellInExchangePath(item.originalPath, teacherName, day, period)) {
        return true;
      }
    }
    return false;
  }

  /// 교체된 셀에 해당하는 교체 경로 찾기 (활성 교체만)
  ExchangePath? findExchangePathByCell(
    String teacherName,
    String day,
    int period,
  ) {
    for (final item in _exchangeList) {
      if (item.isReverted) continue;
      if (_isCellInExchangePath(item.originalPath, teacherName, day, period)) {
        return item.originalPath;
      }
    }
    return null;
  }

  /// ExchangePath에서 특정 셀이 포함되어 있는지 확인
  bool _isCellInExchangePath(
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
  List<dynamic> _getNodesFromPath(ExchangePath path) {
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

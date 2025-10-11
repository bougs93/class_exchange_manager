import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../services/exchange_history_service.dart';
import '../../../utils/timetable_data_source.dart';
import '../../../utils/logger.dart';
import '../../../providers/timetable_theme_provider.dart';
import '../../../providers/state_reset_provider.dart';

/// 교체 실행 관리 클래스
class ExchangeExecutor {
  final WidgetRef ref;
  final ExchangeHistoryService historyService;
  final TimetableDataSource? dataSource;
  final VoidCallback? onExchangeViewUpdate;  // 교체 뷰 업데이트 콜백

  ExchangeExecutor({
    required this.ref,
    required this.historyService,
    required this.dataSource,
    this.onExchangeViewUpdate,
  });

  /// 교체 실행 기능
  void executeExchange(
    ExchangePath exchangePath,
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) {
    // 1. 교체 실행
    historyService.executeExchange(
      exchangePath,
      customDescription: '교체 실행: ${exchangePath.displayTitle}',
      additionalMetadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'manual',
        'source': 'timetable_grid_section',
      },
    );

    // 2. 콘솔 출력
    historyService.printExchangeList();
    historyService.printUndoHistory();

    // 3. 교체된 셀 상태 업데이트
    _updateExchangedCells();

    // 4. 캐시 강제 무효화 및 UI 업데이트
    ref.read(stateResetProvider.notifier).resetExchangeStates(
          reason: '교체 실행 - 선택 상태 초기화',
        );

    // 5. 내부 선택된 경로 초기화
    onInternalPathClear();

    // 6. UI 업데이트
    dataSource?.notifyListeners();

    // 7. 교체 뷰 업데이트 (교체 뷰가 활성화된 경우)
    onExchangeViewUpdate?.call();

    // 8. 사용자 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('교체 경로 "${exchangePath.id}"가 실행되었습니다'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '되돌리기',
          textColor: Colors.white,
          onPressed: () => undoLastExchange(context, onInternalPathClear),
        ),
      ),
    );
  }

  /// 교체 리스트에서 삭제 기능
  void deleteFromExchangeList(
    ExchangePath exchangePath,
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) {
    // 1. 교체 리스트에서 찾아서 삭제
    final exchangeList = historyService.getExchangeList();
    final targetItem = exchangeList.firstWhere(
      (item) => item.originalPath.id == exchangePath.id,
      orElse: () => throw StateError('해당 교체 경로를 교체 리스트에서 찾을 수 없습니다'),
    );

    historyService.removeFromExchangeList(targetItem.id);

    // 2. 교체된 셀 목록 강제 업데이트
    // _exchangeList가 변경되었으므로 UI 업데이트만 필요

    // 3. 콘솔 출력
    historyService.printExchangeList();
    historyService.printUndoHistory();

    // 4. 교체된 셀 상태 업데이트
    _updateExchangedCells();

    // 5. 캐시 강제 무효화 및 UI 업데이트
    ref.read(stateResetProvider.notifier).resetExchangeStates(
          reason: '교체 삭제 - 선택 상태 초기화',
        );

    // 6. 내부 선택된 경로 초기화
    onInternalPathClear();

    // 7. UI 업데이트
    dataSource?.notifyListeners();
  }

  /// 되돌리기 기능
  void undoLastExchange(
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) {
    final item = historyService.undoLastExchange();

    if (item != null) {
      // 교체 리스트에서 삭제
      historyService.removeFromExchangeList(item.id);

      // 콘솔 출력
      historyService.printExchangeList();
      historyService.printUndoHistory();

      // 교체된 셀 상태 업데이트
      _updateExchangedCells();

      // 캐시 강제 무효화 및 UI 업데이트
      ref.read(stateResetProvider.notifier).resetExchangeStates(
            reason: '되돌리기 - 선택 상태 초기화',
          );

      // UI 업데이트
      dataSource?.notifyListeners();

      // 사용자 피드백
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('교체 "${item.description}"가 되돌려졌습니다'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('되돌릴 교체가 없습니다'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 다시 반복 기능
  void repeatLastExchange(BuildContext context) {
    final exchangeList = historyService.getExchangeList();
    if (exchangeList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('반복할 교체가 없습니다'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 가장 최근 교체 항목
    final lastItem = exchangeList.last;

    // 교체 다시 실행
    historyService.executeExchange(
      lastItem.originalPath,
      customDescription: '다시 반복: ${lastItem.description}',
      additionalMetadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'repeat',
        'source': 'timetable_grid_section',
        'originalId': lastItem.id,
      },
    );

    // 콘솔 출력
    historyService.printExchangeList();
    historyService.printUndoHistory();

    // 교체된 셀 상태 업데이트
    _updateExchangedCells();

    // 캐시 강제 무효화 및 UI 업데이트
    ref.read(stateResetProvider.notifier).resetExchangeStates(
          reason: '다시 반복 - 선택 상태 초기화',
        );

    // UI 업데이트
    dataSource?.notifyListeners();

    // 사용자 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('교체 "${lastItem.description}"가 다시 실행되었습니다'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 교체된 셀 상태 업데이트 (공통 메서드)
  void _updateExchangedCells() {
    // 교체된 셀 목록을 _exchangeList에서 직접 추출
    final exchangedCells = _getExchangedCellsFromList();
    ref.read(timetableThemeProvider.notifier).updateExchangedCells(exchangedCells);

    // 교체된 목적지 셀 목록을 _exchangeList에서 직접 추출
    final exchangedDestinationCells = _getExchangedDestinationCellsFromList();
    ref.read(timetableThemeProvider.notifier).updateExchangedDestinationCells(exchangedDestinationCells);

    _debugPrintExchangedDestinationCells(exchangedDestinationCells);
  }

  /// _exchangeList에서 교체된 셀 목록 추출
  List<String> _getExchangedCellsFromList() {
    final cellKeys = <String>[];
    
    for (final item in historyService.getExchangeList()) {
      final path = item.originalPath;
      
      if (path is OneToOneExchangePath) {
        final sourceNode = path.sourceNode;
        final targetNode = path.targetNode;
        
        cellKeys.add('${sourceNode.teacherName}_${sourceNode.day}_${sourceNode.period}');
        cellKeys.add('${targetNode.teacherName}_${targetNode.day}_${targetNode.period}');
      } else if (path is CircularExchangePath) {
        for (final node in path.nodes) {
          cellKeys.add('${node.teacherName}_${node.day}_${node.period}');
        }
      } else if (path is ChainExchangePath) {
        cellKeys.add('${path.nodeA.teacherName}_${path.nodeA.day}_${path.nodeA.period}');
        cellKeys.add('${path.nodeB.teacherName}_${path.nodeB.day}_${path.nodeB.period}');
        cellKeys.add('${path.node1.teacherName}_${path.node1.day}_${path.node1.period}');
        cellKeys.add('${path.node2.teacherName}_${path.node2.day}_${path.node2.period}');
      }
    }
    
    return cellKeys;
  }

  /// _exchangeList에서 교체된 목적지 셀 목록 추출
  List<String> _getExchangedDestinationCellsFromList() {
    final cellKeys = <String>[];
    
    for (final item in historyService.getExchangeList()) {
      final path = item.originalPath;
      
      if (path is OneToOneExchangePath) {
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
    }
    
    return cellKeys;
  }

  /// 교체된 목적지 셀 디버그 출력
  void _debugPrintExchangedDestinationCells(List<String> destinationCellKeys) {
    if (destinationCellKeys.isEmpty) {
      AppLogger.exchangeDebug('교체된 목적지 셀: 없음');
      return;
    }

    AppLogger.exchangeDebug('=== 교체된 목적지 셀 목록 ===');
    AppLogger.exchangeDebug('총 ${destinationCellKeys.length}개 목적지 셀');
    AppLogger.exchangeDebug('========================');
  }
}

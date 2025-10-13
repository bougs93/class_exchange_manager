import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/supplement_exchange_path.dart';
import '../../../models/exchange_history_item.dart';
import '../../../services/exchange_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/timetable_data_source.dart';
import '../../../providers/cell_selection_provider.dart';
import '../../../providers/state_reset_provider.dart';
import '../../../providers/services_provider.dart';

/// 교체 실행 관리 클래스
class ExchangeExecutor {
  final WidgetRef ref;
  final TimetableDataSource? dataSource;

  ExchangeExecutor({
    required this.ref,
    required this.dataSource,
  });

  /// 교체 실행 기능
  void executeExchange(
    ExchangePath exchangePath,
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    
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

    // 7. 교체 뷰 업데이트 로깅
    AppLogger.exchangeDebug('🔄 교체 실행 완료 - 교체 뷰 업데이트');

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
    final historyService = ref.read(exchangeHistoryServiceProvider);
    
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
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final item = historyService.undoLastExchange();

    if (item != null) {
      // 보강교체인 경우 실제 TimeSlot 되돌리기
      if (item.type == ExchangePathType.supplement) {
        _undoSupplementExchange(item);
      }

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

  /// 보강교체 되돌리기 처리
  void _undoSupplementExchange(ExchangeHistoryItem item) {
    if (dataSource?.timeSlots == null) return;

    // SupplementExchangePath에서 목적지 셀 정보 가져오기
    if (item.originalPath is SupplementExchangePath) {
      final supplementPath = item.originalPath as SupplementExchangePath;
      final targetNode = supplementPath.targetNode;

      // ExchangeService를 통해 보강교체 되돌리기 실행
      final exchangeService = ExchangeService();
      final success = exchangeService.undoSupplementExchange(
        dataSource!.timeSlots,
        targetNode.teacherName,
        targetNode.day,
        targetNode.period,
      );

      if (success) {
        AppLogger.exchangeDebug('보강교체 되돌리기 성공: ${targetNode.teacherName} ${targetNode.day}${targetNode.period}교시');
      } else {
        AppLogger.exchangeDebug('보강교체 되돌리기 실패: ${targetNode.teacherName} ${targetNode.day}${targetNode.period}교시');
      }
    }
  }

  /// 다시 반복 기능
  void repeatLastExchange(BuildContext context) {
    final historyService = ref.read(exchangeHistoryServiceProvider);
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
    final cellNotifier = ref.read(cellSelectionProvider.notifier);
       
    // 교체된 소스 셀(교체 전 원본 수업이 있던 셀)의 테두리 스타일 업데이트
    cellNotifier.updateExchangedCells(_extractExchangedCells());
    // 교체된 목적지 셀(교체 후 새 교사가 배정된 셀)의 배경색 업데이트
    cellNotifier.updateExchangedDestinationCells(_extractDestinationCells());
  }

  /// 교체된 소스 셀 목록 추출 (교체 전 원본 위치의 셀들)
  List<String> _extractExchangedCells() {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final cellKeys = <String>[];

    for (final item in historyService.getExchangeList()) {
      cellKeys.addAll(_getCellKeysFromPath(item.originalPath));
    }

    return cellKeys;
  }

  /// [wg]교체 경로에서 소스 셀 키 목록 추출 (교체 전 원본 위치)
  List<String> _getCellKeysFromPath(ExchangePath path) {
    if (path is OneToOneExchangePath) {
      return [
        '${path.sourceNode.teacherName}_${path.sourceNode.day}_${path.sourceNode.period}',
        '${path.targetNode.teacherName}_${path.targetNode.day}_${path.targetNode.period}',
      ];
    } else if (path is CircularExchangePath) {
      // 순환 교체: 마지막 노드를 제외한 모든 노드가 소스 셀
      return path.nodes.take(path.nodes.length - 1).map((node) => '${node.teacherName}_${node.day}_${node.period}').toList();
    } else if (path is ChainExchangePath) {
      return [
        '${path.nodeA.teacherName}_${path.nodeA.day}_${path.nodeA.period}',
        '${path.nodeB.teacherName}_${path.nodeB.day}_${path.nodeB.period}',
        '${path.node1.teacherName}_${path.node1.day}_${path.node1.period}',
        '${path.node2.teacherName}_${path.node2.day}_${path.node2.period}',
      ];
    }
    return [];
  }

  /// [wg]교체된 목적지 셀 목록 추출 (교체 후 새 교사가 배정된 셀들)
  List<String> _extractDestinationCells() {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final cellKeys = <String>[];

    for (final item in historyService.getExchangeList()) {
      final path = item.originalPath;

      // 1:1 교체 경로의 목적지 셀 추출
      if (path is OneToOneExchangePath) {
        cellKeys.addAll([
          '${path.targetNode.teacherName}_${path.sourceNode.day}_${path.sourceNode.period}',
          '${path.sourceNode.teacherName}_${path.targetNode.day}_${path.targetNode.period}',
        ]);

        // 순환교체 경로의 목적지 셀 추출 (각 노드가 다음 노드의 위치로 이동)
      } else if (path is CircularExchangePath) {
        final destinationKeys = <String>[];
        
        for (int i = 0; i < path.nodes.length - 1; i++) {
          final currentNode = path.nodes[i];
          final nextNode = path.nodes[i + 1];
          // 현재 노드가 다음 노드의 위치로 이동
          final destinationKey = '${currentNode.teacherName}_${nextNode.day}_${nextNode.period}';
          destinationKeys.add(destinationKey);
        }
        
        cellKeys.addAll(destinationKeys);

        // 연쇄교체 경로의 목적지 셀 추출
        // 연쇄교체는 2단계로 이루어지므로 각 단계별 목적지 셀을 모두 추출
      } else if (path is ChainExchangePath) {
        // 1단계 교체 후 목적지 셀들
        // node1 교사가 node2 위치로 이동
        cellKeys.add('${path.node1.teacherName}_${path.node2.day}_${path.node2.period}');
        // node2 교사가 node1 위치로 이동
        cellKeys.add('${path.node2.teacherName}_${path.node1.day}_${path.node1.period}');

        // 2단계 교체 후 목적지 셀들
        // nodeA 교사가 nodeB 위치로 이동
        cellKeys.add('${path.nodeA.teacherName}_${path.nodeB.day}_${path.nodeB.period}');
        // nodeB 교사가 nodeA 위치로 이동
        cellKeys.add('${path.nodeB.teacherName}_${path.nodeA.day}_${path.nodeA.period}');
      }
    }

    return cellKeys;
  }
}

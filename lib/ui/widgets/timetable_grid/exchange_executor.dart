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
import '../../../providers/exchange_view_provider.dart';
import '../../../providers/exchange_screen_provider.dart';

/// 교체 실행 관리 클래스
class ExchangeExecutor {
  final WidgetRef ref;
  final TimetableDataSource? dataSource;
  final VoidCallback? onEnableExchangeView; // 교체 뷰 활성화 콜백

  ExchangeExecutor({
    required this.ref,
    required this.dataSource,
    this.onEnableExchangeView,
  });

  /// 공통 후처리 로직
  /// 모든 교체 작업(실행, 삭제, 되돌리기) 후 반복되는 로직을 통합
  void _executeCommonPostProcess({
    required BuildContext context,
    required VoidCallback onInternalPathClear,
    required String message,
    Color? snackBarColor,
    String? undoButtonLabel,
    VoidCallback? onUndoPressed,
  }) {
    final historyService = ref.read(exchangeHistoryServiceProvider);

    // 1. 콘솔 출력
    historyService.printExchangeList();
    historyService.printUndoHistory();

    // 2. 교체된 셀 상태 업데이트
    _updateExchangedCells();

    // 3. 교체 뷰 활성화 여부 검사
    _checkExchangeViewStatus();

    // 4. 캐시 강제 무효화 및 UI 업데이트
    ref.read(stateResetProvider.notifier).resetExchangeStates(reason: message);

    // 5. 내부 선택된 경로 초기화
    onInternalPathClear();

    // 6. UI 업데이트
    dataSource?.notifyDataChanged();

    // 7. 사용자 피드백
    _showSnackBar(
      context,
      message,
      snackBarColor ?? Colors.blue,
      undoButtonLabel,
      onUndoPressed,
    );
  }

  /// SnackBar 표시 헬퍼
  void _showSnackBar(
    BuildContext context,
    String message,
    Color backgroundColor,
    String? actionLabel,
    VoidCallback? onActionPressed,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        action: actionLabel != null && onActionPressed != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onActionPressed,
              )
            : null,
      ),
    );
  }

  /// 교체 실행 기능
  void executeExchange(
    ExchangePath exchangePath,
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) {
    final historyService = ref.read(exchangeHistoryServiceProvider);

    // 교체 실행 - 순환교체의 경우 단계 수 전달
    int? stepCount;
    if (exchangePath is CircularExchangePath) {
      stepCount = exchangePath.nodes.length; // 노드 수 = 단계 수
    }
    
    historyService.executeExchange(
      exchangePath,
      customDescription: '교체 실행: ${exchangePath.displayTitle}',
      additionalMetadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'manual',
        'source': 'timetable_grid_section',
      },
      stepCount: stepCount,
    );

    // 공통 후처리
    _executeCommonPostProcess(
      context: context,
      onInternalPathClear: onInternalPathClear,
      message: '교체 경로 "${exchangePath.id}"가 실행되었습니다',
      snackBarColor: Colors.blue,
      undoButtonLabel: '되돌리기',
      onUndoPressed: () => undoLastExchange(context, onInternalPathClear),
    );
  }

  /// 보강 실행 기능
  void executeSupplementExchange(
    String sourceTeacher,
    String sourceDay,
    int sourcePeriod,
    String targetTeacherName,
    String className,
    String subject,
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) {
    final historyService = ref.read(exchangeHistoryServiceProvider);

    // 보강 경로 생성
    final supplementPath = SupplementExchangePath.simple(
      id: 'supplement_${sourceTeacher}_${sourceDay}_$sourcePeriod',
      sourceTeacher: sourceTeacher,
      sourceDay: sourceDay,
      sourcePeriod: sourcePeriod,
      targetTeacher: targetTeacherName,
      targetDay: sourceDay,
      targetPeriod: sourcePeriod,
      className: className,
      subject: subject,
    );

    // 교체 실행
    historyService.executeExchange(
      supplementPath,
      customDescription: '보강 예약: $targetTeacherName → $sourceTeacher($sourceDay$sourcePeriod교시)',
      additionalMetadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'supplement_reservation',
        'source': 'timetable_grid_section',
      },
    );

    // 공통 후처리
    _executeCommonPostProcess(
      context: context,
      onInternalPathClear: onInternalPathClear,
      message: '보강 계획이 저장되었습니다: $targetTeacherName $sourceDay$sourcePeriod교시',
      snackBarColor: Colors.green,
      undoButtonLabel: '되돌리기',
      onUndoPressed: () => undoLastExchange(context, onInternalPathClear),
    );
  }

  /// 교체 리스트에서 삭제 기능
  /// 교체 뷰가 활성화된 경우 내부적으로 비활성화 → 삭제 → 재활성화 수행
  Future<void> deleteFromExchangeList(
    ExchangePath exchangePath,
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) async {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    
    // 교체 뷰 활성화 상태 확인
    final isExchangeViewEnabled = ref.read(isExchangeViewEnabledProvider);
    bool wasExchangeViewEnabled = false;
    
    if (isExchangeViewEnabled) {
      AppLogger.exchangeDebug('[ExchangeExecutor] 교체 뷰가 활성화된 상태에서 삭제 요청 - 내부적으로 비활성화 후 삭제 실행');
      wasExchangeViewEnabled = true;
      
      // 교체 뷰 비활성화
      final exchangeViewNotifier = ref.read(exchangeViewProvider.notifier);
      final screenState = ref.read(exchangeScreenProvider);
      
      if (screenState.timetableData != null && dataSource != null) {
        await exchangeViewNotifier.disableExchangeView(
          timeSlots: screenState.timetableData!.timeSlots,
          teachers: screenState.timetableData!.teachers,
          dataSource: dataSource!,
        );
        AppLogger.exchangeDebug('[ExchangeExecutor] 교체 뷰 비활성화 완료 - 삭제 실행 준비');
      }
    }
    
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

    // 7. UI 업데이트 (최적화됨 - 특정 셀만 업데이트하여 스크롤 위치 보존)
    dataSource?.notifyDataChanged();
    
    // 8. 교체 뷰가 원래 활성화되어 있었다면 다시 활성화
    if (wasExchangeViewEnabled) {
      AppLogger.exchangeDebug('[ExchangeExecutor] 삭제 완료 - 교체 뷰 재활성화 시작');
      
      final exchangeViewNotifier = ref.read(exchangeViewProvider.notifier);
      final screenState = ref.read(exchangeScreenProvider);
      
      if (screenState.timetableData != null && dataSource != null) {
        await exchangeViewNotifier.enableExchangeView(
          timeSlots: screenState.timetableData!.timeSlots,
          teachers: screenState.timetableData!.teachers,
          dataSource: dataSource!,
        );
        AppLogger.exchangeDebug('[ExchangeExecutor] 교체 뷰 재활성화 완료');
      }
    }
  }

  /// 되돌리기 기능
  void undoLastExchange(
    BuildContext context,
    VoidCallback onInternalPathClear,
  ) {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final item = historyService.undoLastExchange();

    if (item != null) {
      _applyExchangeStateAfterHistoryChange(item);

      historyService.printExchangeList();
      historyService.printUndoHistory();
      historyService.printRedoHistory();

      ref.read(stateResetProvider.notifier).resetExchangeStates(
            reason: '되돌리기 - 선택 상태 초기화',
          );

      dataSource?.notifyDataChanged();

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

  /// 보강 다시 실행 처리
  void _redoSupplementExchange(ExchangeHistoryItem item) {
    if (dataSource?.timeSlots == null) return;
    if (item.originalPath is! SupplementExchangePath) return;

    final supplementPath = item.originalPath as SupplementExchangePath;
    final sourceNode = supplementPath.sourceNode;
    final targetNode = supplementPath.targetNode;

    final exchangeService = ExchangeService();
    final success = exchangeService.performSupplementExchange(
      dataSource!.timeSlots,
      sourceNode.teacherName,
      sourceNode.day,
      sourceNode.period,
      targetNode.teacherName,
      targetNode.day,
      targetNode.period,
    );

    if (success) {
      AppLogger.exchangeDebug(
        '보강 다시 실행 성공: ${targetNode.teacherName} ${targetNode.day}${targetNode.period}교시',
      );
    }
  }

  /// 다시 실행 기능 (되돌리기 후 1단계 복구)
  void redoLastExchange(BuildContext context) {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final item = historyService.redoLastExchange();

    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('다시 실행할 교체가 없습니다'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _applyExchangeStateAfterHistoryChange(item, isRedo: true);

    historyService.printExchangeList();
    historyService.printUndoHistory();
    historyService.printRedoHistory();

    ref.read(stateResetProvider.notifier).resetExchangeStates(
          reason: '다시 실행 - 선택 상태 초기화',
        );

    dataSource?.notifyDataChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('교체 "${item.description}"가 다시 실행되었습니다'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 되돌리기/다시 실행 후 시간표·셀 스타일 동기화
  void _applyExchangeStateAfterHistoryChange(
    ExchangeHistoryItem item, {
    bool isRedo = false,
  }) {
    final isExchangeViewEnabled = ref.read(isExchangeViewEnabledProvider);

    if (isExchangeViewEnabled) {
      _syncExchangeViewIfEnabled();
    } else if (item.type == ExchangePathType.supplement) {
      if (isRedo) {
        _redoSupplementExchange(item);
      } else {
        _undoSupplementExchange(item);
      }
    }

    _updateExchangedCells();
    _checkExchangeViewStatus();
  }

  /// 교체 뷰 ON 상태에서 활성 교체만 시간표에 다시 반영
  void _syncExchangeViewIfEnabled() {
    final screenState = ref.read(exchangeScreenProvider);
    if (screenState.timetableData == null || dataSource == null) return;

    final timeSlots = dataSource!.timeSlots;
    final teachers = screenState.timetableData!.teachers;
    final notifier = ref.read(exchangeViewProvider.notifier);

    Future.microtask(() async {
      await notifier.disableExchangeView(
        timeSlots: timeSlots,
        teachers: teachers,
        dataSource: dataSource!,
      );
      await notifier.enableExchangeView(
        timeSlots: timeSlots,
        teachers: teachers,
        dataSource: dataSource!,
      );
      dataSource?.notifyDataChanged();
    });
  }

  /// 보강 되돌리기 처리
  void _undoSupplementExchange(ExchangeHistoryItem item) {
    if (dataSource?.timeSlots == null) return;

    if (item.originalPath is SupplementExchangePath) {
      final supplementPath = item.originalPath as SupplementExchangePath;
      final targetNode = supplementPath.targetNode;

      final exchangeService = ExchangeService();
      final success = exchangeService.undoSupplementExchange(
        dataSource!.timeSlots,
        targetNode.teacherName,
        targetNode.day,
        targetNode.period,
      );

      if (success) {
        AppLogger.exchangeDebug(
          '보강 되돌리기 성공: ${targetNode.teacherName} ${targetNode.day}${targetNode.period}교시',
        );
      } else {
        AppLogger.exchangeDebug(
          '보강 되돌리기 실패: ${targetNode.teacherName} ${targetNode.day}${targetNode.period}교시',
        );
      }
    }
  }

  /// 교체 뷰 활성화 여부 검사 및 처리 (공통 메서드)
  /// 각 교체 모드의 마지막 단계에서 호출되어 교체 뷰가 활성화되어 있으면 enableExchangeView 실행
  void _checkExchangeViewStatus() {
    // 교체 뷰가 활성화되어 있는지 검사
    final isExchangeViewEnabled = ref.read(isExchangeViewEnabledProvider);
    
    if (isExchangeViewEnabled) {
      AppLogger.exchangeDebug('[ExchangeExecutor] 교체 뷰가 활성화되어 있음 - _enableExchangeView() 실행');
      
      // 교체 뷰 활성화 콜백 호출
      if (onEnableExchangeView != null) {
        onEnableExchangeView!();
        AppLogger.exchangeDebug('[ExchangeExecutor] _enableExchangeView() 실행 완료');
      } else {
        AppLogger.exchangeDebug('[ExchangeExecutor] 교체 뷰 활성화 콜백이 설정되지 않음');
      }
    } else {
      AppLogger.exchangeDebug('[ExchangeExecutor] 교체 뷰가 비활성화되어 있음 - 교체는 리스트에만 저장됨');
    }
  }

  /// 교체된 셀 상태 업데이트 (공통 메서드)
  /// 
  /// 내부에서만 사용되는 private 메서드입니다.
  /// 외부에서 호출하려면 `updateExchangedCells()` public 메서드를 사용하세요.
  void _updateExchangedCells() {
    final cellNotifier = ref.read(cellSelectionProvider.notifier);
    
    // 교체된 셀 정보 추출
    final exchangedCells = _extractExchangedCells();
    final destinationCells = _extractDestinationCells();
    
    AppLogger.exchangeDebug('🔄 [ExchangeExecutor] 교체된 셀 정보 업데이트:');
    AppLogger.exchangeDebug('  - 소스 셀: ${exchangedCells.length}개 - $exchangedCells');
    AppLogger.exchangeDebug('  - 목적지 셀: ${destinationCells.length}개 - $destinationCells');
       
    // 교체된 소스 셀(교체 전 원본 수업이 있던 셀)의 테두리 스타일 업데이트
    cellNotifier.updateExchangedCells(exchangedCells);
    // 교체된 목적지 셀(교체 후 새 교사가 배정된 셀)의 배경색 업데이트
    cellNotifier.updateExchangedDestinationCells(destinationCells);
    
    AppLogger.exchangeDebug('✅ [ExchangeExecutor] 교체된 셀 상태 업데이트 완료');
  }

  /// 교체된 셀 상태 업데이트 (외부 호출용 public 메서드)
  /// 
  /// 현재 교체 리스트를 읽어서 교체된 셀의 시각적 스타일을 업데이트합니다.
  /// 교체 리스트 전체 삭제 등에서 사용할 수 있습니다.
  void updateExchangedCells() {
    _updateExchangedCells();
  }

  /// 교체된 셀 상태 복원 (프로그램 시작 시 호출)
  /// 
  /// 저장된 교체 리스트에서 교체된 셀 정보를 추출하여 CellSelectionProvider에 복원합니다.
  /// 교체 리스트가 비어있으면 모든 교체된 셀 스타일을 제거합니다.
  static void restoreExchangedCells(WidgetRef ref) {
    try {
      final historyService = ref.read(exchangeHistoryServiceProvider);
      final exchangeList = historyService.getExchangeList();
      
      // 교체된 셀 정보 추출 (빈 리스트도 처리)
      final exchangedCells = <String>[];
      final destinationCells = <String>[];
      
      if (exchangeList.isEmpty) {
        AppLogger.info('교체 리스트가 비어있어 모든 교체된 셀 스타일을 제거합니다.');
      } else {
        AppLogger.info('교체된 셀 테마 복원 시작: ${exchangeList.length}개 교체 항목');
        
        for (final item in exchangeList) {
          if (item.isReverted) continue;
          final path = item.originalPath;
          
          // 소스 셀 추출
          final sourceCells = _getCellKeysFromPathStatic(path);
          exchangedCells.addAll(sourceCells);
          
          // 목적지 셀 추출
          final destCells = _getDestinationCellsFromPathStatic(path);
          destinationCells.addAll(destCells);
        }
        
        AppLogger.info('교체된 셀 정보 추출 완료: 소스 ${exchangedCells.length}개, 목적지 ${destinationCells.length}개');
      }
      
      // CellSelectionProvider에 복원/업데이트 (빈 리스트도 업데이트하여 스타일 제거)
      final cellNotifier = ref.read(cellSelectionProvider.notifier);
      cellNotifier.updateExchangedCells(exchangedCells);
      cellNotifier.updateExchangedDestinationCells(destinationCells);
      
      AppLogger.info('✅ 교체된 셀 테마 복원 완료');
    } catch (e) {
      AppLogger.error('교체된 셀 테마 복원 중 오류: $e', e);
    }
  }

  /// 정적 메서드: 교체 경로에서 소스 셀 키 목록 추출 (복원용)
  static List<String> _getCellKeysFromPathStatic(ExchangePath path) {
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
    } else if (path is SupplementExchangePath) {
      // 보강: 소스 셀만 교체된 소스 셀로 표시
      return [
        '${path.sourceTeacher}_${path.sourceDay}_${path.sourcePeriod}',
      ];
    }
    return [];
  }

  /// 정적 메서드: 교체 경로에서 목적지 셀 키 목록 추출 (복원용)
  static List<String> _getDestinationCellsFromPathStatic(ExchangePath path) {
    final cellKeys = <String>[];
    
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

      // 보강 경로의 목적지 셀 추출
      // 타겟 교사의 위치가 목적지 셀
    } else if (path is SupplementExchangePath) {
      cellKeys.add('${path.targetTeacher}_${path.targetDay}_${path.targetPeriod}');
    }

    return cellKeys;
  }

  /// 교체된 소스 셀 목록 추출 (교체 전 원본 위치의 셀들)
  List<String> _extractExchangedCells() {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final cellKeys = <String>[];

    for (final item in historyService.getExchangeList()) {
      if (item.isReverted) continue;
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
    } else if (path is SupplementExchangePath) {
      // 보강: 소스 셀만 교체된 소스 셀로 표시
      return [
        '${path.sourceTeacher}_${path.sourceDay}_${path.sourcePeriod}',
      ];
    }
    return [];
  }

  /// [wg]교체된 목적지 셀 목록 추출 (교체 후 새 교사가 배정된 셀들)
  List<String> _extractDestinationCells() {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final cellKeys = <String>[];

    for (final item in historyService.getExchangeList()) {
      if (item.isReverted) continue;
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

        // 보강 경로의 목적지 셀 추출
        // 타겟 교사의 위치가 목적지 셀
      } else if (path is SupplementExchangePath) {
        cellKeys.add('${path.targetTeacher}_${path.targetDay}_${path.targetPeriod}');
      }
    }

    return cellKeys;
  }
}

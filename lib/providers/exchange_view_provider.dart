import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import '../models/exchange_history_item.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/exchange_node.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../services/exchange_service.dart';
import '../utils/timetable_data_source.dart';
import '../utils/day_utils.dart';
import '../ui/widgets/timetable_grid_section.dart';
import 'services_provider.dart';

/// 교체 뷰 상태 클래스
class ExchangeViewState {
  /// 교체 뷰 활성화 여부
  final bool isEnabled;
  
  /// 백업된 교체 데이터
  final List<ExchangeBackupInfo> backupData;
  
  /// 백업 완료된 교체 개수
  final int backedUpCount;
  
  /// 로딩 상태
  final bool isLoading;
  
  /// 마지막 업데이트 시간
  final DateTime lastUpdated;
  
  /// 현재 실행 중인 작업
  final String? currentOperation;
  
  /// 오류 메시지
  final String? errorMessage;

  const ExchangeViewState({
    this.isEnabled = false,
    this.backupData = const [],
    this.backedUpCount = 0,
    this.isLoading = false,
    required this.lastUpdated,
    this.currentOperation,
    this.errorMessage,
  });

  ExchangeViewState copyWith({
    bool? isEnabled,
    List<ExchangeBackupInfo>? backupData,
    int? backedUpCount,
    bool? isLoading,
    DateTime? lastUpdated,
    String? currentOperation,
    String? errorMessage,
  }) {
    return ExchangeViewState(
      isEnabled: isEnabled ?? this.isEnabled,
      backupData: backupData ?? this.backupData,
      backedUpCount: backedUpCount ?? this.backedUpCount,
      isLoading: isLoading ?? this.isLoading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentOperation: currentOperation ?? this.currentOperation,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'ExchangeViewState('
        'isEnabled: $isEnabled, '
        'backupData: ${backupData.length}, '
        'backedUpCount: $backedUpCount, '
        'isLoading: $isLoading, '
        'currentOperation: $currentOperation, '
        'errorMessage: $errorMessage'
        ')';
  }
}

/// 교체 뷰 상태를 관리하는 Notifier
class ExchangeViewNotifier extends StateNotifier<ExchangeViewState> {
  final Ref _ref;
  
  ExchangeViewNotifier(this._ref) : super(ExchangeViewState(lastUpdated: DateTime.now()));

  /// 교체 뷰 활성화
  Future<void> enableExchangeView({
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
    required TimetableDataSource dataSource,
  }) async {
    final historyService = _ref.read(exchangeHistoryServiceProvider);
    try {
      state = state.copyWith(
        isLoading: true,
        currentOperation: '교체 뷰 활성화 중...',
        errorMessage: null,
        lastUpdated: DateTime.now(),
      );

      AppLogger.exchangeInfo('[ExchangeViewProvider] 교체 뷰 활성화 시작');

      // 교체 리스트 조회
      final exchangeList = historyService.getExchangeList();
      
      AppLogger.exchangeDebug('[백업 추적] exchangeList: ${exchangeList.length}, backedUp: ${state.backedUpCount}, work: ${state.backupData.length}');

      if (exchangeList.isEmpty) {
        AppLogger.exchangeInfo('교체 리스트가 비어있습니다');
        state = state.copyWith(
          isLoading: false,
          currentOperation: null,
          lastUpdated: DateTime.now(),
        );
        return;
      }

      // 새로운 교체만 추출 (백업된 개수 이후부터)
      final newExchanges = exchangeList.skip(state.backedUpCount).toList();
      AppLogger.exchangeDebug('[새로운 교체] skip(${state.backedUpCount}): ${newExchanges.length}개');

      if (newExchanges.isEmpty) {
        AppLogger.exchangeInfo('새로운 교체가 없습니다 (이미 ${state.backedUpCount}개 백업됨)');
        state = state.copyWith(
          isLoading: false,
          currentOperation: null,
          lastUpdated: DateTime.now(),
        );
        return;
      }

      AppLogger.exchangeInfo('새로운 교체 ${newExchanges.length}개 발견 (전체 ${exchangeList.length}개, 기존 백업 ${state.backedUpCount}개)');

      // 1단계: 새로운 교체만 백업
      AppLogger.exchangeDebug('1단계: 신규 교체 ${newExchanges.length}개 백업 시작');
      final beforeBackupCount = state.backupData.length;
      final newBackupData = List<ExchangeBackupInfo>.from(state.backupData);
      
      for (var item in newExchanges) {
        _backupOriginalSlotInfo(item, timeSlots, newBackupData);
      }

      state = state.copyWith(
        backupData: newBackupData,
        backedUpCount: exchangeList.length,
        currentOperation: '교체 실행 중...',
        lastUpdated: DateTime.now(),
      );

      AppLogger.exchangeDebug('[백업 결과] $beforeBackupCount개 → ${newBackupData.length}개 (추가: ${newBackupData.length - beforeBackupCount})');

      // 2단계: 새로운 교체만 실행
      AppLogger.exchangeDebug('2단계: 신규 교체 ${newExchanges.length}개 실행 시작');
      int successCount = 0;
      
      for (var item in newExchanges) {
        if (_executeExchangeFromHistory(item, timeSlots, teachers)) {
          successCount++;
        }
      }

      // UI 업데이트 (교체 성공 시에만)
      if (successCount > 0) {
        dataSource.updateData(timeSlots, teachers);
        AppLogger.exchangeDebug('🔄 교체 뷰 활성화 완료 - UI 업데이트');
        AppLogger.exchangeInfo('교체 뷰 활성화 완료 - $successCount/${newExchanges.length}개 적용');
      }

      state = state.copyWith(
        isEnabled: true,
        isLoading: false,
        currentOperation: null,
        lastUpdated: DateTime.now(),
      );

    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 활성화 중 오류 발생: $e');
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        errorMessage: '교체 뷰 활성화 실패: $e',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 교체 뷰 비활성화
  Future<void> disableExchangeView({
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
    required TimetableDataSource dataSource,
  }) async {
    try {
      state = state.copyWith(
        isLoading: true,
        currentOperation: '교체 뷰 비활성화 중...',
        errorMessage: null,
        lastUpdated: DateTime.now(),
      );

      AppLogger.exchangeInfo('[ExchangeViewProvider] 교체 뷰 비활성화 시작');

      if (state.backupData.isEmpty) {
        AppLogger.exchangeDebug('복원할 교체 백업 데이터가 없습니다');
        state = state.copyWith(
          isEnabled: false,
          isLoading: false,
          currentOperation: null,
          lastUpdated: DateTime.now(),
        );
        return;
      }

      // 역순으로 복원 (마지막에 교체된 것부터 먼저 되돌리기)
      int restoredCount = 0;
      for (int i = state.backupData.length - 1; i >= 0; i--) {
        final backupInfo = state.backupData[i];
        final targetSlot = _findTimeSlotByBackupInfo(backupInfo, timeSlots);

        if (targetSlot != null) {
          targetSlot.subject = backupInfo.subject;
          targetSlot.className = backupInfo.className;
          restoredCount++;
        }
      }

      // UI 업데이트
      dataSource.updateData(timeSlots, teachers);
      AppLogger.exchangeDebug('🔄 교체 뷰 비활성화 완료 - UI 업데이트');

      state = state.copyWith(
        isEnabled: false,
        backupData: const [],
        backedUpCount: 0,
        isLoading: false,
        currentOperation: null,
        lastUpdated: DateTime.now(),
      );

      AppLogger.exchangeInfo('교체 뷰 비활성화 완료 - $restoredCount개 셀 복원됨');

    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 비활성화 중 오류 발생: $e');
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        errorMessage: '교체 뷰 비활성화 실패: $e',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 교체 뷰 상태 초기화
  void reset() {
    state = ExchangeViewState(lastUpdated: DateTime.now());
    AppLogger.exchangeDebug('[ExchangeViewProvider] 교체 뷰 상태 초기화 완료');
  }

  /// 교체 실행 전에 원본 정보를 백업하는 메서드
  void _backupOriginalSlotInfo(
    ExchangeHistoryItem exchangeItem,
    List<TimeSlot> timeSlots,
    List<ExchangeBackupInfo> backupData,
  ) {
    try {
      // originalPath는 required 필드이므로 null이 될 수 없음
      final exchangePath = exchangeItem.originalPath;
      
      AppLogger.exchangeDebug('교체 백업 시작: ${exchangePath.type}');
      
      // 교체 타입에 따라 다르게 처리
      if (exchangePath is OneToOneExchangePath) {
        _backupOneToOneExchange(exchangePath, timeSlots, backupData);
      } else if (exchangePath is CircularExchangePath) {
        _backupCircularExchange(exchangePath, timeSlots, backupData);
      } else if (exchangePath is ChainExchangePath) {
        _backupChainExchange(exchangePath, timeSlots, backupData);
      }
      
      AppLogger.exchangeDebug('교체 백업 완료: ${backupData.length}개 항목 저장됨');
    } catch (e) {
      AppLogger.exchangeDebug('교체 백업 중 오류 발생: $e');
    }
  }

  /// 1:1 교체의 원본 정보 백업
  /// 1:1 교체에서는 교체되는 두 교사의 원본 위치와 목적지 위치 모두 백업해야 함
  void _backupOneToOneExchange(
    OneToOneExchangePath exchangeItem,
    List<TimeSlot> timeSlots,
    List<ExchangeBackupInfo> backupData,
  ) {
    final sourceNode = exchangeItem.sourceNode;
    final targetNode = exchangeItem.targetNode;
    
    AppLogger.exchangeDebug('1:1 교체 백업: ${sourceNode.displayText} ↔ ${targetNode.displayText}');
    
    // 1. 교체되는 두 교사의 원본 위치 백업
    _backupNodeData(sourceNode, timeSlots, backupData);
    _backupNodeData(targetNode, timeSlots, backupData);
    
    // 2. 교체되는 두 교사의 목적지 위치 백업 (교체 후 변경될 셀들)
    // sourceNode의 교사가 targetNode 위치로 이동할 때의 셀
    _backupNodeDataByPosition(
      sourceNode.teacherName, 
      targetNode.day, 
      targetNode.period, 
      timeSlots, 
      backupData
    );
    
    // targetNode의 교사가 sourceNode 위치로 이동할 때의 셀
    _backupNodeDataByPosition(
      targetNode.teacherName, 
      sourceNode.day, 
      sourceNode.period, 
      timeSlots, 
      backupData
    );
  }

  /// 순환 교체의 원본 정보 백업
  /// 순환 교체에서는 각 노드가 다음 노드의 위치로 이동하므로 원본과 목적지 모두 백업해야 함
  void _backupCircularExchange(
    CircularExchangePath exchangeItem,
    List<TimeSlot> timeSlots,
    List<ExchangeBackupInfo> backupData,
  ) {
    final nodes = exchangeItem.nodes;
    AppLogger.exchangeDebug('순환 교체 백업: ${nodes.length}개 노드');
    
    // 순환 교체에서는 마지막 노드를 제외하고 처리 (마지막 노드는 첫 번째 노드로 돌아감)
    for (int i = 0; i < nodes.length - 1; i++) {
      final currentNode = nodes[i];
      final nextNode = nodes[i + 1];
      
      AppLogger.exchangeDebug('순환 백업 ${i + 1}: ${currentNode.displayText} → ${nextNode.displayText}');
      
      // 1. 현재 노드의 원본 위치 백업
      _backupNodeData(currentNode, timeSlots, backupData);
      
      // 2. 현재 노드가 이동할 목적지 위치 백업 (다음 노드의 위치에 있는 현재 교사의 셀)
      _backupNodeDataByPosition(
        currentNode.teacherName,
        nextNode.day,
        nextNode.period,
        timeSlots,
        backupData,
      );
    }
  }

  /// 연쇄 교체의 원본 정보 백업
  /// 연쇄 교체에서는 각 교사가 목적지 위치로 이동하므로 원본과 목적지 모두 백업해야 함
  void _backupChainExchange(
    ChainExchangePath exchangeItem,
    List<TimeSlot> timeSlots,
    List<ExchangeBackupInfo> backupData,
  ) {
    AppLogger.exchangeDebug('연쇄 교체 백업: A(${exchangeItem.nodeA.displayText}) ↔ B(${exchangeItem.nodeB.displayText})');
    
    // 연쇄 교체는 두 단계로 이루어짐:
    // 1단계: node1 ↔ node2 교체
    // 2단계: nodeA ↔ nodeB 교체
    
    // 1단계 백업: node1 ↔ node2 교체 관련 셀들
    AppLogger.exchangeDebug('연쇄 백업 1단계: ${exchangeItem.node1.displayText} ↔ ${exchangeItem.node2.displayText}');
    
    // node1의 원본 위치와 목적지 위치 백업
    _backupNodeData(exchangeItem.node1, timeSlots, backupData);
    _backupNodeDataByPosition(
      exchangeItem.node1.teacherName,
      exchangeItem.node2.day,
      exchangeItem.node2.period,
      timeSlots,
      backupData,
    );
    
    // node2의 원본 위치와 목적지 위치 백업
    _backupNodeData(exchangeItem.node2, timeSlots, backupData);
    _backupNodeDataByPosition(
      exchangeItem.node2.teacherName,
      exchangeItem.node1.day,
      exchangeItem.node1.period,
      timeSlots,
      backupData,
    );
    
    // 2단계 백업: nodeA ↔ nodeB 교체 관련 셀들
    AppLogger.exchangeDebug('연쇄 백업 2단계: ${exchangeItem.nodeA.displayText} ↔ ${exchangeItem.nodeB.displayText}');
    
    // nodeA의 원본 위치와 목적지 위치 백업
    _backupNodeData(exchangeItem.nodeA, timeSlots, backupData);
    _backupNodeDataByPosition(
      exchangeItem.nodeA.teacherName,
      exchangeItem.nodeB.day,
      exchangeItem.nodeB.period,
      timeSlots,
      backupData,
    );
    
    // nodeB의 원본 위치와 목적지 위치 백업
    _backupNodeData(exchangeItem.nodeB, timeSlots, backupData);
    _backupNodeDataByPosition(
      exchangeItem.nodeB.teacherName,
      exchangeItem.nodeA.day,
      exchangeItem.nodeA.period,
      timeSlots,
      backupData,
    );
  }

  /// ExchangeNode의 데이터를 백업
  void _backupNodeData(
    ExchangeNode node,
    List<TimeSlot> timeSlots,
    List<ExchangeBackupInfo> backupData,
  ) {
    try {
      final teacher = node.teacherName;
      final period = node.period;
      
      _backupNodeDataByPosition(teacher, node.day, period, timeSlots, backupData);
      
    } catch (e) {
      AppLogger.exchangeDebug('노드 데이터 백업 중 오류: $e');
    }
  }

  /// 교사명, 요일, 교시로 직접 백업하는 메서드
  void _backupNodeDataByPosition(
    String teacher,
    String day,
    int period,
    List<TimeSlot> timeSlots,
    List<ExchangeBackupInfo> backupData,
  ) {
    try {
      final dayOfWeek = DayUtils.getDayNumber(day);
      
      // TimeSlots에서 현재 subject와 className 조회
      String? currentSubject;
      String? currentClassName;
      
      for (TimeSlot slot in timeSlots) {
        if (slot.teacher == teacher && 
            slot.dayOfWeek == dayOfWeek && 
            slot.period == period) {
          currentSubject = slot.subject;
          currentClassName = slot.className;
          break;
        }
      }
      
      // ExchangeBackupInfo 생성하여 리스트에 추가
      final backupInfo = ExchangeBackupInfo(
        teacher: teacher,
        dayOfWeek: dayOfWeek,
        period: period,
        subject: currentSubject,
        className: currentClassName,
      );
      
      backupData.add(backupInfo);
      AppLogger.exchangeDebug('위치별 데이터 백업: ${backupInfo.debugInfo}');
      
    } catch (e) {
      AppLogger.exchangeDebug('위치별 데이터 백업 중 오류: $e');
    }
  }

  /// 백업 정보로 TimeSlot 찾기
  TimeSlot? _findTimeSlotByBackupInfo(ExchangeBackupInfo backupInfo, List<TimeSlot> timeSlots) {
    for (TimeSlot slot in timeSlots) {
      if (slot.teacher == backupInfo.teacher && 
          slot.dayOfWeek == backupInfo.dayOfWeek && 
          slot.period == backupInfo.period) {
        return slot;
      }
    }
    return null;
  }

  /// 교체 히스토리에서 교체 실행
  bool _executeExchangeFromHistory(
    ExchangeHistoryItem item,
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    try {
      final exchangePath = item.originalPath;
      AppLogger.exchangeDebug('교체 실행: ${exchangePath.type}');
      
      // ExchangeService 인스턴스 생성
      final exchangeService = _ref.read(exchangeServiceProvider);
      
      // 교체 타입에 따라 다르게 처리
      if (exchangePath is OneToOneExchangePath) {
        return _executeOneToOneExchange(exchangePath, timeSlots, exchangeService);
      } else if (exchangePath is CircularExchangePath) {
        return _executeCircularExchange(exchangePath, timeSlots, exchangeService);
      } else if (exchangePath is ChainExchangePath) {
        return _executeChainExchange(exchangePath, timeSlots, exchangeService);
      }
      
      AppLogger.exchangeDebug('지원하지 않는 교체 타입: ${exchangePath.type}');
      return false;
    } catch (e) {
      AppLogger.exchangeDebug('교체 실행 중 오류: $e');
      return false;
    }
  }

  /// 1:1 교체 실행
  bool _executeOneToOneExchange(
    OneToOneExchangePath exchangePath,
    List<TimeSlot> timeSlots,
    ExchangeService exchangeService,
  ) {
    try {
      final sourceNode = exchangePath.sourceNode;
      final targetNode = exchangePath.targetNode;
      
      AppLogger.exchangeDebug('1:1 교체 실행: ${sourceNode.displayText} ↔ ${targetNode.displayText}');
      
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
      AppLogger.exchangeDebug('1:1 교체 실행 중 오류: $e');
      return false;
    }
  }

  /// 순환 교체 실행
  bool _executeCircularExchange(
    CircularExchangePath exchangePath,
    List<TimeSlot> timeSlots,
    ExchangeService exchangeService,
  ) {
    try {
      AppLogger.exchangeDebug('순환 교체 실행: ${exchangePath.nodes.length}개 노드');
      
      return exchangeService.performCircularExchange(
        timeSlots,
        exchangePath.nodes,
      );
    } catch (e) {
      AppLogger.exchangeDebug('순환 교체 실행 중 오류: $e');
      return false;
    }
  }

  /// 연쇄 교체 실행
  bool _executeChainExchange(
    ChainExchangePath exchangePath,
    List<TimeSlot> timeSlots,
    ExchangeService exchangeService,
  ) {
    try {
      AppLogger.exchangeDebug('연쇄 교체 실행: A(${exchangePath.nodeA.displayText}) ↔ B(${exchangePath.nodeB.displayText})');
      
      // 연쇄 교체는 두 단계로 이루어짐:
      // 1단계: node1 ↔ node2 교체 (node2를 비우기 위해)
      // 2단계: nodeA ↔ nodeB 교체 (최종 교체)
      
      AppLogger.exchangeDebug('연쇄 교체 1단계: ${exchangePath.node1.displayText} ↔ ${exchangePath.node2.displayText}');
      
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
        AppLogger.exchangeDebug('연쇄 교체 1단계 실패');
        return false;
      }
      
      AppLogger.exchangeDebug('연쇄 교체 2단계: ${exchangePath.nodeA.displayText} ↔ ${exchangePath.nodeB.displayText}');
      
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
        AppLogger.exchangeDebug('연쇄 교체 2단계 실패');
        return false;
      }
      
      AppLogger.exchangeDebug('연쇄 교체 완료: 2단계 모두 성공');
      return true;
      
    } catch (e) {
      AppLogger.exchangeDebug('연쇄 교체 실행 중 오류: $e');
      return false;
    }
  }
}

/// 교체 뷰 상태 Provider
final exchangeViewProvider = StateNotifierProvider<ExchangeViewNotifier, ExchangeViewState>(
  (ref) => ExchangeViewNotifier(ref),
);

/// 교체 뷰 활성화 여부만 반환하는 간단한 Provider
final isExchangeViewEnabledProvider = Provider<bool>((ref) {
  final exchangeViewState = ref.watch(exchangeViewProvider);
  return exchangeViewState.isEnabled;
});

/// 교체 뷰 로딩 상태만 반환하는 Provider
final isExchangeViewLoadingProvider = Provider<bool>((ref) {
  final exchangeViewState = ref.watch(exchangeViewProvider);
  return exchangeViewState.isLoading;
});

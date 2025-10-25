import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../models/exchange_mode.dart';
import '../utils/logger.dart';

/// 통합된 셀 선택 상태 클래스
/// 모든 셀 선택 관련 상태를 하나의 클래스에서 관리
class CellSelectionState {
  // ==================== 기본 셀 선택 상태 ====================
  /// 현재 선택된 셀
  final String? selectedTeacher;
  final String? selectedDay;
  final int? selectedPeriod;
  
  /// 타겟 셀 (교체 대상)
  final String? targetTeacher;
  final String? targetDay;
  final int? targetPeriod;
  
  /// 교사 이름 선택 상태
  final String? selectedTeacherName;
  
  // ==================== 교체 경로 관리 ====================
  /// 현재 교체 모드
  final ExchangeMode currentMode;
  
  /// 선택된 교체 경로들 (타입별)
  final OneToOneExchangePath? selectedOneToOnePath;
  final CircularExchangePath? selectedCircularPath;
  final ChainExchangePath? selectedChainPath;
  final SupplementExchangePath? selectedSupplementPath;
  
  /// 교체 가능한 교사 정보
  final List<Map<String, dynamic>> exchangeableTeachers;
  
  // ==================== 교체된 셀 관리 ====================
  /// 교체된 소스 셀들
  final Set<String> exchangedCells;
  
  /// 교체된 목적지 셀들
  final Set<String> exchangedDestinationCells;
  
  // ==================== 화살표 표시 관리 ====================
  /// 화살표 표시 여부
  final bool isArrowVisible;
  
  /// 화살표 표시 이유
  final ArrowDisplayReason arrowReason;
  
  /// 교체된 셀에서 선택된 경로인지 여부
  final bool isFromExchangedCell;
  
  // ==================== UI 상태 ====================
  /// 캐시 무효화 플래그
  final bool cacheInvalidated;
  
  /// 마지막 업데이트 시간
  final DateTime lastUpdated;

  const CellSelectionState({
    this.selectedTeacher,
    this.selectedDay,
    this.selectedPeriod,
    this.targetTeacher,
    this.targetDay,
    this.targetPeriod,
    this.selectedTeacherName,
    this.currentMode = ExchangeMode.view,
    this.selectedOneToOnePath,
    this.selectedCircularPath,
    this.selectedChainPath,
    this.selectedSupplementPath,
    this.exchangeableTeachers = const [],
    this.exchangedCells = const {},
    this.exchangedDestinationCells = const {},
    this.isArrowVisible = false,
    this.arrowReason = ArrowDisplayReason.manualHide,
    this.isFromExchangedCell = false,
    this.cacheInvalidated = false,
    required this.lastUpdated,
  });

  CellSelectionState copyWith({
    String? selectedTeacher,
    String? selectedDay,
    int? selectedPeriod,
    String? targetTeacher,
    String? targetDay,
    int? targetPeriod,
    String? selectedTeacherName,
    ExchangeMode? currentMode,
    OneToOneExchangePath? selectedOneToOnePath,
    CircularExchangePath? selectedCircularPath,
    ChainExchangePath? selectedChainPath,
    SupplementExchangePath? selectedSupplementPath,
    List<Map<String, dynamic>>? exchangeableTeachers,
    Set<String>? exchangedCells,
    Set<String>? exchangedDestinationCells,
    bool? isArrowVisible,
    ArrowDisplayReason? arrowReason,
    bool? isFromExchangedCell,
    bool? cacheInvalidated,
    DateTime? lastUpdated,
  }) {
    return CellSelectionState(
      selectedTeacher: selectedTeacher ?? this.selectedTeacher,
      selectedDay: selectedDay ?? this.selectedDay,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      targetTeacher: targetTeacher ?? this.targetTeacher,
      targetDay: targetDay ?? this.targetDay,
      targetPeriod: targetPeriod ?? this.targetPeriod,
      selectedTeacherName: selectedTeacherName ?? this.selectedTeacherName,
      currentMode: currentMode ?? this.currentMode,
      selectedOneToOnePath: selectedOneToOnePath ?? this.selectedOneToOnePath,
      selectedCircularPath: selectedCircularPath ?? this.selectedCircularPath,
      selectedChainPath: selectedChainPath ?? this.selectedChainPath,
      selectedSupplementPath: selectedSupplementPath ?? this.selectedSupplementPath,
      exchangeableTeachers: exchangeableTeachers ?? this.exchangeableTeachers,
      exchangedCells: exchangedCells ?? this.exchangedCells,
      exchangedDestinationCells: exchangedDestinationCells ?? this.exchangedDestinationCells,
      isArrowVisible: isArrowVisible ?? this.isArrowVisible,
      arrowReason: arrowReason ?? this.arrowReason,
      isFromExchangedCell: isFromExchangedCell ?? this.isFromExchangedCell,
      cacheInvalidated: cacheInvalidated ?? this.cacheInvalidated,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'CellSelectionState('
        'selected: $selectedTeacher $selectedDay $selectedPeriod, '
        'target: $targetTeacher $targetDay $targetPeriod, '
        'mode: $currentMode, '
        'arrowVisible: $isArrowVisible, '
        'exchangedCells: ${exchangedCells.length}'
        ')';
  }
}

/// 화살표 표시 이유 열거형
enum ArrowDisplayReason {
  pathSelected,
  exchangedCellClicked,
  manualHide,
}

/// 통합된 셀 선택 상태를 관리하는 Notifier
class CellSelectionNotifier extends StateNotifier<CellSelectionState> {
  CellSelectionNotifier() : super(CellSelectionState(lastUpdated: DateTime.now()));

  // ==================== 기본 셀 선택 관리 ====================
  
  /// 셀 선택 상태 업데이트
  void selectCell(String teacher, String day, int period) {
    state = state.copyWith(
      selectedTeacher: teacher,
      selectedDay: day,
      selectedPeriod: period,
      lastUpdated: DateTime.now(),
    );
  }

  /// 타겟 셀 상태 업데이트
  void selectTargetCell(String teacher, String day, int period) {
    state = state.copyWith(
      targetTeacher: teacher,
      targetDay: day,
      targetPeriod: period,
      lastUpdated: DateTime.now(),
    );
  }

  /// 교사 이름 선택 상태 업데이트
  void selectTeacherName(String? teacherName) {
    state = state.copyWith(
      selectedTeacherName: teacherName,
      lastUpdated: DateTime.now(),
    );
  }

  // ==================== 교체 모드 관리 ====================
  
  /// 교체 모드 설정
  void setExchangeMode(ExchangeMode mode) {
    state = state.copyWith(
      currentMode: mode,
      lastUpdated: DateTime.now(),
    );
  }

  /// 교체 모드 토글
  void toggleExchangeMode(ExchangeMode mode) {
    if (state.currentMode == mode) {
      setExchangeMode(ExchangeMode.view);
    } else {
      setExchangeMode(mode);
    }
  }

  // ==================== 교체 경로 관리 ====================
  
  /// 1:1 교체 경로 설정
  void setOneToOnePath(OneToOneExchangePath? path) {
    state = state.copyWith(
      selectedOneToOnePath: path,
      lastUpdated: DateTime.now(),
    );
  }

  /// 순환 교체 경로 설정
  void setCircularPath(CircularExchangePath? path) {
    state = state.copyWith(
      selectedCircularPath: path,
      lastUpdated: DateTime.now(),
    );
  }

  /// 연쇄 교체 경로 설정
  void setChainPath(ChainExchangePath? path) {
    state = state.copyWith(
      selectedChainPath: path,
      lastUpdated: DateTime.now(),
    );
  }

  /// 보강 교체 경로 설정
  void setSupplementPath(SupplementExchangePath? path) {
    state = state.copyWith(
      selectedSupplementPath: path,
      lastUpdated: DateTime.now(),
    );
  }

  /// 교체 가능한 교사 정보 업데이트
  void updateExchangeableTeachers(List<Map<String, dynamic>> teachers) {
    state = state.copyWith(
      exchangeableTeachers: teachers,
      lastUpdated: DateTime.now(),
    );
  }

  // ==================== 교체된 셀 관리 ====================
  
  /// 교체된 셀 상태 업데이트
  void updateExchangedCells(List<String> cellKeys) {
    state = state.copyWith(
      exchangedCells: cellKeys.toSet(),
      lastUpdated: DateTime.now(),
    );
  }

  /// 교체된 목적지 셀 상태 업데이트
  void updateExchangedDestinationCells(List<String> cellKeys) {
    state = state.copyWith(
      exchangedDestinationCells: cellKeys.toSet(),
      lastUpdated: DateTime.now(),
    );
  }

  // ==================== 화살표 표시 관리 ====================
  
  /// 경로 선택 시 화살표 표시
  void showArrowForPath(ExchangePath path, {bool isFromExchangedCell = false}) {
    state = state.copyWith(
      isArrowVisible: true,
      arrowReason: isFromExchangedCell 
          ? ArrowDisplayReason.exchangedCellClicked 
          : ArrowDisplayReason.pathSelected,
      isFromExchangedCell: isFromExchangedCell,
      lastUpdated: DateTime.now(),
    );
  }

  /// 교체된 셀 클릭 시 화살표 표시
  void showArrowForExchangedCell(ExchangePath path) {
    AppLogger.debug('🔍 [CellSelectionProvider] 교체된 셀 화살표 표시 요청: ${path.type}');
    
    // 경로 타입에 따라 적절한 경로 설정
    if (path is OneToOneExchangePath) {
      AppLogger.debug('🔍 [CellSelectionProvider] 1:1 교체 경로 설정');
      state = state.copyWith(
        selectedOneToOnePath: path,
        isArrowVisible: true,
        arrowReason: ArrowDisplayReason.exchangedCellClicked,
        isFromExchangedCell: true,
        lastUpdated: DateTime.now(),
      );
    } else if (path is CircularExchangePath) {
      AppLogger.debug('🔍 [CellSelectionProvider] 순환 교체 경로 설정');
      state = state.copyWith(
        selectedCircularPath: path,
        isArrowVisible: true,
        arrowReason: ArrowDisplayReason.exchangedCellClicked,
        isFromExchangedCell: true,
        lastUpdated: DateTime.now(),
      );
    } else if (path is ChainExchangePath) {
      AppLogger.debug('🔍 [CellSelectionProvider] 연쇄 교체 경로 설정');
      state = state.copyWith(
        selectedChainPath: path,
        isArrowVisible: true,
        arrowReason: ArrowDisplayReason.exchangedCellClicked,
        isFromExchangedCell: true,
        lastUpdated: DateTime.now(),
      );
    } else if (path is SupplementExchangePath) {
      AppLogger.debug('🔍 [CellSelectionProvider] 보강 교체 경로 설정');
      state = state.copyWith(
        selectedSupplementPath: path,
        isArrowVisible: true,
        arrowReason: ArrowDisplayReason.exchangedCellClicked,
        isFromExchangedCell: true,
        lastUpdated: DateTime.now(),
      );
    }
    
    AppLogger.debug('🔍 [CellSelectionProvider] 화살표 상태 업데이트 완료: isVisible=${state.isArrowVisible}');
  }

  /// 화살표 숨기기
  void hideArrow({ArrowDisplayReason reason = ArrowDisplayReason.manualHide}) {
    state = state.copyWith(
      isArrowVisible: false,
      arrowReason: reason,
      isFromExchangedCell: false,
      lastUpdated: DateTime.now(),
    );
  }

  // ==================== 캐시 관리 ====================
  
  /// 캐시 무효화
  void invalidateCache() {
    state = state.copyWith(
      cacheInvalidated: true,
      lastUpdated: DateTime.now(),
    );
  }

  // ==================== 상태 초기화 ====================

  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    state = CellSelectionState(
      currentMode: state.currentMode,
      exchangeableTeachers: const [],
      exchangedCells: state.exchangedCells,              // ✅ 보존: 교체된 셀 정보 유지
      exchangedDestinationCells: state.exchangedDestinationCells,   // ✅ 보존: 교체된 목적지 셀 정보 유지
      isArrowVisible: false,                // ✅ 초기화: 화살표 숨김
      arrowReason: ArrowDisplayReason.manualHide, // ✅ 초기화: 화살표 이유 초기화
      isFromExchangedCell: false,           // ✅ 초기화: 교체된 셀에서 온 화살표 아님
      cacheInvalidated: false,              // ✅ 초기화: 캐시 무효화 상태 초기화
      lastUpdated: DateTime.now(),
    );
  }

  /// 경로만 초기화 (셀 선택 상태는 유지)
  void clearPathsOnly() {
    state = state.copyWith(
      selectedOneToOnePath: null,
      selectedCircularPath: null,
      selectedChainPath: null,
      selectedSupplementPath: null,
      lastUpdated: DateTime.now(),
    );
  }

  /// 모든 캐시 초기화
  void clearAllCaches() {
    state = state.copyWith(
      cacheInvalidated: false,
      lastUpdated: DateTime.now(),
    );
  }

  /// 교체된 셀 상태 초기화
  void clearExchangedCells() {
    state = state.copyWith(
      exchangedCells: const {},
      exchangedDestinationCells: const {},
      lastUpdated: DateTime.now(),
    );
  }

  /// 모든 선택 상태 초기화 (교체된 셀 정보 포함)
  void clearAllSelectionsIncludingExchanged() {
    state = CellSelectionState(
      currentMode: state.currentMode,
      exchangeableTeachers: const [],
      exchangedCells: const {},              // ✅ 초기화: 교체된 셀 정보 제거
      exchangedDestinationCells: const {},   // ✅ 초기화: 교체된 목적지 셀 정보 제거
      isArrowVisible: false,                // ✅ 초기화: 화살표 숨김
      arrowReason: ArrowDisplayReason.manualHide, // ✅ 초기화: 화살표 이유 초기화
      isFromExchangedCell: false,           // ✅ 초기화: 교체된 셀에서 온 화살표 아님
      cacheInvalidated: false,              // ✅ 초기화: 캐시 무효화 상태 초기화
      lastUpdated: DateTime.now(),
    );
  }

  /// 모든 상태 초기화
  void reset() {
    state = CellSelectionState(lastUpdated: DateTime.now());
  }

  // ==================== 상태 확인 메서드 ====================
  
  /// 특정 셀이 선택된 상태인지 확인
  bool isCellSelected(String teacherName, String day, int period) {
    return state.selectedTeacher == teacherName && 
           state.selectedDay == day && 
           state.selectedPeriod == period;
  }

  /// 특정 셀이 타겟 셀인지 확인
  bool isCellTarget(String teacherName, String day, int period) {
    return state.targetTeacher == teacherName && 
           state.targetDay == day && 
           state.targetPeriod == period;
  }

  /// 특정 셀이 교체된 소스 셀인지 확인
  bool isCellExchangedSource(String teacherName, String day, int period) {
    final cellKey = '${teacherName}_${day}_$period';
    return state.exchangedCells.contains(cellKey);
  }

  /// 특정 셀이 교체된 목적지 셀인지 확인
  bool isCellExchangedDestination(String teacherName, String day, int period) {
    final cellKey = '${teacherName}_${day}_$period';
    return state.exchangedDestinationCells.contains(cellKey);
  }

  /// 교체 가능한 교사인지 확인
  bool isExchangeableTeacher(String teacherName, String day, int period) {
    return state.exchangeableTeachers.any((teacher) => 
        teacher['name'] == teacherName && 
        teacher['day'] == day && 
        teacher['period'] == period);
  }

  /// 현재 선택된 경로가 있는지 확인
  bool get hasSelectedPath {
    return state.selectedOneToOnePath != null ||
           state.selectedCircularPath != null ||
           state.selectedChainPath != null ||
           state.selectedSupplementPath != null;
  }

  /// 화살표가 표시 중인지 확인
  bool get isArrowVisible => state.isArrowVisible;

  /// 현재 교체 모드가 활성화되어 있는지 확인
  bool get isExchangeModeActive => state.currentMode != ExchangeMode.view;

  // ==================== 경로 확인 메서드들 ====================
  
  /// 특정 셀이 순환 교체 경로에 포함되어 있는지 확인
  bool isInCircularPath(String teacherName, String day, int period) {
    if (state.selectedCircularPath == null) return false;
    
    final path = state.selectedCircularPath!;
    for (final node in path.nodes) {
      if (node.teacherName == teacherName && 
          node.day == day && 
          node.period == period) {
        return true;
      }
    }
    return false;
  }

  /// 특정 셀이 연쇄 교체 경로에 포함되어 있는지 확인
  bool isInChainPath(String teacherName, String day, int period) {
    if (state.selectedChainPath == null) return false;
    
    final path = state.selectedChainPath!;
    // node1, node2, nodeA, nodeB 모두 확인
    final nodes = [path.node1, path.node2, path.nodeA, path.nodeB];
    
    for (final node in nodes) {
      if (node.teacherName == teacherName && 
          node.day == day && 
          node.period == period) {
        return true;
      }
    }
    return false;
  }

  /// 특정 셀이 선택된 1:1 교체 경로에 포함되어 있는지 확인
  bool isInSelectedOneToOnePath(String teacherName, String day, int period) {
    if (state.selectedOneToOnePath == null) return false;
    
    final path = state.selectedOneToOnePath!;
    return (path.sourceNode.teacherName == teacherName && 
            path.sourceNode.day == day && 
            path.sourceNode.period == period) ||
           (path.targetNode.teacherName == teacherName && 
            path.targetNode.day == day && 
            path.targetNode.period == period);
  }

  /// 특정 셀이 선택된 보강 교체 경로에 포함되어 있는지 확인
  bool isInSelectedSupplementPath(String teacherName, String day, int period) {
    if (state.selectedSupplementPath == null) return false;
    
    final path = state.selectedSupplementPath!;
    return (path.sourceNode.teacherName == teacherName && 
            path.sourceNode.day == day && 
            path.sourceNode.period == period) ||
           (path.targetNode.teacherName == teacherName && 
            path.targetNode.day == day && 
            path.targetNode.period == period);
  }
}

// ==================== Provider 정의 ====================

/// 통합된 셀 선택 상태 Provider
///
/// **사용 예시** (select 패턴 권장):
/// ```dart
/// // ❌ 비효율적 - 전체 상태 구독
/// final state = ref.watch(cellSelectionProvider);
///
/// // ✅ 효율적 - 필요한 필드만 구독
/// final selectedTeacher = ref.watch(cellSelectionProvider.select((s) => s.selectedTeacher));
/// final isArrowVisible = ref.watch(cellSelectionProvider.select((s) => s.isArrowVisible));
/// final currentMode = ref.watch(cellSelectionProvider.select((s) => s.currentMode));
/// ```
final cellSelectionProvider = StateNotifierProvider<CellSelectionNotifier, CellSelectionState>(
  (ref) => CellSelectionNotifier(),
);

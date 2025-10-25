import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import 'exchange_screen_provider.dart';
import 'cell_selection_provider.dart';
import 'services_provider.dart';
import 'zoom_provider.dart';
import 'exchange_view_provider.dart';
import '../ui/widgets/timetable_grid/arrow_state_manager.dart';
import '../utils/fixed_header_style_manager.dart';
import '../utils/syncfusion_timetable_helper.dart';
import '../services/exchange_history_service.dart';

/// 초기화 레벨 정의
///
/// 3단계 레벨로 구분하여 필요한 만큼만 초기화합니다.
/// 상세 설명: docs/ui_reset_levels.md 참조
enum ResetLevel {
  /// Level 1: 경로 선택만 초기화
  ///
  /// **초기화 대상**:
  /// - 선택된 교체 경로 (OneToOne/Circular/Chain)
  ///
  /// **사용 시점**:
  /// - 새로운 경로 선택 직전
  pathOnly,

  /// Level 2: 이전 교체 상태 초기화
  ///
  /// **초기화 대상**:
  /// - 선택된 교체 경로
  /// - 경로 리스트
  /// - 사이드바 상태
  /// - 캐시
  ///
  /// **사용 시점**:
  /// - 동일 모드 내에서 다른 셀 선택 시
  /// - 교체 후 다음 작업 준비 시
  exchangeStates,

  /// Level 3: 전체 상태 초기화
  ///
  /// **초기화 대상**:
  /// - 모든 교체 서비스 상태
  /// - 전역 Provider 캐시
  /// - 선택된 셀
  /// - UI 상태
  ///
  /// **사용 시점**:
  /// - 교체 모드 전환 시
  /// - 파일 선택/해제 시
  allStates,
}

/// 초기화 상태 모델
///
/// 마지막 초기화 정보를 추적하여 디버깅을 돕습니다.
class ResetState {
  final DateTime? lastResetTime;
  final ResetLevel? lastResetLevel;
  final String? resetReason;

  const ResetState({
    this.lastResetTime,
    this.lastResetLevel,
    this.resetReason,
  });

  ResetState copyWith({
    DateTime? lastResetTime,
    ResetLevel? lastResetLevel,
    String? resetReason,
  }) {
    return ResetState(
      lastResetTime: lastResetTime ?? this.lastResetTime,
      lastResetLevel: lastResetLevel ?? this.lastResetLevel,
      resetReason: resetReason ?? this.resetReason,
    );
  }

  /// 디버깅용 문자열 표현
  @override
  String toString() {
    if (lastResetTime == null) return 'ResetState(초기화 기록 없음)';

    final timeStr = '${lastResetTime!.hour}:${lastResetTime!.minute}:${lastResetTime!.second}';
    return 'ResetState(Level: ${lastResetLevel?.name}, Time: $timeStr, Reason: $resetReason)';
  }
}

/// 초기화 매니저 Notifier
///
/// 3단계 레벨의 초기화 메서드를 제공하며,
/// 모든 초기화 로직을 중앙에서 관리합니다.
///
/// **사용 예시**:
/// ```dart
/// ref.read(stateResetProvider.notifier).resetExchangeStates(
///   reason: '빈 셀 선택',
/// );
/// ```
class StateResetNotifier extends StateNotifier<ResetState> {
  StateResetNotifier(this._ref) : super(const ResetState());

  final Ref _ref;

  // ========================================
  // 공통 유틸리티 메서드
  // ========================================

  /// ExchangeScreenProvider 참조 가져오기
  ExchangeScreenNotifier get _exchangeNotifier => _ref.read(exchangeScreenProvider.notifier);

  /// CellSelectionNotifier 참조 가져오기
  CellSelectionNotifier get _cellNotifier => _ref.read(cellSelectionProvider.notifier);

  /// 공통 초기화 작업 수행 (DataSource 및 화살표 제거)
  ///
  /// **전제 조건**: 호출 전에 Provider와 DataSource 배치 업데이트가 먼저 완료되어야 함
  /// - Level 1: `resetPathSelectionBatch()` 호출 후
  /// - Level 2: `resetExchangeStatesBatch()` 호출 후
  ///
  /// **실행 순서**:
  /// 1. 화살표 메모리 제거
  /// 2. DataSource 경로 초기화 (UI 렌더링에 필수)
  /// 3. UI 업데이트
  ///
  /// **주의**:
  /// - Provider 경로는 배치 업데이트에서 이미 초기화됨
  /// - CellSelectionProvider 경로도 DataSource 배치 업데이트에서 이미 초기화됨
  /// - 헤더 테마 업데이트는 포함하지 않음 (호출자가 결정)
  void _performCommonResetTasks() {
    // 1. 화살표 메모리 제거
    ArrowStateManager().clearAllArrows();
    _ref.read(cellSelectionProvider.notifier).hideArrow();

    // 2. DataSource 경로 초기화 (UI 렌더링에 필수)
    // ⚠️ Provider와 CellSelectionProvider는 배치 업데이트에서 이미 초기화됨
    final dataSource = _exchangeNotifier.state.dataSource;
    if (dataSource != null) {
      dataSource.updateSelectedCircularPath(null);
      dataSource.updateSelectedOneToOnePath(null);
      dataSource.updateSelectedChainPath(null);
      dataSource.updateSelectedSupplementPath(null);
    }

    // 3. UI 업데이트 (경로 초기화 완료 후!)
    dataSource?.notifyDataChanged();
  }

  /// 헤더 테마 업데이트 (Level 3 전용 - 모든 값 null)
  void _updateHeaderTheme() {
    final screenState = _exchangeNotifier.state;
    if (screenState.timetableData == null) return;
    
    // FixedHeaderStyleManager의 셀 선택 전용 업데이트 사용 (성능 최적화)
    FixedHeaderStyleManager.updateHeaderForCellSelection(
      selectedDay: null, // Level 3 초기화 시에는 선택된 셀이 없음
      selectedPeriod: null,
    );
    
    // ExchangeService를 사용하여 교체 가능한 교사 정보 수집
    List<Map<String, dynamic>> exchangeableTeachers = _ref.read(exchangeServiceProvider).getCurrentExchangeableTeachers(
      screenState.timetableData!.timeSlots,
      screenState.timetableData!.teachers,
    );
    
    // 교시 헤더 색상 변경을 위한 캐시 강제 초기화
    FixedHeaderStyleManager.clearCacheForPeriodHeaderColorChange();
    
    // 선택된 교시 정보를 전달하여 헤더만 업데이트 (초기화된 상태)
    final result = SyncfusionTimetableHelper.convertToSyncfusionData(
      screenState.timetableData!.timeSlots,
      screenState.timetableData!.teachers,
      selectedDay: null,      // 초기화된 상태
      selectedPeriod: null,   // 초기화된 상태
      targetDay: null,        // 초기화된 상태
      targetPeriod: null,     // 초기화된 상태
      exchangeableTeachers: exchangeableTeachers,
      // 모든 경로 정보도 초기화된 상태로 전달
      selectedCircularPath: null,
      selectedOneToOnePath: null,
      selectedChainPath: null,
    );
    
    // Provider를 통해 헤더 강제 재생성을 위한 완전한 새로고침
    _exchangeNotifier.setColumns(result.columns);
    _exchangeNotifier.setStackedHeaders(result.stackedHeaders);

    // TimetableDataSource의 notifyListeners를 통한 직접 UI 업데이트
    screenState.dataSource?.notifyListeners();
  }

  /// 교체 히스토리 초기화 (Level 3 전용)
  void _clearExchangeHistory() {
    try {
      final historyService = ExchangeHistoryService();
      historyService.clearExchangeList();
      historyService.clearUndoStack();
      if (kDebugMode) {
        AppLogger.exchangeDebug('[Level 3] 교체 히스토리 초기화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.exchangeDebug('[Level 3] 교체 히스토리 초기화 중 오류: $e');
      }
    }
  }

  /// 줌 상태 초기화 (Level 3 전용)
  void _resetZoomState() {
    try {
      _ref.read(zoomProvider.notifier).reset();
      if (kDebugMode) {
        AppLogger.exchangeDebug('[Level 3] 줌 상태 초기화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.exchangeDebug('[Level 3] 줌 상태 초기화 중 오류: $e');
      }
    }
  }

  /// 교체뷰 상태 초기화 (Level 3 전용)
  void _resetExchangeViewState() {
    try {
      _ref.read(exchangeViewProvider.notifier).reset();
      if (kDebugMode) {
        AppLogger.exchangeDebug('[Level 3] 교체뷰 상태 초기화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.exchangeDebug('[Level 3] 교체뷰 상태 초기화 중 오류: $e');
      }
    }
  }

  // ========================================
  // Level 1: 경로 선택만 초기화
  // ========================================

  /// Level 1: 경로 선택만 초기화
  ///
  /// **초기화 대상**:
  /// - 선택된 교체 경로 (OneToOne/Circular/Chain)
  /// - 화살표 상태
  ///
  /// **유지 대상**:
  /// - 선택된 셀 (source/target)
  /// - 경로 리스트
  /// - UI 상태
  /// - 스크롤 위치
  ///
  /// **사용 시점**:
  /// - 새로운 경로 선택 직전
  /// - 교체 실행 후 경로만 해제할 때
  ///
  /// **주의**: 헤더 테마 업데이트는 호출자(ExchangeScreen)에서 수동으로 호출해야 함
  void resetPathOnly({String? reason}) {
    AppLogger.exchangeDebug('[Level 1] 경로 선택만 초기화: ${reason ?? "이유 없음"}');

    // ExchangeScreenProvider 배치 업데이트
    _exchangeNotifier.resetPathSelectionBatch();

    // TimetableDataSource 배치 업데이트 (Syncfusion DataGrid 전용)
    final dataSource = _exchangeNotifier.state.dataSource;
    dataSource?.resetPathSelectionBatch();

    // 공통 초기화 작업 수행 (경로 초기화 및 화살표 제거)
    _performCommonResetTasks();

    // ⚠️ 헤더 테마는 업데이트하지 않음
    // → ExchangeScreen에서 _updateHeaderTheme() 수동 호출 필요
    // → 이유: Level 1은 선택된 셀을 유지하므로 셀 기반 헤더 업데이트 필요

    // 상태 업데이트 및 로깅
    _updateStateAndLog(ResetLevel.pathOnly, reason ?? 'Level 1 초기화');
  }


  // ========================================
  // Level 2: 이전 교체 상태 초기화
  // ========================================

  /// Level 2: 이전 교체 상태 초기화
  ///
  /// **초기화 대상**:
  /// - 선택된 교체 경로
  /// - 경로 리스트 (circular/oneToOne/chain)
  /// - 사이드바 표시 상태
  /// - 로딩 상태
  /// - 필터 상태
  /// - 캐시
  /// - 선택된 셀 (source/target)
  /// - 교체 서비스의 셀 설정 상태 (_selectedTeacher, _selectedDay, _selectedPeriod)
  /// - 화살표 상태
  ///
  /// **유지 대상**:
  /// - 전역 Provider 상태
  /// - 스크롤 위치
  ///
  /// **사용 시점**:
  /// - 동일 모드 내에서 다른 셀 선택 시
  /// - 교체 후 다음 작업 준비 시
  /// - 모든 모드 전환 시 (보기 ↔ 1:1 ↔ 순환 ↔ 연쇄)
  ///
  /// **주의**: 헤더 테마 업데이트는 호출자(ExchangeScreen)에서 수동으로 호출해야 함
  void resetExchangeStates({String? reason}) {
    AppLogger.exchangeDebug('[Level 2] 이전 교체 상태 초기화: ${reason ?? "이유 없음"}');

    // 1. 먼저 서비스 상태 초기화 (UI 업데이트 전에)
    _ref.read(cellSelectionProvider.notifier).clearAllSelections();
    _ref.read(exchangeServiceProvider).clearAllSelections();
    _ref.read(circularExchangeServiceProvider).clearAllSelections();
    _ref.read(chainExchangeServiceProvider).clearAllSelections();

    // 2. ExchangeScreenProvider 배치 업데이트
    _exchangeNotifier.resetExchangeStatesBatch();

    // 3. TimetableDataSource 배치 업데이트 (Syncfusion DataGrid 전용)
    final dataSource = _exchangeNotifier.state.dataSource;
    dataSource?.resetExchangeStatesBatch();

    // 4. 공통 초기화 작업 수행 (화살표 제거 및 DataSource 경로 초기화, 마지막에 UI 업데이트)
    _performCommonResetTasks();

    // ⚠️ 헤더 테마는 업데이트하지 않음
    // → ExchangeScreen에서 _updateHeaderTheme() 수동 호출 필요 (필요시)
    // → Level 2는 셀 선택을 초기화하므로 빈 상태 헤더가 적절할 수 있음

    // 상태 업데이트 및 로깅
    _updateStateAndLog(ResetLevel.exchangeStates, reason ?? 'Level 2 초기화');
  }

  // ========================================
  // Level 3: 전체 상태 초기화
  // ========================================

  /// Level 3: 전체 상태 초기화
  ///
  /// **초기화 대상**:
  /// - 모든 교체 서비스 상태 (Level 2에서 처리)
  /// - 선택된 교체 경로 (Level 2에서 처리)
  /// - 경로 리스트 (Level 2에서 처리)
  /// - 선택된 셀 (Level 2에서 처리)
  /// - 전역 Provider (CellSelectionProvider 완전 리셋)
  /// - UI 상태 (Level 2에서 처리)
  /// - 헤더 테마 (기본값으로 복원)
  /// - 교체 히스토리 (_undoStack, _exchangeList)
  /// - 줌 상태
  /// - 교체뷰 상태
  ///
  /// **사용 시점**:
  /// - 파일 선택/해제 시
  /// - 교체불가 편집 모드 진입 시
  /// - 앱 시작/종료 시
  void resetAllStates({String? reason}) {
    AppLogger.exchangeDebug('[Level 3] 전체 상태 초기화: ${reason ?? "이유 없음"}');

    // Level 2 먼저 호출 (교체 상태, 서비스, 셀 선택 모두 초기화됨)
    resetExchangeStates(reason: reason);

    // Level 3 추가 작업: 전역 Provider 완전 리셋 (교체된 셀 정보 포함)
    _cellNotifier.clearAllSelectionsIncludingExchanged();

    // 헤더 테마를 기본값으로 복원 (빈 상태로 설정)
    _exchangeNotifier.setColumns([]);
    _exchangeNotifier.setStackedHeaders([]);

    // 모든 교체 모드 상태 초기화
    _exchangeNotifier.setSelectedDay(null);

    // 헤더 테마 업데이트 (모든 값 null로 재생성)
    _updateHeaderTheme();

    // Level 3 전용 초기화
    _clearExchangeHistory();
    _resetZoomState();
    _resetExchangeViewState();

    // 상태 업데이트 및 로깅
    _updateStateAndLog(ResetLevel.allStates, reason ?? 'Level 3 초기화');
  }

  // ========================================
  // 유틸리티 메서드
  // ========================================

  /// 상태 업데이트 및 로깅
  void _updateStateAndLog(ResetLevel level, String reason) {
    state = ResetState(
      lastResetTime: DateTime.now(),
      lastResetLevel: level,
      resetReason: reason,
    );
    AppLogger.exchangeDebug('[$level] 초기화 완료 - $state');
  }
}

/// StateResetProvider
///
/// 전역에서 초기화 상태를 관리하는 Provider입니다.
///
/// **사용 예시**:
/// ```dart
/// // Level 2 초기화
/// ref.read(stateResetProvider.notifier).resetExchangeStates(
///   reason: '빈 셀 선택',
/// );
///
/// // Level 3 초기화
/// ref.read(stateResetProvider.notifier).resetAllStates(
///   reason: '모드 전환',
/// );
///
/// // 마지막 초기화 정보 조회
/// final info = ref.read(stateResetProvider.notifier).getLastResetInfo();
/// ```
final stateResetProvider =
    StateNotifierProvider<StateResetNotifier, ResetState>((ref) {
  return StateResetNotifier(ref);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import 'exchange_screen_provider.dart';
import 'timetable_theme_provider.dart';
import 'services_provider.dart';
import '../ui/widgets/timetable_grid/widget_arrows_manager.dart';
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

  /// TimetableThemeNotifier 참조 가져오기
  TimetableThemeNotifier get _themeNotifier => _ref.read(timetableThemeProvider.notifier);

  /// 공통 초기화 작업 수행
  void _performCommonResetTasks() {
    WidgetArrowsManager().clearAllArrows();
  }

  /// 모든 셀 선택 상태 강제 해제
  void _clearAllCellSelections() {
    // 모든 교체 서비스 초기화
    _ref.read(exchangeServiceProvider).clearAllSelections();
    _ref.read(circularExchangeServiceProvider).clearAllSelections();
    _ref.read(chainExchangeServiceProvider).clearAllSelections();

    // DataSource 및 테마 초기화
    _exchangeNotifier.state.dataSource?.clearAllSelections();
    _themeNotifier.clearAllSelections();

    // Provider 경로 상태 초기화
    _exchangeNotifier
      ..setSelectedCircularPath(null)
      ..setSelectedOneToOnePath(null)
      ..setSelectedChainPath(null);
  }

  /// 헤더 테마 업데이트 (ExchangeScreen의 _updateHeaderTheme와 동일한 로직)
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
      AppLogger.exchangeDebug('[Level 3] 교체 히스토리 초기화 완료');
    } catch (e) {
      AppLogger.exchangeDebug('[Level 3] 교체 히스토리 초기화 중 오류: $e');
    }
  }

  // ========================================
  // Level 1: 경로 선택만 초기화
  // ========================================

  /// Level 1: 경로 선택만 초기화
  ///
  /// **초기화 대상**:
  /// - 선택된 교체 경로 (OneToOne/Circular/Chain)
  ///
  /// **유지 대상**:
  /// - 선택된 셀 (source/target)
  /// - 경로 리스트
  /// - UI 상태
  ///
  /// **사용 시점**:
  /// - 새로운 경로 선택 직전
  /// - 교체 실행 후 경로만 해제할 때
  void resetPathOnly({String? reason}) {
    AppLogger.exchangeDebug('[Level 1] 경로 선택만 초기화: ${reason ?? "이유 없음"}');

    // ExchangeScreenProvider 배치 업데이트
    _exchangeNotifier.resetPathSelectionBatch();

    // TimetableDataSource 배치 업데이트 (Syncfusion DataGrid 전용)
    final dataSource = _exchangeNotifier.state.dataSource;
    dataSource?.resetPathSelectionBatch();

    // 공통 초기화 작업 수행
    _performCommonResetTasks();

    // 화살표 초기화를 위한 추가 처리
    // Level 1에서도 _internalSelectedPath를 초기화해야 화살표가 사라짐
    _clearInternalSelectedPath();

    // 상태 업데이트 및 로깅
    _updateStateAndLog(ResetLevel.pathOnly, reason ?? 'Level 1 초기화');
  }

  /// 내부 선택된 경로 초기화 (화살표 제거용)
  /// TimetableGridSection.clearPathSelectionOnly()에서 처리됨
  void _clearInternalSelectedPath() {
    AppLogger.exchangeDebug('[Level 1] 내부 선택된 경로 초기화');
  }

  // ========================================
  // Level 2: 이전 교체 상태 초기화
  // ========================================

  /// Level 2: 이전 교체 상태 초기화
  ///
  /// **초기화 대상**:
  /// - 선택된 교체 경로 (Level 1 호출)
  /// - 경로 리스트 (circular/oneToOne/chain)
  /// - 사이드바 표시 상태
  /// - 로딩 상태
  /// - 필터 상태
  /// - 캐시
  /// - 선택된 셀 (source/target) - 모드 전환 시 초기화
  ///
  /// **유지 대상**:
  /// - 전역 Provider 상태
  ///
  /// **사용 시점**:
  /// - 동일 모드 내에서 다른 셀 선택 시
  /// - 교체 후 다음 작업 준비 시
  /// - 모든 모드 전환 시 (보기 ↔ 1:1 ↔ 순환 ↔ 연쇄)
  void resetExchangeStates({String? reason}) {
    AppLogger.exchangeDebug('[Level 2] 이전 교체 상태 초기화: ${reason ?? "이유 없음"}');

    // ExchangeScreenProvider 배치 업데이트
    _exchangeNotifier.resetExchangeStatesBatch();

    // TimetableDataSource 배치 업데이트 (Syncfusion DataGrid 전용)
    final dataSource = _exchangeNotifier.state.dataSource;
    dataSource?.resetExchangeStatesBatch();

    // 캐시 초기화
    _themeNotifier.clearAllCaches();

    // 선택된 셀 초기화 (모드 전환 시)
    _themeNotifier.clearAllSelections();

    // 공통 초기화 작업 수행
    _performCommonResetTasks();

    // 상태 업데이트 및 로깅
    _updateStateAndLog(ResetLevel.exchangeStates, reason ?? 'Level 2 초기화');
  }

  // ========================================
  // Level 3: 전체 상태 초기화
  // ========================================

  /// Level 3: 전체 상태 초기화
  ///
  /// **초기화 대상**:
  /// - 모든 교체 서비스 상태
  /// - 선택된 교체 경로 (Level 2 호출)
  /// - 경로 리스트
  /// - 선택된 셀 (source/target)
  /// - 전역 Provider (선택, 캐시, 교체된 셀)
  /// - UI 상태
  /// - 헤더 테마 (기본값으로 복원)
  /// - 교체 히스토리 (_undoStack, _exchangeList)
  ///
  /// **사용 시점**:
  /// - 파일 선택/해제 시
  /// - 교체불가 편집 모드 진입 시
  /// - 앱 시작/종료 시
  void resetAllStates({String? reason}) {
    AppLogger.exchangeDebug('[Level 3] 전체 상태 초기화: ${reason ?? "이유 없음"}');

    // Level 2 먼저 호출 (교체 상태 초기화)
    resetExchangeStates(reason: reason);

    // Level 3 추가 작업: 전역 Provider 상태 초기화
    _themeNotifier.resetAllStatesBatch();

    // 헤더 테마를 기본값으로 복원 (빈 상태로 설정)
    _exchangeNotifier.setColumns([]);
    _exchangeNotifier.setStackedHeaders([]);

    // 모든 교체 모드 상태 초기화 (Level 3 전용 추가 초기화)
    // Level 2에서 대부분 초기화되지만, 일부 누락된 상태들을 추가로 초기화
    _exchangeNotifier.setSelectedDay(null);

    // 🔥 추가: 모든 셀 선택 상태 강제 해제 (ExchangeScreen의 _clearAllCellSelections와 동일한 동작)
    // 이 코드가 없으면 모드 전환 시 선택된 셀이 유지되어 문제가 발생함
    //   -> 헤더 테마 유지됨.
    _clearAllCellSelections();

    // 🔥 추가: 헤더 테마 업데이트 (모든 모드 변경 시 필수)
    // 이 코드가 없으면 모드 전환 시 헤더 테마가 업데이트되지 않아 문제가 발생함
    //   -> 헤더 테마 유지됨.
    _updateHeaderTheme();

    // 🔥 추가: 교체 히스토리 초기화 (Level 3 전용)
    // 파일 선택/해제 시 모든 교체 히스토리를 초기화
    _clearExchangeHistory();

    // 교체 서비스 초기화
    // 주의: 서비스는 exchange_screen.dart에서 별도로 초기화됨
    // Provider 순환 참조를 피하기 위해 여기서는 생략

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

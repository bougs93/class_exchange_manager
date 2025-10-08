import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/exchange_path.dart';
import '../../../services/exchange_service.dart';
import '../../../services/circular_exchange_service.dart';
import '../../../services/chain_exchange_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/timetable_data_source.dart';
import '../../../providers/timetable_theme_provider.dart';

/// 상태 초기화 관련 핸들러
///
/// exchange_screen.dart에서 사용되는 Mixin으로,
/// 3단계 레벨의 초기화 메서드를 제공합니다.
///
/// **초기화 레벨**:
/// - Level 2: resetExchangeStates() - 이전 교체 상태만
/// - Level 3: resetAllStates() - 전체 상태
///
/// 상세 설명: docs/ui_reset_levels.md 참조
mixin StateResetHandler<T extends StatefulWidget> on State<T> {
  // ========================================
  // 인터페이스 - 구현 클래스에서 제공해야 함
  // ========================================

  ExchangeService get exchangeService;
  CircularExchangeService get circularExchangeService;
  ChainExchangeService get chainExchangeService;
  TimetableDataSource? get dataSource;
  WidgetRef get ref;

  void clearTargetCell();
  void updateHeaderTheme();
  void updateExchangeableTimes();

  // 상태 변수 setter
  void Function(CircularExchangePath?) get setSelectedCircularPath;
  void Function(OneToOneExchangePath?) get setSelectedOneToOnePath;
  void Function(ChainExchangePath?) get setSelectedChainPath;
  void Function(List<CircularExchangePath>) get setCircularPaths;
  void Function(List<OneToOneExchangePath>) get setOneToOnePaths;
  void Function(List<ChainExchangePath>) get setChainPaths;
  void Function(bool) get setSidebarVisible;
  void Function(bool) get setCircularPathsLoading;
  void Function(bool) get setChainPathsLoading;
  void Function(double) get setLoadingProgress;
  void Function(List<ExchangePath>) get setFilteredPaths;
  void Function(List<int>) get setAvailableSteps;
  void Function(int?) get setSelectedStep;

  // ========================================
  // Level 2: 이전 교체 상태 초기화 (중간)
  // ========================================

  /// Level 2: 이전 교체 상태 초기화
  ///
  /// **초기화 대상**:
  /// - 타겟 셀
  /// - 선택된 교체 경로 (모든 타입)
  /// - 경로 리스트 (circular/oneToOne/chain)
  /// - 사이드바 표시 상태
  /// - 로딩 상태
  /// - 필터 상태
  ///
  /// **유지 대상**:
  /// - 소스 셀 (현재 선택된 셀)
  /// - 전역 Provider 캐시
  /// - DataSource 캐시
  ///
  /// **사용 시점**:
  /// - 동일 모드 내에서 다른 셀 선택 시
  /// - 교체 후 다음 작업 준비 시
  /// - 교체 모드 전환 시 (1:1 ↔ 순환 ↔ 연쇄)
  void resetExchangeStates() {
    // 1. 타겟 셀 초기화
    clearTargetCell();

    // 2. DataSource의 경로 선택 해제
    dataSource?.updateSelectedCircularPath(null);
    dataSource?.updateSelectedOneToOnePath(null);
    dataSource?.updateSelectedChainPath(null);

    // 3. 선택된 경로 초기화
    setSelectedCircularPath(null);
    setSelectedOneToOnePath(null);
    setSelectedChainPath(null);

    // 4. 경로 리스트 초기화
    setCircularPaths([]);
    setOneToOnePaths([]);
    setChainPaths([]);

    // 5. UI 상태 초기화
    setSidebarVisible(false);
    setCircularPathsLoading(false);
    setChainPathsLoading(false);
    setLoadingProgress(0.0);

    // 6. 필터 상태 초기화
    setFilteredPaths([]);
    setAvailableSteps([]);
    setSelectedStep(null);

    AppLogger.exchangeDebug('[Level 2] 이전 교체 상태 초기화 완료');
  }

  // ========================================
  // Level 3: 전체 상태 초기화 (가장 강함)
  // ========================================

  /// Level 3: 전체 상태 초기화
  ///
  /// **초기화 대상**:
  /// - 모든 교체 서비스 상태
  /// - 타겟 셀
  /// - 전역 Provider (선택, 캐시, 교체된 셀)
  /// - DataSource (선택, 경로, 옵션)
  /// - 선택된 교체 경로
  /// - 경로 리스트
  /// - UI 상태 (사이드바, 로딩 등)
  /// - 필터 상태
  ///
  /// **사용 시점**:
  /// - 파일 선택/해제 시
  /// - 교체불가 편집 모드 진입 시
  /// - 앱 시작/종료 시
  void resetAllStates() {
    // 1. 모든 교체 서비스의 선택 상태 초기화
    exchangeService.clearAllSelections();
    circularExchangeService.clearAllSelections();
    chainExchangeService.clearAllSelections();

    // 2. 타겟 셀 초기화
    clearTargetCell();

    // 3. 전역 Provider를 통한 상태 초기화
    ref.read(timetableThemeProvider.notifier).clearAllSelections();
    ref.read(timetableThemeProvider.notifier).clearAllCaches();
    ref.read(timetableThemeProvider.notifier).clearExchangedCells();

    // 4. DataSource에 모든 선택 상태 해제
    dataSource?.updateSelection(null, null, null);
    dataSource?.updateExchangeOptions([]);
    dataSource?.updateExchangeableTeachers([]);
    dataSource?.updateSelectedCircularPath(null);
    dataSource?.updateSelectedOneToOnePath(null);
    dataSource?.updateSelectedChainPath(null);

    // 5. 모든 선택된 경로 초기화
    setSelectedCircularPath(null);
    setSelectedOneToOnePath(null);
    setSelectedChainPath(null);

    // 6. 모든 경로 리스트 초기화
    setCircularPaths([]);
    setOneToOnePaths([]);
    setChainPaths([]);

    // 7. UI 상태 초기화
    setSidebarVisible(false);
    setCircularPathsLoading(false);
    setChainPathsLoading(false);
    setLoadingProgress(0.0);

    // 8. 필터 상태 초기화
    setFilteredPaths([]);
    setAvailableSteps([]);
    setSelectedStep(null);

    // 9. 헤더 테마를 기본값으로 복원
    updateHeaderTheme();

    // 10. 교체 가능한 시간 업데이트 (빈 목록으로)
    updateExchangeableTimes();

    AppLogger.exchangeDebug('[Level 3] 전체 상태 초기화 완료');
  }
}

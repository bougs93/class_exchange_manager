import 'package:flutter/material.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/exchange_path.dart';
import '../../../services/exchange_service.dart';
import '../../../services/circular_exchange_service.dart';
import '../../../services/chain_exchange_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/timetable_data_source.dart';

/// 상태 초기화 관련 핸들러
mixin StateResetHandler<T extends StatefulWidget> on State<T> {
  // 인터페이스 - 구현 클래스에서 제공해야 함
  ExchangeService get exchangeService;
  CircularExchangeService get circularExchangeService;
  ChainExchangeService get chainExchangeService;
  TimetableDataSource? get dataSource;

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

  /// 이전 교체 관련 상태만 초기화 (현재 선택된 셀은 유지)
  void clearPreviousExchangeStates() {
    // 타겟 셀 초기화
    clearTargetCell();

    // 데이터 소스에 이전 경로 정보만 해제 (현재 선택된 셀은 유지)
    dataSource?.updateSelectedCircularPath(null);
    dataSource?.updateSelectedOneToOnePath(null);
    dataSource?.updateSelectedChainPath(null);

    // 이전 선택된 경로 초기화
    setSelectedCircularPath(null);
    setSelectedOneToOnePath(null);
    setSelectedChainPath(null);

    // 이전 경로 리스트 초기화
    setCircularPaths([]);
    setOneToOnePaths([]);
    setChainPaths([]);

    // UI 상태 초기화
    setSidebarVisible(false);
    setCircularPathsLoading(false);
    setChainPathsLoading(false);
    setLoadingProgress(0.0);

    // 필터 상태 초기화
    setFilteredPaths([]);
    setAvailableSteps([]);
    setSelectedStep(null);

    AppLogger.exchangeDebug('이전 교체 관련 상태 초기화 완료');
  }

  /// 모든 교체 모드 공통 초기화
  void clearAllExchangeStates() {
    // 모든 교체 서비스의 선택 상태 초기화
    exchangeService.clearAllSelections();
    circularExchangeService.clearAllSelections();
    chainExchangeService.clearAllSelections();

    // 타겟 셀 초기화
    clearTargetCell();

    // 데이터 소스에 모든 선택 상태 해제
    dataSource?.updateSelection(null, null, null);
    dataSource?.updateExchangeOptions([]);
    dataSource?.updateExchangeableTeachers([]);
    dataSource?.updateSelectedCircularPath(null);
    dataSource?.updateSelectedOneToOnePath(null);
    dataSource?.updateSelectedChainPath(null);

    // 모든 선택된 경로 초기화
    setSelectedCircularPath(null);
    setSelectedOneToOnePath(null);
    setSelectedChainPath(null);

    // 모든 경로 리스트 초기화
    setCircularPaths([]);
    setOneToOnePaths([]);
    setChainPaths([]);

    // UI 상태 초기화
    setSidebarVisible(false);
    setCircularPathsLoading(false);
    setChainPathsLoading(false);
    setLoadingProgress(0.0);

    // 필터 상태 초기화
    setFilteredPaths([]);
    setAvailableSteps([]);
    setSelectedStep(null);

    AppLogger.exchangeDebug('모든 교체 모드 상태 초기화 완료');
  }

  /// UI를 기본값으로 복원
  void restoreUIToDefault() {
    // 헤더 테마를 기본값으로 복원
    updateHeaderTheme();
    // 모든 교체 모드 상태 초기화
    clearAllExchangeStates();

    // 교체 가능한 시간 업데이트 (빈 목록으로)
    updateExchangeableTimes();
  }
}

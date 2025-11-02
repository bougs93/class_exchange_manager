import 'package:flutter/material.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../utils/logger.dart';
import '../../state_managers/filter_state_manager.dart';

/// 필터 및 검색 처리 관련 핸들러
mixin FilterSearchHandler<T extends StatefulWidget> on State<T> {
  // 인터페이스 - 구현 클래스에서 제공해야 함
  FilterStateManager get filterStateManager;
  TextEditingController get searchController;

  // 모드 상태
  bool get isExchangeModeEnabled;
  bool get isCircularExchangeModeEnabled;
  bool get isChainExchangeModeEnabled;

  // 상태 변수 getter/setter
  String get searchQuery;
  void Function(String) get setSearchQuery;
  int? get selectedStep;
  void Function(int?) get setSelectedStep;
  String? get selectedDay;
  void Function(String?) get setSelectedDay;
  List<int> get availableSteps;
  void Function(List<int>) get setAvailableSteps;

  /// 단계 필터 변경 처리 (순환교체, 1:1 교체 모드만)
  void onStepChanged(int? step) {
    // 연쇄교체에서는 단계 필터 동작 불필요
    if (isChainExchangeModeEnabled) {
      AppLogger.exchangeDebug('연쇄교체: 단계 필터 변경 무시 (필터 동작 불필요)');
      return;
    }

    setSelectedStep(step);
    filterStateManager.setStepFilter(step);

    String mode = isExchangeModeEnabled ? '1:1교체' : '순환교체';
    AppLogger.exchangeDebug('$mode 단계 필터 변경: ${step ?? "전체"}');
  }

  /// 요일 필터 변경 처리 (순환교체, 1:1 교체, 연쇄교체 모드)
  void onDayChanged(String? day) {
    setSelectedDay(day);
    filterStateManager.setDayFilter(day);

    String mode = isExchangeModeEnabled ? '1:1교체' :
                  isCircularExchangeModeEnabled ? '순환교체' : '연쇄교체';
    AppLogger.exchangeDebug('$mode 요일 필터 변경: ${day ?? "전체"}');
  }

  /// 필터 초기화 (셀 선택 시 호출)
  void resetFilters() {
    // 검색 텍스트 초기화
    setSearchQuery('');
    searchController.clear();
    filterStateManager.setSearchKeyword('');

    // 단계 필터 초기화
    if (isExchangeModeEnabled) {
      setSelectedStep(null); // 1:1 교체는 모든 경로 표시
      filterStateManager.setStepFilter(null);
    } else if (isCircularExchangeModeEnabled) {
      // 순환교체: 가장 높은 단계를 기본 선택으로 설정
      setSelectedStep(availableSteps.isNotEmpty ? availableSteps.last : null);
      filterStateManager.setStepFilter(selectedStep);
    } else if (isChainExchangeModeEnabled) {
      // 연쇄교체: 단계 필터 항상 null (필터 동작 불필요)
      setSelectedStep(null);
      filterStateManager.setStepFilter(null);
    }

    // 요일 필터 초기화
    setSelectedDay(null);
    filterStateManager.setDayFilter(null);

    AppLogger.exchangeDebug('필터 초기화 완료');
  }

  /// 사용 가능한 단계들 업데이트
  void updateAvailableSteps(List<CircularExchangePath> paths) {
    Set<int> steps = {};
    for (var path in paths) {
      steps.add(path.nodes.length);
    }
    final newAvailableSteps = steps.toList()..sort();
    setAvailableSteps(newAvailableSteps);

    // 순환교체: 가장 높은 단계를 기본 선택으로 설정
    setSelectedStep(newAvailableSteps.isNotEmpty ? newAvailableSteps.last : null);

    AppLogger.exchangeDebug('사용 가능한 단계들: $newAvailableSteps, 선택된 단계: $selectedStep');
  }

  /// 검색 쿼리 업데이트 및 필터링
  void updateSearchQuery(String query) {
    setSearchQuery(query);
    filterStateManager.setSearchKeyword(query);
  }

  /// 검색 입력 필드 초기화
  void clearSearch() {
    searchController.clear();
    setSearchQuery('');
    filterStateManager.setSearchKeyword('');
  }
}

import 'package:flutter/material.dart';
import '../../../models/exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/dual_exchange_path.dart';
import '../../../models/supplement_exchange_path.dart';
import '../../../models/exchange_node.dart';
import '../../widgets/unified_exchange_sidebar.dart';

/// 사이드바 빌더 헬퍼
mixin SidebarBuilder<T extends StatefulWidget> on State<T> {
  // 인터페이스 - 구현 클래스에서 제공해야 함
  bool get isExchangeModeEnabled;
  bool get isCircularExchangeModeEnabled;
  bool get isDualExchangeModeEnabled;
  bool get isSupplementExchangeModeEnabled;

  OneToOneExchangePath? get selectedOneToOnePath;
  CircularExchangePath? get selectedCircularPath;
  DualExchangePath? get selectedDualPath;
  SupplementExchangePath? get selectedSupplementPath;

  List<OneToOneExchangePath> get oneToOnePaths;
  List<CircularExchangePath> get circularPaths;
  List<DualExchangePath> get dualPaths;

  bool get isCircularPathsLoading;
  bool get isDualPathsLoading;
  double get loadingProgress;

  List<ExchangePath> get filteredPaths;
  String get searchQuery;
  TextEditingController get searchController;
  double get sidebarWidth;

  List<int> get availableSteps;
  int? get selectedStep;
  String? get selectedDay;

  // 콜백 메서드들
  void Function() get toggleSidebar;
  void onUnifiedPathSelected(ExchangePath path);
  void updateSearchQuery(String query);
  void clearSearch();
  String Function(ExchangeNode) get getSubjectName;
  void onStepChanged(int? step);
  void onDayChanged(String? day);
  void Function(String, String, int)? onSupplementTeacherTap; // 보강 교사 버튼 클릭 콜백

  /// 통합 교체 사이드바 빌드
  Widget buildUnifiedExchangeSidebar() {
    // 현재 모드 결정
    ExchangePathType currentMode;
    if (isExchangeModeEnabled) {
      currentMode = ExchangePathType.oneToOne;
    } else if (isCircularExchangeModeEnabled) {
      currentMode = ExchangePathType.circular;
    } else if (isDualExchangeModeEnabled) {
      currentMode = ExchangePathType.dual;
    } else if (isSupplementExchangeModeEnabled) {
      currentMode = ExchangePathType.supplement;
    } else {
      currentMode = ExchangePathType.dual; // 기본값
    }

    // 선택된 경로 결정
    ExchangePath? selectedPath;
    if (isExchangeModeEnabled) {
      selectedPath = selectedOneToOnePath;
    } else if (isCircularExchangeModeEnabled) {
      selectedPath = selectedCircularPath;
    } else if (isDualExchangeModeEnabled) {
      selectedPath = selectedDualPath;
    } else if (isSupplementExchangeModeEnabled) {
      selectedPath = selectedSupplementPath;
    }

    // 경로 리스트 결정
    List<ExchangePath> paths;
    if (isExchangeModeEnabled) {
      paths = oneToOnePaths;
    } else if (isCircularExchangeModeEnabled) {
      paths = circularPaths;
    } else if (isDualExchangeModeEnabled) {
      paths = dualPaths;
    } else {
      paths = []; // 보강 모드에서는 빈 리스트
    }

    // 로딩 상태 결정 (모든 모드 통합 처리)
    bool isLoading = false;
    if (isExchangeModeEnabled) {
      isLoading = isCircularPathsLoading; // 1:1 교체도 동일한 로딩 상태 사용
    } else if (isCircularExchangeModeEnabled) {
      isLoading = isCircularPathsLoading;
    } else if (isDualExchangeModeEnabled) {
      isLoading = isDualPathsLoading;
    } else if (isSupplementExchangeModeEnabled) {
      // 보강는 실제 로딩이 없지만 일관성을 위해 동일한 로딩 상태 사용
      isLoading = isCircularPathsLoading;
    }

    return UnifiedExchangeSidebar(
      width: sidebarWidth,
      paths: paths,
      filteredPaths: filteredPaths,
      selectedPath: selectedPath,
      mode: currentMode,
      isLoading: isLoading,
      loadingProgress: loadingProgress,
      searchQuery: searchQuery,
      searchController: searchController,
      onToggleSidebar: toggleSidebar,
      onSelectPath: onUnifiedPathSelected,
      onUpdateSearchQuery: updateSearchQuery,
      onClearSearch: clearSearch,
      getSubjectName: getSubjectName,
      // 순환교체, 1:1 교체, 2중교체 모드에서 사용되는 단계 필터 매개변수들
      availableSteps:
          (isCircularExchangeModeEnabled ||
                  isExchangeModeEnabled ||
                  isDualExchangeModeEnabled)
              ? availableSteps
              : null,
      selectedStep:
          (isCircularExchangeModeEnabled ||
                  isExchangeModeEnabled ||
                  isDualExchangeModeEnabled)
              ? selectedStep
              : null,
      onStepChanged:
          (isCircularExchangeModeEnabled ||
                  isExchangeModeEnabled ||
                  isDualExchangeModeEnabled)
              ? onStepChanged
              : null,
      selectedDay:
          (isCircularExchangeModeEnabled ||
                  isExchangeModeEnabled ||
                  isDualExchangeModeEnabled)
              ? selectedDay
              : null,
      onDayChanged:
          (isCircularExchangeModeEnabled ||
                  isExchangeModeEnabled ||
                  isDualExchangeModeEnabled)
              ? onDayChanged
              : null,
      // 보강 모드에서 사용되는 교사 버튼 클릭 콜백
      onSupplementTeacherTap:
          isSupplementExchangeModeEnabled ? onSupplementTeacherTap : null,
    );
  }

  /// 현재 선택된 교체 경로 반환 (모든 타입 지원)
  ExchangePath? getCurrentSelectedPath() {
    // 우선순위: 순환교체 > 2중교체 > 1:1교체
    if (selectedCircularPath != null) {
      return selectedCircularPath;
    } else if (selectedDualPath != null) {
      return selectedDualPath;
    } else if (selectedOneToOnePath != null) {
      return selectedOneToOnePath;
    } else if (selectedSupplementPath != null) {
      return selectedSupplementPath;
    }
    return null;
  }
}

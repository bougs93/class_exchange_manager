import 'package:flutter/material.dart';
import '../../../models/exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/exchange_node.dart';
import '../../widgets/unified_exchange_sidebar.dart';

/// 사이드바 빌더 헬퍼
mixin SidebarBuilder<T extends StatefulWidget> on State<T> {
  // 인터페이스 - 구현 클래스에서 제공해야 함
  bool get isExchangeModeEnabled;
  bool get isCircularExchangeModeEnabled;
  bool get isChainExchangeModeEnabled;
  bool get isSupplementExchangeModeEnabled;

  OneToOneExchangePath? get selectedOneToOnePath;
  CircularExchangePath? get selectedCircularPath;
  ChainExchangePath? get selectedChainPath;

  List<OneToOneExchangePath> get oneToOnePaths;
  List<CircularExchangePath> get circularPaths;
  List<ChainExchangePath> get chainPaths;

  bool get isCircularPathsLoading;
  bool get isChainPathsLoading;
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
  void Function(String, String, int)? onSupplementTeacherTap; // 보강교체 교사 버튼 클릭 콜백

  /// 통합 교체 사이드바 빌드
  Widget buildUnifiedExchangeSidebar() {
    // 현재 모드 결정
    ExchangePathType currentMode;
    if (isExchangeModeEnabled) {
      currentMode = ExchangePathType.oneToOne;
    } else if (isCircularExchangeModeEnabled) {
      currentMode = ExchangePathType.circular;
    } else if (isChainExchangeModeEnabled) {
      currentMode = ExchangePathType.chain;
    } else if (isSupplementExchangeModeEnabled) {
      currentMode = ExchangePathType.supplement;
    } else {
      currentMode = ExchangePathType.chain; // 기본값
    }

    // 선택된 경로 결정
    ExchangePath? selectedPath;
    if (isExchangeModeEnabled) {
      selectedPath = selectedOneToOnePath;
    } else if (isCircularExchangeModeEnabled) {
      selectedPath = selectedCircularPath;
    } else if (isChainExchangeModeEnabled) {
      selectedPath = selectedChainPath;
    }
    // 보강교체 모드에서는 선택된 경로가 없음 (메시지만 표시)

    // 경로 리스트 결정
    List<ExchangePath> paths;
    if (isExchangeModeEnabled) {
      paths = oneToOnePaths;
    } else if (isCircularExchangeModeEnabled) {
      paths = circularPaths;
    } else if (isChainExchangeModeEnabled) {
      paths = chainPaths;
    } else {
      paths = []; // 보강교체 모드에서는 빈 리스트
    }

    // 로딩 상태 결정 (모든 모드 통합 처리)
    bool isLoading = false;
    if (isExchangeModeEnabled) {
      isLoading = isCircularPathsLoading; // 1:1 교체도 동일한 로딩 상태 사용
    } else if (isCircularExchangeModeEnabled) {
      isLoading = isCircularPathsLoading;
    } else if (isChainExchangeModeEnabled) {
      isLoading = isChainPathsLoading;
    } else if (isSupplementExchangeModeEnabled) {
      // 보강교체는 실제 로딩이 없지만 일관성을 위해 동일한 로딩 상태 사용
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
      // 순환교체, 1:1 교체, 연쇄교체 모드에서 사용되는 단계 필터 매개변수들
      availableSteps: (isCircularExchangeModeEnabled || isExchangeModeEnabled || isChainExchangeModeEnabled) ? availableSteps : null,
      selectedStep: (isCircularExchangeModeEnabled || isExchangeModeEnabled || isChainExchangeModeEnabled) ? selectedStep : null,
      onStepChanged: (isCircularExchangeModeEnabled || isExchangeModeEnabled || isChainExchangeModeEnabled) ? onStepChanged : null,
      selectedDay: (isCircularExchangeModeEnabled || isExchangeModeEnabled || isChainExchangeModeEnabled) ? selectedDay : null,
      onDayChanged: (isCircularExchangeModeEnabled || isExchangeModeEnabled || isChainExchangeModeEnabled) ? onDayChanged : null,
      // 보강교체 모드에서 사용되는 교사 버튼 클릭 콜백
      onSupplementTeacherTap: isSupplementExchangeModeEnabled ? onSupplementTeacherTap : null,
    );
  }

  /// 현재 선택된 교체 경로 반환 (모든 타입 지원)
  ExchangePath? getCurrentSelectedPath() {
    // 우선순위: 순환교체 > 연쇄교체 > 1:1교체
    if (selectedCircularPath != null) {
      return selectedCircularPath;
    } else if (selectedChainPath != null) {
      return selectedChainPath;
    } else if (selectedOneToOnePath != null) {
      return selectedOneToOnePath;
    }
    return null;
  }
}

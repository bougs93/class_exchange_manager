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
  void Function(String, String, int) get scrollToCellCenter;
  void onStepChanged(int? step);
  void onDayChanged(String? day);

  /// 통합 교체 사이드바 빌드
  Widget buildUnifiedExchangeSidebar() {
    // 현재 모드 결정
    ExchangePathType currentMode;
    if (isExchangeModeEnabled) {
      currentMode = ExchangePathType.oneToOne;
    } else if (isCircularExchangeModeEnabled) {
      currentMode = ExchangePathType.circular;
    } else {
      currentMode = ExchangePathType.chain;
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

    // 경로 리스트 결정
    List<ExchangePath> paths;
    if (isExchangeModeEnabled) {
      paths = oneToOnePaths;
    } else if (isCircularExchangeModeEnabled) {
      paths = circularPaths;
    } else {
      paths = chainPaths;
    }

    // 로딩 상태 결정
    bool isLoading = false;
    if (isCircularExchangeModeEnabled) {
      isLoading = isCircularPathsLoading;
    } else if (isChainExchangeModeEnabled) {
      isLoading = isChainPathsLoading;
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
      onScrollToCell: scrollToCellCenter,
      // 순환교체, 1:1 교체, 연쇄교체 모드에서 사용되는 단계 필터 매개변수들
      availableSteps: (isCircularExchangeModeEnabled || isExchangeModeEnabled || isChainExchangeModeEnabled) ? availableSteps : null,
      selectedStep: (isCircularExchangeModeEnabled || isExchangeModeEnabled || isChainExchangeModeEnabled) ? selectedStep : null,
      onStepChanged: (isCircularExchangeModeEnabled || isExchangeModeEnabled || isChainExchangeModeEnabled) ? onStepChanged : null,
      selectedDay: (isCircularExchangeModeEnabled || isExchangeModeEnabled || isChainExchangeModeEnabled) ? selectedDay : null,
      onDayChanged: (isCircularExchangeModeEnabled || isExchangeModeEnabled || isChainExchangeModeEnabled) ? onDayChanged : null,
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

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/exchange_path.dart';
import '../../../models/exchange_mode.dart';
import '../../../providers/exchange_screen_provider.dart';
import '../../../services/excel_service.dart';

/// ExchangeScreen의 모든 Provider 상태 접근을 중앙 집중화하는 Proxy 클래스
///
/// 84개의 반복적인 getter/setter boilerplate 코드를 제거하고
/// 단일 진입점을 통해 상태 관리를 단순화합니다.
class ExchangeScreenStateProxy {
  final WidgetRef ref;

  ExchangeScreenStateProxy(this.ref);

  // Private helpers
  ExchangeScreenNotifier get _notifier => ref.read(exchangeScreenProvider.notifier);
  ExchangeScreenState get _state => ref.read(exchangeScreenProvider);

  // ===== ExchangeLogicMixin 관련 상태 =====

  ExchangeMode get currentMode => _state.currentMode;
  void setCurrentMode(ExchangeMode value) => _notifier.setCurrentMode(value);

  // 편의 getter들 (기존 코드와의 호환성을 위해 유지)
  bool get isExchangeModeEnabled => _state.currentMode == ExchangeMode.oneToOneExchange;
  bool get isCircularExchangeModeEnabled => _state.currentMode == ExchangeMode.circularExchange;
  bool get isChainExchangeModeEnabled => _state.currentMode == ExchangeMode.chainExchange;
  bool get isNonExchangeableEditMode => _state.currentMode == ExchangeMode.nonExchangeableEdit;

  // 편의 setter들 (기존 코드와의 호환성을 위해 추가)
  void setExchangeModeEnabled(bool enabled) {
    _notifier.setCurrentMode(enabled ? ExchangeMode.oneToOneExchange : ExchangeMode.view);
  }

  void setCircularExchangeModeEnabled(bool enabled) {
    _notifier.setCurrentMode(enabled ? ExchangeMode.circularExchange : ExchangeMode.view);
  }

  void setChainExchangeModeEnabled(bool enabled) {
    _notifier.setCurrentMode(enabled ? ExchangeMode.chainExchange : ExchangeMode.view);
  }

  void setNonExchangeableEditMode(bool enabled) {
    _notifier.setCurrentMode(enabled ? ExchangeMode.nonExchangeableEdit : ExchangeMode.view);
  }

  // ===== ExchangeFileHandler 관련 상태 =====

  TimetableData? get timetableData => _state.timetableData;
  void setTimetableData(TimetableData? value) => _notifier.setTimetableData(value);

  File? get selectedFile => _state.selectedFile;
  void setSelectedFile(File? value) => _notifier.setSelectedFile(value);

  bool get isLoading => _state.isLoading;
  void setLoading(bool value) => _notifier.setLoading(value);

  String? get errorMessage => _state.errorMessage;
  void setErrorMessage(String? value) => _notifier.setErrorMessage(value);

  // ===== ExchangePathHandler 관련 상태 =====

  // 🔥 통합된 경로 접근 (기존 호환성 유지)
  List<ExchangePath> get availablePaths => _state.availablePaths;
  void setAvailablePaths(List<ExchangePath> value) => _notifier.setAvailablePaths(value);
  
  // 타입별 경로 접근 (기존 호환성 유지)
  List<OneToOneExchangePath> get oneToOnePaths => _state.availablePaths.whereType<OneToOneExchangePath>().toList();
  void setOneToOnePaths(List<OneToOneExchangePath> value) => _notifier.setOneToOnePaths(value);

  OneToOneExchangePath? get selectedOneToOnePath => _state.selectedOneToOnePath;
  void setSelectedOneToOnePath(OneToOneExchangePath? value) => _notifier.setSelectedOneToOnePath(value);

  List<CircularExchangePath> get circularPaths => _state.availablePaths.whereType<CircularExchangePath>().toList();
  void setCircularPaths(List<CircularExchangePath> value) => _notifier.setCircularPaths(value);

  CircularExchangePath? get selectedCircularPath => _state.selectedCircularPath;
  void setSelectedCircularPath(CircularExchangePath? value) => _notifier.setSelectedCircularPath(value);

  List<ChainExchangePath> get chainPaths => _state.availablePaths.whereType<ChainExchangePath>().toList();
  void setChainPaths(List<ChainExchangePath> value) => _notifier.setChainPaths(value);

  ChainExchangePath? get selectedChainPath => _state.selectedChainPath;
  void setSelectedChainPath(ChainExchangePath? value) => _notifier.setSelectedChainPath(value);

  bool get isSidebarVisible => _state.isSidebarVisible;
  void setSidebarVisible(bool value) => _notifier.setSidebarVisible(value);

  // ===== TargetCellHandler 관련 상태 =====

  List<int> get availableSteps => _state.availableSteps;
  void setAvailableSteps(List<int> value) => _notifier.setAvailableSteps(value);

  int? get selectedStep => _state.selectedStep;
  void setSelectedStep(int? value) => _notifier.setSelectedStep(value);

  String? get selectedDay => _state.selectedDay;
  void setSelectedDay(String? value) => _notifier.setSelectedDay(value);

  // ===== FilterSearchHandler 관련 상태 =====

  String get searchQuery => _state.searchQuery;
  void setSearchQuery(String value) => _notifier.setSearchQuery(value);

  // ===== SidebarBuilder 관련 상태 =====

  bool get isPathsLoading => _state.isPathsLoading;
  void setPathsLoading(bool value) => _notifier.setPathsLoading(value);
  
  // 기존 호환성을 위한 메서드들 (deprecated)
  @Deprecated('Use isPathsLoading instead')
  bool get isCircularPathsLoading => _state.isPathsLoading;
  @Deprecated('Use setPathsLoading instead')
  void setCircularPathsLoading(bool value) => _notifier.setPathsLoading(value);
  
  @Deprecated('Use isPathsLoading instead')
  bool get isChainPathsLoading => _state.isPathsLoading;
  @Deprecated('Use setPathsLoading instead')
  void setChainPathsLoading(bool value) => _notifier.setPathsLoading(value);

  double get loadingProgress => _state.loadingProgress;
  void setLoadingProgress(double value) => _notifier.setLoadingProgress(value);

  // ===== 편의 메서드 =====

  /// 모든 교체 모드 비활성화 (보기 모드로 변경)
  void disableAllExchangeModes() {
    _notifier.setCurrentMode(ExchangeMode.view);
  }

  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    _notifier.setSelectedOneToOnePath(null);
    _notifier.setSelectedCircularPath(null);
    _notifier.setSelectedChainPath(null);
  }

  /// 모든 경로 초기화
  void clearAllPaths() {
    _notifier.setOneToOnePaths([]);
    _notifier.setCircularPaths([]);
    _notifier.setChainPaths([]);
  }

  /// 현재 활성화된 교체 모드에 따른 경로 목록 반환
  List<ExchangePath> get currentPaths {
    if (isExchangeModeEnabled) {
      return oneToOnePaths.cast<ExchangePath>();
    } else if (isCircularExchangeModeEnabled) {
      return circularPaths.cast<ExchangePath>();
    } else if (isChainExchangeModeEnabled) {
      return chainPaths.cast<ExchangePath>();
    }
    return [];
  }

  /// 로딩 상태 확인
  bool get isAnyLoading => isLoading || isPathsLoading;
}

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/exchange_path.dart';
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

  bool get isExchangeModeEnabled => _state.isExchangeModeEnabled;
  void setExchangeModeEnabled(bool value) => _notifier.setExchangeModeEnabled(value);

  bool get isCircularExchangeModeEnabled => _state.isCircularExchangeModeEnabled;
  void setCircularExchangeModeEnabled(bool value) => _notifier.setCircularExchangeModeEnabled(value);

  bool get isChainExchangeModeEnabled => _state.isChainExchangeModeEnabled;
  void setChainExchangeModeEnabled(bool value) => _notifier.setChainExchangeModeEnabled(value);

  bool get isNonExchangeableEditMode => _state.isNonExchangeableEditMode;
  void setNonExchangeableEditMode(bool value) => _notifier.setNonExchangeableEditMode(value);

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

  List<OneToOneExchangePath> get oneToOnePaths => _state.oneToOnePaths;
  void setOneToOnePaths(List<OneToOneExchangePath> value) => _notifier.setOneToOnePaths(value);

  OneToOneExchangePath? get selectedOneToOnePath => _state.selectedOneToOnePath;
  void setSelectedOneToOnePath(OneToOneExchangePath? value) => _notifier.setSelectedOneToOnePath(value);

  List<CircularExchangePath> get circularPaths => _state.circularPaths;
  void setCircularPaths(List<CircularExchangePath> value) => _notifier.setCircularPaths(value);

  CircularExchangePath? get selectedCircularPath => _state.selectedCircularPath;
  void setSelectedCircularPath(CircularExchangePath? value) => _notifier.setSelectedCircularPath(value);

  List<ChainExchangePath> get chainPaths => _state.chainPaths;
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

  bool get isCircularPathsLoading => _state.isCircularPathsLoading;
  void setCircularPathsLoading(bool value) => _notifier.setCircularPathsLoading(value);

  bool get isChainPathsLoading => _state.isChainPathsLoading;
  void setChainPathsLoading(bool value) => _notifier.setChainPathsLoading(value);

  double get loadingProgress => _state.loadingProgress;
  void setLoadingProgress(double value) => _notifier.setLoadingProgress(value);

  // ===== 편의 메서드 =====

  /// 모든 교체 모드 비활성화
  void disableAllExchangeModes() {
    _notifier.setExchangeModeEnabled(false);
    _notifier.setCircularExchangeModeEnabled(false);
    _notifier.setChainExchangeModeEnabled(false);
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
  bool get isAnyLoading => isLoading || isCircularPathsLoading || isChainPathsLoading;
}

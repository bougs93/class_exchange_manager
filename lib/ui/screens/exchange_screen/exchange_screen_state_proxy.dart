import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/supplement_exchange_path.dart';
import '../../../models/exchange_path.dart';
import '../../../utils/exchange_path_utils.dart';
import '../../../models/exchange_mode.dart';
import '../../../providers/exchange_screen_provider.dart';
import '../../../services/excel_service.dart';
import '../../../utils/logger.dart';

/// ExchangeScreen의 모든 Provider 상태 접근을 중앙 집중화하는 Proxy 클래스
///
/// 84개의 반복적인 getter/setter boilerplate 코드를 제거하고
/// 단일 진입점을 통해 상태 관리를 단순화합니다.
class ExchangeScreenStateProxy {
  final WidgetRef ref;

  ExchangeScreenStateProxy(this.ref);

  // Private helpers
  ExchangeScreenNotifier get _notifier => ref.read(exchangeScreenProvider.notifier);
  // 🔥 중요: ref.read 대신 ref.watch를 사용하면 재시작 후에도 최신 상태를 가져올 수 있음
  // 하지만 getter에서는 watch를 사용할 수 없으므로, 호출 시점에 직접 읽도록 변경
  ExchangeScreenState _getState() => ref.read(exchangeScreenProvider);

  // ===== ExchangeLogicMixin 관련 상태 =====

  ExchangeMode get currentMode => _getState().currentMode;
  void setCurrentMode(ExchangeMode value) => _notifier.setCurrentMode(value);

  // 편의 getter들 (기존 코드와의 호환성을 위해 유지)
  bool get isExchangeModeEnabled => _getState().currentMode == ExchangeMode.oneToOneExchange;
  bool get isCircularExchangeModeEnabled => _getState().currentMode == ExchangeMode.circularExchange;
  bool get isChainExchangeModeEnabled => _getState().currentMode == ExchangeMode.chainExchange;
  bool get isSupplementExchangeModeEnabled => _getState().currentMode == ExchangeMode.supplementExchange;
  bool get isNonExchangeableEditMode => _getState().currentMode == ExchangeMode.nonExchangeableEdit;

  // 편의 setter들 (기존 코드와의 호환성을 위해 유지)
  void setExchangeModeEnabled(bool enabled) => _setModeEnabled(ExchangeMode.oneToOneExchange, enabled);
  void setCircularExchangeModeEnabled(bool enabled) => _setModeEnabled(ExchangeMode.circularExchange, enabled);
  void setChainExchangeModeEnabled(bool enabled) => _setModeEnabled(ExchangeMode.chainExchange, enabled);
  void setSupplementExchangeModeEnabled(bool enabled) => _setModeEnabled(ExchangeMode.supplementExchange, enabled);
  void setNonExchangeableEditMode(bool enabled) => _setModeEnabled(ExchangeMode.nonExchangeableEdit, enabled);

  /// 내부 헬퍼: 모드 활성화/비활성화 공통 로직
  void _setModeEnabled(ExchangeMode mode, bool enabled) {
    _notifier.setCurrentMode(enabled ? mode : ExchangeMode.view);
  }

  // ===== ExchangeFileHandler 관련 상태 =====

  // 🔥 중요: 재시작 후 timetableData가 비어있을 수 있는 문제 해결
  // 매번 최신 상태를 읽도록 수정 (ref.read는 항상 최신 상태를 반환)
  TimetableData? get timetableData {
    final state = _getState();
    final data = state.timetableData;
    // 디버깅: 빈 timeSlots 확인
    if (data != null && data.timeSlots.isEmpty) {
      AppLogger.exchangeDebug('⚠️ [ExchangeScreenStateProxy] timetableData.timeSlots가 비어있습니다! teachers=${data.teachers.length}');
    }
    return data;
  }
  void setTimetableData(TimetableData? value) => _notifier.setTimetableData(value);

  File? get selectedFile => _getState().selectedFile;
  void setSelectedFile(File? value) => _notifier.setSelectedFile(value);

  int get fileLoadId => _getState().fileLoadId;

  bool get isLoading => _getState().isLoading;
  void setLoading(bool value) => _notifier.setLoading(value);

  String? get errorMessage => _getState().errorMessage;
  void setErrorMessage(String? value) => _notifier.setErrorMessage(value);

  // ===== ExchangePathHandler 관련 상태 =====

  // 통합된 경로 접근
  List<ExchangePath> get availablePaths => _getState().availablePaths;
  void setAvailablePaths(List<ExchangePath> value) => _notifier.setAvailablePaths(value);

  // 선택된 경로들
  OneToOneExchangePath? get selectedOneToOnePath => _getState().selectedOneToOnePath;
  void setSelectedOneToOnePath(OneToOneExchangePath? value) => _notifier.setSelectedOneToOnePath(value);

  CircularExchangePath? get selectedCircularPath => _getState().selectedCircularPath;
  void setSelectedCircularPath(CircularExchangePath? value) => _notifier.setSelectedCircularPath(value);

  ChainExchangePath? get selectedChainPath => _getState().selectedChainPath;
  void setSelectedChainPath(ChainExchangePath? value) => _notifier.setSelectedChainPath(value);

  SupplementExchangePath? get selectedSupplementPath => _getState().selectedSupplementPath;
  void setSelectedSupplementPath(SupplementExchangePath? value) => _notifier.setSelectedSupplementPath(value);

  bool get isSidebarVisible => _getState().isSidebarVisible;
  void setSidebarVisible(bool value) => _notifier.setSidebarVisible(value);

  // ===== TargetCellHandler 관련 상태 =====

  List<int> get availableSteps => _getState().availableSteps;
  void setAvailableSteps(List<int> value) => _notifier.setAvailableSteps(value);

  int? get selectedStep => _getState().selectedStep;
  void setSelectedStep(int? value) => _notifier.setSelectedStep(value);

  String? get selectedDay => _getState().selectedDay;
  void setSelectedDay(String? value) => _notifier.setSelectedDay(value);

  // ===== FilterSearchHandler 관련 상태 =====

  String get searchQuery => _getState().searchQuery;
  void setSearchQuery(String value) => _notifier.setSearchQuery(value);

  // ===== SidebarBuilder 관련 상태 =====

  bool get isPathsLoading => _getState().isPathsLoading;
  void setPathsLoading(bool value) => _notifier.setPathsLoading(value);

  double get loadingProgress => _getState().loadingProgress;
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
    _notifier.setSelectedSupplementPath(null);
  }

  /// 모든 경로 초기화
  void clearAllPaths() {
    _notifier.setAvailablePaths([]);
  }

  /// 현재 활성화된 교체 모드에 따른 경로 목록 반환
  List<ExchangePath> get currentPaths {
    if (isExchangeModeEnabled) {
      return ExchangePathUtils.getOneToOnePaths(availablePaths);
    } else if (isCircularExchangeModeEnabled) {
      return ExchangePathUtils.getCircularPaths(availablePaths);
    } else if (isChainExchangeModeEnabled) {
      return ExchangePathUtils.getChainPaths(availablePaths);
    }
    return [];
  }

  /// 로딩 상태 확인
  bool get isAnyLoading => isLoading || isPathsLoading;
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/excel_service.dart';
import '../../services/exchange_service.dart';
import '../../services/circular_exchange_service.dart';
import '../../services/chain_exchange_service.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/services_provider.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/exchange_node.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/syncfusion_timetable_helper.dart';
import '../../utils/logger.dart';
import '../../utils/day_utils.dart';
import '../../models/exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../utils/exchange_path_converter.dart';

import '../widgets/timetable_grid_section.dart';
import '../mixins/exchange_logic_mixin.dart';
import '../state_managers/path_selection_manager.dart';
import '../state_managers/filter_state_manager.dart';
import 'handlers/exchange_file_handler.dart';
import 'handlers/exchange_mode_handler.dart';
import 'handlers/exchange_path_handler.dart';
import 'handlers/exchange_ui_builder.dart';
import 'handlers/target_cell_handler.dart';
import 'handlers/path_selection_handler_mixin.dart';
import 'handlers/filter_search_handler.dart';
import 'handlers/state_reset_handler.dart';
import 'builders/sidebar_builder.dart';
import 'helpers/circular_path_finder.dart';
import 'helpers/chain_path_finder.dart';

// 새로 분리된 위젯과 ViewModel
import 'exchange_screen/widgets/exchange_app_bar.dart';
import 'exchange_screen/widgets/timetable_tab_content.dart';
import 'exchange_screen/exchange_screen_viewmodel.dart';

/// 교체 관리 화면
class ExchangeScreen extends ConsumerStatefulWidget {
  const ExchangeScreen({super.key});

  @override
  ConsumerState<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends ConsumerState<ExchangeScreen>
    with ExchangeLogicMixin,
         TickerProviderStateMixin,
         ExchangeFileHandler,
         ExchangeModeHandler,
         ExchangePathHandler,
         ExchangeUIBuilder,
         TargetCellHandler,
         PathSelectionHandlerMixin,
         FilterSearchHandler,
         StateResetHandler,
         SidebarBuilder {
  // 로컬에 유지해야 하는 것들 (UI 컨트롤러, 매니저)
  TimetableDataSource? _dataSource; // Syncfusion DataGrid 데이터 소스
  List<GridColumn> _columns = []; // 그리드 컬럼
  List<StackedHeaderRow> _stackedHeaders = []; // 스택된 헤더

  // 경로 선택 관리자
  final PathSelectionManager _pathSelectionManager = PathSelectionManager();

  // 필터 상태 관리자
  final FilterStateManager _filterStateManager = FilterStateManager();

  // Mixin에서 요구하는 getter들 - Provider에서 가져옴
  @override
  ExchangeService get exchangeService => ref.read(exchangeServiceProvider);

  @override
  CircularExchangeService get circularExchangeService => ref.read(circularExchangeServiceProvider);

  @override
  ChainExchangeService get chainExchangeService => ref.read(chainExchangeServiceProvider);

  @override
  TimetableData? get timetableData => ref.read(exchangeScreenProvider).timetableData;

  @override
  TimetableDataSource? get dataSource => _dataSource;

  @override
  bool get isExchangeModeEnabled => ref.read(exchangeScreenProvider).isExchangeModeEnabled;

  @override
  bool get isCircularExchangeModeEnabled => ref.read(exchangeScreenProvider).isCircularExchangeModeEnabled;

  @override
  bool get isChainExchangeModeEnabled => ref.read(exchangeScreenProvider).isChainExchangeModeEnabled;

  @override
  bool get isNonExchangeableEditMode => ref.read(exchangeScreenProvider).isNonExchangeableEditMode;

  @override
  CircularExchangePath? get selectedCircularPath => ref.read(exchangeScreenProvider).selectedCircularPath;

  @override
  ChainExchangePath? get selectedChainPath => ref.read(exchangeScreenProvider).selectedChainPath;

  // 시간표 그리드 제어를 위한 GlobalKey
  final GlobalKey<State<TimetableGridSection>> _timetableGridKey = GlobalKey<State<TimetableGridSection>>();

  // UI 컨트롤러 (로컬 유지)
  final TextEditingController _searchController = TextEditingController();

  // 교체불가 편집 모드 관련 상태는 이제 Riverpod Provider를 통해 관리됨

  // 진행률 애니메이션 관련 변수들 (로컬 유지)
  AnimationController? _progressAnimationController;
  Animation<double>? _progressAnimation;

  // 편의 getter들 - Provider 상태 접근용 (메서드 내부에서 사용)
  ExchangeScreenState get _state => ref.read(exchangeScreenProvider);
  TimetableData? get _timetableData => _state.timetableData;
  bool get _isExchangeModeEnabled => _state.isExchangeModeEnabled;
  bool get _isCircularExchangeModeEnabled => _state.isCircularExchangeModeEnabled;
  bool get _isChainExchangeModeEnabled => _state.isChainExchangeModeEnabled;
  CircularExchangePath? get _selectedCircularPath => _state.selectedCircularPath;
  double get _loadingProgress => _state.loadingProgress;
  ChainExchangePath? get _selectedChainPath => _state.selectedChainPath;

  /// 교체불가 편집 모드 토글 (ViewModel 사용)
  void _toggleNonExchangeableEditMode() {
    final viewModel = ref.read(exchangeScreenViewModelProvider);
    viewModel.toggleNonExchangeableEditMode(
      isExchangeModeEnabled: _isExchangeModeEnabled,
      isCircularExchangeModeEnabled: _isCircularExchangeModeEnabled,
      isChainExchangeModeEnabled: _isChainExchangeModeEnabled,
      toggleExchangeMode: toggleExchangeMode,
      toggleCircularExchangeMode: toggleCircularExchangeMode,
      toggleChainExchangeMode: toggleChainExchangeMode,
      dataSource: _dataSource,
    );
  }

  /// 셀을 교체불가로 설정 또는 해제 (ViewModel 사용)
  void _setCellAsNonExchangeable(DataGridCellTapDetails details) {
    final viewModel = ref.read(exchangeScreenViewModelProvider);
    viewModel.setCellAsNonExchangeable(details, _timetableData, _dataSource);
  }

  /// 셀에서 교사명 추출 (ViewModel 위임)
  String? _getTeacherNameFromCell(DataGridCellTapDetails details) {
    final viewModel = ref.read(exchangeScreenViewModelProvider);
    return viewModel.getTeacherNameFromCell(details, _dataSource);
  }

  /// 교사명 클릭 시 해당 교사의 모든 시간을 교체가능/교체불가능으로 토글 (ViewModel 사용)
  void _toggleTeacherAllTimes(DataGridCellTapDetails details) {
    final teacherName = _getTeacherNameFromCell(details);
    if (teacherName == null) return;

    final viewModel = ref.read(exchangeScreenViewModelProvider);
    viewModel.toggleTeacherAllTimes(teacherName, _timetableData, _dataSource);

    // UI 업데이트
    if (mounted) {
      setState(() {});
    }
  }

  OneToOneExchangePath? get _selectedOneToOnePath => _state.selectedOneToOnePath;
  bool get _isSidebarVisible => _state.isSidebarVisible;

  // ExchangeFileHandler 인터페이스 구현 - Provider 사용
  @override
  File? get selectedFile => ref.read(exchangeScreenProvider).selectedFile;
  @override
  void Function(File?) get setSelectedFile => (file) => ref.read(exchangeScreenProvider.notifier).setSelectedFile(file);
  @override
  void Function(TimetableData?) get setTimetableData => (data) {
    ref.read(exchangeScreenProvider.notifier).setTimetableData(data);
    if (data != null) {
      _createSyncfusionGridData();
    }
  };
  @override
  void Function(bool) get setLoading => (loading) => ref.read(exchangeScreenProvider.notifier).setLoading(loading);
  @override
  void Function(String?) get setErrorMessage => (msg) => ref.read(exchangeScreenProvider.notifier).setErrorMessage(msg);
  @override
  void Function() get createSyncfusionGridData => _createSyncfusionGridData;

  // ExchangeModeHandler 인터페이스 구현 - Provider 사용
  @override
  void Function(bool) get setExchangeModeEnabled => (enabled) => ref.read(exchangeScreenProvider.notifier).setExchangeModeEnabled(enabled);
  @override
  void Function(bool) get setCircularExchangeModeEnabled => (enabled) => ref.read(exchangeScreenProvider.notifier).setCircularExchangeModeEnabled(enabled);
  @override
  void Function(bool) get setChainExchangeModeEnabled => (enabled) => ref.read(exchangeScreenProvider.notifier).setChainExchangeModeEnabled(enabled);
  @override
  void Function(bool) get setNonExchangeableEditMode => (enabled) => ref.read(exchangeScreenProvider.notifier).setNonExchangeableEditMode(enabled);
  @override
  void Function() get refreshHeaderTheme => _updateHeaderTheme;
  @override
  List<int> get availableSteps => ref.read(exchangeScreenProvider).availableSteps;
  @override
  set availableSteps(List<int> value) => ref.read(exchangeScreenProvider.notifier).setAvailableSteps(value);
  @override
  int? get selectedStep => ref.read(exchangeScreenProvider).selectedStep;
  @override
  set selectedStep(int? value) => ref.read(exchangeScreenProvider.notifier).setSelectedStep(value);
  @override
  String? get selectedDay => ref.read(exchangeScreenProvider).selectedDay;
  @override
  set selectedDay(String? value) => ref.read(exchangeScreenProvider.notifier).setSelectedDay(value);

  // ExchangePathHandler 인터페이스 구현 - Provider 사용
  @override
  List<OneToOneExchangePath> get oneToOnePaths => ref.read(exchangeScreenProvider).oneToOnePaths;
  @override
  set oneToOnePaths(List<OneToOneExchangePath> value) => ref.read(exchangeScreenProvider.notifier).setOneToOnePaths(value);
  @override
  OneToOneExchangePath? get selectedOneToOnePath => ref.read(exchangeScreenProvider).selectedOneToOnePath;
  @override
  set selectedOneToOnePath(OneToOneExchangePath? value) => ref.read(exchangeScreenProvider.notifier).setSelectedOneToOnePath(value);
  @override
  List<CircularExchangePath> get circularPaths => ref.read(exchangeScreenProvider).circularPaths;
  @override
  set circularPaths(List<CircularExchangePath> value) => ref.read(exchangeScreenProvider.notifier).setCircularPaths(value);
  @override
  List<ChainExchangePath> get chainPaths => ref.read(exchangeScreenProvider).chainPaths;
  @override
  set chainPaths(List<ChainExchangePath> value) => ref.read(exchangeScreenProvider.notifier).setChainPaths(value);
  @override
  bool get isSidebarVisible => ref.read(exchangeScreenProvider).isSidebarVisible;
  @override
  set isSidebarVisible(bool value) => ref.read(exchangeScreenProvider.notifier).setSidebarVisible(value);
  @override
  void Function() get updateFilteredPaths => _updateFilteredPaths;
  @override
  void Function(double) get updateProgressSmoothly => _updateProgressSmoothly;

  // PathSelectionHandlerMixin 인터페이스 구현 - Provider 사용
  @override
  PathSelectionManager get pathSelectionManager => _pathSelectionManager;
  @override
  void Function(OneToOneExchangePath?) get setSelectedOneToOnePath => (path) => ref.read(exchangeScreenProvider.notifier).setSelectedOneToOnePath(path);
  @override
  void Function(ChainExchangePath?) get setSelectedChainPath => (path) => ref.read(exchangeScreenProvider.notifier).setSelectedChainPath(path);

  // FilterSearchHandler 인터페이스 구현 - Provider 사용
  @override
  FilterStateManager get filterStateManager => _filterStateManager;
  @override
  TextEditingController get searchController => _searchController;
  @override
  String get searchQuery => ref.read(exchangeScreenProvider).searchQuery;
  @override
  void Function(String) get setSearchQuery => (query) => ref.read(exchangeScreenProvider.notifier).setSearchQuery(query);
  @override
  void Function(int?) get setSelectedStep => (step) => ref.read(exchangeScreenProvider.notifier).setSelectedStep(step);
  @override
  void Function(String?) get setSelectedDay => (day) => ref.read(exchangeScreenProvider.notifier).setSelectedDay(day);
  @override
  void Function(List<int>) get setAvailableSteps => (steps) => ref.read(exchangeScreenProvider.notifier).setAvailableSteps(steps);

  // SidebarBuilder 인터페이스 구현 - Provider 사용
  @override
  List<ExchangePath> get filteredPaths {
    // filteredPaths는 로컬 계산이 필요
    final state = ref.read(exchangeScreenProvider);
    final paths = state.isExchangeModeEnabled ? state.oneToOnePaths.cast<ExchangePath>() :
                  state.isCircularExchangeModeEnabled ? state.circularPaths.cast<ExchangePath>() :
                  state.chainPaths.cast<ExchangePath>();
    
    // FilterStateManager를 사용하여 모든 필터 적용 (단계 필터, 요일 필터, 검색 필터)
    return _filterStateManager.applyFilters(paths);
  }
  @override
  double get sidebarWidth => 180.0;
  @override
  bool get isCircularPathsLoading => ref.read(exchangeScreenProvider).isCircularPathsLoading;
  @override
  bool get isChainPathsLoading => ref.read(exchangeScreenProvider).isChainPathsLoading;
  @override
  double get loadingProgress => ref.read(exchangeScreenProvider).loadingProgress;
  @override
  void Function() get toggleSidebar => _toggleSidebar;
  @override
  String Function(ExchangeNode) get getSubjectName => _getSubjectName;
  @override
  void Function(String, String, int) get scrollToCellCenter => _scrollToCellCenter;

  // StateResetHandler 인터페이스 구현 - Provider 사용
  @override
  void Function(CircularExchangePath?) get setSelectedCircularPath => (path) => ref.read(exchangeScreenProvider.notifier).setSelectedCircularPath(path);
  @override
  void Function(List<CircularExchangePath>) get setCircularPaths => (paths) => ref.read(exchangeScreenProvider.notifier).setCircularPaths(paths);
  @override
  void Function(List<ChainExchangePath>) get setChainPaths => (chains) => ref.read(exchangeScreenProvider.notifier).setChainPaths(chains);
  @override
  void Function(bool) get setSidebarVisible => (visible) => ref.read(exchangeScreenProvider.notifier).setSidebarVisible(visible);
  @override
  void Function(bool) get setCircularPathsLoading => (loading) => ref.read(exchangeScreenProvider.notifier).setCircularPathsLoading(loading);
  @override
  void Function(bool) get setChainPathsLoading => (loading) => ref.read(exchangeScreenProvider.notifier).setChainPathsLoading(loading);
  @override
  void Function(double) get setLoadingProgress => (progress) => ref.read(exchangeScreenProvider.notifier).setLoadingProgress(progress);
  @override
  void Function(List<ExchangePath>) get setFilteredPaths => (paths) {
    // filteredPaths는 computed property이므로 setter는 no-op
  };
  @override
  void Function(List<OneToOneExchangePath>) get setOneToOnePaths => (paths) => ref.read(exchangeScreenProvider.notifier).setOneToOnePaths(paths);

  @override
  void initState() {
    super.initState();

    // PathSelectionManager 콜백 설정
    _pathSelectionManager.setCallbacks(
      onOneToOnePathChanged: handleOneToOnePathChanged,
      onCircularPathChanged: handleCircularPathChanged,
      onChainPathChanged: handleChainPathChanged,
    );

    // FilterStateManager 콜백 설정
    _filterStateManager.setOnFilterChanged(_updateFilteredPaths);

    // 진행률 애니메이션 컨트롤러 초기화
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController!,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _progressAnimationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provider에서 상태 읽기
    final screenState = ref.watch(exchangeScreenProvider);
    
    // 교체불가 편집 모드 상태가 변경될 때마다 TimetableDataSource에 전달
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dataSource?.setNonExchangeableEditMode(screenState.isNonExchangeableEditMode);
    });

    // 로컬 변수로 캐싱 (build 메서드 내에서 사용)
    final isSidebarVisible = screenState.isSidebarVisible;
    final isExchangeModeEnabled = screenState.isExchangeModeEnabled;
    final isCircularExchangeModeEnabled = screenState.isCircularExchangeModeEnabled;
    final isChainExchangeModeEnabled = screenState.isChainExchangeModeEnabled;
    final oneToOnePaths = screenState.oneToOnePaths;
    final circularPaths = screenState.circularPaths;
    final chainPaths = screenState.chainPaths;
    final isCircularPathsLoading = screenState.isCircularPathsLoading;
    final isChainPathsLoading = screenState.isChainPathsLoading;

    return Scaffold(
      appBar: ExchangeAppBar(
        state: screenState,
        onToggleSidebar: _toggleSidebar,
      ),
      body: Row(
        children: [
          // 시간표 영역
          Expanded(
            child: TimetableTabContent(
              state: screenState,
              timetableData: _timetableData,
              dataSource: _dataSource,
              columns: _columns,
              stackedHeaders: _stackedHeaders,
              timetableGridKey: _timetableGridKey,
              onSelectExcelFile: selectExcelFile,
              onToggleExchangeMode: toggleExchangeMode,
              onToggleCircularExchangeMode: toggleCircularExchangeMode,
              onToggleChainExchangeMode: toggleChainExchangeMode,
              onToggleNonExchangeableEditMode: _toggleNonExchangeableEditMode,
              onClearSelection: _clearSelection,
              onCellTap: _onCellTap,
              getActualExchangeableCount: getActualExchangeableCount,
              getCurrentSelectedPath: getCurrentSelectedPath,
              buildErrorMessageSection: buildErrorMessageSection,
              onClearError: _clearError,
            ),
          ),

          // 통합 교체 사이드바
          if (isSidebarVisible && (
            (isExchangeModeEnabled && oneToOnePaths.isNotEmpty) ||
            (isCircularExchangeModeEnabled && (circularPaths.isNotEmpty || isCircularPathsLoading)) ||
            (isChainExchangeModeEnabled && (chainPaths.isNotEmpty || isChainPathsLoading))
          ))
            buildUnifiedExchangeSidebar(),
        ],
      ),
    );
  }

  
  /// Syncfusion DataGrid 컬럼 및 헤더 생성
  void _createSyncfusionGridData() {
    if (_timetableData == null) return;
    
    // ExchangeService를 사용하여 교체 가능한 교사 정보 수집 (현재 선택된 교사가 있는 경우에만)
    List<Map<String, dynamic>> exchangeableTeachers = [];
    if (exchangeService.hasSelectedCell()) {
      // 현재 교체 가능한 교사 정보를 가져옴
      exchangeableTeachers = exchangeService.getCurrentExchangeableTeachers(
        _timetableData!.timeSlots,
        _timetableData!.teachers,
      );
    }
    
    // 선택된 요일과 교시 결정 (1:1 교체 또는 순환교체 모드에 따라)
    String? selectedDay;
    int? selectedPeriod;
    
    if (_isExchangeModeEnabled && exchangeService.hasSelectedCell()) {
      // 1:1 교체 모드
      selectedDay = exchangeService.selectedDay;
      selectedPeriod = exchangeService.selectedPeriod;
    } else if (_isCircularExchangeModeEnabled && circularExchangeService.hasSelectedCell()) {
      // 순환교체 모드
      selectedDay = circularExchangeService.selectedDay;
      selectedPeriod = circularExchangeService.selectedPeriod;
    }
    
    // SyncfusionTimetableHelper를 사용하여 데이터 생성 (테마 기반)
    final result = SyncfusionTimetableHelper.convertToSyncfusionData(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
      selectedDay: selectedDay,      // 선택된 요일 전달
      selectedPeriod: selectedPeriod, // 선택된 교시 전달
      exchangeableTeachers: exchangeableTeachers, // 교체 가능한 교사 정보 전달
      selectedCircularPath: _selectedCircularPath, // 선택된 순환교체 경로 전달
      selectedOneToOnePath: _selectedOneToOnePath, // 선택된 1:1 교체 경로 전달
    );
    
    _columns = result.columns;
    _stackedHeaders = result.stackedHeaders;
    
    // 데이터 소스 생성
    _dataSource = TimetableDataSource(
      timeSlots: _timetableData!.timeSlots,
      teachers: _timetableData!.teachers,
    );
    
    // 데이터 변경 시 UI 업데이트 콜백 설정
    _dataSource?.setOnDataChanged(() {
      if (mounted) {
        setState(() {});
      }
    });
    
    // 교체불가 편집 모드 상태를 TimetableDataSource에 전달
    _dataSource?.setNonExchangeableEditMode(ref.read(exchangeScreenProvider).isNonExchangeableEditMode);
  }
  
  /// 셀 탭 이벤트 핸들러 - 교체 모드가 활성화된 경우만 동작
  void _onCellTap(DataGridCellTapDetails details) {
    // 교사명 열 클릭 처리 (교체불가 편집 모드에서만 동작)
    if (details.column.columnName == 'teacher' && ref.read(exchangeScreenProvider).isNonExchangeableEditMode) {
      _toggleTeacherAllTimes(details);
      return;
    }
    
    // 교체불가 편집 모드인 경우 셀을 교체불가로 설정
    if (ref.read(exchangeScreenProvider).isNonExchangeableEditMode) {
      _setCellAsNonExchangeable(details);
      return;
    }
    
    // 교체 모드가 비활성화된 경우 아무 동작하지 않음
    if (!_isExchangeModeEnabled && !_isCircularExchangeModeEnabled && !_isChainExchangeModeEnabled) {
      return;
    }

    // 1:1 교체 모드인 경우에만 교체 처리 시작
    if (_isExchangeModeEnabled) {
      startOneToOneExchange(details);
    }
    // 순환교체 모드인 경우 순환교체 처리 시작
    else if (_isCircularExchangeModeEnabled) {
      startCircularExchange(details);
    }
    // 연쇄교체 모드인 경우 연쇄교체 처리 시작
    else if (_isChainExchangeModeEnabled) {
      startChainExchange(details);
    }
  }
  
  // Mixin에서 요구하는 추상 메서드들 구현
  @override
  void updateDataSource() {
    _createSyncfusionGridData();
  }
  
  @override
  void updateHeaderTheme() {
    _updateHeaderTheme();
  }
  
  @override
  void showSnackBar(String message, {Color? backgroundColor}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  @override
  void onEmptyCellSelected() {
    // 빈 셀 선택 시 이전 교체 관련 상태만 초기화
    clearPreviousExchangeStates();
    
    // 필터 초기화
    resetFilters();
    
    // 시간표 그리드 테마 업데이트 (이전 경로 표시 제거)
    _updateHeaderTheme();
  }
  
  @override
  Future<void> findCircularPathsWithProgress() async {
    // 로딩 상태 시작
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setCircularPathsLoading(true);
    notifier.setLoadingProgress(0.0);
    notifier.setSidebarVisible(true); // 로딩 중에도 사이드바 표시

    // 헬퍼를 사용하여 경로 탐색
    final result = await CircularPathFinder.findCircularPathsWithProgress(
      circularExchangeService: circularExchangeService,
      timetableData: _timetableData,
      updateProgress: _updateProgressSmoothly,
      updateAvailableSteps: updateAvailableSteps,
      resetFilters: resetFilters,
      dataSource: _dataSource,
      context: mounted ? context : null,
    );

    // 결과 적용
    notifier.setCircularPaths(result.paths);
    notifier.setSelectedCircularPath(null);
    notifier.setCircularPathsLoading(false);
    notifier.setLoadingProgress(0.0);
    notifier.setSidebarVisible(result.shouldShowSidebar);

    if (result.error == null) {
      // 필터링된 경로 업데이트
      _updateFilteredPaths();
    }
  }
  
  @override
  void onPathSelected(CircularExchangePath path) {
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setSelectedCircularPath(path);

    // 순환 교체 경로가 선택되면 순환 교체 모드 자동 활성화
    if (!_isCircularExchangeModeEnabled) {
      notifier.setCircularExchangeModeEnabled(true);
    }

    // 데이터 소스에 선택된 경로 업데이트
    _dataSource?.updateSelectedCircularPath(path);

    // 시간표 그리드 업데이트
    _updateHeaderTheme();
  }

  @override
  void onPathDeselected() {
    ref.read(exchangeScreenProvider.notifier).setSelectedCircularPath(null);

    // 데이터 소스에서 선택된 경로 제거
    _dataSource?.updateSelectedCircularPath(null);

    // 시간표 그리드 업데이트
    _updateHeaderTheme();
  }
  
  @override
  void clearPreviousCircularExchangeState() {
    // 순환교체 이전 상태만 초기화 (현재 선택된 셀은 유지)
    clearPreviousExchangeStates();
    
    // 필터 초기화
    resetFilters();
    
    // 시간표 그리드 테마 업데이트 (이전 경로 표시 제거)
    _updateHeaderTheme();
  }

  @override
  void clearPreviousChainExchangeState() {
    // 연쇄교체 이전 상태만 초기화 (현재 선택된 셀은 유지)
    clearPreviousExchangeStates();
    
    // 필터 초기화
    resetFilters();
    
    // 시간표 그리드 테마 업데이트 (이전 경로 표시 제거)
    _updateHeaderTheme();
    
    AppLogger.exchangeDebug('연쇄교체: 이전 상태 초기화 완료');
  }

  @override
  void onEmptyChainCellSelected() {
    // 빈 셀 선택 시 처리
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setChainPaths([]);
    notifier.setSelectedChainPath(null);
    notifier.setChainPathsLoading(false);
    notifier.setSidebarVisible(false);

    showSnackBar('빈 셀은 연쇄교체할 수 없습니다.');
    AppLogger.exchangeInfo('연쇄교체: 빈 셀 선택됨 - 경로 탐색 건너뜀');
  }

  @override
  Future<void> findChainPathsWithProgress() async {
    if (_timetableData == null || !chainExchangeService.hasSelectedCell()) {
      AppLogger.warning('연쇄교체: 시간표 데이터 없음 또는 셀 미선택');
      return;
    }

    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setChainPathsLoading(true);
    notifier.setLoadingProgress(0.0);
    notifier.setChainPaths([]);
    notifier.setSelectedChainPath(null);
    notifier.setSidebarVisible(true);

    // 헬퍼를 사용하여 경로 탐색
    final result = await ChainPathFinder.findChainPathsWithProgress(
      chainExchangeService: chainExchangeService,
      timeSlots: _timetableData!.timeSlots,
      teachers: _timetableData!.teachers,
    );

    notifier.setChainPaths(result.paths);
    notifier.setChainPathsLoading(false);
    notifier.setLoadingProgress(1.0);
    notifier.setSidebarVisible(result.shouldShowSidebar);

    if (result.message != null) {
      showSnackBar(result.message!);
    }
  }
  
  @override
  void processCellSelection() {
    // 새로운 셀 선택시 이전 교체 관련 상태만 초기화 (현재 선택된 셀은 유지)
    clearPreviousExchangeStates();
    
    // 순환교체, 1:1 교체, 연쇄교체 모드에서 필터 초기화
    if (_isCircularExchangeModeEnabled || _isExchangeModeEnabled || _isChainExchangeModeEnabled) {
      resetFilters();
    }
    
    // 부모 클래스의 processCellSelection 호출
    super.processCellSelection();
  }

  @override
  void generateOneToOnePaths(List<dynamic> options) {
    if (!exchangeService.hasSelectedCell() || timetableData == null) {
      final notifier = ref.read(exchangeScreenProvider.notifier);
      notifier.setOneToOnePaths([]);
      notifier.setSelectedOneToOnePath(null);
      notifier.setSidebarVisible(false);
      return;
    }

    // 선택된 셀의 학급명 추출
    String selectedClassName = ExchangePathConverter.extractClassNameFromTimeSlots(
      timeSlots: timetableData!.timeSlots,
      teacherName: exchangeService.selectedTeacher!,
      day: exchangeService.selectedDay!,
      period: exchangeService.selectedPeriod!,
    );

    // ExchangeOption을 OneToOneExchangePath로 변환
    List<OneToOneExchangePath> paths = ExchangePathConverter.convertToOneToOnePaths(
      selectedTeacher: exchangeService.selectedTeacher!,
      selectedDay: exchangeService.selectedDay!,
      selectedPeriod: exchangeService.selectedPeriod!,
      selectedClassName: selectedClassName,
      options: options.cast(), // dynamic을 ExchangeOption으로 캐스팅
    );

    // 순차적인 ID 부여
    for (int i = 0; i < paths.length; i++) {
      paths[i].setCustomId('onetoone_path_${i + 1}');
    }

    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setOneToOnePaths(paths);
    notifier.setSelectedOneToOnePath(null);

    // 필터링된 경로 업데이트
    _updateFilteredPaths();

    // 경로가 있으면 사이드바 표시
    notifier.setSidebarVisible(paths.isNotEmpty);
  }

  /// 필터링된 경로 업데이트 (통합)
  void _updateFilteredPaths() {
    // filteredPaths는 computed property이므로 실제 저장하지 않음
    // 필요시 _filterStateManager를 통해 계산됨
  }


  /// 선택 해제 메서드
  void _clearSelection() {
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setSelectedFile(null);
    notifier.setTimetableData(null);
    _dataSource = null;
    _columns = [];
    _stackedHeaders = [];
    notifier.setErrorMessage(null);

    // 모든 교체 서비스의 선택 상태 초기화
    exchangeService.clearAllSelections();
    circularExchangeService.clearAllSelections();
    chainExchangeService.clearAllSelections();

    // 모든 교체 모드도 함께 종료
    notifier.setExchangeModeEnabled(false);
    notifier.setCircularExchangeModeEnabled(false);
    notifier.setChainExchangeModeEnabled(false);

    // 선택된 교체 경로들도 초기화
    notifier.setSelectedCircularPath(null);
    notifier.setSelectedOneToOnePath(null);
    notifier.setSelectedChainPath(null);
    notifier.setCircularPaths([]);
    notifier.setOneToOnePaths([]);
    notifier.setChainPaths([]);
    notifier.setSidebarVisible(false);

    // 교체 가능한 교사 정보도 초기화
    _dataSource?.updateExchangeableTeachers([]);
    _dataSource?.updateSelectedCircularPath(null);
    _dataSource?.updateSelectedOneToOnePath(null);

    // 선택 해제 시에도 헤더 테마 업데이트
    if (_timetableData != null) {
      _updateHeaderTheme();
    }
  }

  /// 오류 메시지 제거 메서드
  void _clearError() {
    ref.read(exchangeScreenProvider.notifier).setErrorMessage(null);
  }
  
  
  
  /// 테마 기반 헤더 업데이트 (선택된 교시 헤더를 연한 파란색으로 표시)
  void _updateHeaderTheme() {
    if (_timetableData == null) return;
    
    // ExchangeService를 사용하여 교체 가능한 교사 정보 수집
    List<Map<String, dynamic>> exchangeableTeachers = exchangeService.getCurrentExchangeableTeachers(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
    );
    
    // 선택된 요일과 교시 결정 (1:1 교체 또는 순환교체 모드에 따라)
    String? selectedDay;
    int? selectedPeriod;
    
    if (_isExchangeModeEnabled && exchangeService.hasSelectedCell()) {
      // 1:1 교체 모드
      selectedDay = exchangeService.selectedDay;
      selectedPeriod = exchangeService.selectedPeriod;
    } else if (_isCircularExchangeModeEnabled && circularExchangeService.hasSelectedCell()) {
      // 순환교체 모드
      selectedDay = circularExchangeService.selectedDay;
      selectedPeriod = circularExchangeService.selectedPeriod;
    } else if (_isChainExchangeModeEnabled && chainExchangeService.hasSelectedCell()) {
      // 연쇄교체 모드
      selectedDay = chainExchangeService.nodeADay;
      selectedPeriod = chainExchangeService.nodeAPeriod;
    }
    
    // 선택된 교시 정보를 전달하여 헤더만 업데이트
    final result = SyncfusionTimetableHelper.convertToSyncfusionData(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
      selectedDay: selectedDay,      // 테마에서 사용할 선택 정보
      selectedPeriod: selectedPeriod,
      exchangeableTeachers: exchangeableTeachers, // 교체 가능한 교사 정보 전달
      selectedCircularPath: _isCircularExchangeModeEnabled ? _selectedCircularPath : null, // 순환교체 모드가 활성화된 경우에만 전달
      selectedOneToOnePath: _isExchangeModeEnabled ? _selectedOneToOnePath : null, // 1:1 교체 모드가 활성화된 경우에만 전달
      selectedChainPath: _isChainExchangeModeEnabled ? _selectedChainPath : null, // 연쇄교체 모드가 활성화된 경우에만 전달
    );
    
    _columns = result.columns; // 헤더만 업데이트
    setState(() {}); // UI 갱신
  }


  /// 통합 경로 선택 처리 (PathSelectionManager 사용)

  /// 부드러운 진행률 업데이트
  void _updateProgressSmoothly(double targetProgress) {
    final notifier = ref.read(exchangeScreenProvider.notifier);

    // 애니메이션 컨트롤러가 초기화되지 않은 경우 즉시 진행률 업데이트
    if (_progressAnimationController == null) {
      notifier.setLoadingProgress(targetProgress);
      return;
    }

    // 현재 진행률에서 목표 진행률로 부드럽게 애니메이션
    _progressAnimationController!.reset();
    _progressAnimation = Tween<double>(
      begin: _loadingProgress,
      end: targetProgress,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController!,
      curve: Curves.easeInOut,
    ));

    _progressAnimationController!.forward().then((_) {
      notifier.setLoadingProgress(targetProgress);
    });

    // 애니메이션 중에도 진행률 업데이트
    _progressAnimation!.addListener(() {
      notifier.setLoadingProgress(_progressAnimation!.value);
    });
  }



  /// 교사 정보에서 과목명 추출
  String _getSubjectName(ExchangeNode node) {
    if (_timetableData == null) return '과목';
    
    // 시간표 데이터에서 해당 교사, 요일, 교시의 과목 정보 찾기
    for (var timeSlot in _timetableData!.timeSlots) {
      if (timeSlot.teacher == node.teacherName &&
          timeSlot.dayOfWeek == DayUtils.getDayNumber(node.day) &&
          timeSlot.period == node.period) {
        return timeSlot.subject ?? '과목';
      }
    }
    
    return '과목';
  }

  /// 사이드바에서 클릭한 셀을 화면 중앙으로 스크롤
  void _scrollToCellCenter(String teacherName, String day, int period) {
    
    if (_timetableData == null) {
      AppLogger.exchangeDebug('오류: timetableData가 null입니다.');
      return;
    }

    // TimetableGridSection의 scrollToCellCenter 메서드 호출
    TimetableGridSection.scrollToCellCenter(_timetableGridKey, teacherName, day, period);
    
    AppLogger.exchangeDebug('셀 스크롤 요청: $teacherName 선생님 ($day $period교시)');
  }

  

  /// 사이드바 토글
  void _toggleSidebar() {
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setSidebarVisible(!_isSidebarVisible);
  }

  
}


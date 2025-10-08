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
import '../../utils/non_exchangeable_manager.dart';
import '../../utils/fixed_header_style_manager.dart';
import '../../models/exchange_path.dart';
import '../../models/exchange_mode.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../utils/exchange_path_converter.dart';

import '../widgets/timetable_grid_section.dart';
import '../mixins/exchange_logic_mixin.dart';
import '../state_managers/path_selection_manager.dart';
import '../state_managers/filter_state_manager.dart';
import 'handlers/exchange_ui_builder.dart';
import 'handlers/target_cell_handler.dart';
import 'handlers/path_selection_handler_mixin.dart';
import 'handlers/filter_search_handler.dart';
import 'builders/sidebar_builder.dart';
import '../../providers/state_reset_provider.dart';
import 'helpers/circular_path_finder.dart';
import 'helpers/chain_path_finder.dart';

// 새로 분리된 위젯, ViewModel, Managers
import 'exchange_screen/widgets/exchange_app_bar.dart';
import 'exchange_screen/widgets/timetable_tab_content.dart';
import 'exchange_screen/exchange_screen_viewmodel.dart';
import 'exchange_screen/exchange_screen_state_proxy.dart';
import 'exchange_screen/managers/exchange_operation_manager.dart';
// PathManager는 Helper가 직접 사용하므로 현재 미사용
// import 'exchange_screen/managers/exchange_path_manager.dart';

/// 교체 관리 화면
class ExchangeScreen extends ConsumerStatefulWidget {
  const ExchangeScreen({super.key});

  @override
  ConsumerState<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends ConsumerState<ExchangeScreen>
    with ExchangeLogicMixin,              // 핵심 비즈니스 로직 (셀 선택, 교체 가능성 확인)
         TickerProviderStateMixin,         // Flutter 애니메이션
         ExchangeUIBuilder,                // UI 빌더 메서드
         TargetCellHandler,                // 타겟 셀 설정
         PathSelectionHandlerMixin,        // 경로 선택 핸들러
         FilterSearchHandler,              // 필터 및 검색
         SidebarBuilder {                  // 사이드바 빌더
  // 로컬 UI 상태 - Provider를 통해 관리
  // TimetableDataSource? _dataSource;
  // List<GridColumn> _columns = [];
  // List<StackedHeaderRow> _stackedHeaders = [];

  /// Provider에서 현재 dataSource 가져오기
  TimetableDataSource? get _dataSource => ref.read(exchangeScreenProvider).dataSource;

  // 상태 관리자
  final PathSelectionManager _pathSelectionManager = PathSelectionManager();
  final FilterStateManager _filterStateManager = FilterStateManager();

  // Proxy 및 Manager (Composition)
  late final ExchangeScreenStateProxy _stateProxy;
  late final ExchangeOperationManager _operationManager;
  // PathManager는 Helper에서 직접 Service를 사용하므로 현재 미사용
  // late final ExchangePathManager _pathManager;

  // Mixin에서 요구하는 getter들 - Service는 Provider에서, 나머지는 Proxy 사용
  @override
  ExchangeService get exchangeService => ref.read(exchangeServiceProvider);

  @override
  CircularExchangeService get circularExchangeService => ref.read(circularExchangeServiceProvider);

  @override
  ChainExchangeService get chainExchangeService => ref.read(chainExchangeServiceProvider);

  @override
  TimetableData? get timetableData => _stateProxy.timetableData;

  @override
  TimetableDataSource? get dataSource => _dataSource;

  @override
  bool get isExchangeModeEnabled => _stateProxy.currentMode == ExchangeMode.oneToOneExchange;

  @override
  bool get isCircularExchangeModeEnabled => _stateProxy.currentMode == ExchangeMode.circularExchange;

  @override
  bool get isChainExchangeModeEnabled => _stateProxy.currentMode == ExchangeMode.chainExchange;

  bool get isNonExchangeableEditMode => _stateProxy.currentMode == ExchangeMode.nonExchangeableEdit;

  @override
  CircularExchangePath? get selectedCircularPath => _stateProxy.selectedCircularPath;

  @override
  ChainExchangePath? get selectedChainPath => _stateProxy.selectedChainPath;

  // 시간표 그리드 제어를 위한 GlobalKey
  final GlobalKey<State<TimetableGridSection>> _timetableGridKey = GlobalKey<State<TimetableGridSection>>();

  // UI 컨트롤러 (로컬 유지)
  final TextEditingController _searchController = TextEditingController();

  // 교체불가 편집 모드 관련 상태는 이제 Riverpod Provider를 통해 관리됨

  // 진행률 애니메이션 관련 변수들 (로컬 유지)
  AnimationController? _progressAnimationController;
  Animation<double>? _progressAnimation;

  // 편의 getter들 - Proxy를 통한 상태 접근 (메서드 내부에서 사용)
  TimetableData? get _timetableData => _stateProxy.timetableData;
  bool get _isExchangeModeEnabled => _stateProxy.currentMode == ExchangeMode.oneToOneExchange;
  bool get _isCircularExchangeModeEnabled => _stateProxy.currentMode == ExchangeMode.circularExchange;
  bool get _isChainExchangeModeEnabled => _stateProxy.currentMode == ExchangeMode.chainExchange;
  CircularExchangePath? get _selectedCircularPath => _stateProxy.selectedCircularPath;
  double get _loadingProgress => _stateProxy.loadingProgress;
  ChainExchangePath? get _selectedChainPath => _stateProxy.selectedChainPath;
  OneToOneExchangePath? get _selectedOneToOnePath => _stateProxy.selectedOneToOnePath;
  bool get _isSidebarVisible => _stateProxy.isSidebarVisible;

  /// 교체 모드 변경 (TabBar에서 호출)
  void _changeMode(ExchangeMode newMode) {
    final notifier = ref.read(exchangeScreenProvider.notifier);
    
    // 즉시 모드 변경 (UI 반응성 향상)
    notifier.setCurrentMode(newMode);
    
    // 무거운 작업들은 비동기로 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _performModeChangeTasks(newMode);
      }
    });
  }
  
  /// 모드 변경 시 무거운 작업들을 비동기로 처리
  void _performModeChangeTasks(ExchangeMode newMode) {
    final notifier = ref.read(exchangeScreenProvider.notifier);
    
    // 모드 변경 전에 현재 선택된 셀 강제 해제
    _clearAllCellSelections();

    // 모든 모드 전환 시 Level 2 초기화로 통일
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '${newMode.displayName} 모드로 전환',
    );
      
    // 각 모드별 초기 설정
    switch (newMode) {
      case ExchangeMode.oneToOneExchange:
        notifier.setAvailableSteps([2]);
        break;
      case ExchangeMode.circularExchange:
      case ExchangeMode.chainExchange:
        notifier.setAvailableSteps([2, 3, 4, 5]);
        break;
      case ExchangeMode.nonExchangeableEdit:
        notifier.setAvailableSteps([]);
        break;
      case ExchangeMode.view:
        notifier.setAvailableSteps([]);
        break;
    }
    
    // 공통 초기화
    notifier.setSelectedStep(null);
    notifier.setSelectedDay(null);
    
    // 헤더 테마 업데이트 (모든 모드 변경 시 필수)
    _updateHeaderTheme();
  }

  /// 셀을 교체불가로 설정 또는 해제 (ViewModel 사용)
  void _setCellAsNonExchangeable(DataGridCellTapDetails details) {
    final viewModel = ref.read(exchangeScreenViewModelProvider);
    viewModel.setCellAsNonExchangeable(details, _timetableData, _dataSource);

    // DataGrid 강제 업데이트 (캐시 무효화 및 재렌더링)
    _dataSource?.notifyDataChanged();
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

    // DataGrid 강제 업데이트 (캐시 무효화 및 재렌더링)
    _dataSource?.notifyDataChanged();
  }

  // ===== Manager 위임 메서드 (Mixin 대체) =====

  /// Excel 파일 선택 (OperationManager 위임)
  Future<void> selectExcelFile() => _operationManager.selectExcelFile();

  /// 엑셀 파일 선택 해제 (OperationManager 위임)
  void clearSelectedFile() => _operationManager.clearSelectedFile();

  /// 교체불가 관리자 접근 (OperationManager 위임)
  NonExchangeableManager get nonExchangeableManager => _operationManager.nonExchangeableManager;

  /// 1:1 교체 모드 토글 (OperationManager 위임)
  void toggleExchangeMode() => _operationManager.toggleExchangeMode();

  /// 순환교체 모드 토글 (OperationManager 위임)
  void toggleCircularExchangeMode() => _operationManager.toggleCircularExchangeMode();

  /// 연쇄교체 모드 토글 (OperationManager 위임)
  void toggleChainExchangeMode() => _operationManager.toggleChainExchangeMode();



  // PathSelectionHandlerMixin 인터페이스 구현
  @override
  PathSelectionManager get pathSelectionManager => _pathSelectionManager;
  @override
  void Function(OneToOneExchangePath?) get setSelectedOneToOnePath => _stateProxy.setSelectedOneToOnePath;
  @override
  void Function(ChainExchangePath?) get setSelectedChainPath => _stateProxy.setSelectedChainPath;

  // FilterSearchHandler 인터페이스 구현
  @override
  FilterStateManager get filterStateManager => _filterStateManager;
  @override
  TextEditingController get searchController => _searchController;
  @override
  String get searchQuery => _stateProxy.searchQuery;
  @override
  void Function(String) get setSearchQuery => _stateProxy.setSearchQuery;
  @override
  void Function(int?) get setSelectedStep => _stateProxy.setSelectedStep;
  @override
  void Function(String?) get setSelectedDay => _stateProxy.setSelectedDay;
  @override
  void Function(List<int>) get setAvailableSteps => _stateProxy.setAvailableSteps;

  // SidebarBuilder 인터페이스 구현
  @override
  List<OneToOneExchangePath> get oneToOnePaths => _stateProxy.oneToOnePaths;
  @override
  OneToOneExchangePath? get selectedOneToOnePath => _stateProxy.selectedOneToOnePath;
  @override
  List<CircularExchangePath> get circularPaths => _stateProxy.circularPaths;
  @override
  List<ChainExchangePath> get chainPaths => _stateProxy.chainPaths;
  @override
  List<int> get availableSteps => _stateProxy.availableSteps;
  @override
  int? get selectedStep => _stateProxy.selectedStep;
  @override
  String? get selectedDay => _stateProxy.selectedDay;
  @override
  List<ExchangePath> get filteredPaths {
    // FilterStateManager를 사용하여 모든 필터 적용
    return _filterStateManager.applyFilters(_stateProxy.currentPaths);
  }
  @override
  double get sidebarWidth => 180.0;
  @override
  bool get isCircularPathsLoading => _stateProxy.isCircularPathsLoading;
  @override
  bool get isChainPathsLoading => _stateProxy.isChainPathsLoading;
  @override
  double get loadingProgress => _stateProxy.loadingProgress;
  @override
  void Function() get toggleSidebar => _toggleSidebar;
  @override
  String Function(ExchangeNode) get getSubjectName => _getSubjectName;
  @override
  void Function(String, String, int) get scrollToCellCenter => _scrollToCellCenter;

  // StateResetHandler Mixin 제거 완료
  // 모든 초기화는 StateResetProvider를 통해 처리됨

  @override
  void initState() {
    super.initState();

    // StateProxy 초기화
    _stateProxy = ExchangeScreenStateProxy(ref);

    // Manager 초기화 (Composition 패턴)
    _operationManager = ExchangeOperationManager(
      context: context,
      stateProxy: _stateProxy,
      onCreateSyncfusionGridData: _createSyncfusionGridData,
      onClearAllExchangeStates: () => ref.read(stateResetProvider.notifier).resetExchangeStates(
        reason: '모드 전환 - 이전 교체 상태 초기화',
      ),
      onRestoreUIToDefault: () => ref.read(stateResetProvider.notifier).resetAllStates(
        reason: 'UI 기본값 복원 - 전체 상태 초기화',
      ),
      onRefreshHeaderTheme: _updateHeaderTheme,
    );

    // PathManager는 Helper가 직접 Service를 사용하므로 현재 미사용
    // _pathManager = ExchangePathManager(
    //   stateProxy: _stateProxy,
    //   exchangeService: ref.read(exchangeServiceProvider),
    //   circularExchangeService: ref.read(circularExchangeServiceProvider),
    //   chainExchangeService: ref.read(chainExchangeServiceProvider),
    //   onUpdateFilteredPaths: _updateFilteredPaths,
    //   onUpdateProgressSmoothly: _updateProgressSmoothly,
    // );

    // PathSelectionManager 콜백 설정
    _pathSelectionManager.setCallbacks(
      onOneToOnePathChanged: handleOneToOnePathChanged,
      onCircularPathChanged: handleCircularPathChanged,
      onChainPathChanged: handleChainPathChanged,
    );
    
    // 교체 관리 화면 진입 시 보기 모드로 자동 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(exchangeScreenProvider.notifier);
      final currentMode = ref.read(exchangeScreenProvider).currentMode;
      
      // 현재 모드가 보기 모드가 아닌 경우에만 보기 모드로 설정
      if (currentMode != ExchangeMode.view) {
        AppLogger.exchangeDebug('🔄 교체관리 화면 진입: ${currentMode.displayName} → 보기 모드로 자동 전환');
        notifier.setCurrentMode(ExchangeMode.view);

        // 보기 모드 상태 초기화 (Level 3)
        ref.read(stateResetProvider.notifier).resetAllStates(
          reason: '교체관리 화면 진입 시 보기 모드로 전환',
        );
      } else {
        AppLogger.exchangeDebug('✅ 교체관리 화면 진입: 이미 보기 모드 상태');
      }
      
      // timetableData 상태 확인
      final timetableData = ref.read(exchangeScreenProvider).timetableData;
      AppLogger.exchangeDebug('📊 timetableData 상태: ${timetableData != null ? "데이터 있음" : "데이터 없음"}');
    });

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
      screenState.dataSource?.setNonExchangeableEditMode(screenState.currentMode == ExchangeMode.nonExchangeableEdit);
      
      // 글로벌 시간표 데이터가 있고 로컬 그리드가 생성되지 않았거나 데이터가 변경된 경우 그리드 생성
      if (screenState.timetableData != null && 
          (screenState.dataSource == null || screenState.columns.isEmpty || 
           (screenState.dataSource != null && screenState.dataSource!.timeSlots != screenState.timetableData!.timeSlots))) {
        _createSyncfusionGridData();
      }
    });

    // 로컬 변수로 캐싱 (build 메서드 내에서 사용)
    final isSidebarVisible = screenState.isSidebarVisible;
    final isExchangeModeEnabled = screenState.currentMode == ExchangeMode.oneToOneExchange;
    final isCircularExchangeModeEnabled = screenState.currentMode == ExchangeMode.circularExchange;
    final isChainExchangeModeEnabled = screenState.currentMode == ExchangeMode.chainExchange;
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
              timetableData: screenState.timetableData, // 글로벌 Provider의 데이터 직접 사용
              dataSource: screenState.dataSource, // Provider의 dataSource 사용
              columns: screenState.columns, // Provider의 columns 사용
              stackedHeaders: screenState.stackedHeaders, // Provider의 stackedHeaders 사용
              timetableGridKey: _timetableGridKey,
              onModeChanged: _changeMode,
              onCellTap: _onCellTap,
              getActualExchangeableCount: getActualExchangeableCount,
              getCurrentSelectedPath: getCurrentSelectedPath,
              buildErrorMessageSection: buildErrorMessageSection,
              onClearError: _clearError,
              onHeaderThemeUpdate: _updateHeaderTheme, // 헤더 테마 업데이트 콜백 전달
              onRestoreUIToDefault: () => ref.read(stateResetProvider.notifier).resetAllStates(
                reason: 'TimetableTabContent에서 UI 복원',
              ),
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
    // 글로벌 Provider에서 시간표 데이터 확인 (HomeScreen에서 설정한 데이터)
    final globalTimetableData = ref.read(exchangeScreenProvider).timetableData;
    
    if (globalTimetableData == null) {
      return;
    }
    
    // ExchangeService를 사용하여 교체 가능한 교사 정보 수집 (현재 선택된 교사가 있는 경우에만)
    List<Map<String, dynamic>> exchangeableTeachers = [];
    if (exchangeService.hasSelectedCell()) {
      // 현재 교체 가능한 교사 정보를 가져옴
      exchangeableTeachers = exchangeService.getCurrentExchangeableTeachers(
        globalTimetableData.timeSlots,
        globalTimetableData.teachers,
      );
    }
    
    // 선택된 요일과 교시 결정 (1:1 교체, 순환교체, 연쇄교체 모드, 또는 모든 모드에서 교체 리스트 셀 선택에 따라)
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
    } else {
      // 모든 모드에서 교체 리스트 셀 선택 시 헤더 색상 변경 (보기 모드뿐만 아니라 다른 모드에서도)
      // TimetableDataSource에서 선택된 경로 확인 (TimetableGridSection에서 설정한 경로)
      final dataSourceCircularPath = _dataSource?.getSelectedCircularPath();
      final dataSourceOneToOnePath = _dataSource?.getSelectedOneToOnePath();
      final dataSourceChainPath = _dataSource?.getSelectedChainPath();
      
      if (dataSourceCircularPath != null && dataSourceCircularPath.nodes.isNotEmpty) {
        selectedDay = dataSourceCircularPath.nodes.first.day;
        selectedPeriod = dataSourceCircularPath.nodes.first.period;
      } else if (dataSourceOneToOnePath != null && dataSourceOneToOnePath.nodes.isNotEmpty) {
        selectedDay = dataSourceOneToOnePath.nodes.first.day;
        selectedPeriod = dataSourceOneToOnePath.nodes.first.period;
      } else if (dataSourceChainPath != null && dataSourceChainPath.nodes.isNotEmpty) {
        selectedDay = dataSourceChainPath.nodes.first.day;
        selectedPeriod = dataSourceChainPath.nodes.first.period;
      }
    }
    
    // SyncfusionTimetableHelper를 사용하여 데이터 생성 (테마 기반)
    final result = SyncfusionTimetableHelper.convertToSyncfusionData(
      globalTimetableData.timeSlots,
      globalTimetableData.teachers,
      selectedDay: selectedDay,      // 선택된 요일 전달
      selectedPeriod: selectedPeriod, // 선택된 교시 전달
      targetDay: _dataSource?.targetDay,      // 타겟 셀 요일 (보기 모드용)
      targetPeriod: _dataSource?.targetPeriod, // 타겟 셀 교시 (보기 모드용)
      exchangeableTeachers: exchangeableTeachers, // 교체 가능한 교사 정보 전달
      selectedCircularPath: _selectedCircularPath, // 선택된 순환교체 경로 전달
      selectedOneToOnePath: _selectedOneToOnePath, // 선택된 1:1 교체 경로 전달
    );
    
    // Provider를 통해 그리드 데이터 업데이트
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setColumns(result.columns);
    notifier.setStackedHeaders(result.stackedHeaders);
    
    // 데이터 소스 생성 및 Provider에 설정
    final dataSource = TimetableDataSource(
      timeSlots: globalTimetableData.timeSlots,
      teachers: globalTimetableData.teachers,
      ref: ref, // WidgetRef 추가
    );
    
    // 데이터 변경 시 UI 업데이트 콜백 설정
    dataSource.setOnDataChanged(() {
      // notifyListeners()가 자동으로 호출되므로 별도의 setState() 불필요
    });
    
    // 교체불가 편집 모드 상태를 TimetableDataSource에 전달
    dataSource.setNonExchangeableEditMode(ref.read(exchangeScreenProvider).currentMode == ExchangeMode.nonExchangeableEdit);
    
    // Provider에 데이터 소스 설정
    notifier.setDataSource(dataSource);
  }
  
  /// 셀 탭 이벤트 핸들러 - 교체 모드가 활성화된 경우만 동작
  void _onCellTap(DataGridCellTapDetails details) {
    // 교사명 열 클릭 처리 (교체불가 편집 모드에서만 동작)
    if (details.column.columnName == 'teacher' && ref.read(exchangeScreenProvider).currentMode == ExchangeMode.nonExchangeableEdit) {
      _toggleTeacherAllTimes(details);
      return;
    }
    
    // 교체불가 편집 모드인 경우 셀을 교체불가로 설정
    if (ref.read(exchangeScreenProvider).currentMode == ExchangeMode.nonExchangeableEdit) {
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
    // 빈 셀 선택 시 이전 교체 관련 상태만 초기화 (Level 2)
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '빈 셀 선택',
    );

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
    if (_stateProxy.currentMode != ExchangeMode.circularExchange) {
      _stateProxy.setCurrentMode(ExchangeMode.circularExchange);
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
    // 순환교체 이전 상태만 초기화 (현재 선택된 셀은 유지) - Level 2
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '순환교체 이전 상태 초기화',
    );

    // 필터 초기화
    resetFilters();

    // 시간표 그리드 테마 업데이트 (이전 경로 표시 제거)
    _updateHeaderTheme();
  }

  @override
  void clearPreviousChainExchangeState() {
    // 연쇄교체 이전 상태만 초기화 (현재 선택된 셀은 유지) - Level 2
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '연쇄교체 이전 상태 초기화',
    );

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
    // 새로운 셀 선택시 이전 교체 관련 상태만 초기화 (현재 선택된 셀은 유지) - Level 2
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '새로운 셀 선택',
    );

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
      timeSlots: timetableData!.timeSlots, // 시간표 데이터 추가
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


  /// 선택 해제 메서드 (현재 미사용, 향후 필요시 사용)
  // ignore: unused_element
  void _clearSelection() {
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setSelectedFile(null);
    notifier.setTimetableData(null);
    notifier.setDataSource(null);
    notifier.setColumns([]);
    notifier.setStackedHeaders([]);
    notifier.setErrorMessage(null);

    // 모든 교체 서비스의 선택 상태 초기화
    exchangeService.clearAllSelections();
    circularExchangeService.clearAllSelections();
    chainExchangeService.clearAllSelections();

    // 모든 교체 모드도 함께 종료
    notifier.setCurrentMode(ExchangeMode.view);

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
  
  /// 모든 셀 선택 상태 강제 해제 (모드 전환 시 사용)
  void _clearAllCellSelections() {
    // 모든 교체 서비스의 선택 상태 초기화
    exchangeService.clearAllSelections();
    circularExchangeService.clearAllSelections();
    chainExchangeService.clearAllSelections();
    
    // TimetableDataSource의 모든 선택 상태 해제
    _dataSource?.clearAllSelections();
    
    // 타겟 셀 초기화
    clearTargetCell();

    // Provider 상태 초기화
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setSelectedCircularPath(null);
    notifier.setSelectedOneToOnePath(null);
    notifier.setSelectedChainPath(null);

    // TimetableGridSection의 화살표 상태 초기화
    // 타겟 셀이 초기화되면 화살표도 함께 숨겨야 함
    final timetableGridState = _timetableGridKey.currentState;
    if (timetableGridState != null) {
      try {
        // Level 2 초기화: 경로 선택 해제 + 캐시 초기화
        (timetableGridState as dynamic).clearAllArrowStates();
      } catch (e) {
        // 메서드가 존재하지 않는 경우 또는 타입 오류 발생 시 안전하게 처리
        AppLogger.error('clearAllArrowStates 메서드 호출 실패: $e');
        // 사용자에게 알림 (선택사항)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('화살표 상태 초기화 중 오류가 발생했습니다.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    // UI 업데이트는 notifyListeners()로 처리됨
  }
  
  
  
  /// 선택된 교시 정보를 안전하게 가져오는 메서드
  ({String? day, int? period}) _getSelectedPeriodInfo() {
    final screenState = ref.read(exchangeScreenProvider);
    
    // 1:1 교체 모드
    if (_isExchangeModeEnabled && exchangeService.hasSelectedCell()) {
      return (day: exchangeService.selectedDay, period: exchangeService.selectedPeriod);
    }
    
    // 순환교체 모드
    if (_isCircularExchangeModeEnabled && circularExchangeService.hasSelectedCell()) {
      return (day: circularExchangeService.selectedDay, period: circularExchangeService.selectedPeriod);
    }
    
    // 연쇄교체 모드
    if (_isChainExchangeModeEnabled && chainExchangeService.hasSelectedCell()) {
      return (day: chainExchangeService.nodeADay, period: chainExchangeService.nodeAPeriod);
    }
    
    // 경로 선택 시 (모든 모드에서 교체 리스트 셀 선택)
    try {
      final dataSourceCircularPath = screenState.dataSource?.getSelectedCircularPath();
      if (dataSourceCircularPath != null && dataSourceCircularPath.nodes.isNotEmpty) {
        return (day: dataSourceCircularPath.nodes.first.day, period: dataSourceCircularPath.nodes.first.period);
      }
      
      final dataSourceOneToOnePath = screenState.dataSource?.getSelectedOneToOnePath();
      if (dataSourceOneToOnePath != null && dataSourceOneToOnePath.nodes.isNotEmpty) {
        return (day: dataSourceOneToOnePath.nodes.first.day, period: dataSourceOneToOnePath.nodes.first.period);
      }
      
      final dataSourceChainPath = screenState.dataSource?.getSelectedChainPath();
      if (dataSourceChainPath != null && dataSourceChainPath.nodes.isNotEmpty) {
        return (day: dataSourceChainPath.nodes.first.day, period: dataSourceChainPath.nodes.first.period);
      }
    } catch (e) {
      // 경로 정보 접근 중 오류 발생 시 안전하게 처리
      AppLogger.error('경로 정보 접근 중 오류: $e');
    }
    
    // 선택된 교시가 없는 경우
    return (day: null, period: null);
  }

  /// 테마 기반 헤더 업데이트 (선택된 교시 헤더를 연한 파란색으로 표시)
  void _updateHeaderTheme() {
    final screenState = ref.read(exchangeScreenProvider);
    if (screenState.timetableData == null) return;
    
    // 선택된 요일과 교시 결정 (단순화된 로직)
    final selectionInfo = _getSelectedPeriodInfo();
    final String? selectedDay = selectionInfo.day;
    final int? selectedPeriod = selectionInfo.period;
    
    // FixedHeaderStyleManager의 셀 선택 전용 업데이트 사용 (성능 최적화)
    FixedHeaderStyleManager.updateHeaderForCellSelection(
      selectedDay: selectedDay,
      selectedPeriod: selectedPeriod,
    );
    
    // ExchangeService를 사용하여 교체 가능한 교사 정보 수집
    List<Map<String, dynamic>> exchangeableTeachers = exchangeService.getCurrentExchangeableTeachers(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
    );
    
    // 선택된 교시 정보를 전달하여 헤더만 업데이트
    final result = SyncfusionTimetableHelper.convertToSyncfusionData(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
      selectedDay: selectedDay,      // 테마에서 사용할 선택 정보
      selectedPeriod: selectedPeriod,
      targetDay: _dataSource?.targetDay,      // 타겟 셀 요일 (보기 모드용)
      targetPeriod: _dataSource?.targetPeriod, // 타겟 셀 교시 (보기 모드용)
      exchangeableTeachers: exchangeableTeachers, // 교체 가능한 교사 정보 전달
      // 보기 모드에서도 경로 정보 전달 (헤더 스타일 적용을 위해)
      selectedCircularPath: _selectedCircularPath, // 순환교체 경로
      selectedOneToOnePath: _selectedOneToOnePath, // 1:1 교체 경로
      selectedChainPath: _selectedChainPath, // 연쇄교체 경로
    );
    
    // Provider를 통해 헤더 강제 재생성을 위한 완전한 새로고침
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setColumns(result.columns); // 헤더만 업데이트
    notifier.setStackedHeaders(result.stackedHeaders); // 스택 헤더도 함께 업데이트 (요일 행 포함)

    // TimetableDataSource의 notifyListeners를 통한 직접 UI 업데이트
    screenState.dataSource?.notifyListeners();
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
    if (_timetableData == null) return '과목명 없음';
    
    // 시간표 데이터에서 해당 교사, 요일, 교시의 과목 정보 찾기
    for (var timeSlot in _timetableData!.timeSlots) {
      if (timeSlot.teacher == node.teacherName &&
          timeSlot.dayOfWeek == DayUtils.getDayNumber(node.day) &&
          timeSlot.period == node.period) {
        return timeSlot.subject ?? '과목명 없음';
      }
    }
    
    return '과목명 없음';
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


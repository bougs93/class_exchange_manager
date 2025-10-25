import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/excel_service.dart';
import '../../services/exchange_service.dart';
import '../../services/circular_exchange_service.dart';
import '../../services/chain_exchange_service.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/services_provider.dart';
import '../../providers/cell_selection_provider.dart';
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
import '../../models/supplement_exchange_path.dart';
import '../../utils/exchange_path_converter.dart';
import '../../utils/exchange_path_utils.dart';
import '../../models/time_slot.dart';

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
import '../widgets/timetable_grid/exchange_executor.dart';

// 새로 분리된 위젯, ViewModel, Managers
import 'exchange_screen/widgets/exchange_app_bar.dart';
import 'exchange_screen/widgets/timetable_tab_content.dart';
import 'exchange_screen/exchange_screen_viewmodel.dart';
import 'exchange_screen/exchange_screen_state_proxy.dart';
import 'exchange_screen/managers/exchange_operation_manager.dart';

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
  
  // 마지막 처리된 fileLoadId 추적 (무한 루프 방지)
  int _lastProcessedFileLoadId = 0;

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

  // 편의 getter들 (mixin getter와 중복되지 않는 것만 유지)
  TimetableData? get _timetableData => timetableData;
  bool get _isExchangeModeEnabled => isExchangeModeEnabled;
  bool get _isCircularExchangeModeEnabled => isCircularExchangeModeEnabled;
  bool get _isChainExchangeModeEnabled => isChainExchangeModeEnabled;
  bool get _isSupplementExchangeModeEnabled => _stateProxy.isSupplementExchangeModeEnabled;
  CircularExchangePath? get _selectedCircularPath => selectedCircularPath;
  double get _loadingProgress => _stateProxy.loadingProgress;
  ChainExchangePath? get _selectedChainPath => selectedChainPath;
  OneToOneExchangePath? get _selectedOneToOnePath => selectedOneToOnePath;
  bool get _isSidebarVisible => _stateProxy.isSidebarVisible;

  /// 교체 모드 변경 (TabBar에서 호출)
  void _changeMode(ExchangeMode newMode) {
    final notifier = ref.read(exchangeScreenProvider.notifier);

    // 모드 전환 전 선택된 셀 정보 저장
    final cellState = ref.read(cellSelectionProvider);
    final savedTeacher = cellState.selectedTeacher;
    final savedDay = cellState.selectedDay;
    final savedPeriod = cellState.selectedPeriod;

    AppLogger.exchangeDebug(
      '[모드 전환] 셀 정보 저장: $savedTeacher $savedDay$savedPeriod'
    );

    // 즉시 모드 변경 (UI 반응성 향상)
    notifier.setCurrentMode(newMode);

    // 무거운 작업들은 비동기로 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _performModeChangeTasks(
          newMode,
          savedTeacher: savedTeacher,
          savedDay: savedDay,
          savedPeriod: savedPeriod,
        );
      }
    });
  }

  /// 모드 변경 시 무거운 작업들을 비동기로 처리
  void _performModeChangeTasks(
    ExchangeMode newMode, {
    String? savedTeacher,
    String? savedDay,
    int? savedPeriod,
  }) {
    final notifier = ref.read(exchangeScreenProvider.notifier);

    // 모든 모드 전환 시 셀 선택 초기화 (단순화)
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
        notifier.setAvailableSteps([2, 3, 4, 5]);
        break;
      case ExchangeMode.chainExchange:
        // 연쇄교체: 단계 필터 불필요 - 빈 배열로 설정하고 단계 필터 강제 초기화
        notifier.setAvailableSteps([]);
        notifier.setSelectedStep(null); // 단계 필터 강제 초기화
        // FilterStateManager에서도 강제 초기화
        _filterStateManager.setStepFilter(null);
        break;
      case ExchangeMode.supplementExchange:
        // 보강교체 모드 활성화 (토글이 아닌 강제 활성화)
        _operationManager.activateSupplementExchangeMode();
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

    // [중요] 헤더 테마 업데이트 (모든 모드 변경 시 필수)
    _updateHeaderTheme();

    // 저장된 셀 정보가 있고, 교체 모드인 경우 셀 복원 및 자동 선택
    if (savedTeacher != null && savedDay != null && savedPeriod != null) {
      _restoreAndSelectCell(newMode, savedTeacher, savedDay, savedPeriod);
    }
  }

  /// 저장된 셀을 복원하고 자동으로 선택 동작 수행
  void _restoreAndSelectCell(
    ExchangeMode mode,
    String teacher,
    String day,
    int period,
  ) {
    // 교체 모드가 아니면 복원하지 않음
    if (!mode.isExchangeMode &&
        mode != ExchangeMode.circularExchange &&
        mode != ExchangeMode.chainExchange &&
        mode != ExchangeMode.supplementExchange) {
      AppLogger.exchangeDebug('[모드 전환] 비교체 모드 - 셀 복원 건너뜀');
      return;
    }

    AppLogger.exchangeDebug(
      '[모드 전환] 셀 복원 시도: $teacher $day$period'
    );

    // DataSource가 없으면 복원 불가
    if (_dataSource == null) {
      AppLogger.exchangeDebug('[모드 전환] DataSource 없음 - 셀 복원 실패');
      return;
    }

    // 다음 프레임에서 셀 선택 처리 (초기화 완료 후)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        // 해당 셀에 대한 모의 탭 이벤트 생성
        _simulateCellTap(teacher, day, period);

        AppLogger.exchangeDebug(
          '[모드 전환] 셀 복원 완료: $teacher $day$period'
        );
      } catch (e) {
        AppLogger.exchangeDebug('[모드 전환] 셀 복원 중 오류: $e');
      }
    });
  }

  /// 셀 탭 시뮬레이션 (모드에 맞는 동작 수행)
  void _simulateCellTap(String teacher, String day, int period) {
    // 셀이 비어있는지 확인
    final hasClass = _isCellNotEmpty(teacher, day, period);

    if (!hasClass) {
      // 빈 셀인 경우
      AppLogger.exchangeDebug('[셀 복원] 빈 셀 처리: $teacher $day$period');
      _processEmptyCellSelection(teacher, day, period);
      return;
    }

    // 수업이 있는 셀인 경우 모드에 맞는 처리
    final currentMode = ref.read(exchangeScreenProvider).currentMode;

    switch (currentMode) {
      case ExchangeMode.oneToOneExchange:
        // 1:1 교체 시작
        exchangeService.selectCell(teacher, day, period);
        ref.read(cellSelectionProvider.notifier).selectCell(teacher, day, period);
        ref.read(cellSelectionProvider.notifier).setExchangeMode(ExchangeMode.oneToOneExchange);
        // 경로 탐색
        updateExchangeableTimes();
        _updateHeaderTheme();
        break;

      case ExchangeMode.circularExchange:
        // 순환 교체 시작
        circularExchangeService.selectCell(teacher, day, period);
        ref.read(cellSelectionProvider.notifier).selectCell(teacher, day, period);
        ref.read(cellSelectionProvider.notifier).setExchangeMode(ExchangeMode.circularExchange);
        // 경로 탐색 (비동기)
        findCircularPathsWithProgress();
        _updateHeaderTheme();
        break;

      case ExchangeMode.chainExchange:
        // 연쇄 교체 시작
        chainExchangeService.selectCell(teacher, day, period);
        ref.read(cellSelectionProvider.notifier).selectCell(teacher, day, period);
        ref.read(cellSelectionProvider.notifier).setExchangeMode(ExchangeMode.chainExchange);
        // 경로 탐색 (비동기)
        findChainPathsWithProgress();
        _updateHeaderTheme();
        break;

      case ExchangeMode.supplementExchange:
        // 보강 교체 시작
        exchangeService.selectCell(teacher, day, period);
        ref.read(cellSelectionProvider.notifier).selectCell(teacher, day, period);
        ref.read(cellSelectionProvider.notifier).selectTeacherName(teacher);
        ref.read(cellSelectionProvider.notifier).setExchangeMode(ExchangeMode.supplementExchange);
        // 보강 교체는 별도 경로 탐색 없음 (전체 빈 시간 표시)
        _updateHeaderTheme();
        break;

      default:
        AppLogger.exchangeDebug('[셀 복원] 지원하지 않는 모드: $currentMode');
    }
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

  /// 요일과 교시 정보 추출 (ViewModel 위임)
  DayPeriodInfo? _extractDayPeriodFromColumnName(DataGridCellTapDetails details) {
    final viewModel = ref.read(exchangeScreenViewModelProvider);
    return viewModel.extractDayPeriodFromColumnName(details);
  }

  /// 보강교체 셀 선택 후 처리 로직 (다른 교체 모드들과 동일)
  void _processSupplementCellSelection() {
    // 데이터 소스에 선택 상태만 업데이트 (재렌더링 방지)
    _dataSource?.updateSelection(
      exchangeService.selectedTeacher, 
      exchangeService.selectedDay, 
      exchangeService.selectedPeriod
    );
    
    // 보강교체 모드에서는 교체 가능한 시간 탐색하지 않음
    // _updateExchangeableTimes(); // 제거됨
    
    // 테마 기반 헤더 업데이트 (컬럼/헤더 재생성 없이)
    _updateHeaderTheme();
    
    // 사이드바 표시 (선택된 셀 정보가 자동으로 표시됨)
    ref.read(exchangeScreenProvider.notifier).setSidebarVisible(true);
    
    // 교사 이름 선택 기능 활성화 (보강받을 교사 선택을 위해)
    ref.read(exchangeScreenProvider.notifier).enableTeacherNameSelection();
    
    AppLogger.exchangeDebug('보강교체: 셀 선택 후 처리 완료 - 사이드바 활성화 및 교사 이름 선택 기능 활성화');
  }

  /// 공통 빈셀 확인 메서드 (모든 교체 모드에서 사용)
  /// 
  /// [teacherName] 교사 이름
  /// [day] 요일 (월, 화, 수, 목, 금)
  /// [period] 교시 (1-7)
  /// 
  /// Returns: `bool` - 수업이 있으면 true, 없으면 false
  bool _isCellNotEmpty(String teacherName, String day, int period) {
    if (_timetableData == null) return false;
    
    try {
      final dayNumber = DayUtils.getDayNumber(day);
      final timeSlot = _timetableData!.timeSlots.firstWhere(
        (slot) => slot.teacher == teacherName && 
                  slot.dayOfWeek == dayNumber && 
                  slot.period == period,
        orElse: () => TimeSlot(), // 빈 TimeSlot 반환
      );
      
      bool hasClass = timeSlot.isNotEmpty;
      AppLogger.exchangeDebug('셀 확인: $teacherName $day$period교시, 수업있음=$hasClass');
      
      return hasClass;
    } catch (e) {
      AppLogger.exchangeDebug('셀 확인 중 오류: $e');
      return false;
    }
  }


  /// Excel 파일 선택 (OperationManager 위임)
  Future<bool> selectExcelFile() => _operationManager.selectExcelFile();

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
  @override
  void Function(SupplementExchangePath?) get setSelectedSupplementPath => _stateProxy.setSelectedSupplementPath;

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
  List<OneToOneExchangePath> get oneToOnePaths => ExchangePathUtils.getOneToOnePaths(_stateProxy.availablePaths);
  @override
  OneToOneExchangePath? get selectedOneToOnePath => _stateProxy.selectedOneToOnePath;
  @override
  List<CircularExchangePath> get circularPaths => ExchangePathUtils.getCircularPaths(_stateProxy.availablePaths);
  @override
  List<ChainExchangePath> get chainPaths => ExchangePathUtils.getChainPaths(_stateProxy.availablePaths);
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
  bool get isCircularPathsLoading => _stateProxy.isPathsLoading;
  @override
  bool get isChainPathsLoading => _stateProxy.isPathsLoading;
  @override
  double get loadingProgress => _stateProxy.loadingProgress;
  @override
  void Function() get toggleSidebar => _toggleSidebar;
  @override
  String Function(ExchangeNode) get getSubjectName => _getSubjectName;
  
  // 보강교체 모드 관련 getter 추가
  @override
  bool get isSupplementExchangeModeEnabled => _isSupplementExchangeModeEnabled;

  // 보강교체 교사 버튼 클릭 콜백 구현
  @override
  void Function(String, String, int)? get onSupplementTeacherTap => _onSupplementTeacherTap;

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
      ref: ref,
      stateProxy: _stateProxy,
      onCreateSyncfusionGridData: _createSyncfusionGridData,
      onClearAllExchangeStates: () => ref.read(stateResetProvider.notifier).resetExchangeStates(
        reason: '모드 전환 - 이전 교체 상태 초기화',
      ),
      onRefreshHeaderTheme: _updateHeaderTheme,
    );

    // PathSelectionManager 콜백 설정
    _pathSelectionManager.setCallbacks(
      onOneToOnePathChanged: (path) => handleOneToOnePathChanged(path as OneToOneExchangePath?),
      onCircularPathChanged: (path) => handleCircularPathChanged(path as CircularExchangePath?),
      onChainPathChanged: (path) => handleChainPathChanged(path as ChainExchangePath?),
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
    // 컨트롤러 정리
    _searchController.dispose();
    _progressAnimationController?.dispose();
    
    // 상태 관리자 정리 (필요한 경우)
    // _pathSelectionManager와 _filterStateManager는 일반적으로 자동 정리됨
    
    // 마지막 처리된 fileLoadId 초기화
    _lastProcessedFileLoadId = 0;
    
    AppLogger.exchangeDebug('🧹 [ExchangeScreen] 메모리 정리 완료');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provider에서 상태 읽기
    final screenState = ref.watch(exchangeScreenProvider);
    
    // 교체불가 편집 모드 상태가 변경될 때마다 TimetableDataSource에 전달
    WidgetsBinding.instance.addPostFrameCallback((_) {
      screenState.dataSource?.setNonExchangeableEditMode(screenState.currentMode == ExchangeMode.nonExchangeableEdit);
      
      // 새로운 파일이 로드되었을 때만 그리드 생성 (무한 루프 방지)
      if (screenState.timetableData != null && 
          screenState.fileLoadId != _lastProcessedFileLoadId) {
        AppLogger.exchangeDebug('🔄 [ExchangeScreen] 새로운 파일 로드 감지 (fileLoadId: ${screenState.fileLoadId}) - 그리드 생성');
        _createSyncfusionGridData();
        _lastProcessedFileLoadId = screenState.fileLoadId;
      }
    });

    // 로컬 변수로 캐싱 (build 메서드 내에서 사용)
    final isSidebarVisible = screenState.isSidebarVisible;
    final isExchangeModeEnabled = screenState.currentMode == ExchangeMode.oneToOneExchange;
    final isCircularExchangeModeEnabled = screenState.currentMode == ExchangeMode.circularExchange;
    final isChainExchangeModeEnabled = screenState.currentMode == ExchangeMode.chainExchange;
    
    // 통합된 경로 접근
    final availablePaths = screenState.availablePaths;
    final isPathsLoading = screenState.isPathsLoading;

    return Scaffold(
      appBar: ExchangeAppBar(
        state: screenState,
        onToggleSidebar: _toggleSidebar,
        onUpdateHeaderTheme: _updateHeaderTheme,
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
            ),
          ),

          // 통합 교체 사이드바
          if (isSidebarVisible && (
            (isExchangeModeEnabled && ExchangePathUtils.hasPathsOfType<OneToOneExchangePath>(availablePaths)) ||
            (isCircularExchangeModeEnabled && (ExchangePathUtils.hasPathsOfType<CircularExchangePath>(availablePaths) || isPathsLoading)) ||
            (isChainExchangeModeEnabled && (ExchangePathUtils.hasPathsOfType<ChainExchangePath>(availablePaths) || isPathsLoading)) ||
            (_isSupplementExchangeModeEnabled) // 보강교체 모드에서는 항상 사이드바 표시
          ))
            buildUnifiedExchangeSidebar(),
        ],
      ),
    );
  }

  
  /// Syncfusion DataGrid 컬럼 및 헤더 생성
  void _createSyncfusionGridData() {
    AppLogger.exchangeDebug('🔄 [ExchangeScreen] _createSyncfusionGridData() 호출됨');
    
    // 글로벌 Provider에서 시간표 데이터 확인 (HomeScreen에서 설정한 데이터)
    final globalTimetableData = ref.read(exchangeScreenProvider).timetableData;
    
    if (globalTimetableData == null) {
      AppLogger.exchangeDebug('❌ [ExchangeScreen] globalTimetableData가 null입니다');
      return;
    }
    
    AppLogger.exchangeDebug('✅ [ExchangeScreen] globalTimetableData 확인됨: ${globalTimetableData.teachers.length}명 교사, ${globalTimetableData.timeSlots.length}개 시간표');
    
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
      selectedDay = chainExchangeService.selectedDay;
      selectedPeriod = chainExchangeService.selectedPeriod;
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
      selectedChainPath: _selectedChainPath, // 선택된 연쇄교체 경로 전달
      selectedSupplementPath: _stateProxy.selectedSupplementPath, // 선택된 보강교체 경로 전달
    );
    
    // Provider를 통해 그리드 데이터 업데이트 (변경이 필요한 경우에만 호출하여 성능 최적화)
    final notifier = ref.read(exchangeScreenProvider.notifier);
    final currentState = ref.read(exchangeScreenProvider);
    
    // 현재 상태와 비교하여 실제로 변경이 필요한 경우에만 업데이트
    if (_shouldUpdateColumns(currentState.columns, result.columns)) {
      notifier.setColumns(result.columns);
    }
    
    if (_shouldUpdateStackedHeaders(currentState.stackedHeaders, result.stackedHeaders)) {
      notifier.setStackedHeaders(result.stackedHeaders);
    }
    
    // 엑셀 파일 로드 시마다 무조건 새로운 데이터소스 생성
    AppLogger.exchangeDebug('🔄 [ExchangeScreen] 새로운 TimetableDataSource 생성');
      
      final dataSource = TimetableDataSource(
        timeSlots: globalTimetableData.timeSlots,
        teachers: globalTimetableData.teachers,
        ref: ref, // WidgetRef 추가
      );
      
      // 교체불가 편집 모드 상태를 TimetableDataSource에 전달
      dataSource.setNonExchangeableEditMode(ref.read(exchangeScreenProvider).currentMode == ExchangeMode.nonExchangeableEdit);
      
    // Provider에 데이터 소스 설정
    notifier.setDataSource(dataSource);
    AppLogger.exchangeDebug('✅ [ExchangeScreen] 새로운 TimetableDataSource 생성 및 설정 완료');
    
    AppLogger.exchangeDebug('🎉 [ExchangeScreen] _createSyncfusionGridData() 완료 - 컬럼: ${result.columns.length}개, 헤더: ${result.stackedHeaders.length}개');
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
    
    // 보강교체 모드인 경우 보강 처리 시작
    if (ref.read(exchangeScreenProvider).currentMode == ExchangeMode.supplementExchange) {
      startSupplementExchange(details);
      // 보강교체 모드에서도 셀 선택은 계속 진행해야 함
    }

    // 교체 모드가 비활성화된 경우 아무 동작하지 않음
    if (!_isExchangeModeEnabled && !_isCircularExchangeModeEnabled && !_isChainExchangeModeEnabled && !_isSupplementExchangeModeEnabled) {
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

  /// 보강교체 시작
  void startSupplementExchange(DataGridCellTapDetails details) {
    AppLogger.exchangeDebug('보강교체 시작 - 셀 클릭');
    
    // 교사명 열 클릭은 교사 이름 선택 기능으로 처리
    if (details.column.columnName == 'teacher') {
      AppLogger.exchangeDebug('보강교체: 교사명 열 클릭 - 교사 이름 선택 기능으로 처리');
      return;
    }
    
    // 셀에서 교사명 추출
    final teacherName = _getTeacherNameFromCell(details);
    if (teacherName == null) {
      AppLogger.exchangeDebug('보강교체 실패: 교사명을 추출할 수 없음');
      return;
    }
    
    // 요일과 교시 정보 추출
    final dayPeriodInfo = _extractDayPeriodFromColumnName(details);
    if (dayPeriodInfo == null) {
      AppLogger.exchangeDebug('보강교체 실패: 요일/교시 정보를 추출할 수 없음');
      return;
    }
    
    AppLogger.exchangeDebug('보강교체 셀 정보: $teacherName ${dayPeriodInfo.day}${dayPeriodInfo.period}교시');
    
    // 셀이 수업이 있는 셀인지 확인
    bool hasClass = _isCellNotEmpty(teacherName, dayPeriodInfo.day, dayPeriodInfo.period);
    AppLogger.exchangeDebug('보강교체 셀 상태: 수업 있음=$hasClass');
    
    // 빈 셀인 경우 경로 탐색하지 않음
    if (!hasClass) {
      AppLogger.exchangeDebug('보강교체: 빈 셀 클릭 - 경로 탐색 건너뜀');
      _processEmptyCellSelection(teacherName, dayPeriodInfo.day, dayPeriodInfo.period);
      return;
    }
    
    // 동일한 셀을 다시 클릭했는지 확인
    if (exchangeService.isSameCell(teacherName, dayPeriodInfo.day, dayPeriodInfo.period)) {
      // 동일한 셀 클릭 시 교체 대상 해제
      exchangeService.clearCellSelection();
      ref.read(cellSelectionProvider.notifier).clearAllSelections();
      ref.read(cellSelectionProvider.notifier).selectTeacherName(null);
      AppLogger.exchangeDebug('보강교체: 동일한 셀 클릭 - 셀 선택 해제');
      return;
    }
    
    // 새로운 셀 선택 (수업이 있는 셀만)
    AppLogger.exchangeDebug('보강교체: 수업이 있는 셀 선택 - $teacherName ${dayPeriodInfo.day}${dayPeriodInfo.period}교시');
    
    // 1. 셀 선택 (ExchangeService와 CellSelectionProvider에 저장)
    exchangeService.selectCell(teacherName, dayPeriodInfo.day, dayPeriodInfo.period);
    ref.read(cellSelectionProvider.notifier).selectCell(teacherName, dayPeriodInfo.day, dayPeriodInfo.period);
    AppLogger.exchangeDebug('보강교체: 셀 선택 완료 - $teacherName ${dayPeriodInfo.day}${dayPeriodInfo.period}교시');
    
    // 2. 교사 이름 선택 상태 설정 (교사 이름 테마 변경용)
    ref.read(cellSelectionProvider.notifier).selectTeacherName(teacherName);
    AppLogger.exchangeDebug('보강교체: 교사 이름 선택 완료 - $teacherName');
    
    // 3. 교체 모드 설정 (테마 변경용)
    ref.read(cellSelectionProvider.notifier).setExchangeMode(ExchangeMode.supplementExchange);
    AppLogger.exchangeDebug('보강교체: 교체 모드 설정 완료 - supplementExchange');
    
    // 4. 셀 선택 후 처리 (사이드바 표시 포함)
    _processSupplementCellSelection();
  }

  /// 보강교체에서 빈 셀 선택 처리 (공통 빈셀 처리 방식)
  void _processEmptyCellSelection(String teacherName, String day, int period) {
    AppLogger.exchangeDebug('보강교체: 빈 셀 선택 처리 - $teacherName $day$period교시');
    
    // 동일한 셀을 다시 클릭했는지 확인
    if (exchangeService.isSameCell(teacherName, day, period)) {
      // 동일한 셀 클릭 시 교체 대상 해제
      exchangeService.clearCellSelection();
      ref.read(cellSelectionProvider.notifier).clearAllSelections();
      ref.read(cellSelectionProvider.notifier).selectTeacherName(null);
      AppLogger.exchangeDebug('보강교체: 동일한 빈 셀 클릭 - 셀 선택 해제');
      return;
    }
    
    // 새로운 빈 셀 선택
    AppLogger.exchangeDebug('보강교체: 새로운 빈 셀 선택 - $teacherName $day$period교시');
    
    // 1. 셀 선택 (ExchangeService와 CellSelectionProvider에 저장)
    exchangeService.selectCell(teacherName, day, period);
    ref.read(cellSelectionProvider.notifier).selectCell(teacherName, day, period);
    
    // 2. 교사 이름 선택 상태 설정 (교사 이름 테마 변경용)
    ref.read(cellSelectionProvider.notifier).selectTeacherName(teacherName);
    
    // 3. 교체 모드 설정 (테마 변경용)
    ref.read(cellSelectionProvider.notifier).setExchangeMode(ExchangeMode.supplementExchange);
    
    // 4. 공통 빈 셀 선택 처리 (경로만 초기화, 셀 선택 유지)
    onEmptyCellSelected();
  }

  
  // Mixin에서 요구하는 추상 메서드들 구현
  @override
  void updateDataSource() {
    // 셀 선택이나 교체 경로 선택 시에는 전체 그리드 재생성 불필요
    // TimetableDataSource의 refreshUI() 메서드로 UI만 갱신
    final dataSource = ref.read(exchangeScreenProvider).dataSource;
    if (dataSource != null) {
      dataSource.refreshUI();
    }
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
    // 빈 셀 선택 시 경로만 초기화 (Level 1) - 선택된 셀은 유지
    ref.read(stateResetProvider.notifier).resetPathOnly(
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
    notifier.setPathsLoading(true);
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
    List<ExchangePath> newPaths = ExchangePathUtils.replacePaths(_stateProxy.availablePaths, result.paths);
    notifier.setAvailablePaths(newPaths);
    
    notifier.setSelectedCircularPath(null);
    notifier.setPathsLoading(false);
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
    // 순환교체 이전 상태만 초기화 (현재 선택된 셀은 유지) - Level 1
    ref.read(stateResetProvider.notifier).resetPathOnly(
      reason: '순환교체 이전 상태 초기화',
    );

    // 필터 초기화
    resetFilters();

    // 시간표 그리드 테마 업데이트 (이전 경로 표시 제거)
    _updateHeaderTheme();
  }

  @override
  void clearPreviousChainExchangeState() {
    // 연쇄교체 이전 상태만 초기화 (현재 선택된 셀은 유지) - Level 1
    ref.read(stateResetProvider.notifier).resetPathOnly(
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
    // 빈 셀 선택 시 경로만 초기화 (Level 1) - 선택된 셀은 유지
    ref.read(stateResetProvider.notifier).resetPathOnly(
      reason: '연쇄교체 빈 셀 선택',
    );

    // 필터 초기화
    resetFilters();

    // 시간표 그리드 테마 업데이트 (이전 경로 표시 제거)
    _updateHeaderTheme();
  }

  @override
  Future<void> findChainPathsWithProgress() async {
    if (_timetableData == null || !chainExchangeService.hasSelectedCell()) {
      AppLogger.warning('연쇄교체: 시간표 데이터 없음 또는 셀 미선택');
      return;
    }

    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setPathsLoading(true);
    notifier.setLoadingProgress(0.0);
    
    // 기존 경로들에서 연쇄교체 경로 제거
    List<ExchangePath> otherPaths = ExchangePathUtils.removePaths<ChainExchangePath>(_stateProxy.availablePaths);
    notifier.setAvailablePaths(otherPaths);
    
    notifier.setSelectedChainPath(null);
    notifier.setSidebarVisible(true);

    // 헬퍼를 사용하여 경로 탐색
    final result = await ChainPathFinder.findChainPathsWithProgress(
      chainExchangeService: chainExchangeService,
      timeSlots: _timetableData!.timeSlots,
      teachers: _timetableData!.teachers,
    );

    // 결과 적용
    List<ExchangePath> newPaths = ExchangePathUtils.replacePaths(_stateProxy.availablePaths, result.paths);
    notifier.setAvailablePaths(newPaths);
    
    notifier.setPathsLoading(false);
    notifier.setLoadingProgress(1.0);
    notifier.setSidebarVisible(result.shouldShowSidebar);

    if (result.message != null) {
      showSnackBar(result.message!);
    }
  }
  
  @override
  void processCellSelection() {
    // 새로운 셀 선택시 경로만 초기화 (Level 1) - 선택된 셀은 유지하고 그리드 재생성 방지
    ref.read(stateResetProvider.notifier).resetPathOnly(
      reason: '새로운 셀 선택 - 경로만 초기화',
    );

    // 순환교체, 1:1 교체, 연쇄교체 모드에서 필터 초기화
    if (_isCircularExchangeModeEnabled || _isExchangeModeEnabled || _isChainExchangeModeEnabled) {
      resetFilters();
    }

    // 부모 클래스의 processCellSelection 호출 (데이터 소스 재생성 없이)
    super.processCellSelection();
  }

  @override
  void generateOneToOnePaths(List<dynamic> options) {
    if (!exchangeService.hasSelectedCell() || timetableData == null) {
      final notifier = ref.read(exchangeScreenProvider.notifier);
      
      // 기존 경로들에서 1:1교체 경로 제거
      List<ExchangePath> otherPaths = ExchangePathUtils.removePaths<OneToOneExchangePath>(_stateProxy.availablePaths);
      notifier.setAvailablePaths(otherPaths);
      
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
    
    // 기존 경로들에서 1:1교체 경로 제거 후 새로운 경로들 추가
    List<ExchangePath> newPaths = ExchangePathUtils.replacePaths(_stateProxy.availablePaths, paths);
    notifier.setAvailablePaths(newPaths);
    
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
    notifier.setSelectedSupplementPath(null);

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
      return (day: chainExchangeService.selectedDay, period: chainExchangeService.selectedPeriod);
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
      
      final dataSourceSupplementPath = screenState.dataSource?.getSelectedSupplementPath();
      if (dataSourceSupplementPath != null && dataSourceSupplementPath.nodes.isNotEmpty) {
        return (day: dataSourceSupplementPath.nodes.first.day, period: dataSourceSupplementPath.nodes.first.period);
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

    // 교시 헤더 색상 변경을 위한 캐시 강제 초기화
    FixedHeaderStyleManager.clearCacheForPeriodHeaderColorChange();

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
      selectedSupplementPath: _stateProxy.selectedSupplementPath, // 보강교체 경로
    );

    // Provider를 통한 헤더 업데이트 (최적화됨 - 구조적 변경이 있는 경우에만 업데이트)
    final notifier = ref.read(exchangeScreenProvider.notifier);
    final currentState = ref.read(exchangeScreenProvider);
    
    // 구조적 변경(컬럼 수, 헤더 수)이 있는 경우에만 업데이트하여 ValueKey 변경 방지
    bool needsStructuralUpdate = _shouldUpdateColumns(currentState.columns, result.columns) ||
                                _shouldUpdateStackedHeaders(currentState.stackedHeaders, result.stackedHeaders);
    
    if (needsStructuralUpdate) {
      // 구조적 변경이 필요한 경우에만 columns/stackedHeaders 업데이트
      if (_shouldUpdateColumns(currentState.columns, result.columns)) {
        notifier.setColumns(result.columns);
      }
      
      if (_shouldUpdateStackedHeaders(currentState.stackedHeaders, result.stackedHeaders)) {
        notifier.setStackedHeaders(result.stackedHeaders);
      }
      
      AppLogger.exchangeDebug('🔄 [헤더 테마] 구조적 변경으로 인한 columns/stackedHeaders 업데이트');
    } else {
      // 구조적 변경이 없는 경우 DataSource만 업데이트하여 스타일 변경 반영
      AppLogger.exchangeDebug('🔄 [헤더 테마] 스타일 변경만 반영 - columns/stackedHeaders 재생성 없음');
    }

    // TimetableDataSource의 최적화된 UI 업데이트 (배치 업데이트 지원)
    screenState.dataSource?.notifyDataChanged();
  }


  /// 컬럼 업데이트가 필요한지 확인 (최적화됨 - 구조적 변경만 감지)
  bool _shouldUpdateColumns(List<GridColumn> currentColumns, List<GridColumn> newColumns) {
    // 길이가 다르면 구조적 변경
    if (currentColumns.length != newColumns.length) return true;
    
    // 컬럼명이나 기본 구조가 변경된 경우만 업데이트 (스타일 변경은 제외)
    for (int i = 0; i < currentColumns.length; i++) {
      if (currentColumns[i].columnName != newColumns[i].columnName) {
        return true; // 컬럼명 변경은 구조적 변경
      }
      // width 변경은 스타일 변경이므로 제외하여 불필요한 ValueKey 변경 방지
    }
    return false;
  }
  
  /// 스택 헤더 업데이트가 필요한지 확인 (최적화됨 - 구조적 변경만 감지)
  bool _shouldUpdateStackedHeaders(List<StackedHeaderRow> currentHeaders, List<StackedHeaderRow> newHeaders) {
    // 길이가 다르면 구조적 변경
    if (currentHeaders.length != newHeaders.length) return true;
    
    // 헤더 구조가 변경된 경우만 업데이트 (스타일 변경은 제외)
    for (int i = 0; i < currentHeaders.length; i++) {
      if (currentHeaders[i].cells.length != newHeaders[i].cells.length) return true;
      
      for (int j = 0; j < currentHeaders[i].cells.length; j++) {
        if (currentHeaders[i].cells[j].columnNames.length != newHeaders[i].cells[j].columnNames.length) return true;
        
        // 컬럼명 구조가 변경된 경우만 업데이트
        for (int k = 0; k < currentHeaders[i].cells[j].columnNames.length; k++) {
          if (currentHeaders[i].cells[j].columnNames[k] != newHeaders[i].cells[j].columnNames[k]) return true;
        }
      }
    }
    return false;
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


  

  /// 사이드바 토글
  void _toggleSidebar() {
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.setSidebarVisible(!_isSidebarVisible);
  }

  /// 보강교체 교사 버튼 클릭 처리 (1컬럼 교사 이름 클릭과 동일한 동작)
  void _onSupplementTeacherTap(String teacherName, String day, int period) {
    AppLogger.exchangeDebug('보강교체 교사 버튼 클릭: $teacherName ($day $period교시)');
    
    // 현재 모드 및 교사 이름 선택 기능 활성화 상태 확인
    final screenState = ref.read(exchangeScreenProvider);
    final currentMode = screenState.currentMode;
    final isSupplementExchangeMode = currentMode == ExchangeMode.supplementExchange;
    final isTeacherNameSelectionEnabled = screenState.isTeacherNameSelectionEnabled;
    
    // 보강교체 모드이고 교사 이름 선택 기능이 활성화된 경우 보강교체 실행
    if (isSupplementExchangeMode && isTeacherNameSelectionEnabled) {
      AppLogger.exchangeDebug('보강교체 모드: 교사 이름 클릭 - 보강교체 실행 - $teacherName');
      
      // 현재 선택된 셀 정보 가져오기
      if (!exchangeService.hasSelectedCell()) {
        AppLogger.exchangeDebug('보강교체 실행 실패: 선택된 셀을 먼저 선택해주세요');
        showSnackBar('보강할 셀을 먼저 선택해주세요', backgroundColor: Colors.red);
        return;
      }
      
      final selectedDay = exchangeService.selectedDay!;
      final selectedPeriod = exchangeService.selectedPeriod!;
      
      // 교사 이름 클릭 시 해당 교사의 해당 시간대가 빈 셀인지 검사
      if (_isCellNotEmpty(teacherName, selectedDay, selectedPeriod)) {
        AppLogger.exchangeDebug('보강교체 실행 실패: $teacherName의 $selectedDay$selectedPeriod교시는 수업이 있는 시간입니다');
        showSnackBar('보강할 시간에 수업이 없는 교사을 선택해주세요. $teacherName의 $selectedDay$selectedPeriod교시는 수업이 있는 시간입니다.', backgroundColor: Colors.orange);
        return;
      }
      
      // 교사 이름 선택 상태 설정
      ref.read(cellSelectionProvider.notifier).selectTeacherName(teacherName);
      
      // 보강교체 실행 (ExchangeExecutor 호출)
      _executeSupplementExchangeViaExecutor(teacherName);
      return;
    }
  }


  /// 보강교체 실행 (ExchangeExecutor 호출)
  void _executeSupplementExchangeViaExecutor(String targetTeacherName) {
    AppLogger.exchangeDebug('보강교체 실행 시작: $targetTeacherName');
    
    if (_timetableData == null) {
      AppLogger.exchangeDebug('보강교체 실행 실패: timetableData가 null입니다');
      return;
    }

    // 현재 선택된 셀 정보 가져오기
    if (!exchangeService.hasSelectedCell()) {
      AppLogger.exchangeDebug('보강교체 실행 실패: 선택된 셀을 먼저 선택해주세요');
      showSnackBar('보강할 셀을 먼저 선택해주세요', backgroundColor: Colors.red);
      return;
    }

    final sourceTeacher = exchangeService.selectedTeacher!;
    final sourceDay = exchangeService.selectedDay!;
    final sourcePeriod = exchangeService.selectedPeriod!;

    // 소스 셀의 정보 가져오기
    final sourceSlot = _timetableData!.timeSlots.firstWhere(
      (slot) => slot.teacher == sourceTeacher && 
                slot.dayOfWeek == DayUtils.getDayNumber(sourceDay) && 
                slot.period == sourcePeriod,
      orElse: () => throw StateError('소스 TimeSlot을 찾을 수 없습니다'),
    );

    // 보강 가능성 검증
    if (!sourceSlot.isNotEmpty) {
      showSnackBar('보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시에 수업이 없습니다', backgroundColor: Colors.red);
      return;
    }

    if (!sourceSlot.canExchange) {
      showSnackBar('보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시 수업은 교체 불가능합니다', backgroundColor: Colors.red);
      return;
    }

    // ExchangeExecutor에 위임 (1:1 교체와 동일한 패턴)
    final exchangeExecutor = ExchangeExecutor(
      ref: ref,
      dataSource: _dataSource,
      onEnableExchangeView: () {}, // 필요시 구현
    );
    
    exchangeExecutor.executeSupplementExchange(
      sourceTeacher,
      sourceDay,
      sourcePeriod,
      targetTeacherName,
      sourceSlot.className ?? '',
      sourceSlot.subject ?? '',
      context,
      () {
        ref.read(stateResetProvider.notifier).resetExchangeStates(
          reason: '내부 경로 초기화',
        );
      },
    );

    // 교사 이름 선택 기능 비활성화
    ref.read(exchangeScreenProvider.notifier).disableTeacherNameSelection();
    ref.read(cellSelectionProvider.notifier).selectTeacherName(null);
  }


  
}


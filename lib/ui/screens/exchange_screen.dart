import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/excel_service.dart';
import '../../services/exchange_service.dart';
import '../../services/circular_exchange_service.dart';
import '../../services/chain_exchange_service.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/exchange_node.dart';
import '../../models/time_slot.dart';
import '../../models/teacher.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/syncfusion_timetable_helper.dart';
import '../../utils/logger.dart';
import '../../utils/day_utils.dart';
import '../widgets/unified_exchange_sidebar.dart';
import '../../models/exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../utils/exchange_path_converter.dart';
import '../widgets/file_selection_section.dart';
import '../widgets/timetable_grid_section.dart';
import '../mixins/exchange_logic_mixin.dart';

/// 교체 관리 화면
class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> with ExchangeLogicMixin, TickerProviderStateMixin {
  File? _selectedFile;        // 선택된 엑셀 파일
  TimetableData? _timetableData; // 파싱된 시간표 데이터
  TimetableDataSource? _dataSource; // Syncfusion DataGrid 데이터 소스
  List<GridColumn> _columns = []; // 그리드 컬럼
  List<StackedHeaderRow> _stackedHeaders = []; // 스택된 헤더
  bool _isLoading = false;    // 로딩 상태
  String? _errorMessage;     // 오류 메시지
  
  // 교체 서비스 인스턴스들
  final ExchangeService _exchangeService = ExchangeService();
  final CircularExchangeService _circularExchangeService = CircularExchangeService();
  final ChainExchangeService _chainExchangeService = ChainExchangeService();

  // Mixin에서 요구하는 getter들
  @override
  ExchangeService get exchangeService => _exchangeService;

  @override
  CircularExchangeService get circularExchangeService => _circularExchangeService;

  @override
  ChainExchangeService get chainExchangeService => _chainExchangeService;

  @override
  TimetableData? get timetableData => _timetableData;

  @override
  TimetableDataSource? get dataSource => _dataSource;

  @override
  bool get isExchangeModeEnabled => _isExchangeModeEnabled;

  @override
  bool get isCircularExchangeModeEnabled => _isCircularExchangeModeEnabled;

  @override
  bool get isChainExchangeModeEnabled => _isChainExchangeModeEnabled;

  @override
  CircularExchangePath? get selectedCircularPath => _selectedCircularPath;

  @override
  ChainExchangePath? get selectedChainPath => _selectedChainPath;

  // 교체 모드 관련 변수들
  bool _isExchangeModeEnabled = false; // 1:1교체 모드 활성화 상태
  bool _isCircularExchangeModeEnabled = false; // 순환교체 모드 활성화 상태
  bool _isChainExchangeModeEnabled = false; // 연쇄교체 모드 활성화 상태
  
  // 시간표 그리드 제어를 위한 GlobalKey
  final GlobalKey<State<TimetableGridSection>> _timetableGridKey = GlobalKey<State<TimetableGridSection>>();
  
  // 순환교체 관련 변수들
  List<CircularExchangePath> _circularPaths = []; // 순환교체 경로들
  CircularExchangePath? _selectedCircularPath; // 선택된 순환교체 경로
  bool _isCircularPathsLoading = false; // 순환교체 경로 탐색 로딩 상태
  double _loadingProgress = 0.0; // 진행률 (0.0 ~ 1.0)

  // 연쇄교체 관련 변수들
  List<ChainExchangePath> _chainPaths = []; // 연쇄교체 경로들
  ChainExchangePath? _selectedChainPath; // 선택된 연쇄교체 경로
  bool _isChainPathsLoading = false; // 연쇄교체 경로 탐색 로딩 상태

  // 1:1교체 관련 변수들
  List<OneToOneExchangePath> _oneToOnePaths = []; // 1:1교체 경로들
  OneToOneExchangePath? _selectedOneToOnePath; // 선택된 1:1교체 경로
  
  // 통합 사이드바 관련 변수들
  bool _isSidebarVisible = false; // 사이드바 표시 여부
  final double _sidebarWidth = 180.0; // 사이드바 너비
  
  // 검색 및 필터링 관련 변수들
  final TextEditingController _searchController = TextEditingController(); // 검색 입력 컨트롤러
  String _searchQuery = ''; // 검색 쿼리
  List<ExchangePath> _filteredPaths = []; // 필터링된 경로들 (통합)
  
  // 순환교체 단계 필터 관련 변수들
  List<int> _availableSteps = []; // 사용 가능한 단계들 (예: [2, 3, 4])
  int? _selectedStep; // 선택된 단계 (null이면 모든 단계 표시)
  
  // 순환교체 요일 필터 관련 변수들
  String? _selectedDay; // 선택된 요일 (null이면 모든 요일 표시)
  
  // 진행률 애니메이션 관련 변수들
  AnimationController? _progressAnimationController;
  Animation<double>? _progressAnimation;

  @override
  void initState() {
    super.initState();
    
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
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // 시간표 영역
          Expanded(
            child: _buildTimetableTab(),
          ),
          
          // 통합 교체 사이드바 (1:1교체, 순환교체, 연쇄교체)
          if (_isSidebarVisible && (
            (_isExchangeModeEnabled && _oneToOnePaths.isNotEmpty) ||
            (_isCircularExchangeModeEnabled && (_circularPaths.isNotEmpty || _isCircularPathsLoading)) ||
            (_isChainExchangeModeEnabled && (_chainPaths.isNotEmpty || _isChainPathsLoading))
          ))
            _buildUnifiedExchangeSidebar(),
        ],
      ),
    );
  }

  /// 앱바 구성
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('교체 관리'),
      backgroundColor: Colors.blue.shade50,
      elevation: 0,
      actions: [
        // 순환교체 사이드바 토글 버튼
        if (_isCircularExchangeModeEnabled && (_circularPaths.isNotEmpty || _isCircularPathsLoading))
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _toggleSidebar,
              icon: Icon(
                _isSidebarVisible ? Icons.chevron_right : Icons.chevron_left,
                size: 16,
              ),
              label: Text(_isCircularPathsLoading ? '${(_loadingProgress * 100).round()}%' : '${_circularPaths.length}개'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.purple.shade600,
              ),
            ),
          ),
      ],
    );
  }

  /// 시간표 탭 구성
  Widget _buildTimetableTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 파일 선택 섹션
          FileSelectionSection(
            selectedFile: _selectedFile,
            isLoading: _isLoading,
            isExchangeModeEnabled: _isExchangeModeEnabled,
            isCircularExchangeModeEnabled: _isCircularExchangeModeEnabled,
            isChainExchangeModeEnabled: _isChainExchangeModeEnabled,
            onSelectExcelFile: _selectExcelFile,
            onToggleExchangeMode: _toggleExchangeMode,
            onToggleCircularExchangeMode: _toggleCircularExchangeMode,
            onToggleChainExchangeMode: _toggleChainExchangeMode,
            onClearSelection: _clearSelection,
          ),
          
          const SizedBox(height: 24),
          
          // 시간표 그리드 표시 섹션
          if (_timetableData != null) 
            Expanded(
              child: TimetableGridSection(
                key: _timetableGridKey, // 스크롤 제어를 위한 GlobalKey 추가
                timetableData: _timetableData,
                dataSource: _dataSource,
                columns: _columns,
                stackedHeaders: _stackedHeaders,
                isExchangeModeEnabled: _isExchangeModeEnabled,
                exchangeableCount: getActualExchangeableCount(),
                onCellTap: _onCellTap,
                selectedExchangePath: _getCurrentSelectedPath(), // 현재 선택된 교체 경로 전달
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),
          
          // 오류 메시지 표시
          if (_errorMessage != null) _buildErrorMessageSection(),
        ],
      ),
    );
  }

  
  /// Syncfusion DataGrid 컬럼 및 헤더 생성
  void _createSyncfusionGridData() {
    if (_timetableData == null) return;
    
    // ExchangeService를 사용하여 교체 가능한 교사 정보 수집 (현재 선택된 교사가 있는 경우에만)
    List<Map<String, dynamic>> exchangeableTeachers = [];
    if (_exchangeService.hasSelectedCell()) {
      // 현재 교체 가능한 교사 정보를 가져옴
      exchangeableTeachers = _exchangeService.getCurrentExchangeableTeachers(
        _timetableData!.timeSlots,
        _timetableData!.teachers,
      );
    }
    
    // 선택된 요일과 교시 결정 (1:1 교체 또는 순환교체 모드에 따라)
    String? selectedDay;
    int? selectedPeriod;
    
    if (_isExchangeModeEnabled && _exchangeService.hasSelectedCell()) {
      // 1:1 교체 모드
      selectedDay = _exchangeService.selectedDay;
      selectedPeriod = _exchangeService.selectedPeriod;
    } else if (_isCircularExchangeModeEnabled && _circularExchangeService.hasSelectedCell()) {
      // 순환교체 모드
      selectedDay = _circularExchangeService.selectedDay;
      selectedPeriod = _circularExchangeService.selectedPeriod;
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
  }
  
  /// 셀 탭 이벤트 핸들러 - 교체 모드가 활성화된 경우만 동작
  void _onCellTap(DataGridCellTapDetails details) {
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
    _clearPreviousExchangeStates();
    
    // 필터 초기화
    _resetFilters();
    
    // 시간표 그리드 테마 업데이트 (이전 경로 표시 제거)
    _updateHeaderTheme();
  }
  
  @override
  Future<void> findCircularPathsWithProgress() async {
    // 로딩 상태 시작
    setState(() {
      _isCircularPathsLoading = true;
      _loadingProgress = 0.0;
      _isSidebarVisible = true; // 로딩 중에도 사이드바 표시
    });
    
    await _findCircularPathsWithProgress();
  }
  
  @override
  void onPathSelected(CircularExchangePath path) {
    setState(() {
      _selectedCircularPath = path;
      // 순환 교체 경로가 선택되면 순환 교체 모드 자동 활성화
      if (!_isCircularExchangeModeEnabled) {
        _isCircularExchangeModeEnabled = true;
      }
    });
    
    // 데이터 소스에 선택된 경로 업데이트
    _dataSource?.updateSelectedCircularPath(path);
    
    // 시간표 그리드 업데이트
    _updateHeaderTheme();
  }
  
  @override
  void onPathDeselected() {
    setState(() {
      _selectedCircularPath = null;
    });
    
    // 데이터 소스에서 선택된 경로 제거
    _dataSource?.updateSelectedCircularPath(null);
    
    // 시간표 그리드 업데이트
    _updateHeaderTheme();
  }
  
  @override
  void clearPreviousCircularExchangeState() {
    // 순환교체 이전 상태만 초기화 (현재 선택된 셀은 유지)
    _clearPreviousExchangeStates();
    
    // 필터 초기화
    _resetFilters();
    
    // 시간표 그리드 테마 업데이트 (이전 경로 표시 제거)
    _updateHeaderTheme();
  }

  @override
  void clearPreviousChainExchangeState() {
    // 연쇄교체 이전 상태만 초기화 (현재 선택된 셀은 유지)
    _clearPreviousExchangeStates();
    
    // 필터 초기화
    _resetFilters();
    
    // 시간표 그리드 테마 업데이트 (이전 경로 표시 제거)
    _updateHeaderTheme();
    
    AppLogger.exchangeDebug('연쇄교체: 이전 상태 초기화 완료');
  }

  @override
  void onEmptyChainCellSelected() {
    // 빈 셀 선택 시 처리
    setState(() {
      _chainPaths = [];
      _selectedChainPath = null;
      _isChainPathsLoading = false;
      _isSidebarVisible = false;
    });

    showSnackBar('빈 셀은 연쇄교체할 수 없습니다.');
    AppLogger.exchangeInfo('연쇄교체: 빈 셀 선택됨 - 경로 탐색 건너뜀');
  }

  @override
  Future<void> findChainPathsWithProgress() async {
    if (_timetableData == null || !chainExchangeService.hasSelectedCell()) {
      AppLogger.warning('연쇄교체: 시간표 데이터 없음 또는 셀 미선택');
      return;
    }

    AppLogger.exchangeInfo('연쇄교체: 경로 탐색 시작');

    setState(() {
      _isChainPathsLoading = true;
      _loadingProgress = 0.0;
      _chainPaths = [];
      _selectedChainPath = null;
      _isSidebarVisible = true;
    });

    try {
      // 백그라운드에서 연쇄교체 경로 탐색
      List<ChainExchangePath> paths = await compute(
        _findChainPathsInBackground,
        {
          'timeSlots': _timetableData!.timeSlots,
          'teachers': _timetableData!.teachers,
          'teacher': chainExchangeService.nodeATeacher!,
          'day': chainExchangeService.nodeADay!,
          'period': chainExchangeService.nodeAPeriod!,
          'className': chainExchangeService.nodeAClass!,
        },
      );

      setState(() {
        _chainPaths = paths;
        _filteredPaths = paths.cast<ExchangePath>();
        _isChainPathsLoading = false;
        _loadingProgress = 1.0;
        
        // 경로에 따른 사이드바 표시 설정
        if (paths.isEmpty) {
          _isSidebarVisible = false; // 경로가 없으면 사이드바 숨김
          AppLogger.exchangeDebug('연쇄교체 경로가 없어서 사이드바를 숨김니다.');
        } else {
          _isSidebarVisible = true; // 경로가 있으면 사이드바 표시
          AppLogger.exchangeDebug('연쇄교체 경로 ${paths.length}개를 찾았습니다. 사이드바를 표시합니다.');
        }
      });

      if (paths.isEmpty) {
        showSnackBar('연쇄교체 가능한 경로가 없습니다.');
        AppLogger.exchangeInfo('연쇄교체: 경로 없음');
      } else {
        showSnackBar('연쇄교체 경로 ${paths.length}개를 찾았습니다.');
        AppLogger.exchangeInfo('연쇄교체: ${paths.length}개 경로 발견');
      }
    } catch (e) {
      setState(() {
        _isChainPathsLoading = false;
        _chainPaths = [];
      });
      showSnackBar('연쇄교체 경로 탐색 중 오류가 발생했습니다: $e');
      AppLogger.error('연쇄교체 경로 탐색 오류: $e');
    }
  }

  // 백그라운드에서 실행할 함수
  static List<ChainExchangePath> _findChainPathsInBackground(Map<String, dynamic> data) {
    List<TimeSlot> timeSlots = data['timeSlots'];
    List<Teacher> teachers = data['teachers'];
    String teacher = data['teacher'];
    String day = data['day'];
    int period = data['period'];
    String className = data['className'];

    ChainExchangeService service = ChainExchangeService();
    service.setSelectedCell(teacher, day, period, className);

    return service.findChainExchangePaths(timeSlots, teachers);
  }
  
  @override
  void processCellSelection() {
    // 새로운 셀 선택시 이전 교체 관련 상태만 초기화 (현재 선택된 셀은 유지)
    _clearPreviousExchangeStates();
    
    // 순환교체 모드에서 필터 초기화
    if (_isCircularExchangeModeEnabled) {
      _resetFilters();
    }
    
    // 부모 클래스의 processCellSelection 호출
    super.processCellSelection();
  }

  @override
  void generateOneToOnePaths(List<dynamic> options) {
    if (!exchangeService.hasSelectedCell() || timetableData == null) {
      setState(() {
        _oneToOnePaths = [];
        _selectedOneToOnePath = null;
        _isSidebarVisible = false;
      });
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

    setState(() {
      _oneToOnePaths = paths;
      _selectedOneToOnePath = null;
      
      // 필터링된 경로 업데이트
      _updateFilteredPaths();
      
      // 경로가 있으면 사이드바 표시
      _isSidebarVisible = paths.isNotEmpty;
    });
  }

  /// 필터링된 경로 업데이트 (통합)
  void _updateFilteredPaths() {
    List<ExchangePath> allPaths = [];
    
    if (_isExchangeModeEnabled) {
      // 1:1교체 모드
      allPaths.addAll(_oneToOnePaths);
    } else if (_isCircularExchangeModeEnabled) {
      // 순환교체 모드
      allPaths.addAll(_circularPaths);
    }

    // 단계 필터링 적용 (순환교체 모드에서만)
    if (_isCircularExchangeModeEnabled && _selectedStep != null) {
      allPaths = allPaths.where((path) {
        if (path is CircularExchangePath) {
          return path.nodes.length == _selectedStep;
        }
        return false;
      }).toList();
    }
    
    // 요일 필터링 적용 (순환교체 모드에서만)
    if (_isCircularExchangeModeEnabled && _selectedDay != null) {
      allPaths = allPaths.where((path) {
        // 경로에 2번째 노드가 있는지 확인
        if (path.nodes.length < 2) {
          return false;
        }
        
        // 2번째 노드의 요일이 선택된 요일과 일치하는지 확인
        ExchangeNode secondNode = path.nodes[1];
        return secondNode.day == _selectedDay;
      }).toList();
    }

    // 검색 쿼리로 필터링
    if (_searchQuery.isNotEmpty) {
      allPaths = allPaths.where((path) {
        if (path.nodes.length < 2) return false;
        return _matchesSearchQuery(path.nodes[1]);
      }).toList();
    }
    
    _filteredPaths = allPaths;
  }
  
  /// 검색 쿼리와 노드가 일치하는지 확인하는 통합 메서드
  bool _matchesSearchQuery(ExchangeNode node) {
    String query = _searchQuery.toLowerCase().trim();
    
    if (query.length == 1) {
      // 단일 글자인 경우 -> 요일 검색
      return node.day.toLowerCase().contains(query);
    } else if (query.length == 2 && RegExp(r'^[월화수목금토일][1-9]$').hasMatch(query)) {
      // 월1, 화2 형태인 경우 -> 요일+교시 검색
      return node.day.toLowerCase().contains(query[0]) && node.period.toString() == query[1];
    } else {
      // 2글자 이상인 경우 -> 교사이름, 과목 검색
      String teacherName = node.teacherName.toLowerCase();
      String subjectName = _getSubjectName(node).toLowerCase();
      return teacherName.contains(query) || subjectName.contains(query);
    }
  }
  
  /// 진행률과 함께 순환교체 경로 탐색
  Future<void> _findCircularPathsWithProgress() async {
    try {
      AppLogger.exchangeDebug('순환교체 경로 탐색 시작');
      
      // 1단계: 초기화 (10%)
      _updateProgressSmoothly(0.1);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 2단계: 교사 정보 수집 (20%)
      _updateProgressSmoothly(0.2);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 3단계: 시간표 분석 (40%)
      _updateProgressSmoothly(0.4);
      await Future.delayed(const Duration(milliseconds: 150));
      
      // 4단계: DFS 경로 탐색 시작 (80%)
      _updateProgressSmoothly(0.8);
      
      AppLogger.exchangeDebug('경로 탐색 실행 시작 - 선택된 셀: ${_circularExchangeService.selectedTeacher}, ${_circularExchangeService.selectedDay}, ${_circularExchangeService.selectedPeriod}');
      
      // 백그라운드에서 경로 탐색 실행 (compute 사용)
      Map<String, dynamic> data = {
        'timeSlots': _timetableData!.timeSlots,
        'teachers': _timetableData!.teachers,
        'selectedTeacher': _circularExchangeService.selectedTeacher,
        'selectedDay': _circularExchangeService.selectedDay,
        'selectedPeriod': _circularExchangeService.selectedPeriod,
      };
      
      List<CircularExchangePath> paths = await compute(_findCircularExchangePathsInBackground, data);
      
      AppLogger.exchangeDebug('경로 탐색 완료 - 발견된 경로 수: ${paths.length}');
      
      // 5단계: 결과 처리 (90%)
      _updateProgressSmoothly(0.9);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 6단계: 완료 (100%)
      _updateProgressSmoothly(1.0);
      await Future.delayed(const Duration(milliseconds: 150));
      
      // 순환교체 경로에 순차적인 ID 부여
      for (int i = 0; i < paths.length; i++) {
        paths[i].setCustomId('circular_path_${i + 1}');
      }

      // 경로 업데이트 및 로딩 완료
      setState(() {
        _circularPaths = paths;
        _selectedCircularPath = null;
        _isCircularPathsLoading = false;
        _loadingProgress = 0.0;
        
        // 사용 가능한 단계들 업데이트
        _updateAvailableSteps(paths);
      });
      
      // 필터 초기화 (새로운 경로 탐색 완료 후)
      _resetFilters();
      
      // 데이터 소스에서도 선택된 경로 초기화
      _dataSource?.updateSelectedCircularPath(null);
      
      // 디버그 콘솔에 출력
      AppLogger.exchangeDebug('순환교체 경로 ${paths.length}개 발견');
      AppLogger.exchangeDebug('필터링된 경로 ${_filteredPaths.length}개');
      _circularExchangeService.logCircularExchangeInfo(paths, _timetableData!.timeSlots);
      
      // 경로에 따른 사이드바 표시 설정
      setState(() {
        if (paths.isEmpty) {
          _isSidebarVisible = false; // 경로가 없으면 사이드바 숨김
          AppLogger.exchangeDebug('순환교체 경로가 없어서 사이드바를 숨김니다.');
        } else {
          _isSidebarVisible = true; // 경로가 있으면 사이드바 표시
          AppLogger.exchangeDebug('순환교체 경로 ${paths.length}개를 찾았습니다. 사이드바를 표시합니다.');
        }
      });
      
    } catch (e, stackTrace) {
      // 오류 처리
      AppLogger.exchangeDebug('순환교체 경로 탐색 중 오류 발생: $e');
      AppLogger.exchangeDebug('스택 트레이스: $stackTrace');
      
      setState(() {
        _isCircularPathsLoading = false;
        _loadingProgress = 0.0;
        _isSidebarVisible = false;
        _circularPaths = [];
        _filteredPaths = [];
      });
      
      // 사용자에게 오류 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('순환교체 경로 탐색 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// 교체 모드 토글
  void _toggleExchangeMode() {
    setState(() {
      // 다른 모드가 활성화되어 있다면 비활성화
      if (_isCircularExchangeModeEnabled || _isChainExchangeModeEnabled) {
        _isCircularExchangeModeEnabled = false;
        _isChainExchangeModeEnabled = false;
        // 모든 교체 모드 상태 초기화
        _clearAllExchangeStates();
      }
      
      _isExchangeModeEnabled = !_isExchangeModeEnabled;
      
      // 교체 모드가 비활성화되면 UI를 기본값으로 복원
      if (!_isExchangeModeEnabled) {
        _restoreUIToDefault();
      } else {
        // 1:1 교체 모드가 활성화되면 선택 상태 초기화
        _clearAllExchangeStates();
      }
    });
    
    // 헤더 테마 업데이트 (모든 상태 초기화 후)
    _updateHeaderTheme();
    
    // 1:1교체 모드 활성화 시 사용자에게 안내 메시지 표시
    if (_isExchangeModeEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('1:1교체 모드가 활성화되었습니다. 두 교사의 시간을 서로 교체할 수 있습니다.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// 순환교체 모드 토글
  void _toggleCircularExchangeMode() {
    AppLogger.exchangeDebug('순환교체 모드 토글 시작 - 현재 상태: $_isCircularExchangeModeEnabled');

    setState(() {
      // 다른 모드가 활성화되어 있다면 비활성화
      if (_isExchangeModeEnabled || _isChainExchangeModeEnabled) {
        _isExchangeModeEnabled = false;
        _isChainExchangeModeEnabled = false;
        // 모든 교체 모드 상태 초기화
        _clearAllExchangeStates();
      }

      _isCircularExchangeModeEnabled = !_isCircularExchangeModeEnabled;

      // 순환교체 모드가 비활성화되면 UI를 기본값으로 복원
      if (!_isCircularExchangeModeEnabled) {
        _restoreUIToDefault();
        // 단계 필터 관련 상태 초기화
        _availableSteps = [];
        _selectedStep = null;
      } else {
        // 순환교체 모드가 활성화되면 선택 상태 초기화
        _clearAllExchangeStates();
      }
    });

    // 헤더 테마 업데이트 (모든 상태 초기화 후)
    _updateHeaderTheme();

    // 순환교체 모드 활성화 시 사용자에게 안내 메시지 표시
    if (_isCircularExchangeModeEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('순환교체 모드가 활성화되었습니다. 여러 교사의 시간을 순환하여 교체할 수 있습니다.'),
          backgroundColor: Colors.indigo,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _toggleChainExchangeMode() {
    AppLogger.exchangeDebug('연쇄교체 모드 토글 시작 - 현재 상태: $_isChainExchangeModeEnabled');

    setState(() {
      // 다른 모드가 활성화되어 있다면 비활성화
      if (_isExchangeModeEnabled || _isCircularExchangeModeEnabled) {
        _isExchangeModeEnabled = false;
        _isCircularExchangeModeEnabled = false;
        // 모든 교체 모드 상태 초기화
        _clearAllExchangeStates();
      }

      _isChainExchangeModeEnabled = !_isChainExchangeModeEnabled;

      // 연쇄교체 모드가 비활성화되면 UI를 기본값으로 복원
      if (!_isChainExchangeModeEnabled) {
        _restoreUIToDefault();
        // 연쇄교체 관련 상태 완전 초기화
        _dataSource?.updateSelectedChainPath(null);
        _filteredPaths = [];
      } else {
        // 연쇄교체 모드가 활성화되면 선택 상태 초기화
        _clearAllExchangeStates();
      }
    });

    // 헤더 테마 업데이트
    _updateHeaderTheme();

    // 연쇄교체 모드 활성화 시 안내 메시지
    if (_isChainExchangeModeEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('연쇄교체 모드가 활성화되었습니다. 2단계 교체로 결강을 해결할 수 있습니다.'),
          backgroundColor: Colors.deepOrange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// UI를 기본값으로 복원
  void _restoreUIToDefault() {
    // 모든 교체 모드 상태 초기화
    _clearAllExchangeStates();
    
    // 교체 가능한 시간 업데이트 (빈 목록으로)
    updateExchangeableTimes();
    
    // 오류 메시지가 있다면 초기화
    if (_errorMessage != null) {
      _errorMessage = null;
    }
    
    // 모든 교체 모드 비활성화
    _isExchangeModeEnabled = false;
    _isCircularExchangeModeEnabled = false;
    _isChainExchangeModeEnabled = false;
    
    // 검색 상태 초기화
    _searchController.clear();
    _searchQuery = '';
    
    // 헤더 테마를 기본값으로 복원 (모든 변수 초기화 후)
    _updateHeaderTheme();
  }

  /// 오류 메시지 섹션 UI
  Widget _buildErrorMessageSection() {
    return Card(
      elevation: 2,
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade600,
                ),
              ),
            ),
            IconButton(
              onPressed: _clearError,
              icon: Icon(
                Icons.close,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 엑셀 파일 선택 및 자동 읽기 메서드
  Future<void> _selectExcelFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        // Web 플랫폼에서는 직접 파일 선택
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'xls'],
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty) {
          final bytes = result.files.first.bytes;
          if (bytes != null) {
            // Web에서 bytes로 엑셀 파일 처리
            await _processExcelBytes(bytes);
          }
        }
      } else {
        // 데스크톱/모바일 플랫폼
        File? selectedFile = await ExcelService.pickExcelFile();
        
        if (selectedFile != null) {
          setState(() {
            _selectedFile = selectedFile;
          });
          
          // 자동으로 엑셀 데이터 읽기
          await _loadExcelData();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '파일 선택 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 엑셀 데이터 읽기 메서드 (내부용)
  Future<void> _loadExcelData() async {
    if (_selectedFile == null) return;

    try {
      Excel? excel = await ExcelService.readExcelFile(_selectedFile!);
      
      if (excel != null) {
        // 파일 유효성 검사
        bool isValid = ExcelService.isValidExcelFile(excel);
        
        if (isValid) {
          // 시간표 데이터 파싱 시도
          await _parseTimetableData(excel);
        } else {
          setState(() {
            _errorMessage = '유효하지 않은 엑셀 파일입니다.';
          });
        }
      } else {
        setState(() {
          _errorMessage = '엑셀 파일을 읽을 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '엑셀 파일 읽기 중 오류가 발생했습니다: $e';
      });
    }
  }

  /// 시간표 데이터 파싱 메서드
  Future<void> _parseTimetableData(Excel excel) async {
    try {
      // 시간표 데이터 파싱
      TimetableData? timetableData = ExcelService.parseTimetableData(excel);
      
      if (timetableData != null) {
        // 파싱된 데이터를 상태에 저장
        setState(() {
          _timetableData = timetableData;
        });
        
        // Syncfusion DataGrid 데이터 생성
        _createSyncfusionGridData();
      } else {
        // 파싱 실패
        setState(() {
          _errorMessage = '시간표 데이터를 파싱할 수 없습니다. 파일 형식을 확인해주세요.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '시간표 파싱 중 오류가 발생했습니다: $e';
      });
    }
  }


  /// Web에서 bytes로 엑셀 파일 처리
  Future<void> _processExcelBytes(List<int> bytes) async {
    try {
      // 엑셀 파일 읽기
      Excel? excel = await ExcelService.readExcelFromBytes(bytes);
      
      if (excel != null) {
        // 파일 유효성 검사
        bool isValid = ExcelService.isValidExcelFile(excel);
        
        if (isValid) {
          // 시간표 데이터 파싱 시도
          await _parseTimetableData(excel);
        } else {
          setState(() {
            _errorMessage = '유효하지 않은 엑셀 파일입니다.';
          });
        }
      } else {
        setState(() {
          _errorMessage = '엑셀 파일을 읽을 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '엑셀 파일 처리 중 오류가 발생했습니다: $e';
      });
    }
  }

  /// 선택 해제 메서드
  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _timetableData = null;
      _dataSource = null;
      _columns = [];
      _stackedHeaders = [];
      _errorMessage = null;
      // 모든 교체 서비스의 선택 상태 초기화
      _exchangeService.clearAllSelections();
      _circularExchangeService.clearAllSelections();
      _chainExchangeService.clearAllSelections();
      // 모든 교체 모드도 함께 종료
      _isExchangeModeEnabled = false;
      _isCircularExchangeModeEnabled = false;
      _isChainExchangeModeEnabled = false;
      // 선택된 교체 경로들도 초기화
      _selectedCircularPath = null;
      _selectedOneToOnePath = null;
      _selectedChainPath = null;
      _circularPaths = [];
      _oneToOnePaths = [];
      _chainPaths = [];
      _isSidebarVisible = false;
    });
    
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
    setState(() {
      _errorMessage = null;
    });
  }
  
  
  
  /// 테마 기반 헤더 업데이트 (선택된 교시 헤더를 연한 파란색으로 표시)
  void _updateHeaderTheme() {
    if (_timetableData == null) return;
    
    // ExchangeService를 사용하여 교체 가능한 교사 정보 수집
    List<Map<String, dynamic>> exchangeableTeachers = _exchangeService.getCurrentExchangeableTeachers(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
    );
    
    // 선택된 요일과 교시 결정 (1:1 교체 또는 순환교체 모드에 따라)
    String? selectedDay;
    int? selectedPeriod;
    
    if (_isExchangeModeEnabled && _exchangeService.hasSelectedCell()) {
      // 1:1 교체 모드
      selectedDay = _exchangeService.selectedDay;
      selectedPeriod = _exchangeService.selectedPeriod;
    } else if (_isCircularExchangeModeEnabled && _circularExchangeService.hasSelectedCell()) {
      // 순환교체 모드
      selectedDay = _circularExchangeService.selectedDay;
      selectedPeriod = _circularExchangeService.selectedPeriod;
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

  /// 순환교체 사이드바 구성
  Widget _buildUnifiedExchangeSidebar() {
    // 현재 모드 결정
    ExchangePathType currentMode;
    if (_isExchangeModeEnabled) {
      currentMode = ExchangePathType.oneToOne;
    } else if (_isCircularExchangeModeEnabled) {
      currentMode = ExchangePathType.circular;
    } else {
      currentMode = ExchangePathType.chain;
    }

    // 선택된 경로 결정
    ExchangePath? selectedPath;
    if (_isExchangeModeEnabled) {
      selectedPath = _selectedOneToOnePath;
    } else if (_isCircularExchangeModeEnabled) {
      selectedPath = _selectedCircularPath;
    } else if (_isChainExchangeModeEnabled) {
      selectedPath = _selectedChainPath;
    }

    // 경로 리스트 결정
    List<ExchangePath> paths;
    if (_isExchangeModeEnabled) {
      paths = _oneToOnePaths;
    } else if (_isCircularExchangeModeEnabled) {
      paths = _circularPaths;
    } else {
      paths = _chainPaths;
    }

    // 로딩 상태 결정
    bool isLoading = false;
    if (_isCircularExchangeModeEnabled) {
      isLoading = _isCircularPathsLoading;
    } else if (_isChainExchangeModeEnabled) {
      isLoading = _isChainPathsLoading;
    }

    return UnifiedExchangeSidebar(
      width: _sidebarWidth,
      paths: paths,
      filteredPaths: _filteredPaths,
      selectedPath: selectedPath,
      mode: currentMode,
      isLoading: isLoading,
      loadingProgress: _loadingProgress,
      searchQuery: _searchQuery,
      searchController: _searchController,
      onToggleSidebar: _toggleSidebar,
      onSelectPath: _onUnifiedPathSelected,
      onUpdateSearchQuery: _updateSearchQuery,
      onClearSearch: _clearSearch,
      getSubjectName: _getSubjectName,
      onScrollToCell: _scrollToCellCenter,
      // 순환교체 모드에서만 사용되는 단계 필터 매개변수들
      availableSteps: _isCircularExchangeModeEnabled ? _availableSteps : null,
      selectedStep: _isCircularExchangeModeEnabled ? _selectedStep : null,
        onStepChanged: _isCircularExchangeModeEnabled ? _onStepChanged : null,
        selectedDay: _isCircularExchangeModeEnabled ? _selectedDay : null,
        onDayChanged: _isCircularExchangeModeEnabled ? _onDayChanged : null,
    );
  }

  /// 현재 선택된 교체 경로 반환 (모든 타입 지원)
  ExchangePath? _getCurrentSelectedPath() {
    // 우선순위: 순환교체 > 연쇄교체 > 1:1교체
    if (_selectedCircularPath != null) {
      return _selectedCircularPath;
    } else if (_selectedChainPath != null) {
      return _selectedChainPath;
    } else if (_selectedOneToOnePath != null) {
      return _selectedOneToOnePath;
    }
    return null;
  }

  /// 통합 경로 선택 처리
  void _onUnifiedPathSelected(ExchangePath path) {
    AppLogger.exchangeDebug('통합 경로 선택: ${path.id}, 타입: ${path.type}');
    
    if (path is OneToOneExchangePath) {
      // 이미 선택된 경로를 다시 클릭하면 선택 해제 (토글 기능)
      bool isSamePathSelected = _selectedOneToOnePath != null && 
                               _selectedOneToOnePath!.id == path.id;
      
      if (isSamePathSelected) {
        // 선택 해제
        AppLogger.exchangeDebug('1:1교체 경로 선택 해제: ${path.id}');
        setState(() {
          _selectedOneToOnePath = null;
        });
        
        // 데이터 소스에서 선택된 1:1 경로 정보 제거
        _dataSource?.updateSelectedOneToOnePath(null);
        
        // 타겟 셀 해제
        _clearTargetCell();
        
        // 시간표 그리드 업데이트
        _updateHeaderTheme();
        
        // 사용자에게 선택 해제 알림
        showSnackBar(
          '1:1교체 경로 선택이 해제되었습니다.',
          backgroundColor: Colors.grey.shade600,
        );
      } else {
        // 새로운 경로 선택
        AppLogger.exchangeDebug('1:1교체 경로 선택: ${path.id}');
        setState(() {
          _selectedOneToOnePath = path;
        });
        
        // 데이터 소스에 선택된 1:1 경로 정보 전달
        _dataSource?.updateSelectedOneToOnePath(path);
        
        // 타겟 셀 설정 (교체 대상의 같은 행 셀)
        _setTargetCellFromPath(path);
        
        // 시간표 그리드 업데이트
        _updateHeaderTheme();
      }
    } else if (path is CircularExchangePath) {
      // 순환교체 경로 선택
      AppLogger.exchangeDebug('순환교체 경로 선택: ${path.id}');
      
      // 이미 선택된 경로를 다시 클릭하면 선택 해제 (토글 기능)
      bool isSamePathSelected = _selectedCircularPath != null && 
                               _selectedCircularPath!.id == path.id;
      
      if (isSamePathSelected) {
        // 선택 해제
        AppLogger.exchangeDebug('순환교체 경로 선택 해제: ${path.id}');
        onPathDeselected();
        
        // 타겟 셀 해제
        _clearTargetCell();
        
        // 사용자에게 선택 해제 알림
        showSnackBar(
          '순환교체 경로 선택이 해제되었습니다.',
          backgroundColor: Colors.grey.shade600,
        );
      } else {
        // 새로운 경로 선택
        onPathSelected(path);
        
        // 타겟 셀 설정 (교체 대상의 같은 행 셀)
        _setTargetCellFromCircularPath(path);
      }
    } else if (path is ChainExchangePath) {
      // 이미 선택된 경로를 다시 클릭하면 선택 해제 (토글 기능)
      bool isSamePathSelected = _selectedChainPath != null && 
                               _selectedChainPath!.id == path.id;
      
      if (isSamePathSelected) {
        // 선택 해제
        AppLogger.exchangeDebug('연쇄교체 경로 선택 해제: ${path.id}');
        setState(() {
          _selectedChainPath = null;
        });
        
        // 데이터 소스에서 선택된 연쇄교체 경로 정보 제거
        _dataSource?.updateSelectedChainPath(null);
        
        // 타겟 셀 해제
        _clearTargetCell();
        
        // 시간표 그리드 업데이트
        _updateHeaderTheme();
        
        // 사용자에게 선택 해제 알림
        showSnackBar(
          '연쇄교체 경로 선택이 해제되었습니다.',
          backgroundColor: Colors.grey.shade600,
        );
      } else {
        // 새로운 경로 선택
        AppLogger.exchangeDebug('연쇄교체 경로 선택: ${path.id}');
        setState(() {
          _selectedChainPath = path;
        });
        
        // 데이터 소스에 선택된 연쇄교체 경로 정보 전달
        _dataSource?.updateSelectedChainPath(path);
        
        // 타겟 셀 설정 (마지막 교체 대상의 같은 행 셀)
        _setTargetCellFromChainPath(path);
        
        // 시간표 그리드 업데이트
        _updateHeaderTheme();
      }
    }
  }

  /// 백그라운드에서 순환교체 경로 탐색을 실행하는 정적 함수 (현재 비활성화)
  // static List<CircularExchangePath> _findCircularExchangePathsInBackground(Map<String, dynamic> data) {
  //   List<dynamic> timeSlotsData = data['timeSlots'] as List<dynamic>;
  //   List<dynamic> teachersData = data['teachers'] as List<dynamic>;
  //   String? selectedTeacher = data['selectedTeacher'] as String?;
  //   String? selectedDay = data['selectedDay'] as String?;
  //   int? selectedPeriod = data['selectedPeriod'] as int?;
  //   
  //   // 동적 리스트를 적절한 타입으로 변환
  //   List<TimeSlot> timeSlots = timeSlotsData.cast<TimeSlot>();
  //   List<Teacher> teachers = teachersData.cast<Teacher>();
  //   
  //   // 새로운 CircularExchangeService 인스턴스 생성 (백그라운드에서 실행)
  //   CircularExchangeService service = CircularExchangeService();
  //   
  //   // 선택된 셀 정보를 백그라운드 서비스에 설정
  //   if (selectedTeacher != null && selectedDay != null && selectedPeriod != null) {
  //     service.setSelectedCell(selectedTeacher, selectedDay, selectedPeriod);
  //   }
  //   
  //   return service.findCircularExchangePaths(timeSlots, teachers);
  // }

  /// 부드러운 진행률 업데이트
  void _updateProgressSmoothly(double targetProgress) {
    // 애니메이션 컨트롤러가 초기화되지 않은 경우 즉시 진행률 업데이트
    if (_progressAnimationController == null) {
      setState(() {
        _loadingProgress = targetProgress;
      });
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
      setState(() {
        _loadingProgress = targetProgress;
      });
    });
    
    // 애니메이션 중에도 진행률 업데이트
    _progressAnimation!.addListener(() {
      setState(() {
        _loadingProgress = _progressAnimation!.value;
      });
    });
  }

  /// 순환교체 단계 필터 변경 처리
  void _onStepChanged(int? step) {
    setState(() {
      _selectedStep = step;
    });
    
    // 필터링된 경로 업데이트
    _updateFilteredPaths();
    
    AppLogger.exchangeDebug('순환교체 단계 필터 변경: ${step ?? "전체"}');
  }
  
  /// 요일 변경 처리
  void _onDayChanged(String? day) {
    setState(() {
      _selectedDay = day;
    });
    
    // 필터링된 경로 업데이트
    _updateFilteredPaths();
    
    AppLogger.exchangeDebug('순환교체 요일 필터 변경: ${day ?? "전체"}');
  }
  
  /// 필터 초기화 (셀 선택 시 호출)
  void _resetFilters() {
    setState(() {
      // 검색 텍스트 초기화
      _searchQuery = '';
      _searchController.clear();
      
      // 단계 필터 초기화 (첫 번째 단계로 설정)
      _selectedStep = _availableSteps.isNotEmpty ? _availableSteps.first : null;
      
      // 요일 필터 초기화
      _selectedDay = null;
    });
    
    // 필터링된 경로 업데이트
    _updateFilteredPaths();
    
    AppLogger.exchangeDebug('필터 초기화 완료');
  }

  /// 사용 가능한 단계들 업데이트
  void _updateAvailableSteps(List<CircularExchangePath> paths) {
    Set<int> steps = {};
    for (var path in paths) {
      steps.add(path.nodes.length);
    }
    _availableSteps = steps.toList()..sort();
    
    // 첫 번째 단계를 기본 선택으로 설정
    _selectedStep = _availableSteps.isNotEmpty ? _availableSteps.first : null;
    
    AppLogger.exchangeDebug('사용 가능한 단계들: $_availableSteps, 선택된 단계: $_selectedStep');
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







  /// 타겟 셀 설정 (교체 대상의 같은 행 셀)
  /// 교체 대상이 월1교시라면, 선택된 셀의 같은 행의 월1교시를 타겟으로 설정
  void _setTargetCellFromPath(OneToOneExchangePath path) {
    if (!_exchangeService.hasSelectedCell() || _timetableData == null) {
      AppLogger.exchangeDebug('1:1 교체 타겟 셀 설정 실패: 조건 불충족');
      return;
    }
    
    // 교체 대상의 요일과 교시 가져오기
    String targetDay = path.targetNode.day;
    int targetPeriod = path.targetNode.period;
    
    // 선택된 셀의 교사명 가져오기
    String selectedTeacher = _exchangeService.selectedTeacher!;
    
    // ExchangeService에 타겟 셀 설정
    _exchangeService.setTargetCell(selectedTeacher, targetDay, targetPeriod);
    
    // 데이터 소스에 타겟 셀 정보 전달
    _dataSource?.updateTargetCell(selectedTeacher, targetDay, targetPeriod);
    
    AppLogger.exchangeDebug('타겟 셀 설정: $selectedTeacher $targetDay $targetPeriod교시');
  }
  
  /// 순환교체 경로에서 타겟 셀 설정 (교체 대상의 같은 행 셀)
  /// 교체 대상이 월1교시라면, 선택된 셀의 같은 행의 월1교시를 타겟으로 설정
  void _setTargetCellFromCircularPath(CircularExchangePath path) {
    if (!_circularExchangeService.hasSelectedCell() || _timetableData == null || path.nodes.length < 2) {
      AppLogger.exchangeDebug('순환교체 타겟 셀 설정 실패: 조건 불충족');
      return;
    }
    
    // 순환교체 경로의 첫 번째 노드는 선택된 셀, 두 번째 노드는 교체 대상
    ExchangeNode sourceNode = path.nodes[0]; // 선택된 셀
    ExchangeNode targetNode = path.nodes[1]; // 교체 대상
    
    // 교체 대상의 요일과 교시 가져오기
    String targetDay = targetNode.day;
    int targetPeriod = targetNode.period;
    
    // 선택된 셀의 교사명 가져오기
    String selectedTeacher = sourceNode.teacherName;
    
    // ExchangeService에 타겟 셀 설정
    _exchangeService.setTargetCell(selectedTeacher, targetDay, targetPeriod);
    
    // 데이터 소스에 타겟 셀 정보 전달
    _dataSource?.updateTargetCell(selectedTeacher, targetDay, targetPeriod);
    
    AppLogger.exchangeDebug('순환교체 타겟 셀 설정: $selectedTeacher $targetDay $targetPeriod교시');
  }
  
  /// 연쇄교체 경로에서 타겟 셀 설정 (마지막 교체 대상의 같은 행 셀)
  /// 마지막 교체 대상이 수1교시라면, 선택된 셀의 같은 행의 수1교시를 타겟으로 설정
  void _setTargetCellFromChainPath(ChainExchangePath path) {
    if (!chainExchangeService.hasSelectedCell() || _timetableData == null) {
      AppLogger.exchangeDebug('연쇄교체 타겟 셀 설정 실패: 조건 불충족');
      return;
    }
    
    // 연쇄교체 경로의 마지막 교체 대상은 nodeB (최종 교체 대상)
    ExchangeNode targetNode = path.nodeB; // 마지막 교체 대상
    
    // 교체 대상의 요일과 교시 가져오기
    String targetDay = targetNode.day;
    int targetPeriod = targetNode.period;
    
    // 선택된 셀의 교사명 가져오기 (nodeA의 교사명)
    String selectedTeacher = path.nodeA.teacherName;
    
    // ExchangeService에 타겟 셀 설정
    _exchangeService.setTargetCell(selectedTeacher, targetDay, targetPeriod);
    
    // 데이터 소스에 타겟 셀 정보 전달
    _dataSource?.updateTargetCell(selectedTeacher, targetDay, targetPeriod);
    
    AppLogger.exchangeDebug('연쇄교체 타겟 셀 설정: $selectedTeacher $targetDay $targetPeriod교시 (마지막 교체 대상)');
  }
  
  /// 이전 교체 관련 상태만 초기화 (현재 선택된 셀은 유지)
  /// 새로운 셀 선택 시 이전 경로와 타겟 셀만 초기화
  void _clearPreviousExchangeStates() {
    // 타겟 셀 초기화
    _clearTargetCell();
    
    // 데이터 소스에 이전 경로 정보만 해제 (현재 선택된 셀은 유지)
    _dataSource?.updateSelectedCircularPath(null);
    _dataSource?.updateSelectedOneToOnePath(null);
    _dataSource?.updateSelectedChainPath(null);
    
    // 이전 선택된 경로 초기화
    _selectedCircularPath = null;
    _selectedOneToOnePath = null;
    _selectedChainPath = null;
    
    // 이전 경로 리스트 초기화
    _circularPaths = [];
    _oneToOnePaths = [];
    _chainPaths = [];
    
    // UI 상태 초기화
    _isSidebarVisible = false;
    _isCircularPathsLoading = false;
    _isChainPathsLoading = false;
    _loadingProgress = 0.0;
    
    // 필터 상태 초기화
    _filteredPaths = [];
    _availableSteps = [];
    _selectedStep = null;
    
    AppLogger.exchangeDebug('이전 교체 관련 상태 초기화 완료');
  }
  
  /// 모든 교체 모드 공통 초기화
  /// 모드 전환 시 모든 교체 관련 상태를 초기화
  void _clearAllExchangeStates() {
    // 모든 교체 서비스의 선택 상태 초기화
    _exchangeService.clearAllSelections();
    _circularExchangeService.clearAllSelections();
    _chainExchangeService.clearAllSelections();
    
    // 타겟 셀 초기화
    _clearTargetCell();
    
    // 데이터 소스에 모든 선택 상태 해제
    _dataSource?.updateSelection(null, null, null);
    _dataSource?.updateExchangeOptions([]);
    _dataSource?.updateExchangeableTeachers([]);
    _dataSource?.updateSelectedCircularPath(null);
    _dataSource?.updateSelectedOneToOnePath(null);
    _dataSource?.updateSelectedChainPath(null);
    
    // 모든 선택된 경로 초기화
    _selectedCircularPath = null;
    _selectedOneToOnePath = null;
    _selectedChainPath = null;
    
    // 모든 경로 리스트 초기화
    _circularPaths = [];
    _oneToOnePaths = [];
    _chainPaths = [];
    
    // UI 상태 초기화
    _isSidebarVisible = false;
    _isCircularPathsLoading = false;
    _isChainPathsLoading = false;
    _loadingProgress = 0.0;
    
    // 필터 상태 초기화
    _filteredPaths = [];
    _availableSteps = [];
    _selectedStep = null;
    
    AppLogger.exchangeDebug('모든 교체 모드 상태 초기화 완료');
  }
  
  /// 타겟 셀 해제
  void _clearTargetCell() {
    // ExchangeService에서 타겟 셀 해제
    _exchangeService.clearTargetCell();
    
    // 데이터 소스에서 타겟 셀 정보 제거
    _dataSource?.updateTargetCell(null, null, null);
    
    AppLogger.exchangeDebug('타겟 셀 해제');
  }

  /// 사이드바 토글
  void _toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
  }

  /// 검색 쿼리 업데이트 및 필터링
  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
      _updateFilteredPaths(); // 통합 필터링 사용
    });
  }


  /// 검색 입력 필드 초기화
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _updateFilteredPaths(); // 통합 필터링 사용
    });
  }

  
}

/// 백그라운드에서 순환교체 경로 탐색을 실행하는 함수
/// compute 함수에서 사용하기 위해 클래스 외부에 정의
List<CircularExchangePath> _findCircularExchangePathsInBackground(Map<String, dynamic> data) {
  // 백그라운드에서 새로운 CircularExchangeService 인스턴스 생성
  CircularExchangeService service = CircularExchangeService();
  
  // 선택된 셀 정보 설정
  service.setSelectedCell(
    data['selectedTeacher'] as String,
    data['selectedDay'] as String,
    data['selectedPeriod'] as int,
  );
  
  // 경로 탐색 실행
  return service.findCircularExchangePaths(
    data['timeSlots'] as List<TimeSlot>,
    data['teachers'] as List<Teacher>,
  );
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/excel_service.dart';
import '../../services/exchange_service.dart';
import '../../services/circular_exchange_service.dart';
import '../../models/circular_exchange_path.dart';
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
  
  // Mixin에서 요구하는 getter들
  @override
  ExchangeService get exchangeService => _exchangeService;
  
  @override
  CircularExchangeService get circularExchangeService => _circularExchangeService;
  
  @override
  TimetableData? get timetableData => _timetableData;
  
  @override
  TimetableDataSource? get dataSource => _dataSource;
  
  @override
  bool get isExchangeModeEnabled => _isExchangeModeEnabled;
  
  @override
  bool get isCircularExchangeModeEnabled => _isCircularExchangeModeEnabled;
  
  @override
  CircularExchangePath? get selectedCircularPath => _selectedCircularPath;
  
  // 교체 모드 관련 변수들
  bool _isExchangeModeEnabled = false; // 1:1교체 모드 활성화 상태
  bool _isCircularExchangeModeEnabled = false; // 순환교체 모드 활성화 상태
  
  // 시간표 그리드 제어를 위한 GlobalKey
  final GlobalKey<State<TimetableGridSection>> _timetableGridKey = GlobalKey<State<TimetableGridSection>>();
  
  // 순환교체 관련 변수들
  List<CircularExchangePath> _circularPaths = []; // 순환교체 경로들
  CircularExchangePath? _selectedCircularPath; // 선택된 순환교체 경로
  bool _isCircularPathsLoading = false; // 순환교체 경로 탐색 로딩 상태
  double _loadingProgress = 0.0; // 진행률 (0.0 ~ 1.0)
  
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
          
          // 통합 교체 사이드바 (1:1교체 및 순환교체)
          if (_isSidebarVisible && (
            (_isExchangeModeEnabled && _oneToOnePaths.isNotEmpty) ||
            (_isCircularExchangeModeEnabled && (_circularPaths.isNotEmpty || _isCircularPathsLoading))
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
            onSelectExcelFile: _selectExcelFile,
            onToggleExchangeMode: _toggleExchangeMode,
            onToggleCircularExchangeMode: _toggleCircularExchangeMode,
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
    if (!_isExchangeModeEnabled && !_isCircularExchangeModeEnabled) {
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
    setState(() {
      // 순환교체 경로와 관련된 모든 상태 초기화
      _circularPaths = [];
      _selectedCircularPath = null;
      _isSidebarVisible = false;
      _isCircularPathsLoading = false;
      _loadingProgress = 0.0;
      _filteredPaths = [];
    });
    
    // 데이터 소스에서도 순환교체 관련 상태 초기화
    _dataSource?.updateSelectedCircularPath(null);
    
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
    // onEmptyCellSelected와 동일한 로직 재사용
    onEmptyCellSelected();
  }
  
  @override
  void processCellSelection() {
    // 새로운 셀 선택시 이전 1:1 교체 관련 상태 초기화
    setState(() {
      _selectedOneToOnePath = null;
      _oneToOnePaths = [];
    });
    
    // 데이터 소스에서 이전 1:1 교체 관련 상태 초기화
    _dataSource?.updateSelectedOneToOnePath(null);
    
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

    // 검색 쿼리로 필터링 - 패턴별 검색 로직 적용
    if (_searchQuery.isEmpty) {
      _filteredPaths = allPaths;
    } else {
      String query = _searchQuery.toLowerCase().trim();
      _filteredPaths = allPaths.where((path) {
        // 경로에 2번째 노드가 있는지 확인
        if (path.nodes.length < 2) {
          return false; // 2번째 노드가 없으면 필터링에서 제외
        }
        
        // 2번째 노드만 검색 (인덱스 1)
        ExchangeNode secondNode = path.nodes[1];
        
        // 검색어 패턴 분석
        if (query.length == 1) {
          // 단일 글자인 경우 -> 요일 검색 (월, 화, 수, 목, 금)
          String day = secondNode.day.toLowerCase();
          return day.contains(query);
          
        } else if (query.length == 2 && RegExp(r'^[월화수목금토일][1-9]$').hasMatch(query)) {
          // 월1, 화2 형태인 경우 -> 요일+교시 검색
          String day = secondNode.day.toLowerCase();
          String period = secondNode.period.toString();
          
          // 요일과 교시가 모두 일치하는지 확인
          return day.contains(query[0]) && period == query[1];
          
        } else {
          // 2글자 이상인 경우 -> 교사이름, 과목 검색
          String teacherName = secondNode.teacherName.toLowerCase();
          String subjectName = _getSubjectName(secondNode).toLowerCase();
          
          return teacherName.contains(query) || subjectName.contains(query);
        }
      }).toList();
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
      
      // 필터링된 경로도 함께 업데이트
      _updateFilteredPaths();
      
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
      // 순환교체 모드가 활성화되어 있다면 비활성화
      if (_isCircularExchangeModeEnabled) {
        _isCircularExchangeModeEnabled = false;
        // 순환교체 모드의 선택 상태와 경로 정보 초기화
        _circularExchangeService.clearAllSelections();
        _selectedCircularPath = null;
        _circularPaths = [];
        _isSidebarVisible = false;
        _isCircularPathsLoading = false;
        _loadingProgress = 0.0;
        _dataSource?.updateSelectedCircularPath(null);
      }
      
      _isExchangeModeEnabled = !_isExchangeModeEnabled;
      
      // 교체 모드가 비활성화되면 UI를 기본값으로 복원
      if (!_isExchangeModeEnabled) {
        _restoreUIToDefault();
      } else {
        // 1:1 교체 모드가 활성화되면 선택 상태 초기화
        _exchangeService.clearAllSelections();
        _dataSource?.updateSelection(null, null, null);
        _dataSource?.updateExchangeOptions([]);
        _dataSource?.updateExchangeableTeachers([]);
        _dataSource?.updateSelectedOneToOnePath(null);
        _selectedOneToOnePath = null;
        _oneToOnePaths = [];
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
      // 1:1교체 모드가 활성화되어 있다면 비활성화
      if (_isExchangeModeEnabled) {
        _isExchangeModeEnabled = false;
        // 1:1 교체 모드의 선택 상태와 교체 가능한 시간 정보 초기화
        _exchangeService.clearAllSelections();
        _dataSource?.updateSelection(null, null, null);
        _dataSource?.updateExchangeOptions([]);
        _dataSource?.updateExchangeableTeachers([]);
        _dataSource?.updateSelectedOneToOnePath(null);
        _selectedOneToOnePath = null;
        _oneToOnePaths = [];
      }
      
      _isCircularExchangeModeEnabled = !_isCircularExchangeModeEnabled;
      
      // 순환교체 모드가 비활성화되면 UI를 기본값으로 복원
      if (!_isCircularExchangeModeEnabled) {
        _restoreUIToDefault();
        // 단계 필터 관련 상태 초기화
        _availableSteps = [];
        _selectedStep = null;
      } else {
        // 순환교체 모드가 활성화되면 사이드바도 숨김 (새로운 경로 탐색 전까지)
        _isSidebarVisible = false;
        // 순환교체 모드의 선택 상태도 초기화
        _circularExchangeService.clearAllSelections();
        _selectedCircularPath = null;
        _circularPaths = [];
        _isCircularPathsLoading = false;
        // 단계 필터 관련 상태 초기화
        _availableSteps = [];
        _selectedStep = null;
        _loadingProgress = 0.0;
        _dataSource?.updateSelectedCircularPath(null);
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
  
  /// UI를 기본값으로 복원
  void _restoreUIToDefault() {
    // 모든 교체 서비스의 선택 상태 초기화
    _exchangeService.clearAllSelections();
    _circularExchangeService.clearAllSelections();
    
    // 데이터 소스에 선택 상태 해제
    _dataSource?.updateSelection(null, null, null);
    _dataSource?.updateExchangeOptions([]);
    _dataSource?.updateExchangeableTeachers([]);
    _dataSource?.updateSelectedCircularPath(null);
    _dataSource?.updateSelectedOneToOnePath(null);
    
    // 교체 가능한 시간 업데이트 (빈 목록으로)
    updateExchangeableTimes();
    
    // 오류 메시지가 있다면 초기화
    if (_errorMessage != null) {
      _errorMessage = null;
    }
    
    // 모든 교체 모드 및 선택된 경로 초기화
    _isExchangeModeEnabled = false;
    _isCircularExchangeModeEnabled = false;
    _selectedCircularPath = null;
    _selectedOneToOnePath = null;
    _circularPaths = [];
    _oneToOnePaths = [];
    _isSidebarVisible = false;
    _isCircularPathsLoading = false;
    _loadingProgress = 0.0;
    
    // 검색 상태 초기화
    _searchController.clear();
    _searchQuery = '';
    _filteredPaths = [];
    
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
      // 모든 교체 모드도 함께 종료
      _isExchangeModeEnabled = false;
      _isCircularExchangeModeEnabled = false;
      // 선택된 순환교체 경로도 초기화
      _selectedCircularPath = null;
      _selectedOneToOnePath = null;
      _circularPaths = [];
      _oneToOnePaths = [];
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
    );
    
    _columns = result.columns; // 헤더만 업데이트
    setState(() {}); // UI 갱신
  }

  /// 순환교체 사이드바 구성
  Widget _buildUnifiedExchangeSidebar() {
    // 현재 모드 결정
    ExchangePathType currentMode = _isExchangeModeEnabled 
        ? ExchangePathType.oneToOne 
        : ExchangePathType.circular;
    
    // 선택된 경로 결정
    ExchangePath? selectedPath;
    if (_isExchangeModeEnabled) {
      selectedPath = _selectedOneToOnePath;
    } else if (_isCircularExchangeModeEnabled) {
      selectedPath = _selectedCircularPath;
    }
    
    return UnifiedExchangeSidebar(
      width: _sidebarWidth,
      paths: _isExchangeModeEnabled ? _oneToOnePaths : _circularPaths,
      filteredPaths: _filteredPaths,
      selectedPath: selectedPath,
      mode: currentMode,
      isLoading: _isCircularPathsLoading, // 1:1교체는 즉시 로딩되므로 순환교체 로딩만 사용
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
    );
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
        
        // 시간표 그리드 업데이트
        _updateHeaderTheme();
      }
    } else if (path is CircularExchangePath) {
      // 순환교체 경로 선택
      AppLogger.exchangeDebug('순환교체 경로 선택: ${path.id}');
      selectPath(path);
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

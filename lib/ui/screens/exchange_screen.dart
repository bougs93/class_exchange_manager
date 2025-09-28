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
import '../../utils/timetable_data_source.dart';
import '../../utils/syncfusion_timetable_helper.dart';
import '../../utils/logger.dart';
import '../../utils/day_utils.dart';
import '../widgets/circular_exchange_sidebar.dart';
import '../widgets/file_selection_section.dart';
import '../widgets/timetable_grid_section.dart';
import '../mixins/exchange_logic_mixin.dart';

/// 교체 관리 화면
class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> with ExchangeLogicMixin {
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
  
  // 사이드바 관련 변수들
  bool _isSidebarVisible = false; // 사이드바 표시 여부
  final double _sidebarWidth = 180.0; // 사이드바 너비
  
  // 검색 및 필터링 관련 변수들
  final TextEditingController _searchController = TextEditingController(); // 검색 입력 컨트롤러
  String _searchQuery = ''; // 검색 쿼리
  List<CircularExchangePath> _filteredCircularPaths = []; // 필터링된 순환교체 경로들

  @override
  void dispose() {
    _searchController.dispose();
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
          
          // 순환교체 사이드바
          if (_isCircularExchangeModeEnabled && _isSidebarVisible && (_circularPaths.isNotEmpty || _isCircularPathsLoading))
            _buildCircularExchangeSidebar(),
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
      _filteredCircularPaths = [];
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
  
  
  /// 진행률과 함께 순환교체 경로 탐색
  Future<void> _findCircularPathsWithProgress() async {
    try {
      // 1단계: 초기화 (10%)
      setState(() => _loadingProgress = 0.1);
      await Future.delayed(const Duration(milliseconds: 50));
      
      // 2단계: 교사 정보 수집 (20%)
      setState(() => _loadingProgress = 0.2);
      await Future.delayed(const Duration(milliseconds: 50));
      
      // 3단계: 시간표 분석 (40%)
      setState(() => _loadingProgress = 0.4);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 4단계: DFS 경로 탐색 (80%)
      setState(() => _loadingProgress = 0.8);
      
      // 실제 경로 탐색 실행 (메인 처리)
      List<CircularExchangePath> paths = await Future(() {
        return _circularExchangeService.findCircularExchangePaths(
          _timetableData!.timeSlots,
          _timetableData!.teachers,
        );
      });
      
      // 5단계: 결과 처리 (90%)
      setState(() => _loadingProgress = 0.9);
      await Future.delayed(const Duration(milliseconds: 50));
      
      // 6단계: 완료 (100%)
      setState(() => _loadingProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 경로 업데이트 및 로딩 완료
      setState(() {
        _circularPaths = paths;
        _selectedCircularPath = null;
        _isCircularPathsLoading = false;
        _loadingProgress = 0.0;
      });
      
      // 필터링된 경로도 함께 업데이트
      _filterCircularPaths();
      
      // 데이터 소스에서도 선택된 경로 초기화
      _dataSource?.updateSelectedCircularPath(null);
      
      // 디버그 콘솔에 출력
      AppLogger.exchangeDebug('순환교체 경로 ${paths.length}개 발견');
      AppLogger.exchangeDebug('필터링된 경로 ${_filteredCircularPaths.length}개');
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
      
    } catch (e) {
      // 오류 처리
      setState(() {
        _isCircularPathsLoading = false;
        _loadingProgress = 0.0;
        _isSidebarVisible = false;
      });
      rethrow;
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
      }
      
      _isCircularExchangeModeEnabled = !_isCircularExchangeModeEnabled;
      
      // 순환교체 모드가 비활성화되면 UI를 기본값으로 복원
      if (!_isCircularExchangeModeEnabled) {
        _restoreUIToDefault();
      } else {
        // 순환교체 모드가 활성화되면 사이드바도 숨김 (새로운 경로 탐색 전까지)
        _isSidebarVisible = false;
        // 순환교체 모드의 선택 상태도 초기화
        _circularExchangeService.clearAllSelections();
        _selectedCircularPath = null;
        _circularPaths = [];
        _isCircularPathsLoading = false;
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
    _circularPaths = [];
    _isSidebarVisible = false;
    _isCircularPathsLoading = false;
    _loadingProgress = 0.0;
    
    // 검색 상태 초기화
    _searchController.clear();
    _searchQuery = '';
    _filteredCircularPaths = [];
    
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
      _circularPaths = [];
      _isSidebarVisible = false;
    });
    
    // 교체 가능한 교사 정보도 초기화
    _dataSource?.updateExchangeableTeachers([]);
    _dataSource?.updateSelectedCircularPath(null);
    
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
    );
    
    _columns = result.columns; // 헤더만 업데이트
    setState(() {}); // UI 갱신
  }

  /// 순환교체 사이드바 구성
  Widget _buildCircularExchangeSidebar() {
    return CircularExchangeSidebar(
      width: _sidebarWidth,
      circularPaths: _circularPaths,
      filteredCircularPaths: _filteredCircularPaths,
      selectedCircularPath: _selectedCircularPath,
      isLoading: _isCircularPathsLoading,
      loadingProgress: _loadingProgress,
      searchQuery: _searchQuery,
      searchController: _searchController,
      onToggleSidebar: _toggleSidebar,
      onSelectPath: (path) => selectPath(path),
      onUpdateSearchQuery: _updateSearchQuery,
      onClearSearch: _clearSearch,
      getSubjectName: _getSubjectName,
      onScrollToCell: _scrollToCellCenter, // 셀 스크롤 콜백 추가
    );
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
    _searchQuery = query;
    _filterCircularPaths();
  }

  /// 순환교체 경로 필터링
  void _filterCircularPaths() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredCircularPaths = List.from(_circularPaths);
      } else {
        _filteredCircularPaths = _circularPaths.where((path) {
          // 경로의 모든 노드에서 검색 쿼리와 일치하는지 확인
          return path.nodes.any((node) {
            final day = node.day.toLowerCase();
            final teacherName = node.teacherName.toLowerCase();
            final subject = _getSubjectName(node).toLowerCase();
            final query = _searchQuery.toLowerCase();
            
            return day.contains(query) || 
                   teacherName.contains(query) || 
                   subject.contains(query);
          });
        }).toList();
      }
      
      // 디버그 로그
      AppLogger.exchangeDebug('필터링 완료: 원본 ${_circularPaths.length}개 → 필터링 ${_filteredCircularPaths.length}개');
    });
  }

  /// 검색 입력 필드 초기화
  void _clearSearch() {
    _searchController.clear();
    _updateSearchQuery('');
  }

  
}

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
import '../../utils/timetable_data_source.dart';
import '../../utils/syncfusion_timetable_helper.dart';
import '../../utils/constants.dart';
import '../../utils/exchange_algorithm.dart';
import '../../utils/exchange_visualizer.dart';

/// 교체 관리 화면
class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  File? _selectedFile;        // 선택된 엑셀 파일
  TimetableData? _timetableData; // 파싱된 시간표 데이터
  TimetableDataSource? _dataSource; // Syncfusion DataGrid 데이터 소스
  List<GridColumn> _columns = []; // 그리드 컬럼
  List<StackedHeaderRow> _stackedHeaders = []; // 스택된 헤더
  bool _isLoading = false;    // 로딩 상태
  String? _errorMessage;     // 오류 메시지
  
  // 교체 서비스 인스턴스들
  final ExchangeService _exchangeService = ExchangeService();
  final CircularExchangeService _circularExchangeService = CircularExchangeService(); // 순환교체 구현 예정
  
  // 교체 모드 관련 변수들
  bool _isExchangeModeEnabled = false; // 1:1교체 모드 활성화 상태
  bool _isCircularExchangeModeEnabled = false; // 순환교체 모드 활성화 상태

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교체 관리'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  /// 메인 바디 위젯 구성
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 파일 선택 섹션
          _buildFileSelectionSection(),
          
          const SizedBox(height: 24),
          
          // 시간표 그리드 표시 섹션 (나머지 영역 전체 차지)
          if (_timetableData != null) 
            Expanded(child: _buildTimetableGridSection())
          else
            const Expanded(child: SizedBox.shrink()),
          
          // 오류 메시지 표시
          if (_errorMessage != null) _buildErrorMessageSection(),
        ],
      ),
    );
  }

  /// 파일 선택 섹션 UI
  Widget _buildFileSelectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.upload_file,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '엑셀 파일 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 선택된 파일이 있을 때와 없을 때 다른 UI 표시
            if (_selectedFile == null) ...[
              Text(
                '시간표가 포함된 엑셀 파일(.xlsx, .xls)을 선택하세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _selectExcelFile,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open),
                  label: Text(_isLoading ? '처리 중...' : '엑셀 파일 선택'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // 선택된 파일 정보 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '선택된 파일: ${_selectedFile!.path.split('\\').last}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _selectExcelFile,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_isLoading ? '처리 중...' : '다른 파일 선택'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleExchangeMode,
                      icon: Icon(_isExchangeModeEnabled ? Icons.swap_horiz : Icons.swap_horiz_outlined),
                      label: Text(_isExchangeModeEnabled ? '교체 모드 종료' : '1:1교체'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isExchangeModeEnabled ? Colors.orange.shade600 : Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleCircularExchangeMode,
                      icon: Icon(_isCircularExchangeModeEnabled ? Icons.refresh : Icons.refresh_outlined),
                      label: Text(_isCircularExchangeModeEnabled ? '순환교체 종료' : '순환교체'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCircularExchangeModeEnabled ? Colors.purple.shade600 : Colors.indigo.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 선택 해제 버튼 (항상 표시)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.clear),
                      label: const Text('선택 해제'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }



  /// 시간표 그리드 섹션 UI
  Widget _buildTimetableGridSection() {
    if (_timetableData == null || _dataSource == null) return const SizedBox.shrink();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.grid_on,
                  color: Colors.green.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '시간표 그리드 (Syncfusion)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
                const Spacer(),
                // 파싱 통계 표시
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    '교사 ${_timetableData!.teachers.length}명 | 슬롯 ${_timetableData!.timeSlots.length}개',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 교체 모드가 활성화된 경우에만 교체 가능한 시간 개수 표시
                if (_isExchangeModeEnabled)
                  ExchangeVisualizer.buildExchangeableCountWidget(_exchangeService.exchangeOptions.length),
              ],
            ),
            const SizedBox(height: 16),
            
            // Syncfusion DataGrid 위젯 (전체 영역 차지)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SfDataGrid(
                  source: _dataSource!,
                  columns: _columns,
                  stackedHeaderRows: _stackedHeaders,
                  gridLinesVisibility: GridLinesVisibility.both,
                  headerGridLinesVisibility: GridLinesVisibility.both,
                  headerRowHeight: AppConstants.headerRowHeight,
                  rowHeight: AppConstants.dataRowHeight,
                  allowColumnsResizing: false,
                  allowSorting: false,
                  allowEditing: false,
                  allowTriStateSorting: false,
                  allowPullToRefresh: false,
                  selectionMode: SelectionMode.none,
                  columnWidthMode: ColumnWidthMode.none,
                  frozenColumnsCount: 1, // 교사명 열(첫 번째 열) 고정
                  onCellTap: _onCellTap, // 셀 탭 이벤트 핸들러
                ),
              ),
            ),
          ],
        ),
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
      _startOneToOneExchange(details);
    }
    // 순환교체 모드인 경우 순환교체 처리 시작
    else if (_isCircularExchangeModeEnabled) {
      _startCircularExchange(details);
    }
  }
  
  /// 1:1 교체 처리 시작 - 교체 모드에서만 호출됨
  void _startOneToOneExchange(DataGridCellTapDetails details) {
    // 데이터 소스가 없는 경우 처리하지 않음
    if (_dataSource == null) {
      return;
    }
    
    // ExchangeService를 사용하여 교체 처리
    ExchangeResult result = _exchangeService.startOneToOneExchange(details, _dataSource!);
    
    if (result.isNoAction) {
      return; // 아무 동작하지 않음
    }
    
    setState(() {
      // UI 상태 업데이트는 ExchangeService에서 처리됨
    });
    
    // 교체 대상 선택 후 교체 가능한 시간 탐색 및 표시
    _processCellSelection();
  }
  
  /// 순환교체 처리 시작 - 순환교체 모드에서만 호출됨
  void _startCircularExchange(DataGridCellTapDetails details) {
    // 데이터 소스가 없는 경우 처리하지 않음
    if (_dataSource == null) {
      return;
    }
    
    // CircularExchangeService를 사용하여 순환교체 처리
    CircularExchangeResult result = _circularExchangeService.startCircularExchange(details, _dataSource!);
    
    if (result.isNoAction) {
      return; // 아무 동작하지 않음
    }
    
    setState(() {
      // UI 상태 업데이트
    });
    
    // 교체 대상 선택 후 교체 가능한 시간 탐색 및 표시
    _processCircularCellSelection();
    
    // 메시지 표시 제거 - 셀 선택 시 메시지 없이 동작
  }
  
  
  /// 셀 선택 후 처리 로직
  void _processCellSelection() {
    // 데이터 소스에 선택 상태 업데이트
    _dataSource?.updateSelection(
      _exchangeService.selectedTeacher, 
      _exchangeService.selectedDay, 
      _exchangeService.selectedPeriod
    );
    
    // 교체 가능한 시간 탐색 및 표시
    _updateExchangeableTimes();
    
    // 테마 기반 헤더 업데이트 (선택된 교시 헤더를 연한 파란색으로 표시)
    _updateHeaderTheme();
  }
  
  /// 순환교체 셀 선택 후 처리 로직
  void _processCircularCellSelection() {
    // 데이터 소스에 선택 상태 업데이트
    _dataSource?.updateSelection(
      _circularExchangeService.selectedTeacher, 
      _circularExchangeService.selectedDay, 
      _circularExchangeService.selectedPeriod
    );
    
    // 테마 기반 헤더 업데이트 (선택된 교시 헤더를 연한 파란색으로 표시)
    _updateHeaderTheme();
    
    // 순환 교체 경로 찾기 및 디버그 콘솔에 출력
    if (_timetableData != null) {
      List<CircularExchangePath> paths = _circularExchangeService.findCircularExchangePaths(
        _timetableData!.timeSlots,
        _timetableData!.teachers,
      );
      _circularExchangeService.logCircularExchangeInfo(paths, _timetableData!.timeSlots);
    }
  }
  
  /// 교체 모드 토글
  void _toggleExchangeMode() {
    setState(() {
      // 순환교체 모드가 활성화되어 있다면 비활성화
      if (_isCircularExchangeModeEnabled) {
        _isCircularExchangeModeEnabled = false;
      }
      
      _isExchangeModeEnabled = !_isExchangeModeEnabled;
      
      // 교체 모드가 비활성화되면 UI를 기본값으로 복원
      if (!_isExchangeModeEnabled) {
        _restoreUIToDefault();
      }
    });
    
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
    setState(() {
      // 1:1교체 모드가 활성화되어 있다면 비활성화
      if (_isExchangeModeEnabled) {
        _isExchangeModeEnabled = false;
      }
      
      _isCircularExchangeModeEnabled = !_isCircularExchangeModeEnabled;
      
      // 순환교체 모드가 비활성화되면 UI를 기본값으로 복원
      if (!_isCircularExchangeModeEnabled) {
        _restoreUIToDefault();
      }
    });
    
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
    
    // 교체 가능한 시간 업데이트 (빈 목록으로)
    _updateExchangeableTimes();
    
    // 헤더 테마를 기본값으로 복원
    _updateHeaderTheme();
    
    // 오류 메시지가 있다면 초기화
    if (_errorMessage != null) {
      _errorMessage = null;
    }
    
    // 모든 교체 모드 초기화
    _isExchangeModeEnabled = false;
    _isCircularExchangeModeEnabled = false;
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
            // 파일 선택 성공 메시지 표시
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('파일이 선택되었습니다: ${result.files.first.name}'),
                  backgroundColor: Colors.green.shade600,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
            
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
          
          // 파일 선택 성공 메시지 표시
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('파일이 선택되었습니다: ${selectedFile.path.split('/').last}'),
                backgroundColor: Colors.green.shade600,
                duration: const Duration(seconds: 1),
              ),
            );
          }
          
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
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('엑셀 파일을 성공적으로 읽었습니다!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
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
        
        // 파싱 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('시간표 파싱 완료! 교사 ${timetableData.teachers.length}명, 슬롯 ${timetableData.timeSlots.length}개'),
              backgroundColor: Colors.blue.shade600,
              duration: const Duration(seconds: 3),
            ),
          );
        }
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
    });
    
    // 교체 가능한 교사 정보도 초기화
    _dataSource?.updateExchangeableTeachers([]);
    
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
  
  /// 교체 가능한 시간 업데이트
  void _updateExchangeableTimes() {
    if (_timetableData == null || !_exchangeService.hasSelectedCell()) {
      setState(() {
        // 빈 목록으로 설정
      });
      _dataSource?.updateExchangeOptions([]);
      return;
    }
    
    // ExchangeService를 사용하여 교체 가능한 시간 탐색
    List<ExchangeOption> options = _exchangeService.updateExchangeableTimes(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
    );
    
    setState(() {
      // UI 상태 업데이트
    });
    
    // 데이터 소스에 교체 옵션 업데이트
    _dataSource?.updateExchangeOptions(options);
    
    // 교체 가능한 교사 정보를 별도로 업데이트
    List<Map<String, dynamic>> exchangeableTeachers = _exchangeService.getCurrentExchangeableTeachers(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
    );
    _dataSource?.updateExchangeableTeachers(exchangeableTeachers);
    
    // 디버그 로그 출력
    _exchangeService.logExchangeableInfo(exchangeableTeachers);
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
    );
    
    _columns = result.columns; // 헤더만 업데이트
    setState(() {}); // UI 갱신
  }
}

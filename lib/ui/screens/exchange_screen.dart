import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/excel_service.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/constants.dart';
import '../../models/time_slot.dart';

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
                  allowColumnsResizing: true,
                  allowSorting: false,
                  allowEditing: false,
                  allowTriStateSorting: false,
                  allowPullToRefresh: false,
                  selectionMode: SelectionMode.none,
                  columnWidthMode: ColumnWidthMode.none,
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
    
    // 요일별로 데이터 그룹화
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = _groupTimeSlotsByDayAndPeriod();
    
    // 요일 목록 추출 및 정렬
    List<String> days = groupedData.keys.toList()..sort(_compareDays);
    
    // 교시 목록 추출 및 정렬
    Set<int> allPeriods = {};
    for (var dayData in groupedData.values) {
      allPeriods.addAll(dayData.keys);
    }
    List<int> periods = allPeriods.toList()..sort();
    
    // 컬럼 생성
    _columns = _createColumns(days, periods);
    
    // 스택된 헤더 생성
    _stackedHeaders = _createStackedHeaders(days, periods);
    
    // 데이터 소스 생성
    _dataSource = TimetableDataSource(
      timeSlots: _timetableData!.timeSlots,
      teachers: _timetableData!.teachers,
    );
  }
  
  /// TimeSlot 리스트를 요일별, 교시별로 그룹화
  Map<String, Map<int, Map<String, TimeSlot?>>> _groupTimeSlotsByDayAndPeriod() {
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = {};
    
    for (TimeSlot slot in _timetableData!.timeSlots) {
      if (slot.dayOfWeek == null || slot.period == null || slot.teacher == null) {
        continue;
      }
      
      String dayName = _getDayName(slot.dayOfWeek!);
      int period = slot.period!;
      String teacherName = slot.teacher!;
      
      // 요일별 데이터 초기화
      groupedData.putIfAbsent(dayName, () => {});
      
      // 교시별 데이터 초기화
      groupedData[dayName]!.putIfAbsent(period, () => {});
      
      // 교사별 데이터 저장
      groupedData[dayName]![period]![teacherName] = slot;
    }
    
    return groupedData;
  }
  
  /// 요일 번호를 요일명으로 변환
  String _getDayName(int dayOfWeek) {
    const dayNames = ['월', '화', '수', '목', '금'];
    if (dayOfWeek >= 1 && dayOfWeek <= 5) {
      return dayNames[dayOfWeek - 1];
    }
    return '월'; // 기본값
  }
  
  /// 요일 정렬을 위한 비교 함수
  int _compareDays(String a, String b) {
    const dayOrder = ['월', '화', '수', '목', '금'];
    int indexA = dayOrder.indexOf(a);
    int indexB = dayOrder.indexOf(b);
    
    if (indexA == -1) indexA = 999;
    if (indexB == -1) indexB = 999;
    
    return indexA.compareTo(indexB);
  }
  
  /// Syncfusion DataGrid 컬럼 생성
  List<GridColumn> _createColumns(List<String> days, List<int> periods) {
    List<GridColumn> columns = [];
    
    // 첫 번째 컬럼: 교사명
    columns.add(
      GridColumn(
        columnName: 'teacher',
        width: 120,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            border: Border(
              right: BorderSide(color: Colors.grey, width: 1),
              bottom: BorderSide(color: Colors.grey, width: 1),
            ),
          ),
          child: const Text(
            '교사',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
    
    // 요일별 교시 컬럼 생성
    for (String day in days) {
      for (int period in periods) {
        columns.add(
          GridColumn(
            columnName: '${day}_$period',
            width: 100,
            label: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                border: Border(
                  right: BorderSide(color: Colors.grey, width: 1),
                  bottom: BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              child: Text(
                period.toString(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }
    }
    
    return columns;
  }
  
  /// 스택된 헤더 생성 (요일별 셀 병합 효과)
  List<StackedHeaderRow> _createStackedHeaders(List<String> days, List<int> periods) {
    List<StackedHeaderRow> stackedHeaders = [];
    
    // 요일 헤더 행 생성
    List<StackedHeaderCell> headerCells = [];
    
    // 교사명 헤더 (병합되지 않음)
    headerCells.add(
      StackedHeaderCell(
        columnNames: ['teacher'],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE3F2FD),
            border: Border(
              right: BorderSide(color: Colors.grey, width: 1),
              bottom: BorderSide(color: Colors.grey, width: 1),
            ),
          ),
          child: const Text(
            '교사',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
    
    // 요일별 헤더 (교시 수만큼 병합)
    for (String day in days) {
      headerCells.add(
        StackedHeaderCell(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              border: Border(
                right: BorderSide(color: Colors.grey, width: 1),
                bottom: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          columnNames: periods.map((period) => '${day}_$period').toList(),
        ),
      );
    }
    
    stackedHeaders.add(StackedHeaderRow(cells: headerCells));
    
    return stackedHeaders;
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


  /// 선택 해제 메서드
  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _timetableData = null;
      _dataSource = null;
      _columns = [];
      _stackedHeaders = [];
      _errorMessage = null;
    });
  }

  /// 오류 메시지 제거 메서드
  void _clearError() {
    setState(() {
      _errorMessage = null;
    });
  }
}

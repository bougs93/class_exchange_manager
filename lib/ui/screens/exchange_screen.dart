import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/excel_service.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/syncfusion_timetable_helper.dart';
import '../../utils/constants.dart';
import '../../utils/exchange_algorithm.dart';
import '../../utils/exchange_visualizer.dart';
import '../../utils/logger.dart';
import '../../models/time_slot.dart';
import '../../models/teacher.dart';

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
  
  // 셀 선택 관련 변수들
  String? _selectedTeacher;   // 선택된 교사명
  String? _selectedDay;       // 선택된 요일
  int? _selectedPeriod;       // 선택된 교시
  
  // 교체 가능한 시간 관련 변수들
  List<ExchangeOption> _exchangeOptions = []; // 교체 가능한 시간 옵션들

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
                const SizedBox(width: 8),
                // 교체 가능한 시간 개수 표시
                ExchangeVisualizer.buildExchangeableCountWidget(_exchangeOptions.length),
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
    
    // SyncfusionTimetableHelper를 사용하여 데이터 생성 (테마 기반)
    final result = SyncfusionTimetableHelper.convertToSyncfusionData(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
      selectedDay: _selectedDay,      // 선택된 요일 전달
      selectedPeriod: _selectedPeriod, // 선택된 교시 전달
    );
    
    _columns = result.columns;
    _stackedHeaders = result.stackedHeaders;
    
    // 데이터 소스 생성
    _dataSource = TimetableDataSource(
      timeSlots: _timetableData!.timeSlots,
      teachers: _timetableData!.teachers,
    );
  }
  
  /// 셀 탭 이벤트 핸들러 - 클릭 시 선택/해제 토글
  void _onCellTap(DataGridCellTapDetails details) {
    // 교사명 열은 선택하지 않음
    if (details.column.columnName == 'teacher') return;
    
    // 컬럼명에서 요일과 교시 추출 (예: "월_1", "화_2")
    List<String> parts = details.column.columnName.split('_');
    if (parts.length == 2) {
      String day = parts[0];
      int period = int.tryParse(parts[1]) ?? 0;
      
      // 선택된 셀의 교사명 찾기 (헤더를 고려한 행 인덱스 계산)
      String teacherName = '';
      if (_dataSource != null) {
        // Syncfusion DataGrid에서 헤더는 다음과 같이 구성됨:
        // - 일반 헤더: 1개 (컬럼명 표시)
        // - 스택된 헤더: 1개 (요일별 병합)
        // 총 2개의 헤더 행이 있으므로 실제 데이터 행 인덱스는 2를 빼야 함
        int actualRowIndex = details.rowColumnIndex.rowIndex - 2;
        
        if (actualRowIndex >= 0 && actualRowIndex < _dataSource!.dataGridRows.length) {
          DataGridRow row = _dataSource!.dataGridRows[actualRowIndex];
          for (DataGridCell rowCell in row.getCells()) {
            if (rowCell.columnName == 'teacher') {
              teacherName = rowCell.value.toString();
              break;
            }
          }
        }
      }
      
      // 동일한 셀을 다시 클릭했는지 확인 (토글 기능)
      bool isSameCell = _selectedTeacher == teacherName && 
                       _selectedDay == day && 
                       _selectedPeriod == period;
      
      setState(() {
        if (isSameCell) {
          // 동일한 셀 클릭 시 선택 해제
          _selectedTeacher = null;
          _selectedDay = null;
          _selectedPeriod = null;
        } else {
          // 새로운 셀 선택
          _selectedTeacher = teacherName;
          _selectedDay = day;
          _selectedPeriod = period;
        }
      });
      
      // 데이터 소스에 선택 상태 업데이트
      _dataSource?.updateSelection(_selectedTeacher, _selectedDay, _selectedPeriod);
      
      // 교체 가능한 시간 탐색 및 표시
      _updateExchangeableTimes();
      
      // 해당 교사의 빈시간 검사 및 디버그 출력
      _checkTeacherEmptySlots();
      
      // 테마 기반 헤더 업데이트 (선택된 교시 헤더를 연한 파란색으로 표시)
      _updateHeaderTheme();
    }
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
      // 셀 선택 상태도 초기화
      _selectedTeacher = null;
      _selectedDay = null;
      _selectedPeriod = null;
    });
    
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
    if (_timetableData == null || _selectedTeacher == null || _selectedDay == null || _selectedPeriod == null) {
      setState(() {
        _exchangeOptions = [];
      });
      _dataSource?.updateExchangeOptions(_exchangeOptions);
      return;
    }
    
    // 교체 가능한 시간 탐색
    List<ExchangeOption> options = ExchangeAlgorithm.findExchangeableTimes(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
      _selectedTeacher!,
      _selectedDay!,
      _selectedPeriod!,
    );
    
    setState(() {
      _exchangeOptions = options;
    });
    
    // 데이터 소스에 교체 옵션 업데이트
    _dataSource?.updateExchangeOptions(_exchangeOptions);
    
  }
  
  
  /// 해당 교사의 빈시간 검사 및 디버그 출력
  void _checkTeacherEmptySlots() {
    if (_timetableData == null || _selectedTeacher == null) return;
    
    // 선택된 셀의 학급 정보 가져오기
    String? selectedClassName = _getSelectedClassName();
    if (selectedClassName == null) {
      return;
    }
    
    // 요일별로 빈시간 검사
    List<String> days = ['월', '화', '수', '목', '금'];
    List<int> periods = [1, 2, 3, 4, 5, 6, 7];
    
    // 교사 빈시간 검사
    List<String> allEmptySlots = [];
    
    for (String day in days) {
      List<String> emptySlots = [];
      
      for (int period in periods) {
        // 해당 교사의 해당 요일, 교시에 수업이 있는지 확인
        bool hasClass = _timetableData!.timeSlots.any((slot) => 
          slot.teacher == _selectedTeacher &&
          slot.dayOfWeek == _getDayNumber(day) &&
          slot.period == period &&
          slot.isNotEmpty
        );
        
        if (!hasClass) {
          emptySlots.add('$period교시');
        }
      }
      
      if (emptySlots.isNotEmpty) {
        allEmptySlots.add('$day요일: ${emptySlots.join(', ')}');
        // 빈시간에 같은 반을 가르치는 교사 찾기
        _findSameClassTeachers(day, emptySlots, selectedClassName);
      }
    }
    
    // 빈시간이 있는 경우에만 결과 출력
    if (allEmptySlots.isNotEmpty) {
      AppLogger.teacherEmptySlotsInfo('$_selectedTeacher 교사 빈시간: ${allEmptySlots.join(' | ')}');
    } else {
      AppLogger.teacherEmptySlotsInfo('$_selectedTeacher 교사: 빈시간 없음');
    }
  }
  
  /// 선택된 셀의 학급 정보 가져오기
  String? _getSelectedClassName() {
    if (_timetableData == null || _selectedTeacher == null || _selectedDay == null || _selectedPeriod == null) {
      return null;
    }
    
    // 선택된 셀의 TimeSlot 찾기
    TimeSlot? selectedSlot = _timetableData!.timeSlots.firstWhere(
      (slot) => slot.teacher == _selectedTeacher &&
                slot.dayOfWeek == _getDayNumber(_selectedDay!) &&
                slot.period == _selectedPeriod,
      orElse: () => TimeSlot.empty(),
    );
    
    return selectedSlot.className;
  }
  
  /// 빈시간에 같은 반을 가르치는 교사 찾기
  void _findSameClassTeachers(String day, List<String> emptySlots, String selectedClassName) {
    List<String> allSameClassTeachers = [];
    
    for (String emptySlot in emptySlots) {
      int period = int.tryParse(emptySlot.replaceAll('교시', '')) ?? 0;
      if (period == 0) continue;
      
      // 모든 교사 중에서 해당 시간에 같은 반을 가르치는 교사 찾기
      List<String> sameClassTeachers = [];
      
      for (Teacher teacher in _timetableData!.teachers) {
        if (teacher.name == _selectedTeacher) continue; // 자기 자신 제외
        
        // 해당 교사가 해당 시간에 같은 반을 가르치는지 확인
        bool hasSameClass = _timetableData!.timeSlots.any((slot) => 
          slot.teacher == teacher.name &&
          slot.dayOfWeek == _getDayNumber(day) &&
          slot.period == period &&
          slot.className == selectedClassName &&
          slot.isNotEmpty
        );
        
        if (hasSameClass) {
          // 해당 교사의 과목 정보도 함께 출력
          TimeSlot? teacherSlot = _timetableData!.timeSlots.firstWhere(
            (slot) => slot.teacher == teacher.name &&
                      slot.dayOfWeek == _getDayNumber(day) &&
                      slot.period == period &&
                      slot.className == selectedClassName,
            orElse: () => TimeSlot.empty(),
          );
          
          String subject = teacherSlot.subject ?? '과목 없음';
          sameClassTeachers.add('${teacher.name}($subject)');
        }
      }
      
      if (sameClassTeachers.isNotEmpty) {
        allSameClassTeachers.add('$period교시: ${sameClassTeachers.join(', ')}');
      }
    }
    
    // 같은 반 교사가 있는 경우에만 출력
    if (allSameClassTeachers.isNotEmpty) {
      AppLogger.teacherEmptySlotsInfo('$day요일 교체 가능한 교사: ${allSameClassTeachers.join(' | ')}');
    }
  }
  
  /// 요일명을 숫자로 변환
  int _getDayNumber(String day) {
    const dayMap = {
      '월': 1,
      '화': 2,
      '수': 3,
      '목': 4,
      '금': 5,
    };
    return dayMap[day] ?? 1;
  }
  
  /// 테마 기반 헤더 업데이트 (선택된 교시 헤더를 연한 파란색으로 표시)
  void _updateHeaderTheme() {
    if (_timetableData == null) return;
    
    // 선택된 교시 정보를 전달하여 헤더만 업데이트
    final result = SyncfusionTimetableHelper.convertToSyncfusionData(
      _timetableData!.timeSlots,
      _timetableData!.teachers,
      selectedDay: _selectedDay,      // 테마에서 사용할 선택 정보
      selectedPeriod: _selectedPeriod,
    );
    
    _columns = result.columns; // 헤더만 업데이트
    setState(() {}); // UI 갱신
  }
}

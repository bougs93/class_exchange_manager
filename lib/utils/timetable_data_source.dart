import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/circular_exchange_path.dart';
import '../ui/widgets/simplified_timetable_cell.dart';
import 'exchange_algorithm.dart';
import 'day_utils.dart';

/// Syncfusion DataGrid용 시간표 데이터 소스
class TimetableDataSource extends DataGridSource {
  TimetableDataSource({
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
  }) {
    _timeSlots = timeSlots;
    _teachers = teachers;
    _buildDataGridRows();
  }

  List<TimeSlot> _timeSlots = [];
  List<Teacher> _teachers = [];
  List<DataGridRow> _dataGridRows = [];
  
  // 셀 선택 관련 변수들
  String? _selectedTeacher;
  String? _selectedDay;
  int? _selectedPeriod;
  
  // 교체 가능한 교사 정보 (교사명, 요일, 교시)
  List<Map<String, dynamic>> _exchangeableTeachers = [];
  
  // 교체 옵션 정보
  List<ExchangeOption> _exchangeOptions = [];
  
  // 선택된 순환교체 경로
  CircularExchangePath? _selectedCircularPath;

  /// DataGrid 행 데이터 빌드
  void _buildDataGridRows() {
    // 요일별로 데이터 그룹화
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = _groupTimeSlotsByDayAndPeriod();
    
    // 요일 목록 추출 및 정렬
    List<String> days = groupedData.keys.toList()..sort(DayUtils.compareDays);
    
    // 교시 목록 추출 및 정렬
    Set<int> allPeriods = {};
    for (var dayData in groupedData.values) {
      allPeriods.addAll(dayData.keys);
    }
    List<int> periods = allPeriods.toList()..sort();
    
    _dataGridRows = _createRows(groupedData, days, periods);
  }

  /// TimeSlot 리스트를 요일별, 교시별로 그룹화
  Map<String, Map<int, Map<String, TimeSlot?>>> _groupTimeSlotsByDayAndPeriod() {
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = {};
    
    for (TimeSlot slot in _timeSlots) {
      if (slot.dayOfWeek == null || slot.period == null || slot.teacher == null) {
        continue;
      }
      
      String dayName = DayUtils.getDayName(slot.dayOfWeek!);
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


  /// DataGrid 행 생성
  List<DataGridRow> _createRows(
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData,
    List<String> days,
    List<int> periods,
  ) {
    List<DataGridRow> rows = [];
    
    for (Teacher teacher in _teachers) {
      List<DataGridCell> cells = [];
      
      // 교사명 셀
      cells.add(
        DataGridCell<String>(
          columnName: 'teacher',
          value: teacher.name,
        ),
      );
      
      // 각 요일별 교시 데이터 추가
      for (String day in days) {
        for (int period in periods) {
          String columnName = '${day}_$period';
          TimeSlot? slot = groupedData[day]?[period]?[teacher.name];
          
          String cellValue = '';
          if (slot != null && slot.isNotEmpty) {
            // 학급번호와 과목명을 줄바꿈으로 구분하여 표시
            if (slot.className != null && slot.className!.isNotEmpty) {
              cellValue += slot.className!;
            }
            if (slot.subject != null && slot.subject!.isNotEmpty) {
              if (cellValue.isNotEmpty) {
                cellValue += '\n';
              }
              cellValue += slot.subject!;
            }
          }
          
          cells.add(
            DataGridCell<String>(
              columnName: columnName,
              value: cellValue,
            ),
          );
        }
      }
      
      rows.add(DataGridRow(cells: cells));
    }
    
    return rows;
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;
  
  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
      return DataGridRowAdapter(
        cells: row.getCells().asMap().entries.map<Widget>((entry) {
          DataGridCell dataGridCell = entry.value;
          
          // 선택 상태 확인
          bool isSelected = false;
          bool isTeacherColumn = dataGridCell.columnName == 'teacher';
          
          if (isTeacherColumn) {
            // 교사명 열: 해당 교사가 선택된 경우
            isSelected = _isTeacherSelected(dataGridCell.value.toString());
          } else {
            // 교시 열: 해당 요일의 교시가 선택된 경우 또는 선택된 셀인 경우
            List<String> parts = dataGridCell.columnName.split('_');
            if (parts.length == 2) {
              String day = parts[0];
              int period = int.tryParse(parts[1]) ?? 0;
              
              // 교사명 찾기
              String teacherName = '';
              for (DataGridCell rowCell in row.getCells()) {
                if (rowCell.columnName == 'teacher') {
                  teacherName = rowCell.value.toString();
                  break;
                }
              }
              
              // 선택된 셀인지 확인
              isSelected = _isCellSelected(teacherName, day, period);
            }
          }
          
          // 요일별 구분선을 위한 로직
          bool isLastColumnOfDay = false;
          if (!isTeacherColumn) {
            // 컬럼명에서 요일과 교시 추출 (예: "월_1", "월_2", ..., "월_7", "화_1", ...)
            List<String> parts = dataGridCell.columnName.split('_');
            if (parts.length == 2) {
              String day = parts[0];
              int period = int.tryParse(parts[1]) ?? 0;
              
              // 현재 요일의 마지막 교시인지 확인 (7교시)
              isLastColumnOfDay = period == 7;
              
              // 마지막 요일(금요일)의 마지막 교시는 전체 테이블의 마지막이므로 구분선을 두껍게 하지 않음
              if (day == '금' && period == 7) {
                isLastColumnOfDay = false;
              }
            }
          }
          
          // 교체 가능한 교사인지 확인
          bool isExchangeableTeacher = false;
          
          // 순환교체 경로에 포함된 셀인지 확인
          bool isInCircularPath = false;
          int? circularPathStep;
          
          // 교사명 찾기
          String teacherName = '';
          for (DataGridCell rowCell in row.getCells()) {
            if (rowCell.columnName == 'teacher') {
              teacherName = rowCell.value.toString();
              break;
            }
          }
          
          if (isTeacherColumn) {
            // 교사명 열인 경우: 해당 교사가 교체 가능한 교사인지 확인
            isExchangeableTeacher = _isExchangeableTeacherForTeacher(teacherName);
            isInCircularPath = _isTeacherInCircularPath(teacherName);
          } else {
            // 데이터 셀인 경우: 해당 교사와 시간이 교체 가능한지 확인
            String day = '';
            int period = 0;
            
            // 요일과 교시 추출
            List<String> parts = dataGridCell.columnName.split('_');
            if (parts.length == 2) {
              day = parts[0];
              period = int.tryParse(parts[1]) ?? 0;
            }
            
            // 교체 가능한 교사인지 확인
            isExchangeableTeacher = _isExchangeableTeacher(teacherName, day, period);
            // 순환교체 경로에 포함된 셀인지 확인
            isInCircularPath = _isInCircularPath(teacherName, day, period);
            // 순환교체 경로에서의 단계 번호 가져오기
            circularPathStep = _getCircularPathStep(teacherName, day, period);
          }
          
          // SimplifiedTimetableCell을 사용하여 일관된 스타일 적용
          return SimplifiedTimetableCell(
            content: dataGridCell.value.toString(),
            isTeacherColumn: isTeacherColumn,
            isSelected: isSelected,
            isExchangeable: isExchangeableTeacher,
            isLastColumnOfDay: isLastColumnOfDay,
            isInCircularPath: isInCircularPath,
            circularPathStep: circularPathStep,
          );
        }).toList(),
      );
  }

  /// 선택 상태 업데이트
  void updateSelection(String? teacher, String? day, int? period) {
    _selectedTeacher = teacher;
    _selectedDay = day;
    _selectedPeriod = period;
    notifyListeners(); // UI 갱신
  }
  
  /// 특정 셀이 선택된 상태인지 확인
  bool _isCellSelected(String teacherName, String day, int period) {
    return _selectedTeacher == teacherName && 
           _selectedDay == day && 
           _selectedPeriod == period;
  }
  
  /// 특정 교사가 선택된 상태인지 확인
  bool _isTeacherSelected(String teacherName) {
    return _selectedTeacher == teacherName;
  }
  
  /// 교체 가능한 교사 정보 업데이트
  void updateExchangeableTeachers(List<Map<String, dynamic>> exchangeableTeachers) {
    _exchangeableTeachers = exchangeableTeachers;
    notifyListeners(); // UI 갱신
  }
  
  /// 교체 옵션 업데이트
  void updateExchangeOptions(List<ExchangeOption> exchangeOptions) {
    _exchangeOptions = exchangeOptions;
    notifyListeners(); // UI 갱신
  }
  
  /// 교체 옵션 가져오기
  List<ExchangeOption> get exchangeOptions => _exchangeOptions;
  
  /// 교체 가능한 옵션 개수
  int get exchangeableCount => _exchangeOptions.where((option) => option.isExchangeable).length;
  
  /// 선택된 순환교체 경로 업데이트
  void updateSelectedCircularPath(CircularExchangePath? path) {
    _selectedCircularPath = path;
    notifyListeners(); // UI 갱신
  }
  
  
  /// 교체 가능한 교사인지 확인 (교사명, 요일, 교시 기준)
  bool _isExchangeableTeacher(String teacherName, String day, int period) {
    return _exchangeableTeachers.any((teacher) => 
      teacher['teacherName'] == teacherName &&
      teacher['day'] == day &&
      teacher['period'] == period
    );
  }
  
  /// 교체 가능한 교사인지 확인 (교사명만 기준)
  bool _isExchangeableTeacherForTeacher(String teacherName) {
    return _exchangeableTeachers.any((teacher) => 
      teacher['teacherName'] == teacherName
    );
  }
  
  /// 순환교체 경로에 포함된 셀인지 확인
  bool _isInCircularPath(String teacherName, String day, int period) {
    if (_selectedCircularPath == null) return false;
    
    return _selectedCircularPath!.nodes.any((node) => 
      node.teacherName == teacherName &&
      node.day == day &&
      node.period == period
    );
  }
  
  /// 순환교체 경로에서 해당 셀의 단계 번호 가져오기
  int? _getCircularPathStep(String teacherName, String day, int period) {
    if (_selectedCircularPath == null) return null;
    
    for (int i = 0; i < _selectedCircularPath!.nodes.length; i++) {
      final node = _selectedCircularPath!.nodes[i];
      if (node.teacherName == teacherName &&
          node.day == day &&
          node.period == period) {
        // 첫 번째 노드(시작점)는 오버레이 표시하지 않음 (null 반환)
        if (i == 0) {
          return null;
        }
        // 두 번째 노드부터는 1, 2, 3... 순서로 표시
        return i;
      }
    }
    
    return null;
  }
  
  /// 순환교체 경로에 포함된 교사인지 확인
  bool _isTeacherInCircularPath(String teacherName) {
    if (_selectedCircularPath == null) return false;
    
    return _selectedCircularPath!.nodes.any((node) => 
      node.teacherName == teacherName
    );
  }
  

  /// 데이터 업데이트
  void updateData(List<TimeSlot> timeSlots, List<Teacher> teachers) {
    _timeSlots = timeSlots;
    _teachers = teachers;
    _buildDataGridRows();
    notifyListeners();
  }
}

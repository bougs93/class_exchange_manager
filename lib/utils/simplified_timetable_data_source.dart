import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../ui/widgets/simplified_timetable_cell.dart';

/// 단순화된 시간표 데이터 소스
class SimplifiedTimetableDataSource extends DataGridSource {
  SimplifiedTimetableDataSource({
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
  
  // 선택 상태 (단순화)
  String? _selectedTeacher;
  String? _selectedDay;
  int? _selectedPeriod;
  
  // 교체 가능한 교사 정보
  List<Map<String, dynamic>> _exchangeableTeachers = [];

  /// DataGrid 행 데이터 빌드
  void _buildDataGridRows() {
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = _groupTimeSlotsByDayAndPeriod();
    List<String> days = groupedData.keys.toList()..sort(_compareDays);
    
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
      
      String dayName = _getDayName(slot.dayOfWeek!);
      int period = slot.period!;
      String teacherName = slot.teacher!;
      
      groupedData.putIfAbsent(dayName, () => {});
      groupedData[dayName]!.putIfAbsent(period, () => {});
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
    return '월';
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
        
        bool isTeacherColumn = dataGridCell.columnName == 'teacher';
        bool isSelected = _isCellSelected(dataGridCell, row);
        bool isExchangeable = _isExchangeableCell(dataGridCell, row);
        bool isLastColumnOfDay = _isLastColumnOfDay(dataGridCell);
        
        return SimplifiedTimetableCell(
          content: dataGridCell.value.toString(),
          isTeacherColumn: isTeacherColumn,
          isSelected: isSelected,
          isExchangeable: isExchangeable,
          isLastColumnOfDay: isLastColumnOfDay,
        );
      }).toList(),
    );
  }

  /// 선택 상태 업데이트
  void updateSelection(String? teacher, String? day, int? period) {
    _selectedTeacher = teacher;
    _selectedDay = day;
    _selectedPeriod = period;
    notifyListeners();
  }
  
  /// 교체 가능한 교사 정보 업데이트
  void updateExchangeableTeachers(List<Map<String, dynamic>> exchangeableTeachers) {
    _exchangeableTeachers = exchangeableTeachers;
    notifyListeners();
  }
  
  /// 특정 셀이 선택된 상태인지 확인
  bool _isCellSelected(DataGridCell dataGridCell, DataGridRow row) {
    if (dataGridCell.columnName == 'teacher') {
      return _selectedTeacher == dataGridCell.value.toString();
    }
    
    List<String> parts = dataGridCell.columnName.split('_');
    if (parts.length == 2) {
      String day = parts[0];
      int period = int.tryParse(parts[1]) ?? 0;
      String teacherName = _getTeacherNameFromRow(row);
      
      return _selectedTeacher == teacherName && 
             _selectedDay == day && 
             _selectedPeriod == period;
    }
    
    return false;
  }
  
  /// 특정 셀이 교체 가능한 상태인지 확인
  bool _isExchangeableCell(DataGridCell dataGridCell, DataGridRow row) {
    if (dataGridCell.columnName == 'teacher') {
      String teacherName = dataGridCell.value.toString();
      return _exchangeableTeachers.any((teacher) => 
        teacher['teacherName'] == teacherName
      );
    }
    
    List<String> parts = dataGridCell.columnName.split('_');
    if (parts.length == 2) {
      String day = parts[0];
      int period = int.tryParse(parts[1]) ?? 0;
      String teacherName = _getTeacherNameFromRow(row);
      
      return _exchangeableTeachers.any((teacher) => 
        teacher['teacherName'] == teacherName &&
        teacher['day'] == day &&
        teacher['period'] == period
      );
    }
    
    return false;
  }
  
  /// 행에서 교사명 추출
  String _getTeacherNameFromRow(DataGridRow row) {
    for (DataGridCell cell in row.getCells()) {
      if (cell.columnName == 'teacher') {
        return cell.value.toString();
      }
    }
    return '';
  }
  
  /// 마지막 열인지 확인
  bool _isLastColumnOfDay(DataGridCell dataGridCell) {
    if (dataGridCell.columnName == 'teacher') return false;
    
    List<String> parts = dataGridCell.columnName.split('_');
    if (parts.length == 2) {
      String day = parts[0];
      int period = int.tryParse(parts[1]) ?? 0;
      return period == 7 && day != '금';
    }
    return false;
  }
}

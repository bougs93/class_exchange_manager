import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';

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

  /// DataGrid 행 데이터 빌드
  void _buildDataGridRows() {
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
      cells: row.getCells().map<Widget>((dataGridCell) {
        // 셀과 텍스트 간 여백을 최소화
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dataGridCell.columnName == 'teacher' 
                ? const Color(0xFFF5F5F5) 
                : Colors.white,
            border: const Border(
              right: BorderSide(color: Colors.grey, width: 0.5),
              bottom: BorderSide(color: Colors.grey, width: 0.5),
            ),
          ),
          child: Text(
            dataGridCell.value.toString(),
            style: const TextStyle(
              fontSize: 10,
              height: 1.2, // 줄 간격 최소화
            ),
            textAlign: TextAlign.center,
            maxLines: 2, // 최대 2줄까지 표시
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
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

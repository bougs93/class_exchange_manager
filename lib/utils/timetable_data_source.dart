import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import 'constants.dart';
import 'exchange_algorithm.dart';

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
  
  // 교체 가능한 시간 관련 변수들
  List<ExchangeOption> _exchangeOptions = [];

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
  
  /// DataGrid 행에 접근할 수 있는 getter
  List<DataGridRow> get dataGridRows => _dataGridRows;

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
          
          // 배경색 결정 (교체 가능한 시간 고려)
          Color backgroundColor;
          if (isTeacherColumn) {
            backgroundColor = isSelected 
                ? Colors.blue.shade100  // 선택된 교사명 열 - 연한 파란색
                : const Color(AppConstants.teacherHeaderColor);
          } else {
            if (isSelected) {
              backgroundColor = Colors.blue.shade100; // 선택된 교시 셀 - 연한 파란색
            } else {
              backgroundColor = const Color(AppConstants.dataCellColor); // 기본 색상
            }
          }
          
          // 셀과 텍스트 간 여백을 최소화
          return Container(
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                right: BorderSide(
                  color: Colors.grey, 
                  width: isTeacherColumn 
                      ? 3  // 교사명과 월요일 사이 구분선을 두껍게
                      : (isLastColumnOfDay ? 3 : 0.5), // 요일별 구분선을 두껍게
                ),
                bottom: const BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: Stack(
              children: [
                Text(
                  dataGridCell.value.toString(),
                  style: TextStyle(
                    fontSize: AppConstants.dataFontSize,
                    height: AppConstants.dataLineHeight, // 줄 간격 최소화
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, // 선택된 셀은 굵게
                    color: _getTextColor(dataGridCell, row, isSelected), // 교체 가능한 시간 텍스트 색상
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2, // 최대 2줄까지 표시
                  overflow: TextOverflow.ellipsis,
                ),
                // 교체 가능한 시간 아이콘 표시
                if (!isTeacherColumn && !isSelected)
                  _buildExchangeIcon(dataGridCell, row),
              ],
            ),
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
  

  /// 교체 가능한 시간 옵션 업데이트
  void updateExchangeOptions(List<ExchangeOption> exchangeOptions) {
    _exchangeOptions = exchangeOptions;
    notifyListeners(); // UI 갱신
  }
  
  /// 현재 셀의 TimeSlot 가져오기
  TimeSlot? _getCurrentTimeSlot(DataGridCell dataGridCell, DataGridRow row) {
    if (dataGridCell.columnName == 'teacher') return null;
    
    List<String> parts = dataGridCell.columnName.split('_');
    if (parts.length != 2) return null;
    
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
    
    // 해당 TimeSlot 찾기
    return _timeSlots.firstWhere(
      (slot) => slot.teacher == teacherName && 
                _getDayName(slot.dayOfWeek!) == day && 
                slot.period == period,
      orElse: () => TimeSlot.empty(),
    );
  }
  
  /// 교체 가능한 시간인지 확인
  bool _isExchangeableSlot(TimeSlot slot) {
    return _exchangeOptions.any((option) => 
      option.timeSlot.dayOfWeek == slot.dayOfWeek && 
      option.timeSlot.period == slot.period && 
      option.timeSlot.teacher == slot.teacher
    );
  }
  
  /// 텍스트 색상 결정
  Color _getTextColor(DataGridCell dataGridCell, DataGridRow row, bool isSelected) {
    if (isSelected) return Colors.black;
    
    TimeSlot? currentSlot = _getCurrentTimeSlot(dataGridCell, row);
    if (currentSlot != null && _isExchangeableSlot(currentSlot)) {
      return Colors.red.shade700; // 교체 가능한 시간은 빨간색 텍스트
    }
    
    return Colors.black; // 기본 텍스트 색상
  }
  
  /// 교체 가능한 시간 아이콘 빌드
  Widget _buildExchangeIcon(DataGridCell dataGridCell, DataGridRow row) {
    TimeSlot? currentSlot = _getCurrentTimeSlot(dataGridCell, row);
    if (currentSlot == null || !_isExchangeableSlot(currentSlot)) {
      return const SizedBox.shrink();
    }
    
    // 교체 옵션에서 해당 슬롯의 교체 유형 찾기
    ExchangeOption? option = _exchangeOptions.firstWhere(
      (opt) => opt.timeSlot.dayOfWeek == currentSlot.dayOfWeek && 
               opt.timeSlot.period == currentSlot.period && 
               opt.timeSlot.teacher == currentSlot.teacher,
      orElse: () => ExchangeOption(
        timeSlot: currentSlot,
        teacherName: currentSlot.teacher ?? '',
        type: ExchangeType.notExchangeable,
        priority: 999,
        reason: '교체 불가',
      ),
    );
    
    if (!option.isExchangeable) {
      return const SizedBox.shrink();
    }
    
    // 교체 유형에 따른 아이콘
    IconData iconData;
    Color iconColor;
    
    switch (option.type) {
      case ExchangeType.sameClass:
        iconData = Icons.swap_horiz;
        iconColor = Colors.red.shade600;
        break;
      case ExchangeType.notExchangeable:
        return const SizedBox.shrink();
    }
    
    return Positioned(
      top: 2,
      right: 2,
      child: Icon(
        iconData,
        color: iconColor,
        size: 12,
      ),
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

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/circular_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import 'constants.dart';
import 'simplified_timetable_theme.dart';
import 'day_utils.dart';

/// Syncfusion DataGrid를 사용한 시간표 데이터 변환 헬퍼 클래스
class SyncfusionTimetableHelper {
  // 상수 정의
  static const Color _stackedHeaderColor = Color(0xFFE3F2FD);
  static const Color _borderColor = Colors.grey;
  static const double _thickBorderWidth = 3.0;
  static const double _thinBorderWidth = 1.0;
  static const BorderSide _thickBorder = BorderSide(color: _borderColor, width: _thickBorderWidth);
  static const BorderSide _thinBorder = BorderSide(color: _borderColor, width: _thinBorderWidth);
  /// TimeSlot 리스트를 Syncfusion DataGrid 데이터로 변환
  /// 
  /// 매개변수:
  /// - `List<TimeSlot>` timeSlots: 변환할 시간표 슬롯 리스트
  /// - `List<Teacher>` teachers: 교사 리스트 (행 헤더용)
  /// 
  /// 반환값:
  /// - `List<DataGridRow>`: Syncfusion DataGrid에서 사용할 행 데이터
  /// - `List<GridColumn>`: Syncfusion DataGrid에서 사용할 열 데이터
  /// - `List<StackedHeaderRow>`: 스택된 헤더 행 데이터
  static ({
    List<DataGridRow> rows, 
    List<GridColumn> columns, 
    List<StackedHeaderRow> stackedHeaders
  }) convertToSyncfusionData(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers, {
    String? selectedDay,      // 선택된 요일
    int? selectedPeriod,      // 선택된 교시
    List<Map<String, dynamic>>? exchangeableTeachers, // 교체 가능한 교사 정보
    CircularExchangePath? selectedCircularPath, // 선택된 순환교체 경로
    OneToOneExchangePath? selectedOneToOnePath, // 선택된 1:1 교체 경로
  }) {
    // 요일별로 데이터 그룹화
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = _groupTimeSlotsByDayAndPeriod(timeSlots);
    
    // 요일 목록 추출 및 정렬
    List<String> days = groupedData.keys.toList()..sort(DayUtils.compareDays);
    
    // 교시 목록 추출 및 정렬
    Set<int> allPeriods = {};
    for (var dayData in groupedData.values) {
      allPeriods.addAll(dayData.keys);
    }
    List<int> periods = allPeriods.toList()..sort();
    
    // Syncfusion DataGrid 컬럼 생성 (테마 기반)
    List<GridColumn> columns = _createColumns(days, periods, selectedDay, selectedPeriod, exchangeableTeachers, selectedCircularPath, selectedOneToOnePath);
    
    // Syncfusion DataGrid 행 생성
    List<DataGridRow> rows = _createRows(teachers, groupedData, days, periods);
    
    // 스택된 헤더 생성 (요일별 셀 병합 효과)
    List<StackedHeaderRow> stackedHeaders = _createStackedHeaders(days, periods);
    
    return (rows: rows, columns: columns, stackedHeaders: stackedHeaders);
  }
  
  /// TimeSlot 리스트를 요일별, 교시별로 그룹화
  static Map<String, Map<int, Map<String, TimeSlot?>>> _groupTimeSlotsByDayAndPeriod(
    List<TimeSlot> timeSlots,
  ) {
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = {};
    
    for (TimeSlot slot in timeSlots) {
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
  
  /// Syncfusion DataGrid 컬럼 생성 (테마 기반)
  static List<GridColumn> _createColumns(List<String> days, List<int> periods, String? selectedDay, int? selectedPeriod, List<Map<String, dynamic>>? exchangeableTeachers, CircularExchangePath? selectedCircularPath, OneToOneExchangePath? selectedOneToOnePath) {
    List<GridColumn> columns = [];
    
    // 첫 번째 컬럼: 교사명 (고정 열)
    columns.add(
      GridColumn(
        columnName: 'teacher',
        width: AppConstants.teacherColumnWidth,
        label: Container(
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SimplifiedTimetableTheme.teacherHeaderColor,
            border: const Border(
              right: _thickBorder, // 교사명과 월요일 사이 구분선을 두껍게
              bottom: _thinBorder,
            ),
          ),
          child: const Text(
            '교시',
            style: TextStyle(
              fontSize: AppConstants.headerFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
    
    // 요일별 교시 컬럼 생성
    for (String day in days) {
      for (int i = 0; i < periods.length; i++) {
        int period = periods[i];
        bool isLastPeriod = i == periods.length - 1; // 마지막 교시인지 확인
        
        // 테마를 사용하여 선택 상태 확인
        bool isSelected = SimplifiedTimetableTheme.isPeriodSelected(day, period, selectedDay, selectedPeriod);
        
        // 교체 가능한 교시인지 확인
        bool isExchangeablePeriod = _isExchangeablePeriod(day, period, exchangeableTeachers);
        
        // 순환교체 경로에 포함된 교시인지 확인
        bool isInCircularPath = _isPeriodInCircularPath(day, period, selectedCircularPath);
        
        // 순환교체 경로의 두 번째 시간인지 확인
        bool isSecondCircularStep = _isSecondCircularStep(day, period, selectedCircularPath);
        
        // 선택된 1:1 경로에 포함된 교시인지 확인
        bool isInSelectedOneToOnePath = _isPeriodInSelectedOneToOnePath(day, period, selectedOneToOnePath);
        
        // 통합 함수를 사용하여 헤더 스타일 가져오기
        CellStyle headerStyles = SimplifiedTimetableTheme.getCellStyle(
          isTeacherColumn: false,
          isSelected: isSelected,
          isExchangeable: isExchangeablePeriod,
          isLastColumnOfDay: isLastPeriod,
          isHeader: true,
          isInCircularPath: isInCircularPath,
          isInSelectedPath: isInSelectedOneToOnePath,
        );
        
        columns.add(
          GridColumn(
            columnName: '${day}_$period',
            width: AppConstants.periodColumnWidth,
            label: Container(
              padding: EdgeInsets.zero,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: headerStyles.backgroundColor,
                border: headerStyles.border,
              ),
              child: Stack(
                children: [
                  // 기본 교시 번호
                  Center(
                    child: Text(
                      period.toString(),
                      style: headerStyles.textStyle,
                    ),
                  ),
                  // 순환교체 두 번째 시간에만 교체 아이콘 오버레이
                  if (isSecondCircularStep)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 1,
                              offset: const Offset(0.5, 0.5),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.refresh,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    }
    
    return columns;
  }
  
  /// Syncfusion DataGrid 행 생성
  static List<DataGridRow> _createRows(
    List<Teacher> teachers,
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData,
    List<String> days,
    List<int> periods,
  ) {
    List<DataGridRow> rows = [];
    
    for (Teacher teacher in teachers) {
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
  
  /// 스택된 헤더 생성 (요일별 셀 병합 효과)
  static List<StackedHeaderRow> _createStackedHeaders(List<String> days, List<int> periods) {
    List<StackedHeaderRow> stackedHeaders = [];
    
    // 요일 헤더 행 생성
    List<StackedHeaderCell> headerCells = [];
    
    // 교사명 헤더 (병합되지 않음, 고정 열)
    headerCells.add(
      StackedHeaderCell(
        columnNames: ['teacher'],
        child: Container(
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _stackedHeaderColor, // 스택된 헤더 배경색
            border: Border(
              right: _thickBorder, // 교사명과 월요일 사이 구분선을 두껍게
              bottom: _thinBorder,
            ),
          ),
          child: const SizedBox.shrink(), // 빈 공간
        ),
      ),
    );
    
    // 요일별 헤더 (교시 수만큼 병합)
    for (int i = 0; i < days.length; i++) {
      String day = days[i];
      bool isLastDay = i == days.length - 1; // 마지막 요일(금요일)인지 확인
      
      headerCells.add(
        StackedHeaderCell(
          child: Container(
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _stackedHeaderColor, // 스택된 헤더 배경색
              border: Border(
                // 요일 간 구분선을 두껍게 (마지막 요일 제외)
                right: isLastDay ? _thinBorder : _thickBorder, // 마지막 요일이 아니면 3px, 마지막 요일이면 1px
                bottom: _thinBorder,
              ),
            ),
            child: Text(
              day,
              style: const TextStyle(
                fontSize: AppConstants.headerFontSize,
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
  
  /// 교체 가능한 교시인지 확인
  static bool _isExchangeablePeriod(String day, int period, List<Map<String, dynamic>>? exchangeableTeachers) {
    if (exchangeableTeachers == null || exchangeableTeachers.isEmpty) return false;
    
    return exchangeableTeachers.any((teacher) => 
      teacher['day'] == day && teacher['period'] == period
    );
  }
  
  /// 순환교체 경로에 포함된 교시인지 확인
  static bool _isPeriodInCircularPath(String day, int period, CircularExchangePath? selectedCircularPath) {
    if (selectedCircularPath == null) return false;
    
    return selectedCircularPath.nodes.any((node) => 
      node.day == day && node.period == period
    );
  }
  
  /// 순환교체 경로의 두 번째 시간인지 확인
  static bool _isSecondCircularStep(String day, int period, CircularExchangePath? selectedCircularPath) {
    if (selectedCircularPath == null || selectedCircularPath.nodes.length < 2) return false;
    
    // 두 번째 노드와 일치하는지 확인 (인덱스 1)
    var secondNode = selectedCircularPath.nodes[1];
    return secondNode.day == day && secondNode.period == period;
  }
  
  /// 선택된 1:1 경로에 포함된 교시인지 확인
  static bool _isPeriodInSelectedOneToOnePath(String day, int period, OneToOneExchangePath? selectedOneToOnePath) {
    if (selectedOneToOnePath == null) return false;
    
    return selectedOneToOnePath.nodes.any((node) => 
      node.day == day && node.period == period
    );
  }
}

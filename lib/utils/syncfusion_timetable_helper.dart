import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import 'constants.dart';

/// Syncfusion DataGrid를 사용한 시간표 데이터 변환 헬퍼 클래스
class SyncfusionTimetableHelper {
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
    List<Teacher> teachers,
  ) {
    // 요일별로 데이터 그룹화
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = _groupTimeSlotsByDayAndPeriod(timeSlots);
    
    // 요일 목록 추출 및 정렬
    List<String> days = groupedData.keys.toList()..sort(_compareDays);
    
    // 교시 목록 추출 및 정렬
    Set<int> allPeriods = {};
    for (var dayData in groupedData.values) {
      allPeriods.addAll(dayData.keys);
    }
    List<int> periods = allPeriods.toList()..sort();
    
    // Syncfusion DataGrid 컬럼 생성
    List<GridColumn> columns = _createColumns(days, periods);
    
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
  static String _getDayName(int dayOfWeek) {
    const dayNames = ['월', '화', '수', '목', '금'];
    if (dayOfWeek >= 1 && dayOfWeek <= 5) {
      return dayNames[dayOfWeek - 1];
    }
    return '월'; // 기본값
  }
  
  /// 요일 정렬을 위한 비교 함수
  static int _compareDays(String a, String b) {
    const dayOrder = ['월', '화', '수', '목', '금'];
    int indexA = dayOrder.indexOf(a);
    int indexB = dayOrder.indexOf(b);
    
    if (indexA == -1) indexA = 999;
    if (indexB == -1) indexB = 999;
    
    return indexA.compareTo(indexB);
  }
  
  /// Syncfusion DataGrid 컬럼 생성
  static List<GridColumn> _createColumns(List<String> days, List<int> periods) {
    List<GridColumn> columns = [];
    
    // 첫 번째 컬럼: 교사명
    columns.add(
      GridColumn(
        columnName: 'teacher',
        width: AppConstants.teacherColumnWidth,
        label: Container(
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(AppConstants.teacherHeaderColor),
            border: Border(
              right: BorderSide(color: Colors.grey, width: 1),
              bottom: BorderSide(color: Colors.grey, width: 1),
            ),
          ),
          child: const Text(
            '교사',
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
      for (int period in periods) {
        columns.add(
          GridColumn(
            columnName: '${day}_$period',
            width: AppConstants.periodColumnWidth,
            label: Container(
              padding: EdgeInsets.zero,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(AppConstants.periodHeaderColor),
                border: Border(
                  right: BorderSide(color: Colors.grey, width: 1),
                  bottom: BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              child: Text(
                period.toString(),
                style: const TextStyle(
                  fontSize: AppConstants.headerFontSize,
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
    
    // 교사명 헤더 (병합되지 않음)
    headerCells.add(
      StackedHeaderCell(
        columnNames: ['teacher'],
        child: Container(
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(AppConstants.stackedHeaderColor),
            border: Border(
              right: BorderSide(color: Colors.grey, width: 1),
              bottom: BorderSide(color: Colors.grey, width: 1),
            ),
          ),
          child: const Text(
            '교사',
            style: TextStyle(
              fontSize: AppConstants.headerFontSize,
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
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(AppConstants.stackedHeaderColor),
              border: Border(
                right: BorderSide(color: Colors.grey, width: 1),
                bottom: BorderSide(color: Colors.grey, width: 1),
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
  
  /// 특정 교사의 시간표 슬롯을 필터링
  static List<TimeSlot> getTeacherTimeSlots(List<TimeSlot> timeSlots, String teacherName) {
    return timeSlots.where((slot) => slot.teacher == teacherName).toList();
  }
  
  /// 특정 요일의 시간표 슬롯을 필터링
  static List<TimeSlot> getDayTimeSlots(List<TimeSlot> timeSlots, int dayOfWeek) {
    return timeSlots.where((slot) => slot.dayOfWeek == dayOfWeek).toList();
  }
  
  /// 특정 교시의 시간표 슬롯을 필터링
  static List<TimeSlot> getPeriodTimeSlots(List<TimeSlot> timeSlots, int period) {
    return timeSlots.where((slot) => slot.period == period).toList();
  }
  
  /// 교체 가능한 시간표 슬롯만 필터링
  static List<TimeSlot> getExchangeableTimeSlots(List<TimeSlot> timeSlots) {
    return timeSlots.where((slot) => slot.canExchange).toList();
  }
}

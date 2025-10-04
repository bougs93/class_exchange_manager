import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/circular_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/exchange_node.dart';
import 'constants.dart';
import 'simplified_timetable_theme.dart';
import 'cell_style_config.dart';
import 'day_utils.dart';

/// Syncfusion DataGrid를 사용한 시간표 데이터 변환 헬퍼 클래스
class SyncfusionTimetableHelper {
  // 상수 정의
  static const Color _stackedHeaderColor = Color(0xFFE3F2FD);
  static const BorderSide _thinBorder = BorderSide(color: SimplifiedTimetableTheme.normalBorderColor, width: SimplifiedTimetableTheme.normalBorderWidth);
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
    ChainExchangePath? selectedChainPath, // 선택된 연쇄교체 경로
  }) {
    // 요일별로 데이터 그룹화
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = _groupTimeSlotsByDayAndPeriod(timeSlots);
    
    // 요일 목록 추출 및 정렬
    List<String> days = groupedData.keys.toList()..sort(DayUtils.compareDays);
    
    // 행 데이터 생성
    List<DataGridRow> rows = [];
    for (Teacher teacher in teachers) {
      List<DataGridCell> cells = [];
      
      // 교사명 셀 (첫 번째 컬럼)
      cells.add(DataGridCell(columnName: 'teacher', value: teacher.name));
      
      // 각 요일의 실제 존재하는 교시에 대한 셀 생성
      for (String day in days) {
        // 해당 요일에 실제 존재하는 교시만 가져오기
        List<int> dayPeriods = (groupedData[day]?.keys.toList() ?? [])..sort();
        for (int period in dayPeriods) {
          String columnName = '${day}_$period';
          TimeSlot? timeSlot = groupedData[day]?[period]?[teacher.name];
          cells.add(DataGridCell(columnName: columnName, value: timeSlot));
        }
      }
      
      rows.add(DataGridRow(cells: cells));
    }
    
    // 컬럼 데이터 생성
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
              border: Border(
                right: BorderSide(color: SimplifiedTimetableTheme.normalBorderColor, width: SimplifiedTimetableTheme.normalBorderWidth), // 교사명과 월요일 사이 구분선을 일반 교시와 동일하게
                bottom: _thinBorder,
              ),
            ),
          child: Text(
            '교시',
            style: TextStyle(
              fontSize: AppConstants.headerFontSize * SimplifiedTimetableTheme.fontScaleFactor, // 줌 팩터 적용
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
    
    // 요일별 교시 컬럼 생성
    for (String day in days) {
      // 해당 요일에 실제 존재하는 교시만 가져오기
      List<int> dayPeriods = (groupedData[day]?.keys.toList() ?? [])..sort();
      for (int i = 0; i < dayPeriods.length; i++) {
        int period = dayPeriods[i];
        bool isFirstPeriod = i == 0; // 해당 요일의 첫 번째 교시인지 확인
        bool isLastPeriod = i == dayPeriods.length - 1; // 해당 요일의 마지막 교시인지 확인
        
        // 테마를 사용하여 선택 상태 확인
        bool isSelected = SimplifiedTimetableTheme.isPeriodSelected(day, period, selectedDay, selectedPeriod);
        
        // 교체 가능한 교시인지 확인
        bool isExchangeablePeriod = _isExchangeablePeriod(day, period, exchangeableTeachers);
        
        // 순환교체 경로에 포함된 교시인지 확인
        bool isInCircularPath = _isPeriodInCircularPath(day, period, selectedCircularPath);
        
        // 선택된 1:1 경로에 포함된 교시인지 확인
        bool isInSelectedOneToOnePath = _isPeriodInSelectedOneToOnePath(day, period, selectedOneToOnePath);
        
        // 연쇄교체 경로에 포함된 교시인지 확인
        bool isInChainPath = _isPeriodInChainPath(day, period, selectedChainPath);
        
        // CellStyleConfig를 사용하여 헤더 스타일 가져오기
        CellStyle headerStyles = SimplifiedTimetableTheme.getCellStyleFromConfig(
          CellStyleConfig(
            isTeacherColumn: false,
            isSelected: isSelected,
            isExchangeable: isExchangeablePeriod,
            isLastColumnOfDay: isLastPeriod,
            isFirstColumnOfDay: isFirstPeriod,
            isHeader: true,
            isInCircularPath: isInCircularPath,
            isInSelectedPath: isInSelectedOneToOnePath,
            isInChainPath: isInChainPath,
          ),
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
                border: headerStyles.border, // 테마에서 제공하는 테두리 사용
              ),
              child: Text(
                '$period',
                style: TextStyle(
                  fontSize: AppConstants.headerFontSize * SimplifiedTimetableTheme.fontScaleFactor, // 줌 팩터 적용
                  fontWeight: FontWeight.bold,
                  color: headerStyles.textStyle.color ?? Colors.black,
                ),
              ),
            ),
          ),
        );
      }
    }
    
    // 스택된 헤더 생성
    List<StackedHeaderRow> stackedHeaders = [];
    List<StackedHeaderCell> headerCells = [];
    
    // 교사명 헤더
    headerCells.add(
      StackedHeaderCell(
        child: Container(
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _stackedHeaderColor,
            border: Border(
              right: BorderSide(color: SimplifiedTimetableTheme.normalBorderColor, width: SimplifiedTimetableTheme.normalBorderWidth), // 교사명과 월요일 사이 구분선을 일반 교시와 동일하게
              bottom: _thinBorder,
            ),
          ),
          child: Text(
            '',
            style: TextStyle(
              fontSize: AppConstants.headerFontSize * SimplifiedTimetableTheme.fontScaleFactor, // 줌 팩터 적용
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        columnNames: ['teacher'],
      ),
    );
    
    // 요일별 헤더
    for (String day in days) {
      // 해당 요일에 실제 존재하는 교시만 가져오기
      List<int> dayPeriods = (groupedData[day]?.keys.toList() ?? [])..sort();
      List<String> dayColumnNames = dayPeriods.map((period) => '${day}_$period').toList();
      
      headerCells.add(
        StackedHeaderCell(
          child: Container(
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _stackedHeaderColor,
              border: Border(
                left: BorderSide(
                  color: SimplifiedTimetableTheme.dayHeaderBorderColor, // 요일 헤더 왼쪽 경계선 색상
                  width: SimplifiedTimetableTheme.dayHeaderBorderWidth, // 요일 헤더 왼쪽 경계선 두께
                ),
                right: _thinBorder, // 모든 교시에 얇은 경계선
                bottom: _thinBorder,
              ),
            ),
            child: Text(
              day,
              style: TextStyle(
                fontSize: AppConstants.headerFontSize * SimplifiedTimetableTheme.fontScaleFactor, // 줌 팩터 적용
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          columnNames: dayColumnNames,
        ),
      );
    }
    
    stackedHeaders.add(StackedHeaderRow(cells: headerCells));
    
    return (
      rows: rows,
      columns: columns,
      stackedHeaders: stackedHeaders,
    );
  }
  
  /// TimeSlot 리스트를 요일과 교시별로 그룹화
  static Map<String, Map<int, Map<String, TimeSlot?>>> _groupTimeSlotsByDayAndPeriod(List<TimeSlot> timeSlots) {
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = {};
    
    for (TimeSlot timeSlot in timeSlots) {
      int? dayOfWeek = timeSlot.dayOfWeek;
      int period = timeSlot.period ?? 0;
      String teacherName = timeSlot.teacher ?? '';
      
      if (dayOfWeek == null) continue; // 요일이 없으면 건너뛰기
      
      String day = _convertDayOfWeekToString(dayOfWeek);
      
      if (!groupedData.containsKey(day)) {
        groupedData[day] = {};
      }
      if (!groupedData[day]!.containsKey(period)) {
        groupedData[day]![period] = {};
      }
      groupedData[day]![period]![teacherName] = timeSlot;
    }
    
    return groupedData;
  }
  
  /// 교체 가능한 교시인지 확인 (통합 메서드)
  static bool _isPeriodInPath(String day, int period, List<ExchangeNode>? nodes) {
    if (nodes == null) return false;
    return nodes.any((node) => node.day == day && node.period == period);
  }

  /// 교체 가능한 교시인지 확인 (exchangeableTeachers용)
  static bool _isExchangeablePeriod(String day, int period, List<Map<String, dynamic>>? exchangeableTeachers) {
    if (exchangeableTeachers == null) return false;
    return exchangeableTeachers.any((teacher) =>
      teacher['day'] == day && teacher['period'] == period
    );
  }

  /// 순환교체 경로에 포함된 교시인지 확인
  static bool _isPeriodInCircularPath(String day, int period, CircularExchangePath? selectedCircularPath) {
    return _isPeriodInPath(day, period, selectedCircularPath?.nodes);
  }

  /// 선택된 1:1 경로에 포함된 교시인지 확인
  static bool _isPeriodInSelectedOneToOnePath(String day, int period, OneToOneExchangePath? selectedOneToOnePath) {
    return _isPeriodInPath(day, period, selectedOneToOnePath?.nodes);
  }

  /// 연쇄교체 경로에 포함된 교시인지 확인
  static bool _isPeriodInChainPath(String day, int period, ChainExchangePath? selectedChainPath) {
    return _isPeriodInPath(day, period, selectedChainPath?.nodes);
  }
  
  /// 요일 숫자를 문자열로 변환
  static String _convertDayOfWeekToString(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1: return '월';
      case 2: return '화';
      case 3: return '수';
      case 4: return '목';
      case 5: return '금';
      default: return '월';
    }
  }
}
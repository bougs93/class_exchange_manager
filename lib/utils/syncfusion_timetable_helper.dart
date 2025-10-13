import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/circular_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import 'day_utils.dart';
import 'fixed_header_style_manager.dart';

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
    List<Teacher> teachers, {
    String? selectedDay,      // 선택된 요일
    int? selectedPeriod,      // 선택된 교시
    String? targetDay,        // 타겟 셀의 요일 (보기 모드)
    int? targetPeriod,        // 타겟 셀의 교시 (보기 모드)
    List<Map<String, dynamic>>? exchangeableTeachers, // 교체 가능한 교사 정보
    CircularExchangePath? selectedCircularPath, // 선택된 순환교체 경로
    OneToOneExchangePath? selectedOneToOnePath, // 선택된 1:1 교체 경로
    ChainExchangePath? selectedChainPath, // 선택된 연쇄교체 경로
    SupplementExchangePath? selectedSupplementPath, // 선택된 보강교체 경로
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
    
    // 컬럼 데이터 생성 (FixedHeaderStyleManager 사용)
    List<GridColumn> columns = FixedHeaderStyleManager.buildGridColumns(
      days: days,
      groupedData: groupedData,
      selectedDay: selectedDay,
      selectedPeriod: selectedPeriod,
      targetDay: targetDay,
      targetPeriod: targetPeriod,
      exchangeableTeachers: exchangeableTeachers,
      selectedCircularPath: selectedCircularPath,
      selectedOneToOnePath: selectedOneToOnePath,
      selectedChainPath: selectedChainPath,
      selectedSupplementPath: selectedSupplementPath,
    );
    
    // 스택된 헤더 생성 (FixedHeaderStyleManager 사용)
    List<StackedHeaderRow> stackedHeaders = [
      FixedHeaderStyleManager.buildStackedHeaderRow(
        days: days,
        groupedData: groupedData,
      ),
    ];
    
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
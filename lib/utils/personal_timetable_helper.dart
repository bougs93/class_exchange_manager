import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import 'day_utils.dart';
import 'week_date_calculator.dart';

/// 개인 시간표 데이터 변환 헬퍼 클래스
/// 
/// 특정 교사의 시간표를 세로행(교시) × 가로행(요일) 형태로 변환합니다.
class PersonalTimetableHelper {
  /// 특정 교사의 TimeSlot을 개인 시간표 형태로 변환
  /// 
  /// 매개변수:
  /// - `List<TimeSlot>` timeSlots: 전체 시간표 슬롯 리스트
  /// - `String` teacherName: 개인 시간표를 표시할 교사명
  /// - `List<DateTime>` weekDates: 현재 주의 날짜 리스트 [월, 화, 수, 목, 금]
  /// 
  /// 반환값:
  /// - `List<DataGridRow>`: 교시별 행 데이터
  /// - `List<GridColumn>`: 요일별 열 데이터
  /// - `List<StackedHeaderRow>`: 날짜가 포함된 헤더
  static ({
    List<DataGridRow> rows,
    List<GridColumn> columns,
    List<StackedHeaderRow> stackedHeaders,
  }) convertToPersonalTimetableData(
    List<TimeSlot> timeSlots,
    String teacherName,
    List<DateTime> weekDates,
  ) {
    // 1. 해당 교사의 TimeSlot만 필터링
    final teacherTimeSlots = timeSlots
        .where((slot) => slot.teacher == teacherName)
        .toList();

    // 2. 요일과 교시별로 그룹화
    final Map<String, Map<int, TimeSlot?>> groupedData = {};
    final Set<int> allPeriods = {};

    for (final slot in teacherTimeSlots) {
      if (slot.dayOfWeek == null || slot.period == null) continue;

      final dayName = DayUtils.getDayName(slot.dayOfWeek!);
      final period = slot.period!;

      groupedData.putIfAbsent(dayName, () => {})[period] = slot;
      allPeriods.add(period);
    }

    // 3. 교시 목록 정렬
    final sortedPeriods = allPeriods.toList()..sort();

    // 4. 요일 목록 (월~금 순서)
    final days = DayUtils.dayNames;

    // 5. 행 데이터 생성 (각 교시가 하나의 행)
    final List<DataGridRow> rows = [];
    for (final period in sortedPeriods) {
      final List<DataGridCell> cells = [];

      // 교시 헤더 셀 (첫 번째 컬럼)
      cells.add(DataGridCell(columnName: 'period', value: '$period교시'));

      // 각 요일별 셀 생성
      for (final day in days) {
        final slot = groupedData[day]?[period];
        final columnName = '${day}_$period';
        cells.add(DataGridCell(columnName: columnName, value: slot));
      }

      rows.add(DataGridRow(cells: cells));
    }

    // 6. 열 데이터 생성
    final List<GridColumn> columns = [
      // 교시 헤더 열
      GridColumn(
        columnName: 'period',
        width: 80,
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: const Text(
            '교시',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      // 요일별 열 생성
      ...days.asMap().entries.map((entry) {
        final day = entry.value;

        return GridColumn(
          columnName: day,
          width: 120,
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: Text(
              day,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }),
    ];

    // 7. 스택된 헤더 생성 (날짜 표시용)
    final List<StackedHeaderCell> headerCells = [
      // 교시 헤더 (날짜 헤더)
      StackedHeaderCell(
        columnNames: ['period'],
        child: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: const Text(
            '날짜',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      // 각 요일별 날짜 헤더
      ...days.asMap().entries.map((entry) {
        final index = entry.key;
        final day = entry.value;
        final date = weekDates[index];

        return StackedHeaderCell(
          columnNames: [day],
          child: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: Text(
              WeekDateCalculator.formatDateShort(date),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }),
    ];
    
    final List<StackedHeaderRow> stackedHeaders = [
      StackedHeaderRow(cells: headerCells),
    ];

    return (
      rows: rows,
      columns: columns,
      stackedHeaders: stackedHeaders,
    );
  }

}


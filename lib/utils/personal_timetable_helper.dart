import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import 'day_utils.dart';
import 'week_date_calculator.dart';
import 'constants.dart';
import 'simplified_timetable_theme.dart';

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
  /// - `double` zoomFactor: 현재 줌 팩터 (기본값: 1.0)
  ///
  /// 반환값:
  /// - `List<DataGridRow>`: 교시별 행 데이터
  /// - `List<GridColumn>`: 요일별 열 데이터
  /// - `List<StackedHeaderRow>`: 비어 있음 — 날짜는 요일 칸 두 번째 줄에 붙는다
  static ({
    List<DataGridRow> rows,
    List<GridColumn> columns,
    List<StackedHeaderRow> stackedHeaders,
  })
  convertToPersonalTimetableData(
    List<TimeSlot> timeSlots,
    String teacherName,
    List<DateTime> weekDates, {
    double zoomFactor = 1.0,
  }) {
    // 1. 해당 교사의 TimeSlot만 필터링
    final teacherTimeSlots =
        timeSlots.where((slot) => slot.teacher == teacherName).toList();

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

    // 4. weekDates를 기반으로 동적으로 요일 목록 생성
    // weekDates는 이미 실제 존재하는 요일만 포함하도록 필터링됨
    final days = <String>[];
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    for (final date in weekDates) {
      final dayOfWeek = date.weekday; // 1=월요일, 7=일요일
      if (dayOfWeek >= 1 && dayOfWeek <= 7) {
        days.add(dayNames[dayOfWeek - 1]);
      }
    }

    // 5. 행 데이터 생성 (각 교시가 하나의 행)
    final List<DataGridRow> rows = [];
    for (final period in sortedPeriods) {
      final List<DataGridCell> cells = [];

      // 교시 헤더 셀 — "교시"는 열 제목에 있으므로 숫자만 표시한다.
      cells.add(DataGridCell(columnName: 'period', value: '$period'));

      // 각 요일별 셀 생성
      for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
        final day = days[dayIndex];
        final slot = groupedData[day]?[period];

        // 날짜 문자열 생성 (YYYY.MM.DD 형식)
        final date = weekDates[dayIndex];
        final dateStr =
            '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

        // columnName에 날짜 포함: "월_5_2025.11.10"
        final columnName = '${day}_${period}_$dateStr';
        cells.add(DataGridCell(columnName: columnName, value: slot));
      }

      rows.add(DataGridRow(cells: cells));
    }

    // 6. 열 데이터 생성
    // 개인 시간표 테이블 크기 20% 증가 적용 (가로폭)
    const double personalTimetableSizeMultiplier = 1.2;
    // 본문은 숫자 한 자리라 더 좁혀도 되지만, 헤더 "교시"(2글자, 14px)가
    // 잘리지 않는 너비가 하한이다. (기존 48px은 "1교시" 4글자 기준)
    const double periodColumnWidth = 40.0;

    final List<GridColumn> columns = [
      GridColumn(
        columnName: 'period',
        width: periodColumnWidth,
        label: Container(
          padding: EdgeInsets.zero, // 교체 관리 화면과 동일한 padding (없음)
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SimplifiedTimetableTheme.teacherHeaderColor,
            border: Border(
              right: BorderSide(
                color:
                    SimplifiedTimetableTheme.normalBorderColor, // 내용 셀과 동일한 테두리
                width: SimplifiedTimetableTheme.normalBorderWidth,
              ),
              bottom: BorderSide(
                color:
                    SimplifiedTimetableTheme.normalBorderColor, // 내용 셀과 동일한 테두리
                width: SimplifiedTimetableTheme.normalBorderWidth,
              ),
            ),
          ),
          child: Text(
            '교시',
            style: TextStyle(
              fontSize: AppConstants.headerFontSize * zoomFactor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      // 요일별 열 생성 (20% 증가 적용)
      ...days.asMap().entries.map((entry) {
        final dayIndex = entry.key;
        final day = entry.value;
        final date = weekDates[dayIndex];
        final dateStr =
            '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

        return GridColumn(
          columnName: '${day}_$dateStr', // 날짜 포함: "월_2025.11.10"
          width:
              AppConstants.periodColumnWidth *
              personalTimetableSizeMultiplier, // 20% 증가
          label: Container(
            padding: EdgeInsets.zero, // 교체 관리 화면과 동일한 padding (없음)
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SimplifiedTimetableTheme.teacherHeaderColor, // 요일 헤더 배경색
              border: Border(
                left: BorderSide(
                  color:
                      SimplifiedTimetableTheme
                          .normalBorderColor, // 내용 셀과 동일한 테두리
                  width: SimplifiedTimetableTheme.normalBorderWidth,
                ),
                right: BorderSide(
                  color:
                      SimplifiedTimetableTheme
                          .normalBorderColor, // 내용 셀과 동일한 테두리
                  width: SimplifiedTimetableTheme.normalBorderWidth,
                ),
                bottom: BorderSide(
                  color:
                      SimplifiedTimetableTheme
                          .normalBorderColor, // 내용 셀과 동일한 테두리
                  width: SimplifiedTimetableTheme.normalBorderWidth,
                ),
              ),
            ),
            // 날짜 행을 없애고 요일 아래에 붙인다. "12.12"(5자)가 칸(42px)에
            // 들어가는 최대 크기는 12.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day,
                  style: TextStyle(
                    fontSize: AppConstants.headerFontSize * zoomFactor,
                    height: 1.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  WeekDateCalculator.formatDateShort(date),
                  style: TextStyle(
                    fontSize: 12 * zoomFactor,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ];

    // 날짜는 요일 칸 두 번째 줄에 붙으므로 날짜 전용 스택 헤더 행은 두지 않는다.
    return (rows: rows, columns: columns, stackedHeaders: const []);
  }
}

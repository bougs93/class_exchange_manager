import 'dart:developer' as developer;
import 'package:excel/excel.dart';
import '../../models/teacher.dart';
import '../../models/time_slot.dart';
import '../../models/timetable_data.dart';
import '../../utils/day_utils.dart';
import 'excel_cell_parser.dart';
import 'excel_constants.dart';
import 'excel_parsing_utils.dart';
import 'excel_teacher_extractor.dart';

/// 엑셀 시트에서 실제 시간표 데이터(TimeSlot 목록)를 추출하는 클래스
///
/// `excel_service.dart`에서 분리되었습니다 (2026-10-03).
/// 원래 `ExcelService`의 private 메서드였던 내용을 그대로 옮긴 것으로,
/// `ExcelService.parseTimetableData`가 내부적으로 호출합니다.
class ExcelTimeSlotExtractor {
  /// 시간표 데이터를 추출하는 메서드 (요일별 교시 고려)
  static List<TimeSlot> extractTimeSlotsByDay(
    Sheet sheet,
    ExcelParsingConfig config,
    List<String> dayHeaders,
    Map<String, List<int>> periodsByDay,
    List<Teacher> teachers,
    CellOrderPattern cellOrderPattern,
    Map<Teacher, int> teacherRowCounts,
  ) {
    try {
      List<TimeSlot> timeSlots = [];

      // 요일별 시작 열 위치 계산
      Map<String, int> dayColumnMapping = ExcelParsingUtils.calculateDayColumns(
        sheet,
        config,
        dayHeaders,
      );

      // 각 교사에 대해 시간표 데이터 추출
      for (Teacher teacher in teachers) {
        // 교사 이름이 있는 행 찾기
        int teacherRow = ExcelTeacherExtractor.findTeacherNameRow(
          sheet,
          config,
          teacher,
          config.dataStartRow,
        );
        if (teacherRow == 0) continue;

        // 교사 행 개수 가져오기
        int rowCount = teacherRowCounts[teacher] ?? 1;

        // 각 요일별로 데이터 추출
        _extractTeacherTimeSlots(
          sheet,
          config,
          teacher,
          teacherRow,
          rowCount,
          dayHeaders,
          dayColumnMapping,
          periodsByDay,
          timeSlots,
          cellOrderPattern,
        );
      }

      return timeSlots;
    } catch (e) {
      developer.log('시간표 데이터 추출 중 오류 발생: $e', name: 'ExcelService');
      return [];
    }
  }

  /// 단일 교사의 시간표 데이터 추출
  static void _extractTeacherTimeSlots(
    Sheet sheet,
    ExcelParsingConfig config,
    Teacher teacher,
    int teacherRow,
    int rowCount,
    List<String> dayHeaders,
    Map<String, int> dayColumnMapping,
    Map<String, List<int>> periodsByDay,
    List<TimeSlot> timeSlots,
    CellOrderPattern cellOrderPattern,
  ) {
    for (String day in dayHeaders) {
      int? dayStartCol = dayColumnMapping[day];
      if (dayStartCol == null) continue;

      int dayOfWeek = DayUtils.getDayNumber(day);
      List<int> periods = periodsByDay[day] ?? [];

      _extractDayTimeSlots(
        sheet,
        config,
        teacher,
        teacherRow,
        rowCount,
        day,
        dayStartCol,
        dayOfWeek,
        periods,
        timeSlots,
        cellOrderPattern,
      );
    }
  }

  /// 특정 요일의 시간표 데이터 추출
  static void _extractDayTimeSlots(
    Sheet sheet,
    ExcelParsingConfig config,
    Teacher teacher,
    int teacherRow,
    int rowCount,
    String day,
    int dayStartCol,
    int dayOfWeek,
    List<int> periods,
    List<TimeSlot> timeSlots,
    CellOrderPattern cellOrderPattern,
  ) {
    for (int period in periods) {
      TimeSlot? slot = _extractSingleTimeSlot(
        sheet,
        config,
        teacher,
        teacherRow,
        rowCount,
        dayStartCol,
        dayOfWeek,
        period,
        cellOrderPattern,
      );
      if (slot != null) {
        timeSlots.add(slot);
      }
    }
  }

  /// 단일 시간표 슬롯 추출
  ///
  /// 교사 행 개수에 따라 처리:
  /// - 1행: 현재 방식 (줄바꿈으로 구분)
  /// - 2행 이상: 교사 블록 내 **비어 있지 않은 행**에서 학급·과목 추출 (순서 무관, 3행째 빈행 무시)
  static TimeSlot? _extractSingleTimeSlot(
    Sheet sheet,
    ExcelParsingConfig config,
    Teacher teacher,
    int teacherRow,
    int rowCount,
    int dayStartCol,
    int dayOfWeek,
    int period,
    CellOrderPattern cellOrderPattern,
  ) {
    int? periodCol = ExcelParsingUtils.findPeriodColumnInDay(
      sheet,
      config,
      dayStartCol,
      period,
    );
    if (periodCol == null) return null;

    String cellValue;

    if (rowCount == 1) {
      // 1행인 경우: 현재 방식 (줄바꿈으로 구분)
      cellValue = ExcelParsingUtils.getCellValue(
        sheet,
        teacherRow - 1,
        periodCol - 1,
      );
    } else {
      // 교사 블록(rowCount행) 안에서 값이 있는 행만 수집 → 과목/학급 행 순서·중간 빈행 모두 허용
      final rowValues = <String>[];

      for (int i = 0; i < rowCount; i++) {
        final currentRow = teacherRow + i - 1; // 0-based
        final rowValue =
            ExcelParsingUtils.getCellValue(
              sheet,
              currentRow,
              periodCol - 1,
            ).trim();

        if (rowValue.isNotEmpty) {
          rowValues.add(rowValue);
        }
      }

      // 내용 기준으로 학급·과목 분리 (행 순서와 무관)
      if (rowValues.isEmpty) {
        cellValue = '';
      } else if (rowValues.length == 1) {
        cellValue = rowValues.first;
      } else {
        // 2줄 이상: 셀 파서에 줄 단위로 넘겨 내용 기준 분류 (전역 순서 패턴에 덜 의존)
        final fields = ExcelCellParser.classifyByContent(rowValues);
        if (fields['className'] != null || fields['subject'] != null) {
          return TimeSlot(
            teacher: teacher.name,
            subject: fields['subject'],
            className: fields['className'],
            dayOfWeek: dayOfWeek,
            period: period,
            isExchangeable: true,
          );
        }
        cellValue = rowValues.join('\n');
      }
    }

    return ExcelCellParser.parseTimeSlotCell(
      cellValue,
      teacher,
      dayOfWeek,
      period,
      // 다중 행은 셀마다 내용 기준 분류 — 파일 전역 패턴 강제 적용 안 함
      orderPattern: rowCount >= 2 ? CellOrderPattern.unknown : cellOrderPattern,
    );
  }
}

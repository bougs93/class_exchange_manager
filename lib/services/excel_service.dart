import 'dart:io';
import 'dart:developer' as developer;
import 'package:excel/excel.dart';
import '../models/teacher.dart';
import '../models/time_slot.dart';
import 'excel_parsing/excel_header_finder.dart';
import 'excel_parsing/excel_teacher_extractor.dart';
import 'excel_parsing/excel_parsing_utils.dart';
import 'excel_parsing/excel_file_access.dart';
import 'excel_parsing/excel_row_count_detector.dart';
import 'excel_parsing/excel_cell_order_detector.dart';
import 'excel_parsing/excel_timeslot_extractor.dart';

import '../models/timetable_data.dart';
import 'excel_parsing/excel_constants.dart';
import 'excel_parsing/duplicate_teacher_exception.dart';

// 아래 타입들은 원래 이 파일에 있었으나 2026-10-03에 분리했다.
// 기존 import 경로(`excel_service.dart`)를 그대로 쓰던 24개 파일이 깨지지
// 않도록 여기서 다시 export 한다.
export '../models/timetable_data.dart' show ExcelParsingConfig, TimetableData;
export 'excel_parsing/excel_constants.dart'
    show ExcelServiceConstants, CellOrderPattern;
export 'excel_parsing/duplicate_teacher_exception.dart'
    show DuplicateTeacherException;

/// 엑셀 파일을 읽고 처리하는 서비스 클래스
///
/// 2026-10-03에 내부 구현을 아래 클래스들로 분리했다. 이 클래스는 공개 API를
/// 그대로 유지하는 facade 역할만 하며, 실제 로직은 각 클래스에 있다.
/// - [ExcelFileAccess]: 파일 선택/읽기/기본 검증
/// - [ExcelRowCountDetector]: 교사별 행 개수 감지/계산
/// - [ExcelCellOrderDetector]: 셀 내용 순서(학급·과목) 감지
/// - [ExcelTimeSlotExtractor]: 시간표 데이터(TimeSlot) 추출
class ExcelService {
  // 싱글톤 인스턴스
  static final ExcelService _instance = ExcelService._internal();

  // 싱글톤 생성자
  factory ExcelService() => _instance;

  // 내부 생성자
  ExcelService._internal();

  /// 최근 [parseTimetableData] 실패 사유 (성공 시 null). UI 안내용.
  static String? lastParseFailureReason;

  static TimetableData? _failParse(String reason) {
    lastParseFailureReason = reason;
    developer.log(reason, name: 'ExcelService');
    return null;
  }

  /// 사용자가 엑셀 파일을 선택할 수 있게 하는 메서드
  ///
  /// 반환값:
  /// - File?: 선택된 파일 (취소 시 null)
  ///
  /// 사용 예시:
  /// ```dart
  /// File? selectedFile = await ExcelService.pickExcelFile();
  /// if (selectedFile != null) {
  ///   // 파일이 선택됨
  /// }
  /// ```
  /// 네이티브 전용 파일 선택 (File 반환).
  ///
  /// 웹에서는 파일 경로가 존재하지 않으므로 이 메서드를 쓰지 않는다.
  /// 웹 업로드 경로는 `ExchangeOperationManager._selectExcelFileWeb` →
  /// `processExcelBytes` → `readExcelFromBytes`로 통합되어 있다.
  static Future<File?> pickExcelFile() => ExcelFileAccess.pickExcelFile();

  /// 엑셀 파일을 읽어서 Excel 객체로 변환하는 메서드
  ///
  /// 매개변수:
  /// - File file: 읽을 엑셀 파일
  ///
  /// 반환값:
  /// - Excel?: 읽은 엑셀 객체 (실패 시 null)
  ///
  /// 사용 예시:
  /// ```dart
  /// File file = File('path/to/file.xlsx');
  /// Excel? excel = await ExcelService.readExcelFile(file);
  /// if (excel != null) {
  ///   // 엑셀 파일 읽기 성공
  /// }
  /// ```

  /// Web에서 bytes로 엑셀 파일을 읽어서 Excel 객체로 변환
  ///
  /// 매개변수:
  /// - `List<int>` bytes: 엑셀 파일의 바이트 데이터
  ///
  /// 반환값:
  /// - Excel?: 파싱된 엑셀 데이터 (실패 시 null)
  static Future<Excel?> readExcelFromBytes(List<int> bytes) =>
      ExcelFileAccess.readExcelFromBytes(bytes);

  static Future<Excel?> readExcelFile(File file) =>
      ExcelFileAccess.readExcelFile(file);

  /// 엑셀 파일의 기본 정보를 출력하는 디버깅 메서드
  ///
  /// 매개변수:
  /// - Excel excel: 분석할 엑셀 객체
  ///
  /// 사용 예시:
  /// ```dart
  /// Excel excel = await ExcelService.readExcelFile(file);
  /// ExcelService.printExcelInfo(excel);
  /// ```
  static void printExcelInfo(Excel excel) =>
      ExcelFileAccess.printExcelInfo(excel);

  /// 엑셀 파일의 특정 셀 값을 읽는 헬퍼 메서드
  ///
  /// 매개변수:
  /// - Excel excel: 엑셀 객체
  /// - String sheetName: 워크시트 이름
  /// - int row: 행 번호 (0부터 시작)
  /// - int col: 열 번호 (0부터 시작)
  ///
  /// 반환값:
  /// - String: 셀 값 (빈 셀이거나 오류 시 빈 문자열)
  ///
  /// 사용 예시:
  /// ```dart
  /// String cellValue = ExcelService.getCellValue(excel, 'Sheet1', 0, 1);
  /// ```
  static String getCellValue(Excel excel, String sheetName, int row, int col) =>
      ExcelFileAccess.getCellValue(excel, sheetName, row, col);

  /// 엑셀 파일의 유효성을 검사하는 메서드
  ///
  /// 매개변수:
  /// - Excel excel: 검사할 엑셀 객체
  ///
  /// 반환값:
  /// - bool: 유효한 엑셀 파일인지 여부
  ///
  /// 사용 예시:
  /// ```dart
  /// bool isValid = ExcelService.isValidExcelFile(excel);
  /// if (isValid) {
  ///   // 유효한 엑셀 파일
  /// }
  /// ```
  static bool isValidExcelFile(Excel excel) =>
      ExcelFileAccess.isValidExcelFile(excel);

  /// 시간표 데이터를 파싱하는 메인 메서드
  ///
  /// 매개변수:
  /// - Excel excel: 파싱할 엑셀 객체
  /// - ExcelParsingConfig? config: 파싱 설정 (기본값 사용 시 null)
  ///
  /// 반환값:
  /// - TimetableData?: 파싱된 시간표 데이터 (실패 시 null)
  ///
  /// 사용 예시:
  /// ```dart
  /// // 기본 설정으로 파싱
  /// TimetableData? data = ExcelService.parseTimetableData(excel);
  ///
  /// // 커스텀 설정으로 파싱
  /// ExcelParsingConfig config = ExcelParsingConfig(dayHeaderRow: 1);
  /// TimetableData? data = ExcelService.parseTimetableData(excel, config: config);
  /// ```
  static TimetableData? parseTimetableData(
    Excel excel, {
    ExcelParsingConfig? config,
  }) {
    lastParseFailureReason = null;
    try {
      developer.log(
        '시간표 파싱 시작: ${config ?? const ExcelParsingConfig()}',
        name: 'ExcelService',
      );

      // 첫 번째 워크시트 가져오기
      var sheet = excel.tables.values.first;

      if (sheet.maxRows < 2) {
        return _failParse('시트에 데이터 행이 부족합니다.');
      }

      // 교사명 헤더 찾기 (1~10행까지 검색)
      Map<String, dynamic> teacherHeaderResult =
          ExcelHeaderFinder.findTeacherHeader(sheet);
      int foundTeacherHeaderRow = teacherHeaderResult['row'] as int;
      int foundTeacherColumn = teacherHeaderResult['column'] as int;

      if (foundTeacherHeaderRow == 0 || foundTeacherColumn == 0) {
        return _failParse(
          '1~10행에서 교사명 헤더를 찾을 수 없습니다. '
          '엑셀 상단에 "교사" 또는 "성명" 열이 있는지 확인해 주세요.',
        );
      }

      // 요일 헤더 찾기 (1~10행까지 검색)
      Map<String, dynamic> dayHeaderResult = ExcelHeaderFinder.findDayHeaders(
        sheet,
      );
      int foundDayHeaderRow = dayHeaderResult['row'] as int;
      List<String> dayHeaders =
          (dayHeaderResult['days'] as List).cast<String>();

      if (dayHeaders.isEmpty || foundDayHeaderRow == 0) {
        return _failParse('요일 헤더(월·화·수…)를 찾을 수 없습니다.');
      }

      // 교시 헤더 행 계산: 요일 헤더 행의 다음 행
      int periodHeaderRow = foundDayHeaderRow + 1;

      // dataStartRow 계산: 교시 헤더 행 + 1 (교시 헤더 다음 행부터 실제 데이터 시작)
      // (교사 데이터는 교시 헤더 행의 다음 행부터 시작)
      int finalDataStartRow = periodHeaderRow + 1;

      // dataStartColumn 계산: 첫 번째 요일의 1교시 열 찾기
      int? dataStartColumn = ExcelHeaderFinder.findDataStartColumn(
        sheet,
        foundDayHeaderRow,
        periodHeaderRow,
        dayHeaders,
      );
      if (dataStartColumn == null) {
        return _failParse('데이터 시작 열(1교시)을 찾을 수 없습니다.');
      }

      // 동적으로 찾은 헤더 정보를 사용하여 설정 업데이트
      // 교시 헤더 행은 요일 헤더 행의 다음 행으로 자동 설정
      final dynamicConfig = ExcelParsingConfig(
        dayHeaderRow: foundDayHeaderRow,
        periodHeaderRow: periodHeaderRow, // 요일 헤더 행의 다음 행
        teacherColumn: foundTeacherColumn, // 동적으로 찾은 교사명 열
        dataStartRow: finalDataStartRow, // 교시 헤더 행 + 1 (교시 헤더 다음 행부터 데이터 시작)
        dataStartColumn: dataStartColumn, // 첫 번째 요일의 1교시 열
      );

      developer.log(
        '동적으로 찾은 파싱 설정: dayHeaderRow=${dynamicConfig.dayHeaderRow}, periodHeaderRow=${dynamicConfig.periodHeaderRow}, teacherColumn=${dynamicConfig.teacherColumn}, dataStartRow=${dynamicConfig.dataStartRow}, dataStartColumn=${dynamicConfig.dataStartColumn}',
        name: 'ExcelService',
      );

      // 동적 설정으로 유효성 재검사
      if (!_validateParsingConfig(dynamicConfig, sheet)) {
        return _failParse('시간표 레이아웃을 해석할 수 없습니다. 엑셀 양식을 확인해 주세요.');
      }

      // 교사 정보 추출 (동적 설정 사용)
      // 중복된 교사 이름이 발견되면 DuplicateTeacherException이 발생합니다.
      List<Teacher> teachers;
      try {
        teachers = ExcelTeacherExtractor.extractTeacherInfo(
          sheet,
          dynamicConfig,
        );
      } on DuplicateTeacherException catch (e) {
        lastParseFailureReason = e.userMessage;
        developer.log('교사 이름 중복 오류: ${e.toString()}', name: 'ExcelService');
        rethrow;
      }

      // 요일별 교시 번호 찾기 (동적 설정 사용)
      Map<String, List<int>> periodsByDay = ExcelHeaderFinder.findPeriodsByDay(
        sheet,
        dynamicConfig.periodHeaderRow,
        dayHeaders,
        dynamicConfig,
      );
      if (periodsByDay.isEmpty) {
        return _failParse('교시 번호를 찾을 수 없습니다.');
      }

      // 요일별 교시 정보 로그 출력
      for (String day in dayHeaders) {
        List<int> periods = periodsByDay[day] ?? [];
        developer.log('$day요일 교시: $periods', name: 'ExcelService');
      }

      // 교사 행 개수 패턴 감지 (샘플링 기반)
      Map<String, dynamic> teacherRowPattern =
          ExcelRowCountDetector.detectTeacherRowCountPattern(
            sheet,
            dynamicConfig,
            teachers,
          );

      // 모든 교사의 행 개수 계산
      Map<Teacher, int> teacherRowCounts =
          ExcelRowCountDetector.calculateAllTeacherRowCounts(
            sheet,
            dynamicConfig,
            teachers,
            teacherRowPattern,
          );

      // 셀 순서 패턴 감지 (하이브리드 검증, 교사 행 개수 정보 전달)
      CellOrderPattern cellOrderPattern =
          ExcelCellOrderDetector.detectCellOrder(
            sheet,
            dynamicConfig,
            teachers,
            dayHeaders,
            periodsByDay,
            teacherRowCounts,
          );
      developer.log('감지된 셀 순서 패턴: $cellOrderPattern', name: 'ExcelService');

      // 셀 순서 패턴을 확인할 수 없는 경우 파싱 중단
      if (cellOrderPattern == CellOrderPattern.unknown) {
        return _failParse('셀 내용 형식(학급·과목)을 확인할 수 없습니다. 샘플 데이터가 충분한지 확인해 주세요.');
      }

      // 시간표 데이터 추출 (동적 설정 사용, 셀 순서 패턴 및 교사 행 개수 전달)
      List<TimeSlot> timeSlots = ExcelTimeSlotExtractor.extractTimeSlotsByDay(
        sheet,
        dynamicConfig,
        dayHeaders,
        periodsByDay,
        teachers,
        cellOrderPattern,
        teacherRowCounts,
      );

      // 파싱 통계 계산
      int totalCells = 0;
      for (String day in dayHeaders) {
        List<int> periods = periodsByDay[day] ?? [];
        totalCells += teachers.length * periods.length;
      }
      int successCount = timeSlots.where((slot) => slot.isNotEmpty).length;
      int errorCount = totalCells - successCount;

      TimetableData result = TimetableData(
        teachers: teachers,
        timeSlots: timeSlots,
        config: dynamicConfig, // 동적으로 찾은 설정 사용
        totalParsedCells: totalCells,
        successCount: successCount,
        errorCount: errorCount,
      );

      developer.log('시간표 파싱 완료: $result', name: 'ExcelService');

      // 디버깅 로그 제거 - 성능 개선

      return result;
    } on DuplicateTeacherException catch (e) {
      lastParseFailureReason ??= e.userMessage;
      developer.log(
        '시간표 파싱 중 교사 이름 중복 오류: ${e.toString()}',
        name: 'ExcelService',
      );
      rethrow;
    } catch (e) {
      return _failParse('시간표 파싱 중 오류가 발생했습니다: $e');
    }
  }

  // ==================== 헬퍼 메서드들 ====================

  /// 파싱 설정의 유효성을 검사하는 메서드
  static bool _validateParsingConfig(ExcelParsingConfig config, Sheet sheet) {
    try {
      // 요일 헤더 행이 유효한지 확인
      if (config.dayHeaderRow > sheet.maxRows) {
        developer.log(
          '요일 헤더 행(${config.dayHeaderRow})이 시트 범위를 벗어났습니다.',
          name: 'ExcelService',
        );
        return false;
      }

      // 교시 헤더 행이 유효한지 확인
      if (config.periodHeaderRow > sheet.maxRows) {
        developer.log(
          '교시 헤더 행(${config.periodHeaderRow})이 시트 범위를 벗어났습니다.',
          name: 'ExcelService',
        );
        return false;
      }

      // 교사 열이 유효한지 확인 (최대 50열까지 가정)
      if (config.teacherColumn > ExcelServiceConstants.maxColumnsToCheck) {
        developer.log(
          '교사 열(${config.teacherColumn})이 시트 범위를 벗어났습니다.',
          name: 'ExcelService',
        );
        return false;
      }

      // 데이터 시작 행이 유효한지 확인
      if (config.dataStartRow > sheet.maxRows) {
        developer.log(
          '데이터 시작 행(${config.dataStartRow})이 시트 범위를 벗어났습니다.',
          name: 'ExcelService',
        );
        return false;
      }

      return true;
    } catch (e) {
      developer.log('파싱 설정 검증 중 오류 발생: $e', name: 'ExcelService');
      return false;
    }
  }

  /// 학급명에서 학년 추출하는 유틸리티 메서드
  ///
  /// 추출 규칙:
  /// - "203", "210" → "2" (3자리 숫자: 첫 자리=학년)
  /// - "1-1" → "1" (하이픈 형태)
  /// - "1학년 3반" → "1" (학년 포함 형태)
  /// - "1반" → "1" (단순 숫자 시작)
  static String extractGradeFromClassName(String className) {
    return ExcelParsingUtils.extractGradeFromClassName(className);
  }

  /// 학급명에서 반 번호만 추출하는 유틸리티 메서드
  ///
  /// 추출 규칙:
  /// - "203", "210" → "3", "10" (3자리 숫자: 나머지=반)
  /// - "1-3" → "3" (하이픈 형태)
  /// - "1학년 3반" → "3" (학년 포함 형태)
  static String extractClassNumberFromClassName(String className) {
    return ExcelParsingUtils.extractClassNumberFromClassName(className);
  }
}

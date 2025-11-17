import 'dart:io';
import 'dart:developer' as developer;
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/teacher.dart';
import '../models/time_slot.dart';
import '../utils/day_utils.dart';

/// 상수 정의
class ExcelServiceConstants {
  // 파일 크기 제한
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  // 검색 범위 제한
  static const int maxColumnsToCheck = 50; // 요일 헤더 검색 최대 열 수
  static const int maxPeriodsToCheck = 10; // 교시 검색 최대 범위
  static const int maxRowsToLog = 20; // 로그 출력 최대 행 수
  
  // 셀 순서 검증 샘플링 설정
  static const int maxSamplesForOrderDetection = 20; // 순서 검증 최대 샘플 개수
  static const int minSamplesForOrderDetection = 5; // 순서 검증 최소 샘플 개수
  
  // 교사 행 개수 검증 샘플링 설정
  static const int maxSamplesForTeacherRowDetection = 10; // 교사 행 개수 검증 최대 샘플 개수
  static const int minSamplesForTeacherRowDetection = 3;  // 교사 행 개수 검증 최소 샘플 개수
  
  // 교사 정보 추출 시 추가 검색 설정
  static const int additionalSearchRowsAfterEmptyCell = 20; // 빈 셀 이후 추가 검색 행 수
}

/// 셀 순서 패턴을 나타내는 enum
/// 
/// 셀 내용이 두 줄로 구성될 때의 순서를 나타냅니다.
enum CellOrderPattern {
  /// 정상 순서: 학급번호 → 과목 (예: "103\n국어")
  normal,
  
  /// 바뀐 순서: 과목 → 학급번호 (예: "국어\n103")
  reversed,
  
  /// 확인 불가: 패턴을 확인할 수 없는 경우
  unknown,
}

/// 엑셀 파일 파싱 설정을 위한 클래스
class ExcelParsingConfig {
  final int dayHeaderRow;    // 요일 헤더가 있는 행 (1-based)
  final int periodHeaderRow; // 교시 번호가 있는 행 (1-based)
  final int teacherColumn;   // 교사명이 있는 열 (A열 = 1)
  final int dataStartRow;    // 실제 데이터가 시작하는 행 (1-based)
  final int dataStartColumn; // 실제 데이터가 시작하는 열 (1-based, 첫 번째 요일의 1교시 열)
  
  const ExcelParsingConfig({
    this.dayHeaderRow = 2,
    this.periodHeaderRow = 3,
    this.teacherColumn = 1,
    this.dataStartRow = 4,
    this.dataStartColumn = 2, // 기본값: B열 (A열은 교사명)
  });
  
}

/// 시간표 파싱 결과를 담는 클래스
class TimetableData {
  final List<Teacher> teachers;
  final List<TimeSlot> timeSlots;
  final ExcelParsingConfig config;
  final int totalParsedCells;
  final int successCount;
  final int errorCount;
  
  TimetableData({
    required this.teachers,
    required this.timeSlots,
    required this.config,
    required this.totalParsedCells,
    required this.successCount,
    required this.errorCount,
  });
  
  /// 파싱 성공률 계산
  double get successRate => totalParsedCells > 0 ? successCount / totalParsedCells : 0.0;
  
  /// JSON 직렬화 (저장용)
  /// 
  /// TimetableData를 Map 형태로 변환하여 JSON 파일에 저장할 수 있도록 합니다.
  Map<String, dynamic> toJson() {
    return {
      'teachers': teachers.map((teacher) => teacher.toJson()).toList(),
      'timeSlots': timeSlots.map((slot) => slot.toJson()).toList(),
      'config': {
        'dayHeaderRow': config.dayHeaderRow,
        'periodHeaderRow': config.periodHeaderRow,
        'teacherColumn': config.teacherColumn,
        'dataStartRow': config.dataStartRow,
        'dataStartColumn': config.dataStartColumn,
      },
      'totalParsedCells': totalParsedCells,
      'successCount': successCount,
      'errorCount': errorCount,
    };
  }
  
  /// JSON 역직렬화 (로드용)
  /// 
  /// JSON 파일에서 읽어온 Map 데이터를 TimetableData 객체로 변환합니다.
  factory TimetableData.fromJson(Map<String, dynamic> json) {
    final teachersJson = json['teachers'] as List<dynamic>;
    final teachers = teachersJson
        .map((teacherJson) => Teacher.fromJson(teacherJson as Map<String, dynamic>))
        .toList();
    
    final timeSlotsJson = json['timeSlots'] as List<dynamic>;
    final timeSlots = timeSlotsJson
        .map((slotJson) => TimeSlot.fromJson(slotJson as Map<String, dynamic>))
        .toList();
    
    final configJson = json['config'] as Map<String, dynamic>;
    final config = ExcelParsingConfig(
      dayHeaderRow: configJson['dayHeaderRow'] as int? ?? 2,
      periodHeaderRow: configJson['periodHeaderRow'] as int? ?? 3,
      teacherColumn: configJson['teacherColumn'] as int? ?? 1,
      dataStartRow: configJson['dataStartRow'] as int? ?? 4,
      dataStartColumn: configJson['dataStartColumn'] as int? ?? 2,
    );
    
    return TimetableData(
      teachers: teachers,
      timeSlots: timeSlots,
      config: config,
      totalParsedCells: json['totalParsedCells'] as int? ?? 0,
      successCount: json['successCount'] as int? ?? 0,
      errorCount: json['errorCount'] as int? ?? 0,
    );
  }
  
}

/// 엑셀 파일을 읽고 처리하는 서비스 클래스
class ExcelService {
  // 싱글톤 인스턴스
  static final ExcelService _instance = ExcelService._internal();
  
  // 싱글톤 생성자
  factory ExcelService() => _instance;
  
  // 내부 생성자
  ExcelService._internal();
  
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
  static Future<File?> pickExcelFile() async {
    try {
      // 파일 선택 다이얼로그 표시
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'xlsm'], // 엑셀 파일 형식만 허용 (xlsm: 매크로 포함)
        allowMultiple: false, // 단일 파일만 선택 가능
      );

      // 사용자가 파일을 선택했는지 확인
      if (result != null && result.files.isNotEmpty) {
        // Web 플랫폼에서는 다른 방식으로 처리
        if (kIsWeb) {
          // Web에서는 bytes를 직접 사용
          final bytes = result.files.first.bytes;
          if (bytes != null) {
            // 임시 파일로 저장 (Web에서는 실제 파일 시스템 접근 불가)
            return null; // Web에서는 File 객체 대신 bytes를 직접 사용
          }
        } else {
          // 선택된 파일의 경로를 File 객체로 변환
          String filePath = result.files.first.path!;
          return File(filePath);
        }
      }
      
      // 파일을 선택하지 않았거나 취소한 경우
      return null;
    } catch (e) {
      // 파일 선택 중 오류 발생
      developer.log('파일 선택 중 오류 발생: $e', name: 'ExcelService');
      return null;
    }
  }

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
  static Future<Excel?> readExcelFromBytes(List<int> bytes) async {
    try {
      // bytes를 Excel 객체로 변환
      Excel excel = Excel.decodeBytes(bytes);
      return excel;
    } catch (e) {
      developer.log('엑셀 파일 파싱 실패: $e', name: 'ExcelService');
      return null;
    }
  }

  static Future<Excel?> readExcelFile(File file) async {
    try {
      // 파일이 존재하는지 확인
      if (!await file.exists()) {
        developer.log('파일이 존재하지 않습니다: ${file.path}', name: 'ExcelService');
        return null;
      }

      // 파일 크기 확인 (너무 큰 파일은 처리하지 않음)
      int fileSize = await file.length();
      if (fileSize > ExcelServiceConstants.maxFileSizeBytes) {
        developer.log('파일 크기가 너무 큽니다: ${fileSize / 1024 / 1024}MB', name: 'ExcelService');
        return null;
      }

      // 엑셀 파일 읽기
      var bytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(bytes);
      
      developer.log('엑셀 파일 읽기 성공: ${file.path}', name: 'ExcelService');
      return excel;
    } catch (e) {
      // 엑셀 파일 읽기 중 오류 발생
      developer.log('엑셀 파일 읽기 중 오류 발생: $e', name: 'ExcelService');
      return null;
    }
  }

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
  static void printExcelInfo(Excel excel) {
    try {
      developer.log('=== 엑셀 파일 정보 ===', name: 'ExcelService');
      
      // 워크시트 개수 및 이름 출력
      developer.log('워크시트 개수: ${excel.tables.length}', name: 'ExcelService');
      developer.log('워크시트 이름들: ${excel.tables.keys.toList()}', name: 'ExcelService');
      
      // 각 워크시트별 정보 출력
      excel.tables.forEach((sheetName, sheet) {
        developer.log('\n--- 워크시트: $sheetName ---', name: 'ExcelService');
        developer.log('최대 행 수: ${sheet.maxRows}', name: 'ExcelService');
        developer.log('최대 열 수: 동적으로 확인됨', name: 'ExcelService');
        
        // 첫 번째 행의 데이터 출력 (헤더 확인용)
        if (sheet.maxRows > 0) {
          developer.log('첫 번째 행 데이터:', name: 'ExcelService');
          // 열 수를 동적으로 확인
          int colCount = 0;
          while (colCount < ExcelServiceConstants.maxRowsToLog) { // 최대 행/열 로그 제한
            try {
              var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colCount, rowIndex: 0));
              String cellValue = cell.value?.toString() ?? '';
              if (cellValue.isNotEmpty) {
                developer.log('  열 $colCount: $cellValue', name: 'ExcelService');
              }
              colCount++;
            } catch (e) {
              break; // 더 이상 열이 없으면 중단
            }
          }
        }
        
        // 첫 번째 열의 데이터 출력 (교사명 확인용)
        developer.log('첫 번째 열 데이터:', name: 'ExcelService');
        for (int row = 0; row < sheet.maxRows && row < ExcelServiceConstants.maxRowsToLog; row++) {
          try {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
            String cellValue = cell.value?.toString() ?? '';
            if (cellValue.isNotEmpty) {
              developer.log('  행 $row: $cellValue', name: 'ExcelService');
            }
          } catch (e) {
            break; // 더 이상 행이 없으면 중단
          }
        }
      });
      
      developer.log('=== 엑셀 파일 정보 끝 ===', name: 'ExcelService');
    } catch (e) {
      developer.log('엑셀 정보 출력 중 오류 발생: $e', name: 'ExcelService');
    }
  }

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
  static String getCellValue(Excel excel, String sheetName, int row, int col) {
    try {
      var sheet = excel.tables[sheetName];
      if (sheet == null) {
        developer.log('워크시트를 찾을 수 없습니다: $sheetName', name: 'ExcelService');
        return '';
      }

      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      return cell.value?.toString() ?? '';
    } catch (e) {
      developer.log('셀 값 읽기 중 오류 발생: $e', name: 'ExcelService');
      return '';
    }
  }

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
  static bool isValidExcelFile(Excel excel) {
    try {
      // 워크시트가 있는지 확인
      if (excel.tables.isEmpty) {
        developer.log('워크시트가 없습니다.', name: 'ExcelService');
        return false;
      }

      // 첫 번째 워크시트 가져오기
      var firstSheet = excel.tables.values.first;
      
      // 최소한의 데이터가 있는지 확인
      if (firstSheet.maxRows < 2) {
        developer.log('데이터가 부족합니다. 최소 2행이 필요합니다.', name: 'ExcelService');
        return false;
      }

      return true;
    } catch (e) {
      developer.log('엑셀 파일 유효성 검사 중 오류 발생: $e', name: 'ExcelService');
      return false;
    }
  }

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
  static TimetableData? parseTimetableData(Excel excel, {ExcelParsingConfig? config}) {
    try {
      // 기본 설정 사용
      final parsingConfig = config ?? const ExcelParsingConfig();
      
      developer.log('시간표 파싱 시작: $parsingConfig', name: 'ExcelService');
      
      // 첫 번째 워크시트 가져오기
      var sheet = excel.tables.values.first;
      
      // 기본 설정 유효성 검사 (dataStartRow만 검증)
      // dayHeaderRow, periodHeaderRow, teacherColumn은 동적으로 찾으므로 여기서는 검증하지 않음
      if (parsingConfig.dataStartRow < 1 || parsingConfig.dataStartRow > sheet.maxRows) {
        developer.log('데이터 시작 행 설정이 유효하지 않습니다: ${parsingConfig.dataStartRow}', name: 'ExcelService');
        return null;
      }
      
      // 교사명 헤더 찾기 (1~10행까지 검색)
      Map<String, dynamic> teacherHeaderResult = _findTeacherHeader(sheet);
      int foundTeacherHeaderRow = teacherHeaderResult['row'] as int;
      int foundTeacherColumn = teacherHeaderResult['column'] as int;
      
      if (foundTeacherHeaderRow == 0 || foundTeacherColumn == 0) {
        developer.log('교사명 헤더를 찾을 수 없습니다.', name: 'ExcelService');
        return null;
      }
      
      // 요일 헤더 찾기 (1~10행까지 검색)
      Map<String, dynamic> dayHeaderResult = _findDayHeaders(sheet);
      int foundDayHeaderRow = dayHeaderResult['row'] as int;
      List<String> dayHeaders = (dayHeaderResult['days'] as List).cast<String>();
      
      if (dayHeaders.isEmpty || foundDayHeaderRow == 0) {
        developer.log('요일 헤더를 찾을 수 없습니다.', name: 'ExcelService');
        return null;
      }
      
      // 교시 헤더 행 계산: 요일 헤더 행의 다음 행
      int periodHeaderRow = foundDayHeaderRow + 1;
      
      // dataStartRow 계산: 교시 헤더 행 + 1 (교시 헤더 다음 행부터 실제 데이터 시작)
      // (교사 데이터는 교시 헤더 행의 다음 행부터 시작)
      int finalDataStartRow = periodHeaderRow + 1;
      
      // dataStartColumn 계산: 첫 번째 요일의 1교시 열 찾기
      int? dataStartColumn = _findDataStartColumn(sheet, foundDayHeaderRow, periodHeaderRow, dayHeaders);
      if (dataStartColumn == null) {
        developer.log('데이터 시작 열을 찾을 수 없습니다.', name: 'ExcelService');
        return null;
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
      
      developer.log('동적으로 찾은 파싱 설정: dayHeaderRow=${dynamicConfig.dayHeaderRow}, periodHeaderRow=${dynamicConfig.periodHeaderRow}, teacherColumn=${dynamicConfig.teacherColumn}, dataStartRow=${dynamicConfig.dataStartRow}, dataStartColumn=${dynamicConfig.dataStartColumn}', name: 'ExcelService');
      
      // 동적 설정으로 유효성 재검사
      if (!_validateParsingConfig(dynamicConfig, sheet)) {
        developer.log('동적으로 찾은 파싱 설정이 유효하지 않습니다.', name: 'ExcelService');
        return null;
      }
      
      // 교사 정보 추출 (동적 설정 사용)
      List<Teacher> teachers = _extractTeacherInfo(sheet, dynamicConfig);
      
      // 요일별 교시 번호 찾기 (동적 설정 사용)
      Map<String, List<int>> periodsByDay = _findPeriodsByDay(sheet, dynamicConfig.periodHeaderRow, dayHeaders, dynamicConfig);
      if (periodsByDay.isEmpty) {
        developer.log('교시 번호를 찾을 수 없습니다.', name: 'ExcelService');
        return null;
      }
      
      // 요일별 교시 정보 로그 출력
      for (String day in dayHeaders) {
        List<int> periods = periodsByDay[day] ?? [];
        developer.log('$day요일 교시: $periods', name: 'ExcelService');
      }
      
      // 교사 행 개수 패턴 감지 (샘플링 기반)
      Map<String, dynamic> teacherRowPattern = _detectTeacherRowCountPattern(
        sheet, dynamicConfig, teachers);
      
      // 모든 교사의 행 개수 계산
      Map<Teacher, int> teacherRowCounts = _calculateAllTeacherRowCounts(
        sheet, dynamicConfig, teachers, teacherRowPattern);
      
      // 셀 순서 패턴 감지 (하이브리드 검증, 교사 행 개수 정보 전달)
      CellOrderPattern cellOrderPattern = _detectCellOrder(
        sheet, dynamicConfig, teachers, dayHeaders, periodsByDay, teacherRowCounts);
      developer.log('감지된 셀 순서 패턴: $cellOrderPattern', name: 'ExcelService');
      
      // 셀 순서 패턴을 확인할 수 없는 경우 파싱 중단
      if (cellOrderPattern == CellOrderPattern.unknown) {
        developer.log('셀 순서 패턴을 확인할 수 없어 파싱을 중단합니다. 충분한 샘플 데이터가 없거나 패턴이 일관되지 않습니다.', name: 'ExcelService');
        return null;
      }
      
      // 시간표 데이터 추출 (동적 설정 사용, 셀 순서 패턴 및 교사 행 개수 전달)
      List<TimeSlot> timeSlots = _extractTimeSlotsByDay(
        sheet, dynamicConfig, dayHeaders, periodsByDay, teachers, cellOrderPattern, teacherRowCounts);
      
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
      
    } catch (e) {
      developer.log('시간표 파싱 중 오류 발생: $e', name: 'ExcelService');
      return null;
    }
  }

  // ==================== 헬퍼 메서드들 ====================

  /// 파싱 설정의 유효성을 검사하는 메서드
  static bool _validateParsingConfig(ExcelParsingConfig config, Sheet sheet) {
    try {
      // 요일 헤더 행이 유효한지 확인
      if (config.dayHeaderRow > sheet.maxRows) {
        developer.log('요일 헤더 행(${config.dayHeaderRow})이 시트 범위를 벗어났습니다.', name: 'ExcelService');
        return false;
      }
      
      // 교시 헤더 행이 유효한지 확인
      if (config.periodHeaderRow > sheet.maxRows) {
        developer.log('교시 헤더 행(${config.periodHeaderRow})이 시트 범위를 벗어났습니다.', name: 'ExcelService');
        return false;
      }
      
      // 교사 열이 유효한지 확인 (최대 50열까지 가정)
      if (config.teacherColumn > ExcelServiceConstants.maxColumnsToCheck) {
        developer.log('교사 열(${config.teacherColumn})이 시트 범위를 벗어났습니다.', name: 'ExcelService');
        return false;
      }
      
      // 데이터 시작 행이 유효한지 확인
      if (config.dataStartRow > sheet.maxRows) {
        developer.log('데이터 시작 행(${config.dataStartRow})이 시트 범위를 벗어났습니다.', name: 'ExcelService');
        return false;
      }
      
      return true;
    } catch (e) {
      developer.log('파싱 설정 검증 중 오류 발생: $e', name: 'ExcelService');
      return false;
    }
  }

  /// 교사명 헤더를 찾는 메서드 (1~10행까지 검색)
  /// 
  /// 반환값: `Map<String, dynamic>` 형태로 {'row': 찾은 행 번호(1-based), 'column': 찾은 열 번호(1-based)}
  /// 교사명 헤더를 찾지 못한 경우 {'row': 0, 'column': 0} 반환
  static Map<String, dynamic> _findTeacherHeader(Sheet sheet) {
    try {
      // 교사명 헤더 키워드 목록
      List<String> teacherHeaderKeywords = ['교사', '성명', '이름'];
      
      // 1행부터 10행까지 검색
      for (int row = 1; row <= 10; row++) {
        // 각 행의 모든 열을 확인 (최대 50열까지)
        for (int col = 1; col <= ExcelServiceConstants.maxColumnsToCheck; col++) {
          String cellValue = _getCellValue(sheet, row - 1, col - 1); // 0-based로 변환
          cellValue = cellValue.trim();
          
          // 키워드와 일치하는지 확인
          for (String keyword in teacherHeaderKeywords) {
            if (cellValue == keyword) {
              developer.log('교사명 헤더를 $row행 $col열에서 찾았습니다: $keyword', name: 'ExcelService');
              return {
                'row': row,
                'column': col,
              };
            }
          }
        }
      }
      
      // 교사명 헤더를 찾지 못한 경우
      developer.log('1~10행에서 교사명 헤더를 찾을 수 없습니다.', name: 'ExcelService');
      return {
        'row': 0,
        'column': 0,
      };
    } catch (e) {
      developer.log('교사명 헤더 찾기 중 오류 발생: $e', name: 'ExcelService');
      return {
        'row': 0,
        'column': 0,
      };
    }
  }

  /// 요일 헤더를 찾는 메서드 (1~10행까지 검색)
  /// 
  /// 반환값: `Map<String, dynamic>` 형태로 {'row': 찾은 행 번호(1-based), 'days': 요일 목록}
  /// 요일을 찾지 못한 경우 {'row': 0, 'days': []} 반환
  static Map<String, dynamic> _findDayHeaders(Sheet sheet) {
    try {
      // 요일 매핑 (월~일 모두 포함)
      Map<String, String> dayMapping = {
        '월': '월',
        '화': '화', 
        '수': '수',
        '목': '목',
        '금': '금',
        '토': '토',
        '일': '일',
        'MON': '월',
        'TUE': '화',
        'WED': '수',
        'THU': '목',
        'FRI': '금',
        'SAT': '토',
        'SUN': '일',
      };
      
      // 1행부터 10행까지 검색
      for (int row = 1; row <= 10; row++) {
        List<String> dayHeaders = [];
        
        // 해당 행의 모든 셀을 확인 (최대 50열까지)
        for (int col = 1; col <= ExcelServiceConstants.maxColumnsToCheck; col++) {
          String cellValue = _getCellValue(sheet, row - 1, col - 1); // 0-based로 변환
          cellValue = cellValue.trim().toUpperCase();
          
          if (dayMapping.containsKey(cellValue)) {
            String day = dayMapping[cellValue]!;
            // 중복 제거
            if (!dayHeaders.contains(day)) {
              dayHeaders.add(day);
            }
          }
        }
        
        // 요일을 찾은 경우 (최소 1개 이상)
        if (dayHeaders.isNotEmpty) {
          developer.log('요일 헤더를 $row행에서 찾았습니다: $dayHeaders', name: 'ExcelService');
          return {
            'row': row,
            'days': dayHeaders,
          };
        }
      }
      
      // 요일을 찾지 못한 경우
      developer.log('1~10행에서 요일 헤더를 찾을 수 없습니다.', name: 'ExcelService');
      return {
        'row': 0,
        'days': [],
      };
    } catch (e) {
      developer.log('요일 헤더 찾기 중 오류 발생: $e', name: 'ExcelService');
      return {
        'row': 0,
        'days': [],
      };
    }
  }

  /// 교시 번호를 찾는 메서드 (요일별로 실제 존재하는 교시만 찾기)
  /// 요일 바로 다음 행에서 교시 번호를 찾습니다.
  static Map<String, List<int>> _findPeriodsByDay(Sheet sheet, int periodHeaderRow, List<String> dayHeaders, ExcelParsingConfig config) {
    try {
      Map<String, List<int>> periodsByDay = {};
      
      // 요일별 시작 열 위치 계산
      Map<String, int> dayColumnMapping = _calculateDayColumns(sheet, config, dayHeaders);
      
      for (String day in dayHeaders) {
        int? dayStartCol = dayColumnMapping[day];
        if (dayStartCol == null) continue;
        
        List<int> periods = [];
        
        // 해당 요일의 교시 번호만 찾기 (요일 바로 다음 행에서)
        // 요일 헤더 행의 다음 행이 교시 행이므로 periodHeaderRow 사용
        Set<int> uniquePeriods = {}; // 중복 제거를 위한 Set 사용
        
        // 각 요일의 시작 열부터 연속된 교시만 찾기
        List<String> cellValues = []; // 디버깅용
        for (int col = dayStartCol; col < dayStartCol + 15; col++) { // 최대 15열까지 검색
          String cellValue = _getCellValue(sheet, periodHeaderRow - 1, col - 1); // 0-based로 변환
          cellValue = cellValue.trim();
          
          cellValues.add(cellValue); // 디버깅용
          
          // 빈 셀이 나오면 해당 요일의 교시 검색 중단
          if (cellValue.isEmpty) {
            break;
          }
          
          // 숫자로 변환 시도
          int? period = int.tryParse(cellValue);
          if (period != null && period >= 1 && period <= ExcelServiceConstants.maxPeriodsToCheck) {
            // 이미 나온 숫자(교시)가 나오면 해당 요일의 교시 검색 중단
            if (uniquePeriods.contains(period)) {
              break;
            }
            uniquePeriods.add(period); // Set에 추가하여 중복 자동 제거
          } else {
            // 숫자가 아닌 값이 나오면 해당 요일의 교시 검색 중단
            break;
          }
        }
        
        // 디버깅 로그 - 각 열의 값 확인
        developer.log('$day요일 열 값들: $cellValues', name: 'ExcelService');
        
        // Set을 List로 변환하고 정렬
        periods = uniquePeriods.toList()..sort();
        periodsByDay[day] = periods;
        
        // 디버깅 로그
        developer.log('$day요일에서 찾은 교시: $periods (시작열: $dayStartCol)', name: 'ExcelService');
      }
      
      return periodsByDay;
    } catch (e) {
      developer.log('요일별 교시 번호 찾기 중 오류 발생: $e', name: 'ExcelService');
      return {};
    }
  }

  /// 교사 정보를 추출하는 메서드
  /// 
  /// 교사 행 개수를 고려하여 모든 교사 이름을 추출합니다.
  /// 빈 셀을 만나면 추가로 지정된 행 수만큼 더 검색하여 마지막 교사까지 찾습니다.
  static List<Teacher> _extractTeacherInfo(Sheet sheet, ExcelParsingConfig config) {
    try {
      List<Teacher> teachers = [];
      Set<String> seenNames = {}; // 중복 제거용
      int consecutiveEmptyRows = 0; // 연속된 빈 행 개수
      
      // 교사 이름이 있는 행 찾기
      for (int row = config.dataStartRow; row <= sheet.maxRows; row++) {
        String teacherCell = _getCellValue(sheet, row - 1, config.teacherColumn - 1); // 0-based로 변환
        
        if (teacherCell.trim().isEmpty) {
          // 빈 셀을 만난 경우
          consecutiveEmptyRows++;
          
          // 연속된 빈 행이 추가 검색 행 수를 초과하면 중단
          if (consecutiveEmptyRows > ExcelServiceConstants.additionalSearchRowsAfterEmptyCell) {
            developer.log('연속된 빈 행 $consecutiveEmptyRows개를 만나 검색을 중단합니다. ($row행)', name: 'ExcelService');
            break;
          }
          
          continue; // 빈 셀은 건너뛰기
        }
        
        // 빈 셀이 아닌 경우 연속 빈 행 카운터 리셋
        consecutiveEmptyRows = 0;
        
        // 교사명 파싱: "A교사(20)" → name: "A교사", id: "20"
        Teacher? teacher = _parseTeacherName(teacherCell);
        if (teacher != null && !seenNames.contains(teacher.name)) {
          teachers.add(teacher);
          seenNames.add(teacher.name);
          developer.log('교사 발견: $teacher.name ($row행)', name: 'ExcelService');
        }
      }
      
      developer.log('총 ${teachers.length}명의 교사를 찾았습니다.', name: 'ExcelService');
      return teachers;
    } catch (e) {
      developer.log('교사 정보 추출 중 오류 발생: $e', name: 'ExcelService');
      return [];
    }
  }

  /// 특정 교사 이름이 있는 행을 찾는 헬퍼 메서드
  /// 
  /// 매개변수:
  /// - Sheet sheet: 엑셀 시트
  /// - ExcelParsingConfig config: 파싱 설정
  /// - Teacher teacher: 찾을 교사
  /// - int startSearchRow: 검색 시작 행 (1-based)
  /// 
  /// 반환값:
  /// - int: 교사 이름이 있는 행 번호 (1-based), 찾지 못하면 0
  static int _findTeacherNameRow(
    Sheet sheet,
    ExcelParsingConfig config,
    Teacher teacher,
    int startSearchRow,
  ) {
    try {
      for (int row = startSearchRow; row <= sheet.maxRows; row++) {
        String cellValue = _getCellValue(sheet, row - 1, config.teacherColumn - 1);
        Teacher? parsedTeacher = _parseTeacherName(cellValue);
        
        if (parsedTeacher != null && parsedTeacher.name == teacher.name) {
          return row;
        }
      }
      return 0;
    } catch (e) {
      developer.log('교사 이름 행 찾기 중 오류 발생: $e', name: 'ExcelService');
      return 0;
    }
  }

  /// 교사 이름 행부터 다음 교사 이름 행 전까지의 행 개수를 계산하는 메서드
  /// 
  /// 예시:
  /// - 홍길동(4행) → 이순신(5행): 1행 (4행만)
  /// - 홍길동(4행), 빈행(5행), 이순신(6행): 2행 (4-5행)
  /// - 홍길동(4행), 빈행(5행), 빈행(6행), 이순신(7행): 3행 (4-6행)
  /// 
  /// 매개변수:
  /// - Sheet sheet: 엑셀 시트
  /// - ExcelParsingConfig config: 파싱 설정
  /// - Teacher currentTeacher: 현재 교사
  /// - int currentTeacherRow: 현재 교사 이름이 있는 행 (1-based)
  /// - Teacher? nextTeacher: 다음 교사 (없으면 null)
  /// 
  /// 반환값:
  /// - int: 교사가 차지하는 행 개수 (최소 1)
  static int _calculateTeacherRowCount(
    Sheet sheet,
    ExcelParsingConfig config,
    Teacher currentTeacher,
    int currentTeacherRow,
    Teacher? nextTeacher,
  ) {
    try {
      // 다음 교사 이름이 있는 행 찾기
      int nextTeacherRow = sheet.maxRows + 1; // 기본값: 마지막 행 다음
      
      if (nextTeacher != null) {
        // 다음 교사 이름이 있는 행 검색 (현재 교사 행 다음부터)
        for (int row = currentTeacherRow + 1; row <= sheet.maxRows; row++) {
          String cellValue = _getCellValue(sheet, row - 1, config.teacherColumn - 1);
          Teacher? parsedTeacher = _parseTeacherName(cellValue);
          
          if (parsedTeacher != null && parsedTeacher.name == nextTeacher.name) {
            nextTeacherRow = row;
            break;
          }
        }
      }
      
      // 행 개수 계산: 다음 교사 행 - 현재 교사 행
      int rowCount = nextTeacherRow - currentTeacherRow;
      
      // 최소 1행 보장
      if (rowCount < 1) {
        rowCount = 1;
      }
      
      return rowCount;
    } catch (e) {
      developer.log('교사 행 개수 계산 중 오류 발생: $e', name: 'ExcelService');
      return 1; // 오류 시 기본값 1행
    }
  }

  /// 샘플링 기반으로 교사 행 개수 패턴을 감지하는 메서드
  /// 
  /// 처음 몇 개 교사를 샘플링하여 각 교사가 몇 행을 차지하는지 확인합니다.
  /// 
  /// 반환값:
  /// - `Map<String, dynamic>`: {
  ///     'rowsPerTeacher': `int?`, // 교사당 행 수 (일관된 경우), null이면 일관되지 않음
  ///     'sampleCounts': `Map<Teacher, int>`, // 샘플 교사별 행 개수
  ///     'isConsistent': bool, // 패턴이 일관되는지 여부
  ///   }
  static Map<String, dynamic> _detectTeacherRowCountPattern(
    Sheet sheet,
    ExcelParsingConfig config,
    List<Teacher> teachers,
  ) {
    try {
      Map<Teacher, int> sampleCounts = {};
      List<int> rowsPerTeacherList = [];
      
      // 처음 몇 개 교사만 샘플링
      int sampleCount = teachers.length < ExcelServiceConstants.maxSamplesForTeacherRowDetection
          ? teachers.length
          : ExcelServiceConstants.maxSamplesForTeacherRowDetection;
      
      // 교사 이름이 있는 행들을 먼저 찾기
      Map<Teacher, int> teacherRows = {};
      for (int i = 0; i < sampleCount; i++) {
        Teacher teacher = teachers[i];
        int teacherRow = _findTeacherNameRow(sheet, config, teacher, config.dataStartRow);
        if (teacherRow > 0) {
          teacherRows[teacher] = teacherRow;
        }
      }
      
      // 각 샘플 교사의 행 개수 계산
      for (int i = 0; i < sampleCount; i++) {
        Teacher teacher = teachers[i];
        int? teacherRow = teacherRows[teacher];
        
        if (teacherRow == null) continue;
        
        Teacher? nextTeacher = (i < teachers.length - 1) ? teachers[i + 1] : null;
        int rowCount = _calculateTeacherRowCount(
          sheet, config, teacher, teacherRow, nextTeacher);
        
        sampleCounts[teacher] = rowCount;
        rowsPerTeacherList.add(rowCount);
        
        developer.log('샘플 교사 ${teacher.name}: $rowCount행 ($teacherRow행부터)', 
            name: 'ExcelService');
      }
      
      // 패턴 일관성 검증
      bool isConsistent = false;
      int? consistentRowsPerTeacher;
      
      if (rowsPerTeacherList.length >= ExcelServiceConstants.minSamplesForTeacherRowDetection) {
        // 가장 많이 나타나는 행 수 찾기
        Map<int, int> frequency = {};
        for (int rows in rowsPerTeacherList) {
          frequency[rows] = (frequency[rows] ?? 0) + 1;
        }
        
        int maxFrequency = frequency.values.reduce((a, b) => a > b ? a : b);
        int mostCommonRows = frequency.entries
            .firstWhere((e) => e.value == maxFrequency)
            .key;
        
        // 일관성 검증: 샘플의 80% 이상이 동일한 행 수를 가지는지 확인
        int consistentCount = frequency[mostCommonRows] ?? 0;
        double consistencyRate = consistentCount / rowsPerTeacherList.length;
        
        if (consistencyRate >= 0.8) {
          isConsistent = true;
          consistentRowsPerTeacher = mostCommonRows;
          developer.log('교사 행 개수 패턴 감지: 교사당 $consistentRowsPerTeacher행 (일관성: ${(consistencyRate * 100).toStringAsFixed(1)}%)', 
              name: 'ExcelService');
        } else {
          developer.log('교사 행 개수가 일관되지 않음. 각 교사별로 개별 계산합니다.', name: 'ExcelService');
        }
      }
      
      return {
        'rowsPerTeacher': consistentRowsPerTeacher,
        'sampleCounts': sampleCounts,
        'isConsistent': isConsistent,
      };
    } catch (e) {
      developer.log('교사 행 개수 패턴 감지 중 오류 발생: $e', name: 'ExcelService');
      return {
        'rowsPerTeacher': null,
        'sampleCounts': {},
        'isConsistent': false,
      };
    }
  }

  /// 모든 교사의 행 개수를 계산하는 메서드 (패턴 결과 활용)
  /// 
  /// 샘플링으로 감지된 패턴을 사용하여 모든 교사의 행 개수를 계산합니다.
  /// 
  /// 반환값:
  /// - `Map<Teacher, int>`: 각 교사별 행 개수
  static Map<Teacher, int> _calculateAllTeacherRowCounts(
    Sheet sheet,
    ExcelParsingConfig config,
    List<Teacher> teachers,
    Map<String, dynamic> patternResult,
  ) {
    Map<Teacher, int> rowCounts = {};
    
    int? rowsPerTeacher = patternResult['rowsPerTeacher'] as int?;
    bool isConsistent = patternResult['isConsistent'] as bool;
    Map<Teacher, int> sampleCounts = 
        (patternResult['sampleCounts'] as Map).cast<Teacher, int>();
    
    // 교사 이름이 있는 행들을 먼저 찾기
    Map<Teacher, int> teacherRows = {};
    for (Teacher teacher in teachers) {
      int teacherRow = _findTeacherNameRow(sheet, config, teacher, config.dataStartRow);
      if (teacherRow > 0) {
        teacherRows[teacher] = teacherRow;
      }
    }
    
    if (isConsistent && rowsPerTeacher != null) {
      // 패턴이 일관된 경우: 모든 교사에 동일한 행 수 적용
      developer.log('일관된 패턴 적용: 교사당 $rowsPerTeacher행', name: 'ExcelService');
      
      for (Teacher teacher in teachers) {
        rowCounts[teacher] = rowsPerTeacher;
      }
    } else {
      // 패턴이 일관되지 않은 경우: 각 교사별로 개별 계산
      developer.log('일관되지 않은 패턴: 각 교사별로 개별 계산', name: 'ExcelService');
      
      for (int i = 0; i < teachers.length; i++) {
        Teacher teacher = teachers[i];
        
        // 샘플에 포함된 교사는 샘플 결과 사용
        if (sampleCounts.containsKey(teacher)) {
          rowCounts[teacher] = sampleCounts[teacher]!;
          continue;
        }
        
        // 샘플에 포함되지 않은 교사는 개별 계산
        int? teacherRow = teacherRows[teacher];
        if (teacherRow == null) {
          rowCounts[teacher] = 1; // 기본값
          continue;
        }
        
        Teacher? nextTeacher = (i < teachers.length - 1) ? teachers[i + 1] : null;
        int rowCount = _calculateTeacherRowCount(
          sheet, config, teacher, teacherRow, nextTeacher);
        
        rowCounts[teacher] = rowCount;
      }
    }
    
    // 로그 출력
    for (Teacher teacher in teachers) {
      int rowCount = rowCounts[teacher] ?? 1;
      int? teacherRow = teacherRows[teacher];
      developer.log('교사 ${teacher.name}: $rowCount행${teacherRow != null ? ' ($teacherRow행부터)' : ''}', 
          name: 'ExcelService');
    }
    
    return rowCounts;
  }

  /// 교사명을 파싱하는 메서드
  static Teacher? _parseTeacherName(String teacherText) {
    try {
      teacherText = teacherText.trim();
      
      // 괄호가 있는 경우: "A교사(20)" → "A교사"로 변환
      if (teacherText.contains('(') && teacherText.contains(')')) {
        int openIndex = teacherText.indexOf('(');
        
        if (openIndex > 0) {
          String name = teacherText.substring(0, openIndex).trim();
          
          if (name.isNotEmpty) {
            return Teacher(
              id: null, // 괄호 안의 숫자는 ID가 아니므로 null로 설정
              name: name,
              subject: '', // 주 담당 과목은 나중에 계산
              remarks: null,
            );
          }
        }
      }
      
      // 괄호가 없는 경우: "A교사"
      if (teacherText.isNotEmpty) {
        return Teacher(
          id: null,
          name: teacherText,
          subject: '', // 주 담당 과목은 나중에 계산
          remarks: null,
        );
      }
      
      return null;
    } catch (e) {
      developer.log('교사명 파싱 중 오류 발생: $e', name: 'ExcelService');
      return null;
    }
  }

  /// 시간표 데이터를 추출하는 메서드 (요일별 교시 고려)
  static List<TimeSlot> _extractTimeSlotsByDay(
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
      Map<String, int> dayColumnMapping = _calculateDayColumns(sheet, config, dayHeaders);

      // 각 교사에 대해 시간표 데이터 추출
      for (Teacher teacher in teachers) {
        // 교사 이름이 있는 행 찾기
        int teacherRow = _findTeacherNameRow(sheet, config, teacher, config.dataStartRow);
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
  /// - 2행 이상: 1행과 2행을 줄바꿈으로 합쳐서 처리, 3행 이후는 무시
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
    int? periodCol = _findPeriodColumnInDay(sheet, config, dayStartCol, period);
    if (periodCol == null) return null;

    String cellValue;
    
    if (rowCount == 1) {
      // 1행인 경우: 현재 방식 (줄바꿈으로 구분)
      cellValue = _getCellValue(sheet, teacherRow - 1, periodCol - 1);
    } else {
      // 2행 이상인 경우: 1행과 2행을 줄바꿈으로 합쳐서 처리, 3행 이후는 무시
      List<String> rowValues = [];
      
      // 최대 2행만 사용 (3행 이후는 무시)
      int rowsToUse = rowCount > 2 ? 2 : rowCount;
      
      for (int i = 0; i < rowsToUse; i++) {
        int currentRow = teacherRow + i - 1; // 0-based로 변환
        String rowValue = _getCellValue(sheet, currentRow, periodCol - 1);
        rowValue = rowValue.trim();
        
        // 빈 셀이 아닌 경우만 추가
        if (rowValue.isNotEmpty) {
          rowValues.add(rowValue);
        }
      }
      
      // 줄바꿈으로 합치기
      cellValue = rowValues.join('\n');
    }
    
    return _parseTimeSlotCell(cellValue, teacher, dayOfWeek, period, 
        orderPattern: cellOrderPattern);
  }

  /// 데이터 시작 열을 찾는 메서드 (첫 번째 요일의 1교시 열)
  /// 
  /// 매개변수:
  /// - Sheet sheet: 엑셀 시트
  /// - int dayHeaderRow: 요일 헤더 행 (1-based)
  /// - int periodHeaderRow: 교시 헤더 행 (1-based)
  /// - `List<String>` dayHeaders: 요일 목록
  /// 
  /// 반환값:
  /// - int?: 첫 번째 요일의 1교시 열 위치 (1-based), 찾지 못하면 null
  static int? _findDataStartColumn(Sheet sheet, int dayHeaderRow, int periodHeaderRow, List<String> dayHeaders) {
    try {
      if (dayHeaders.isEmpty) {
        return null;
      }
      
      // 첫 번째 요일 찾기
      String firstDay = dayHeaders.first;
      
      // 첫 번째 요일의 시작 열 찾기
      int? firstDayStartCol;
      for (int col = 1; col <= ExcelServiceConstants.maxColumnsToCheck; col++) {
        String cellValue = _getCellValue(sheet, dayHeaderRow - 1, col - 1); // 0-based로 변환
        cellValue = cellValue.trim();
        
        if (cellValue == firstDay) {
          firstDayStartCol = col;
          break;
        }
      }
      
      if (firstDayStartCol == null) {
        developer.log('첫 번째 요일($firstDay)의 시작 열을 찾을 수 없습니다.', name: 'ExcelService');
        return null;
      }
      
      // 첫 번째 요일의 시작 열부터 1교시 찾기
      for (int col = firstDayStartCol; col < firstDayStartCol + ExcelServiceConstants.maxPeriodsToCheck; col++) {
        String cellValue = _getCellValue(sheet, periodHeaderRow - 1, col - 1); // 0-based로 변환
        cellValue = cellValue.trim();
        
        // 숫자로 변환 시도
        int? period = int.tryParse(cellValue);
        if (period == 1) {
          developer.log('데이터 시작 열을 찾았습니다: $col열 ($firstDay요일 1교시)', name: 'ExcelService');
          return col;
        }
        
        // 빈 셀이 나오면 해당 요일의 교시 검색 중단
        if (cellValue.isEmpty) {
          break;
        }
      }
      
      developer.log('첫 번째 요일($firstDay)에서 1교시를 찾을 수 없습니다.', name: 'ExcelService');
      return null;
    } catch (e) {
      developer.log('데이터 시작 열 찾기 중 오류 발생: $e', name: 'ExcelService');
      return null;
    }
  }

  /// 요일별 시작 열 위치를 계산하는 메서드
  static Map<String, int> _calculateDayColumns(Sheet sheet, ExcelParsingConfig config, List<String> dayHeaders) {
    try {
      Map<String, int> dayColumnMapping = {};
      
      // 요일 헤더 행에서 각 요일의 위치 찾기 (최대 50열까지)
      for (int col = 1; col <= ExcelServiceConstants.maxColumnsToCheck; col++) {
        String cellValue = _getCellValue(sheet, config.dayHeaderRow - 1, col - 1); // 0-based로 변환
        cellValue = cellValue.trim();
        
        for (String day in dayHeaders) {
          if (cellValue == day) {
            dayColumnMapping[day] = col;
            break;
          }
        }
      }
      
      // 로그 제거
      return dayColumnMapping;
    } catch (e) {
      developer.log('요일별 열 위치 계산 중 오류 발생: $e', name: 'ExcelService');
      return {};
    }
  }

  /// 특정 요일 내에서 교시의 열 위치를 찾는 메서드
  /// 
  /// 매개변수:
  /// - Sheet sheet: 엑셀 시트
  /// - ExcelParsingConfig config: 파싱 설정
  /// - int dayStartCol: 요일의 시작 열 (1-based)
  /// - int period: 찾을 교시 번호
  /// 
  /// 반환값:
  /// - int?: 교시의 열 위치 (찾지 못하면 null)
  static int? _findPeriodColumnInDay(Sheet sheet, ExcelParsingConfig config, int dayStartCol, int period) {
    try {
      // 요일 시작 열부터 오른쪽으로 최대 10열까지 검색
      for (int col = dayStartCol; col < dayStartCol + ExcelServiceConstants.maxPeriodsToCheck; col++) {
        String cellValue = _getCellValue(sheet, config.periodHeaderRow - 1, col - 1); // 0-based로 변환
        cellValue = cellValue.trim();
        
        // 숫자로 변환 시도
        int? cellPeriod = int.tryParse(cellValue);
        if (cellPeriod == period) {
          return col;
        }
      }
      
      // 로그 제거
      return null;
    } catch (e) {
      developer.log('교시 열 위치 찾기 중 오류 발생: $e', name: 'ExcelService');
      return null;
    }
  }


  /// 학급번호를 표준 형식으로 변환하는 메서드
  /// 
  /// 변환 규칙:
  /// - "202" → "2-2" (3자리 숫자: 첫 자리=학년, 나머지=반)
  /// - "103" → "1-3"
  /// - "1-3" → "1-3" (이미 변환된 형태는 그대로)
  /// - "2-1" → "2-1" (이미 변환된 형태는 그대로)
  static String _convertClassName(String className) {
    try {
      className = className.trim();
      
      // 이미 '-'가 포함된 경우 그대로 반환
      if (className.contains('-')) {
        return className;
      }
      
      // 3자리 숫자인 경우 변환 (예: "202" → "2-2")
      if (className.length == 3 && RegExp(r'^\d{3}$').hasMatch(className)) {
        String grade = className[0];      // 첫 번째 자리: 학년
        String classNum = className.substring(1); // 나머지: 반
        
        // 반 번호가 한 자리인 경우 앞의 0 제거
        if (classNum.startsWith('0') && classNum.length > 1) {
          classNum = classNum.substring(1);
        }
        
        String converted = '$grade-$classNum';
        return converted;
      }
      
      // 변환할 수 없는 형태는 그대로 반환
      return className;
    } catch (e) {
      developer.log('학급번호 변환 중 오류 발생: $e', name: 'ExcelService');
      return className;
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
    try {
      className = className.trim();
      
      // 1. 3자리 숫자 형태 처리 (예: "103" -> "1", "203" -> "2")
      if (className.length == 3 && RegExp(r'^\d{3}$').hasMatch(className)) {
        return className[0]; // 첫 번째 자리: 학년
      }
      
      // 2. 하이픈 형태 처리 (예: "1-1" -> "1")
      final gradeMatch = RegExp(r'(\d+)[-학년]').firstMatch(className);
      if (gradeMatch != null) {
        return gradeMatch.group(1) ?? '';
      }
      
      // 3. 학년 포함 형태 처리 (예: "1학년 3반" -> "1", "2학년 10반" -> "2")
      final gradeYearMatch = RegExp(r'(\d+)학년').firstMatch(className);
      if (gradeYearMatch != null) {
        return gradeYearMatch.group(1) ?? '';
      }
      
      return '';
    } catch (e) {
      developer.log('학년 추출 중 오류 발생: $e', name: 'ExcelService');
      return '';
    }
  }

  /// 학급명에서 반 번호만 추출하는 유틸리티 메서드
  /// 
  /// 추출 규칙:
  /// - "203", "210" → "3", "10" (3자리 숫자: 나머지=반)
  /// - "1-3" → "3" (하이픈 형태)
  /// - "1학년 3반" → "3" (학년 포함 형태)
  static String extractClassNumberFromClassName(String className) {
    try {
      className = className.trim();
      
      // 1. 3자리 숫자 형태 처리 (예: "103" -> "3", "110" -> "10")
      if (className.length == 3 && RegExp(r'^\d{3}$').hasMatch(className)) {
        String classNum = className.substring(1); // 나머지: 반
        // 반 번호가 한 자리인 경우 앞의 0 제거
        if (classNum.startsWith('0') && classNum.length > 1) {
          classNum = classNum.substring(1);
        }
        return classNum;
      }
      
      // 2. 하이픈 형태 처리 (예: "1-3" -> "3", "2-10" -> "10")
      if (className.contains('-')) {
        final parts = className.split('-');
        if (parts.length >= 2) {
          return parts[1].trim();
        }
      }
      
      // 3. 학년 포함 형태 처리 (예: "1학년 3반" -> "3", "2학년 10반" -> "10")
      final classMatch = RegExp(r'학년\s*(\d+)반').firstMatch(className);
      if (classMatch != null) {
        return classMatch.group(1) ?? '';
      }
      
      return '';
    } catch (e) {
      developer.log('반 번호 추출 중 오류 발생: $e', name: 'ExcelService');
      return '';
    }
  }

  /// 학급번호 패턴인지 확인하는 메서드
  /// 
  /// 학급번호 패턴 예시:
  /// - "103", "202" (3자리 숫자)
  /// - "1-3", "2-1", "2-10" (하이픈 형태)
  /// - "1반", "2반" (숫자+반)
  /// - "1학년 3반" (학년-반 형태)
  static bool _isClassNamePattern(String text) {
    try {
      text = text.trim();
      
      // 1. 3자리 숫자 (예: "103", "202")
      if (RegExp(r'^\d{3}$').hasMatch(text)) return true;
      
      // 2. 하이픈 형태 (예: "1-3", "2-1", "2-10")
      if (RegExp(r'^\d+-\d+$').hasMatch(text)) return true;
      
      // 3. 숫자+반 형태 (예: "1반", "2반")
      if (RegExp(r'^\d+반?$').hasMatch(text)) return true;
      
      // 4. 학년-반 형태 (예: "1학년 3반", "2학년 10반")
      if (RegExp(r'^\d+학년\s*\d+반$').hasMatch(text)) return true;
      
      return false;
    } catch (e) {
      developer.log('학급번호 패턴 확인 중 오류 발생: $e', name: 'ExcelService');
      return false;
    }
  }

  /// 과목명 패턴인지 확인하는 메서드
  /// 
  /// 과목명 패턴 예시:
  /// - "국어", "수학", "영어" (한글)
  /// - "English", "Math" (영문)
  /// - "체육", "음악" (한글 과목명)
  static bool _isSubjectPattern(String text) {
    try {
      text = text.trim();
      
      // 학급번호 패턴이면 과목이 아님
      if (_isClassNamePattern(text)) return false;
      
      // 숫자만 있는 경우는 과목이 아님
      if (RegExp(r'^\d+$').hasMatch(text)) return false;
      
      // 한글이나 영문으로 구성된 텍스트 (일반적인 과목명)
      if (RegExp(r'^[가-힣a-zA-Z\s]+$').hasMatch(text)) return true;
      
      return false;
    } catch (e) {
      developer.log('과목명 패턴 확인 중 오류 발생: $e', name: 'ExcelService');
      return false;
    }
  }

  /// 샘플링 기반으로 셀 순서 패턴을 검증하는 메서드
  /// 
  /// 처음 몇 개 셀을 샘플링하여 정상 순서인지 바뀐 순서인지 판단합니다.
  /// 
  /// 매개변수:
  /// - Sheet sheet: 엑셀 시트
  /// - ExcelParsingConfig config: 파싱 설정
  /// - `List<Teacher>` teachers: 교사 목록
  /// - `List<String>` dayHeaders: 요일 목록
  /// - `Map<String, List<int>>` periodsByDay: 요일별 교시 목록
  /// - `Map<Teacher, int>` teacherRowCounts: 교사별 행 개수
  /// 
  /// 반환값:
  /// - `Map<String, dynamic>`: {'pattern': CellOrderPattern, 'normalCount': int, 'reversedCount': int, 'sampleSize': int}
  static Map<String, dynamic> _detectCellOrderPattern(
    Sheet sheet,
    ExcelParsingConfig config,
    List<Teacher> teachers,
    List<String> dayHeaders,
    Map<String, List<int>> periodsByDay,
    Map<Teacher, int> teacherRowCounts,
  ) {
    try {
      int normalOrderCount = 0;  // 정상 순서 셀 개수 (학급번호 → 과목)
      int reversedOrderCount = 0; // 바뀐 순서 셀 개수 (과목 → 학급번호)
      int sampleSize = 0;
      
      // 요일별 시작 열 위치 계산
      Map<String, int> dayColumnMapping = _calculateDayColumns(sheet, config, dayHeaders);
      
      // 처음 몇 개 교사의 시간표 셀을 샘플링
      for (int teacherIndex = 0; 
           teacherIndex < teachers.length && sampleSize < ExcelServiceConstants.maxSamplesForOrderDetection; 
           teacherIndex++) {
        Teacher teacher = teachers[teacherIndex];
        
        // 교사 이름이 있는 행 찾기
        int teacherRow = _findTeacherNameRow(sheet, config, teacher, config.dataStartRow);
        if (teacherRow == 0) continue;
        
        // 교사 행 개수 가져오기
        int rowCount = teacherRowCounts[teacher] ?? 1;
        
        // 각 요일의 첫 번째 교시 셀만 샘플링 (성능 고려)
        for (String day in dayHeaders) {
          if (sampleSize >= ExcelServiceConstants.maxSamplesForOrderDetection) break;
          
          int? dayStartCol = dayColumnMapping[day];
          if (dayStartCol == null) continue;
          
          List<int> periods = periodsByDay[day] ?? [];
          if (periods.isEmpty) continue;
          
          // 첫 번째 교시 셀 읽기
          int firstPeriod = periods.first;
          int? periodCol = _findPeriodColumnInDay(sheet, config, dayStartCol, firstPeriod);
          if (periodCol == null) continue;
          
          // 교사 행 개수에 따라 셀 값 읽기
          String cellValue;
          if (rowCount == 1) {
            // 1행인 경우: 현재 방식 (줄바꿈으로 구분)
            cellValue = _getCellValue(sheet, teacherRow - 1, periodCol - 1);
          } else {
            // 2행 이상인 경우: 1행과 2행을 줄바꿈으로 합쳐서 처리, 3행 이후는 무시
            List<String> rowValues = [];
            
            // 최대 2행만 사용 (3행 이후는 무시)
            int rowsToUse = rowCount > 2 ? 2 : rowCount;
            
            for (int i = 0; i < rowsToUse; i++) {
              int currentRow = teacherRow + i - 1; // 0-based로 변환
              String rowValue = _getCellValue(sheet, currentRow, periodCol - 1);
              rowValue = rowValue.trim();
              
              // 빈 셀이 아닌 경우만 추가
              if (rowValue.isNotEmpty) {
                rowValues.add(rowValue);
              }
            }
            
            // 줄바꿈으로 합치기
            cellValue = rowValues.join('\n');
          }
          
          if (cellValue.trim().isNotEmpty) {
            // 셀 내용을 줄바꿈으로 분할
            List<String> lines = cellValue
                .replaceAll('\r', '')
                .replaceAll('_x000D_', '')
                .split('\n')
                .map((line) => line.trim())
                .where((line) => line.isNotEmpty)
                .toList();
            
            if (lines.length >= 2) {
              bool firstIsClassName = _isClassNamePattern(lines[0]);
              bool secondIsSubject = _isSubjectPattern(lines[1]);
              bool firstIsSubject = _isSubjectPattern(lines[0]);
              bool secondIsClassName = _isClassNamePattern(lines[1]);
              
              if (firstIsClassName && secondIsSubject) {
                normalOrderCount++;
                sampleSize++;
              } else if (firstIsSubject && secondIsClassName) {
                reversedOrderCount++;
                sampleSize++;
              }
            }
          }
        }
      }
      
      // 통계적으로 더 많은 패턴을 기본값으로 사용
      CellOrderPattern pattern;
      if (sampleSize < ExcelServiceConstants.minSamplesForOrderDetection) {
        // 샘플이 부족한 경우, 100% 일관성이 있으면 그 패턴 사용
        if (sampleSize > 0) {
          if (normalOrderCount == sampleSize) {
            // 모든 샘플이 normal 패턴
            pattern = CellOrderPattern.normal;
            developer.log('샘플이 부족하지만 100% 일관성으로 normal 패턴 사용 (samples=$sampleSize)', name: 'ExcelService');
          } else if (reversedOrderCount == sampleSize) {
            // 모든 샘플이 reversed 패턴
            pattern = CellOrderPattern.reversed;
            developer.log('샘플이 부족하지만 100% 일관성으로 reversed 패턴 사용 (samples=$sampleSize)', name: 'ExcelService');
          } else {
            // 일관성이 없음
            pattern = CellOrderPattern.unknown;
          }
        } else {
          pattern = CellOrderPattern.unknown;
        }
      } else if (normalOrderCount >= reversedOrderCount) {
        pattern = CellOrderPattern.normal;
      } else {
        pattern = CellOrderPattern.reversed;
      }
      
      developer.log('셀 순서 패턴 검증 완료: pattern=$pattern, normal=$normalOrderCount, reversed=$reversedOrderCount, samples=$sampleSize', 
          name: 'ExcelService');
      
      return {
        'pattern': pattern,
        'normalCount': normalOrderCount,
        'reversedCount': reversedOrderCount,
        'sampleSize': sampleSize,
      };
    } catch (e) {
      developer.log('셀 순서 패턴 검증 중 오류 발생: $e', name: 'ExcelService');
      return {
        'pattern': CellOrderPattern.unknown,
        'normalCount': 0,
        'reversedCount': 0,
        'sampleSize': 0,
      };
    }
  }

  /// 하이브리드 방식으로 셀 순서를 검증하는 메서드
  /// 
  /// 1단계: 샘플링으로 빠른 검증
  /// 2단계: 샘플링 결과가 불확실하면 패턴 기반으로 재검증
  /// 
  /// 매개변수:
  /// - Sheet sheet: 엑셀 시트
  /// - ExcelParsingConfig config: 파싱 설정
  /// - `List<Teacher>` teachers: 교사 목록
  /// - `List<String>` dayHeaders: 요일 목록
  /// - `Map<String, List<int>>` periodsByDay: 요일별 교시 목록
  /// - `Map<Teacher, int>` teacherRowCounts: 교사별 행 개수
  /// 
  /// 반환값:
  /// - CellOrderPattern: 검증된 셀 순서 패턴
  static CellOrderPattern _detectCellOrder(
    Sheet sheet,
    ExcelParsingConfig config,
    List<Teacher> teachers,
    List<String> dayHeaders,
    Map<String, List<int>> periodsByDay,
    Map<Teacher, int> teacherRowCounts,
  ) {
    try {
      // 1단계: 샘플링으로 빠른 검증
      Map<String, dynamic> samplingResult = _detectCellOrderPattern(
        sheet, config, teachers, dayHeaders, periodsByDay, teacherRowCounts);
      
      CellOrderPattern pattern = samplingResult['pattern'] as CellOrderPattern;
      int normalCount = samplingResult['normalCount'] as int;
      int reversedCount = samplingResult['reversedCount'] as int;
      int sampleSize = samplingResult['sampleSize'] as int;
      
      // 샘플링 결과가 불확실한 경우 (차이가 적거나 샘플이 부족한 경우)
      if (pattern == CellOrderPattern.unknown || 
          (sampleSize >= ExcelServiceConstants.minSamplesForOrderDetection && 
           (normalCount - reversedCount).abs() <= 2)) {
        // 2단계: 패턴 기반으로 재검증 (추가 샘플링)
        // 더 많은 샘플을 수집하여 재검증
        developer.log('샘플링 결과가 불확실하여 추가 검증 수행', name: 'ExcelService');
        
        // 추가 샘플링 (더 많은 셀 확인)
        Map<String, dynamic> extendedResult = _detectCellOrderPattern(
          sheet, config, teachers, dayHeaders, periodsByDay, teacherRowCounts);
        
        int extendedNormalCount = extendedResult['normalCount'] as int;
        int extendedReversedCount = extendedResult['reversedCount'] as int;
        int extendedSampleSize = extendedResult['sampleSize'] as int;
        
        if (extendedSampleSize > sampleSize) {
          // 확장된 샘플링 결과 사용
          if (extendedNormalCount >= extendedReversedCount) {
            pattern = CellOrderPattern.normal;
          } else {
            pattern = CellOrderPattern.reversed;
          }
          developer.log('추가 검증 완료: pattern=$pattern', name: 'ExcelService');
        }
      }
      
      return pattern;
    } catch (e) {
      developer.log('하이브리드 셀 순서 검증 중 오류 발생: $e', name: 'ExcelService');
      return CellOrderPattern.unknown;
    }
  }

  /// 시간표 셀을 파싱하는 메서드
  /// 
  /// 셀 내용 예시:
  /// - 빈 셀 → TimeSlot 생성 (subject, className = null)
  /// - "103\n국어" → className: "103", subject: "국어" (정상 순서)
  /// - "국어\n103" → className: "103", subject: "국어" (바뀐 순서)
  /// - "1-3\n수학" → className: "1-3", subject: "수학"
  /// - "2-1" → className: "2-1", subject: null
  /// 
  /// 매개변수:
  /// - String cellValue: 셀 내용
  /// - Teacher teacher: 교사 정보
  /// - int dayOfWeek: 요일 번호
  /// - int period: 교시 번호
  /// - CellOrderPattern? orderPattern: 셀 순서 패턴 (null이면 자동 감지)
  static TimeSlot _parseTimeSlotCell(
    String cellValue, 
    Teacher teacher, 
    int dayOfWeek, 
    int period,
    {CellOrderPattern? orderPattern}
  ) {
    try {
      String? className;
      String? subject;
      
      // 빈 셀이 아닌 경우에만 내용 파싱
      if (cellValue.trim().isNotEmpty) {
        // 셀 내용 정리: 특수 문자 제거 및 줄바꿈 정규화
        String cleanCellValue = cellValue
            .replaceAll('\r', '')           // 캐리지 리턴 제거
            .replaceAll('_x000D_', '')      // Excel 특수 문자 제거
            .replaceAll('\n', '\n')          // 줄바꿈 정규화
            .trim();
        
        // 셀 내용을 줄바꿈으로 분할하고 빈 줄 제거
        List<String> lines = cleanCellValue.split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        
        if (lines.isNotEmpty) {
          // 순서 패턴이 지정된 경우 해당 순서 사용, 없으면 자동 감지
          CellOrderPattern detectedPattern = orderPattern ?? CellOrderPattern.unknown;
          
          if (detectedPattern == CellOrderPattern.unknown && lines.length >= 2) {
            // 자동 감지: 각 줄의 패턴을 분석
            bool firstIsClassName = _isClassNamePattern(lines[0]);
            bool secondIsSubject = _isSubjectPattern(lines[1]);
            bool firstIsSubject = _isSubjectPattern(lines[0]);
            bool secondIsClassName = _isClassNamePattern(lines[1]);
            
            if (firstIsClassName && secondIsSubject) {
              detectedPattern = CellOrderPattern.normal;
            } else if (firstIsSubject && secondIsClassName) {
              detectedPattern = CellOrderPattern.reversed;
            } else {
              // 패턴을 확인할 수 없으면 기본값(정상 순서) 사용
              detectedPattern = CellOrderPattern.normal;
            }
          }
          
          // 순서 패턴에 따라 학급번호와 과목 추출
          if (lines.length >= 2) {
            if (detectedPattern == CellOrderPattern.reversed) {
              // 바뀐 순서: 첫 번째 줄 = 과목, 두 번째 줄 = 학급번호
              subject = lines[0];
              className = _convertClassName(lines[1]);
            } else {
              // 정상 순서 또는 확인 불가: 첫 번째 줄 = 학급번호, 두 번째 줄 = 과목
              className = _convertClassName(lines[0]);
              subject = lines[1];
            }
          } else if (lines.length == 1) {
            // 한 줄만 있는 경우: 패턴으로 판단
            if (_isClassNamePattern(lines[0])) {
              className = _convertClassName(lines[0]);
            } else if (_isSubjectPattern(lines[0])) {
              subject = lines[0];
            } else {
              // 패턴을 확인할 수 없으면 기본값으로 처리 (학급번호로 가정)
              className = _convertClassName(lines[0]);
            }
          }
        }
      }
      
      // 빈 셀과 내용이 있는 셀 모두 TimeSlot 생성
      return TimeSlot(
        teacher: teacher.name,
        subject: subject,  // 빈 셀은 null
        className: className,  // 빈 셀은 null
        dayOfWeek: dayOfWeek,
        period: period,
        isExchangeable: true, // 기본값: 교체 가능
      );
    } catch (e) {
      developer.log('시간표 셀 파싱 중 오류 발생: $e', name: 'ExcelService');
      // 오류 발생 시에도 빈 TimeSlot 생성
      return TimeSlot(
        teacher: teacher.name,
        subject: null,
        className: null,
        dayOfWeek: dayOfWeek,
        period: period,
        isExchangeable: true,
      );
    }
  }

  /// Sheet에서 셀 값을 안전하게 읽는 헬퍼 메서드
  static String _getCellValue(Sheet sheet, int row, int col) {
    try {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      return cell.value?.toString() ?? '';
    } catch (e) {
      developer.log('셀 값 읽기 중 오류 발생 (행: $row, 열: $col): $e', name: 'ExcelService');
      return '';
    }
  }

}

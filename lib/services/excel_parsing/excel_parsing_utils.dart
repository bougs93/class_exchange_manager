import 'package:excel/excel.dart';
import 'dart:developer' as developer;
import '../excel_service.dart';

/// 엑셀 파싱 관련 유틸리티 메서드 클래스
/// 
/// 학급번호 변환, 패턴 검증 등 파싱에 필요한 유틸리티 메서드들을 제공합니다.
class ExcelParsingUtils {
  /// 요일별 시작 열 위치를 계산하는 메서드
  static Map<String, int> calculateDayColumns(
    Sheet sheet, 
    ExcelParsingConfig config, 
    List<String> dayHeaders,
  ) {
    try {
      Map<String, int> dayColumnMapping = {};
      
      // 요일 헤더 행에서 각 요일의 위치 찾기 (최대 50열까지)
      for (int col = 1; col <= ExcelServiceConstants.maxColumnsToCheck; col++) {
        String cellValue = getCellValue(sheet, config.dayHeaderRow - 1, col - 1); // 0-based로 변환
        cellValue = cellValue.trim();
        
        for (String day in dayHeaders) {
          if (cellValue == day) {
            dayColumnMapping[day] = col;
            break;
          }
        }
      }
      
      return dayColumnMapping;
    } catch (e) {
      developer.log('요일별 열 위치 계산 중 오류 발생: $e', name: 'ExcelParsingUtils');
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
  static int? findPeriodColumnInDay(
    Sheet sheet, 
    ExcelParsingConfig config, 
    int dayStartCol, 
    int period,
  ) {
    try {
      // 요일 시작 열부터 오른쪽으로 최대 10열까지 검색
      for (int col = dayStartCol; col < dayStartCol + ExcelServiceConstants.maxPeriodsToCheck; col++) {
        String cellValue = getCellValue(sheet, config.periodHeaderRow - 1, col - 1); // 0-based로 변환
        cellValue = cellValue.trim();
        
        // 숫자로 변환 시도
        int? cellPeriod = int.tryParse(cellValue);
        if (cellPeriod == period) {
          return col;
        }
      }
      
      return null;
    } catch (e) {
      developer.log('교시 열 위치 찾기 중 오류 발생: $e', name: 'ExcelParsingUtils');
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
  static String convertClassName(String className) {
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
      developer.log('학급번호 변환 중 오류 발생: $e', name: 'ExcelParsingUtils');
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
      developer.log('학년 추출 중 오류 발생: $e', name: 'ExcelParsingUtils');
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
      developer.log('반 번호 추출 중 오류 발생: $e', name: 'ExcelParsingUtils');
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
  static bool isClassNamePattern(String text) {
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
      developer.log('학급번호 패턴 확인 중 오류 발생: $e', name: 'ExcelParsingUtils');
      return false;
    }
  }

  /// 과목명 패턴인지 확인하는 메서드
  /// 
  /// 과목명 패턴 예시:
  /// - "국어", "수학", "영어" (한글)
  /// - "English", "Math" (영문)
  /// - "체육", "음악" (한글 과목명)
  static bool isSubjectPattern(String text) {
    try {
      text = text.trim();
      
      // 학급번호 패턴이면 과목이 아님
      if (isClassNamePattern(text)) return false;
      
      // 숫자만 있는 경우는 과목이 아님
      if (RegExp(r'^\d+$').hasMatch(text)) return false;
      
      // 한글이나 영문으로 구성된 텍스트 (일반적인 과목명)
      if (RegExp(r'^[가-힣a-zA-Z\s]+$').hasMatch(text)) return true;
      
      return false;
    } catch (e) {
      developer.log('과목명 패턴 확인 중 오류 발생: $e', name: 'ExcelParsingUtils');
      return false;
    }
  }

  /// Sheet에서 셀 값을 안전하게 읽는 유틸리티 메서드
  ///
  /// 엑셀 시트에서 지정된 행과 열의 셀 값을 읽습니다.
  /// 셀이 비어있거나 오류 발생 시 빈 문자열을 반환합니다.
  ///
  /// 매개변수:
  /// - `sheet`: 엑셀 시트 객체
  /// - `row`: 행 번호 (0-based)
  /// - `col`: 열 번호 (0-based)
  ///
  /// 반환값:
  /// - `String`: 셀 값 (빈 셀이거나 오류 시 빈 문자열)
  static String getCellValue(Sheet sheet, int row, int col) {
    try {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      return cell.value?.toString() ?? '';
    } catch (e) {
      developer.log('셀 값 읽기 중 오류 발생 (행: $row, 열: $col): $e', name: 'ExcelParsingUtils');
      return '';
    }
  }
}


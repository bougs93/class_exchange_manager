import 'package:excel/excel.dart';
import 'dart:developer' as developer;
import '../excel_service.dart';
import 'excel_parsing_utils.dart';

/// 엑셀 파일의 헤더를 찾는 클래스
/// 
/// 교사명 헤더, 요일 헤더, 교시 헤더 등을 찾는 로직을 담당합니다.
class ExcelHeaderFinder {
  /// 교사명 헤더를 찾는 메서드 (1~10행까지 검색)
  /// 
  /// 반환값: `Map<String, dynamic>` 형태로 {'row': 찾은 행 번호(1-based), 'column': 찾은 열 번호(1-based)}
  /// 교사명 헤더를 찾지 못한 경우 {'row': 0, 'column': 0} 반환
  static Map<String, dynamic> findTeacherHeader(Sheet sheet) {
    try {
      // 교사명 헤더 키워드 목록
      List<String> teacherHeaderKeywords = ['교사', '성명', '이름'];
      
      // 1행부터 10행까지 검색
      for (int row = 1; row <= ExcelServiceConstants.maxHeaderSearchRows; row++) {
        // 각 행의 모든 열을 확인 (최대 50열까지)
        for (int col = 1; col <= ExcelServiceConstants.maxColumnsToCheck; col++) {
          String cellValue = ExcelParsingUtils.getCellValue(sheet, row - 1, col - 1); // 0-based로 변환
          cellValue = cellValue.trim();
          
          // 키워드와 일치하는지 확인
          for (String keyword in teacherHeaderKeywords) {
            if (cellValue == keyword) {
              developer.log('교사명 헤더를 $row행 $col열에서 찾았습니다: $keyword', name: 'ExcelHeaderFinder');
              return {
                'row': row,
                'column': col,
              };
            }
          }
        }
      }
      
      // 교사명 헤더를 찾지 못한 경우
      developer.log('1~10행에서 교사명 헤더를 찾을 수 없습니다.', name: 'ExcelHeaderFinder');
      return {
        'row': 0,
        'column': 0,
      };
    } catch (e) {
      developer.log('교사명 헤더 찾기 중 오류 발생: $e', name: 'ExcelHeaderFinder');
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
  static Map<String, dynamic> findDayHeaders(Sheet sheet) {
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
      for (int row = 1; row <= ExcelServiceConstants.maxHeaderSearchRows; row++) {
        List<String> dayHeaders = [];
        
        // 해당 행의 모든 셀을 확인 (최대 50열까지)
        for (int col = 1; col <= ExcelServiceConstants.maxColumnsToCheck; col++) {
          String cellValue = ExcelParsingUtils.getCellValue(sheet, row - 1, col - 1); // 0-based로 변환
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
          developer.log('요일 헤더를 $row행에서 찾았습니다: $dayHeaders', name: 'ExcelHeaderFinder');
          return {
            'row': row,
            'days': dayHeaders,
          };
        }
      }
      
      // 요일을 찾지 못한 경우
      developer.log('1~10행에서 요일 헤더를 찾을 수 없습니다.', name: 'ExcelHeaderFinder');
      return {
        'row': 0,
        'days': [],
      };
    } catch (e) {
      developer.log('요일 헤더 찾기 중 오류 발생: $e', name: 'ExcelHeaderFinder');
      return {
        'row': 0,
        'days': [],
      };
    }
  }

  /// 교시 번호를 찾는 메서드 (요일별로 실제 존재하는 교시만 찾기)
  /// 요일 바로 다음 행에서 교시 번호를 찾습니다.
  static Map<String, List<int>> findPeriodsByDay(
    Sheet sheet, 
    int periodHeaderRow, 
    List<String> dayHeaders, 
    ExcelParsingConfig config,
  ) {
    try {
      Map<String, List<int>> periodsByDay = {};
      
      // 요일별 시작 열 위치 계산
      Map<String, int> dayColumnMapping = ExcelParsingUtils.calculateDayColumns(sheet, config, dayHeaders);
      
      for (String day in dayHeaders) {
        int? dayStartCol = dayColumnMapping[day];
        if (dayStartCol == null) continue;
        
        List<int> periods = [];
        
        // 해당 요일의 교시 번호만 찾기 (요일 바로 다음 행에서)
        // 요일 헤더 행의 다음 행이 교시 행이므로 periodHeaderRow 사용
        Set<int> uniquePeriods = {}; // 중복 제거를 위한 Set 사용
        
        // 각 요일의 시작 열부터 연속된 교시만 찾기
        List<String> cellValues = []; // 디버깅용
        for (int col = dayStartCol; col < dayStartCol + ExcelServiceConstants.maxPeriodsToCheck; col++) {
          String cellValue = ExcelParsingUtils.getCellValue(sheet, periodHeaderRow - 1, col - 1); // 0-based로 변환
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
        developer.log('$day요일 열 값들: $cellValues', name: 'ExcelHeaderFinder');
        
        // Set을 List로 변환하고 정렬
        periods = uniquePeriods.toList()..sort();
        periodsByDay[day] = periods;
        
        // 디버깅 로그
        developer.log('$day요일에서 찾은 교시: $periods (시작열: $dayStartCol)', name: 'ExcelHeaderFinder');
      }
      
      return periodsByDay;
    } catch (e) {
      developer.log('요일별 교시 번호 찾기 중 오류 발생: $e', name: 'ExcelHeaderFinder');
      return {};
    }
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
  static int? findDataStartColumn(
    Sheet sheet, 
    int dayHeaderRow, 
    int periodHeaderRow, 
    List<String> dayHeaders,
  ) {
    try {
      if (dayHeaders.isEmpty) {
        return null;
      }
      
      // 첫 번째 요일 찾기
      String firstDay = dayHeaders.first;
      
      // 첫 번째 요일의 시작 열 찾기
      int? firstDayStartCol;
      for (int col = 1; col <= ExcelServiceConstants.maxColumnsToCheck; col++) {
        String cellValue = ExcelParsingUtils.getCellValue(sheet, dayHeaderRow - 1, col - 1); // 0-based로 변환
        cellValue = cellValue.trim();
        
        if (cellValue == firstDay) {
          firstDayStartCol = col;
          break;
        }
      }
      
      if (firstDayStartCol == null) {
        developer.log('첫 번째 요일($firstDay)의 시작 열을 찾을 수 없습니다.', name: 'ExcelHeaderFinder');
        return null;
      }
      
      // 첫 번째 요일의 시작 열부터 1교시 찾기
      for (int col = firstDayStartCol; col < firstDayStartCol + ExcelServiceConstants.maxPeriodsToCheck; col++) {
        String cellValue = ExcelParsingUtils.getCellValue(sheet, periodHeaderRow - 1, col - 1); // 0-based로 변환
        cellValue = cellValue.trim();
        
        // 숫자로 변환 시도
        int? period = int.tryParse(cellValue);
        if (period == 1) {
          developer.log('데이터 시작 열을 찾았습니다: $col열 ($firstDay요일 1교시)', name: 'ExcelHeaderFinder');
          return col;
        }
        
        // 빈 셀이 나오면 해당 요일의 교시 검색 중단
        if (cellValue.isEmpty) {
          break;
        }
      }
      
      developer.log('첫 번째 요일($firstDay)에서 1교시를 찾을 수 없습니다.', name: 'ExcelHeaderFinder');
      return null;
    } catch (e) {
      developer.log('데이터 시작 열 찾기 중 오류 발생: $e', name: 'ExcelHeaderFinder');
      return null;
    }
  }

}


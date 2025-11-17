import 'package:excel/excel.dart';
import 'dart:developer' as developer;
import '../../models/teacher.dart';
import '../excel_service.dart';

/// 교사 정보 추출 클래스
/// 
/// 엑셀 파일에서 교사 정보를 추출하는 로직을 담당합니다.
class ExcelTeacherExtractor {
  /// 교사 정보를 추출하는 메서드
  /// 
  /// 교사 행 개수를 고려하여 모든 교사 이름을 추출합니다.
  /// 빈 셀을 만나면 추가로 지정된 행 수만큼 더 검색하여 마지막 교사까지 찾습니다.
  /// 
  /// 중복된 교사 이름이 발견되면 [DuplicateTeacherException]을 던집니다.
  /// 
  /// 예외:
  /// - [DuplicateTeacherException]: 동일한 교사 이름이 중복되어 발견된 경우
  static List<Teacher> extractTeacherInfo(Sheet sheet, ExcelParsingConfig config) {
    try {
      List<Teacher> teachers = [];
      // 중복 검사를 위한 Map: 교사 이름 -> 첫 번째로 발견된 행 번호
      Map<String, int> seenNames = {}; // 중복 검사용 (이름 -> 첫 번째 행 번호)
      int consecutiveEmptyRows = 0; // 연속된 빈 행 개수
      
      // 교사 이름이 있는 행 찾기
      for (int row = config.dataStartRow; row <= sheet.maxRows; row++) {
        String teacherCell = _getCellValue(sheet, row - 1, config.teacherColumn - 1); // 0-based로 변환
        
        if (teacherCell.trim().isEmpty) {
          // 빈 셀을 만난 경우
          consecutiveEmptyRows++;
          
          // 연속된 빈 행이 추가 검색 행 수를 초과하면 중단
          if (consecutiveEmptyRows > ExcelServiceConstants.additionalSearchRowsAfterEmptyCell) {
            developer.log('연속된 빈 행 $consecutiveEmptyRows개를 만나 검색을 중단합니다. ($row행)', name: 'ExcelTeacherExtractor');
            break;
          }
          
          continue; // 빈 셀은 건너뛰기
        }
        
        // 빈 셀이 아닌 경우 연속 빈 행 카운터 리셋
        consecutiveEmptyRows = 0;
        
        // 교사명 파싱: "A교사(20)" → name: "A교사", id: "20"
        Teacher? teacher = parseTeacherName(teacherCell);
        if (teacher != null) {
          // 중복 검사: 이미 본 이름인지 확인
          if (seenNames.containsKey(teacher.name)) {
            // 중복 발견: 예외 던지기
            int firstRow = seenNames[teacher.name]!;
            developer.log('교사 이름 중복 발견: "$teacher.name"이(가) $firstRow행과 $row행에서 중복되었습니다.', name: 'ExcelTeacherExtractor');
            throw DuplicateTeacherException(
              teacherName: teacher.name,
              firstRow: firstRow,
              duplicateRow: row,
            );
          }
          
          // 중복이 아닌 경우: 교사 추가 및 기록
          teachers.add(teacher);
          seenNames[teacher.name] = row; // 첫 번째로 발견된 행 번호 저장
          developer.log('교사 발견: $teacher.name ($row행)', name: 'ExcelTeacherExtractor');
        }
      }
      
      developer.log('총 ${teachers.length}명의 교사를 찾았습니다.', name: 'ExcelTeacherExtractor');
      return teachers;
    } catch (e) {
      // DuplicateTeacherException은 그대로 전파
      if (e is DuplicateTeacherException) {
        rethrow;
      }
      // 다른 예외는 로그만 남기고 빈 리스트 반환
      developer.log('교사 정보 추출 중 오류 발생: $e', name: 'ExcelTeacherExtractor');
      return [];
    }
  }

  /// 교사명을 파싱하는 메서드 (public)
  /// 
  /// 외부에서도 사용할 수 있도록 public으로 제공합니다.
  static Teacher? parseTeacherName(String teacherText) {
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
      developer.log('교사명 파싱 중 오류 발생: $e', name: 'ExcelTeacherExtractor');
      return null;
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
  static int findTeacherNameRow(
    Sheet sheet,
    ExcelParsingConfig config,
    Teacher teacher,
    int startSearchRow,
  ) {
    try {
      for (int row = startSearchRow; row <= sheet.maxRows; row++) {
        String cellValue = _getCellValue(sheet, row - 1, config.teacherColumn - 1);
        Teacher? parsedTeacher = parseTeacherName(cellValue);
        
        if (parsedTeacher != null && parsedTeacher.name == teacher.name) {
          return row;
        }
      }
      return 0;
    } catch (e) {
      developer.log('교사 이름 행 찾기 중 오류 발생: $e', name: 'ExcelTeacherExtractor');
      return 0;
    }
  }

  /// Sheet에서 셀 값을 안전하게 읽는 헬퍼 메서드
  static String _getCellValue(Sheet sheet, int row, int col) {
    try {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      return cell.value?.toString() ?? '';
    } catch (e) {
      developer.log('셀 값 읽기 중 오류 발생 (행: $row, 열: $col): $e', name: 'ExcelTeacherExtractor');
      return '';
    }
  }
}


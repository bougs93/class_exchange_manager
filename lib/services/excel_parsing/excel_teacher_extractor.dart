import 'package:excel/excel.dart';
import 'dart:developer' as developer;
import '../../models/teacher.dart';
import '../../utils/teacher_display.dart';
import '../excel_service.dart';
import 'excel_parsing_utils.dart';

/// 교사 정보 추출 클래스
///
/// 엑셀 파일에서 교사 정보를 추출하는 로직을 담당합니다.
class ExcelTeacherExtractor {
  /// 교사 정보를 추출하는 메서드
  ///
  /// 교사 행 개수를 고려하여 모든 교사 이름을 추출합니다.
  /// 빈 셀을 만나면 추가로 지정된 행 수만큼 더 검색하여 마지막 교사까지 찾습니다.
  ///
  /// 같은 이름의 교사(동명이인)가 여러 행에 있으면 중단하지 않고 엑셀 행 순서대로
  /// 원숫자를 붙여 구분합니다(`김철수①`, `김철수②`). 동명이인이 없는 교사의 이름은
  /// 그대로입니다. 각 교사는 [Teacher.sourceRow]에 자기 행을 기억합니다.
  static List<Teacher> extractTeacherInfo(
    Sheet sheet,
    ExcelParsingConfig config,
  ) {
    try {
      List<Teacher> teachers = [];
      int consecutiveEmptyRows = 0; // 연속된 빈 행 개수

      // 교사 이름이 있는 행 찾기
      for (int row = config.dataStartRow; row <= sheet.maxRows; row++) {
        String teacherCell = ExcelParsingUtils.getCellValue(
          sheet,
          row - 1,
          config.teacherColumn - 1,
        ); // 0-based로 변환

        if (teacherCell.trim().isEmpty) {
          // 빈 셀을 만난 경우
          consecutiveEmptyRows++;

          // 연속된 빈 행이 추가 검색 행 수를 초과하면 중단
          if (consecutiveEmptyRows >
              ExcelServiceConstants.additionalSearchRowsAfterEmptyCell) {
            developer.log(
              '연속된 빈 행 $consecutiveEmptyRows개를 만나 검색을 중단합니다. ($row행)',
              name: 'ExcelTeacherExtractor',
            );
            break;
          }

          continue; // 빈 셀은 건너뛰기
        }

        // 빈 셀이 아닌 경우 연속 빈 행 카운터 리셋
        consecutiveEmptyRows = 0;

        // 교사명 파싱: "A교사(20)" → name: "A교사", id: "20"
        Teacher? teacher = parseTeacherName(teacherCell);
        if (teacher != null) {
          teacher.sourceRow = row;
          teachers.add(teacher);
        }
      }

      // 동명이인에게 등장 순서(= 엑셀 행 순서)대로 번호를 붙여 이름을 고유하게 만든다
      final uniqueNames = uniqueTeacherNames(
        teachers.map((t) => t.name).toList(),
      );
      for (int i = 0; i < teachers.length; i++) {
        if (teachers[i].name != uniqueNames[i]) {
          developer.log(
            '동명이인 구분: ${teachers[i].name} → ${uniqueNames[i]} '
            '(${teachers[i].sourceRow}행)',
            name: 'ExcelTeacherExtractor',
          );
          teachers[i].name = uniqueNames[i];
        }
      }

      developer.log(
        '총 ${teachers.length}명의 교사를 찾았습니다.',
        name: 'ExcelTeacherExtractor',
      );
      return teachers;
    } catch (e) {
      // 예외는 로그만 남기고 빈 리스트 반환
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
    // 파싱 단계에서 행을 기억해 둔 교사는 이름 대신 그 행을 쓴다.
    // (이름으로 찾으면 동명이인이 모두 첫 번째 행으로 해석된다)
    final knownRow = teacher.sourceRow;
    if (knownRow != null) {
      return knownRow >= startSearchRow ? knownRow : 0;
    }

    try {
      for (int row = startSearchRow; row <= sheet.maxRows; row++) {
        String cellValue = ExcelParsingUtils.getCellValue(
          sheet,
          row - 1,
          config.teacherColumn - 1,
        );
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
}

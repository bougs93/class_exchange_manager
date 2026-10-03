import 'dart:developer' as developer;
import 'package:excel/excel.dart';
import '../../models/teacher.dart';
import '../../models/timetable_data.dart';
import 'excel_constants.dart';
import 'excel_teacher_extractor.dart';

/// 교사 한 명이 시간표에서 차지하는 행(row) 개수를 감지/계산하는 클래스
///
/// `excel_service.dart`에서 분리되었습니다 (2026-10-03).
/// 원래 `ExcelService`의 private 메서드였던 내용을 그대로 옮긴 것으로,
/// `ExcelService.parseTimetableData`가 내부적으로 호출합니다.
class ExcelRowCountDetector {
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
  static int calculateTeacherRowCount(
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
        nextTeacherRow = ExcelTeacherExtractor.findTeacherNameRow(
          sheet,
          config,
          nextTeacher,
          currentTeacherRow + 1,
        );
        if (nextTeacherRow == 0) {
          nextTeacherRow = sheet.maxRows + 1; // 찾지 못한 경우 기본값 유지
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
  static Map<String, dynamic> detectTeacherRowCountPattern(
    Sheet sheet,
    ExcelParsingConfig config,
    List<Teacher> teachers,
  ) {
    try {
      Map<Teacher, int> sampleCounts = {};
      List<int> rowsPerTeacherList = [];

      // 처음 몇 개 교사만 샘플링
      int sampleCount =
          teachers.length <
                  ExcelServiceConstants.maxSamplesForTeacherRowDetection
              ? teachers.length
              : ExcelServiceConstants.maxSamplesForTeacherRowDetection;

      // 교사 이름이 있는 행들을 먼저 찾기
      Map<Teacher, int> teacherRows = {};
      for (int i = 0; i < sampleCount; i++) {
        Teacher teacher = teachers[i];
        int teacherRow = ExcelTeacherExtractor.findTeacherNameRow(
          sheet,
          config,
          teacher,
          config.dataStartRow,
        );
        if (teacherRow > 0) {
          teacherRows[teacher] = teacherRow;
        }
      }

      // 각 샘플 교사의 행 개수 계산
      for (int i = 0; i < sampleCount; i++) {
        Teacher teacher = teachers[i];
        int? teacherRow = teacherRows[teacher];

        if (teacherRow == null) continue;

        Teacher? nextTeacher =
            (i < teachers.length - 1) ? teachers[i + 1] : null;
        int rowCount = calculateTeacherRowCount(
          sheet,
          config,
          teacher,
          teacherRow,
          nextTeacher,
        );

        sampleCounts[teacher] = rowCount;
        rowsPerTeacherList.add(rowCount);

        developer.log(
          '샘플 교사 ${teacher.name}: $rowCount행 ($teacherRow행부터)',
          name: 'ExcelService',
        );
      }

      // 패턴 일관성 검증
      bool isConsistent = false;
      int? consistentRowsPerTeacher;

      if (rowsPerTeacherList.length >=
          ExcelServiceConstants.minSamplesForTeacherRowDetection) {
        // 가장 많이 나타나는 행 수 찾기
        Map<int, int> frequency = {};
        for (int rows in rowsPerTeacherList) {
          frequency[rows] = (frequency[rows] ?? 0) + 1;
        }

        int maxFrequency = frequency.values.reduce((a, b) => a > b ? a : b);
        int mostCommonRows =
            frequency.entries.firstWhere((e) => e.value == maxFrequency).key;

        // 일관성 검증: 샘플의 80% 이상이 동일한 행 수를 가지는지 확인
        int consistentCount = frequency[mostCommonRows] ?? 0;
        double consistencyRate = consistentCount / rowsPerTeacherList.length;

        if (consistencyRate >= 0.8) {
          isConsistent = true;
          consistentRowsPerTeacher = mostCommonRows;
          developer.log(
            '교사 행 개수 패턴 감지: 교사당 $consistentRowsPerTeacher행 (일관성: ${(consistencyRate * 100).toStringAsFixed(1)}%)',
            name: 'ExcelService',
          );
        } else {
          developer.log(
            '교사 행 개수가 일관되지 않음. 각 교사별로 개별 계산합니다.',
            name: 'ExcelService',
          );
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
  static Map<Teacher, int> calculateAllTeacherRowCounts(
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
      int teacherRow = ExcelTeacherExtractor.findTeacherNameRow(
        sheet,
        config,
        teacher,
        config.dataStartRow,
      );
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

        Teacher? nextTeacher =
            (i < teachers.length - 1) ? teachers[i + 1] : null;
        int rowCount = calculateTeacherRowCount(
          sheet,
          config,
          teacher,
          teacherRow,
          nextTeacher,
        );

        rowCounts[teacher] = rowCount;
      }
    }

    // 로그 출력
    for (Teacher teacher in teachers) {
      int rowCount = rowCounts[teacher] ?? 1;
      int? teacherRow = teacherRows[teacher];
      developer.log(
        '교사 ${teacher.name}: $rowCount행${teacherRow != null ? ' ($teacherRow행부터)' : ''}',
        name: 'ExcelService',
      );
    }

    return rowCounts;
  }
}

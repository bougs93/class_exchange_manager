import 'dart:developer' as developer;
import 'package:excel/excel.dart';
import '../../models/teacher.dart';
import '../../models/timetable_data.dart';
import 'excel_constants.dart';
import 'excel_parsing_utils.dart';
import 'excel_teacher_extractor.dart';

/// 엑셀 시트의 셀 내용 순서(학급번호 → 과목 / 과목 → 학급번호)를
/// 샘플링 기반으로 감지하는 클래스
///
/// `excel_service.dart`에서 분리되었습니다 (2026-10-03).
/// 원래 `ExcelService`의 private 메서드였던 내용을 그대로 옮긴 것으로,
/// `ExcelService.parseTimetableData`가 내부적으로 호출합니다.
class ExcelCellOrderDetector {
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
  static Map<String, dynamic> detectCellOrderPattern(
    Sheet sheet,
    ExcelParsingConfig config,
    List<Teacher> teachers,
    List<String> dayHeaders,
    Map<String, List<int>> periodsByDay,
    Map<Teacher, int> teacherRowCounts,
  ) {
    try {
      int normalOrderCount = 0; // 정상 순서 셀 개수 (학급번호 → 과목)
      int reversedOrderCount = 0; // 바뀐 순서 셀 개수 (과목 → 학급번호)
      int sampleSize = 0;

      // 요일별 시작 열 위치 계산
      Map<String, int> dayColumnMapping = ExcelParsingUtils.calculateDayColumns(
        sheet,
        config,
        dayHeaders,
      );

      // 처음 몇 개 교사의 시간표 셀을 샘플링
      for (
        int teacherIndex = 0;
        teacherIndex < teachers.length &&
            sampleSize < ExcelServiceConstants.maxSamplesForOrderDetection;
        teacherIndex++
      ) {
        Teacher teacher = teachers[teacherIndex];

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

        // 각 요일의 첫 번째 교시 셀만 샘플링 (성능 고려)
        for (String day in dayHeaders) {
          if (sampleSize >= ExcelServiceConstants.maxSamplesForOrderDetection) {
            break;
          }

          int? dayStartCol = dayColumnMapping[day];
          if (dayStartCol == null) continue;

          List<int> periods = periodsByDay[day] ?? [];
          if (periods.isEmpty) continue;

          // 첫 번째 교시 셀 읽기
          int firstPeriod = periods.first;
          int? periodCol = ExcelParsingUtils.findPeriodColumnInDay(
            sheet,
            config,
            dayStartCol,
            firstPeriod,
          );
          if (periodCol == null) continue;

          // 교사 행 개수에 따라 셀 값 읽기
          String cellValue;
          if (rowCount == 1) {
            // 1행인 경우: 현재 방식 (줄바꿈으로 구분)
            cellValue = ExcelParsingUtils.getCellValue(
              sheet,
              teacherRow - 1,
              periodCol - 1,
            );
          } else {
            // 2행 이상인 경우: 1행과 2행을 줄바꿈으로 합쳐서 처리, 3행 이후는 무시
            List<String> rowValues = [];

            // 최대 2행만 사용 (3행 이후는 무시)
            int rowsToUse = rowCount > 2 ? 2 : rowCount;

            for (int i = 0; i < rowsToUse; i++) {
              int currentRow = teacherRow + i - 1; // 0-based로 변환
              String rowValue = ExcelParsingUtils.getCellValue(
                sheet,
                currentRow,
                periodCol - 1,
              );
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
            List<String> lines =
                cellValue
                    .replaceAll('\r', '')
                    .replaceAll('_x000D_', '')
                    .split('\n')
                    .map((line) => line.trim())
                    .where((line) => line.isNotEmpty)
                    .toList();

            if (lines.length >= 2) {
              bool firstIsClassName = ExcelParsingUtils.isClassNamePattern(
                lines[0],
              );
              bool secondIsSubject = ExcelParsingUtils.isSubjectPattern(
                lines[1],
              );
              bool firstIsSubject = ExcelParsingUtils.isSubjectPattern(
                lines[0],
              );
              bool secondIsClassName = ExcelParsingUtils.isClassNamePattern(
                lines[1],
              );

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
            developer.log(
              '샘플이 부족하지만 100% 일관성으로 normal 패턴 사용 (samples=$sampleSize)',
              name: 'ExcelService',
            );
          } else if (reversedOrderCount == sampleSize) {
            // 모든 샘플이 reversed 패턴
            pattern = CellOrderPattern.reversed;
            developer.log(
              '샘플이 부족하지만 100% 일관성으로 reversed 패턴 사용 (samples=$sampleSize)',
              name: 'ExcelService',
            );
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

      developer.log(
        '셀 순서 패턴 검증 완료: pattern=$pattern, normal=$normalOrderCount, reversed=$reversedOrderCount, samples=$sampleSize',
        name: 'ExcelService',
      );

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
  static CellOrderPattern detectCellOrder(
    Sheet sheet,
    ExcelParsingConfig config,
    List<Teacher> teachers,
    List<String> dayHeaders,
    Map<String, List<int>> periodsByDay,
    Map<Teacher, int> teacherRowCounts,
  ) {
    try {
      // 1단계: 샘플링으로 빠른 검증
      Map<String, dynamic> samplingResult = detectCellOrderPattern(
        sheet,
        config,
        teachers,
        dayHeaders,
        periodsByDay,
        teacherRowCounts,
      );

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
        Map<String, dynamic> extendedResult = detectCellOrderPattern(
          sheet,
          config,
          teachers,
          dayHeaders,
          periodsByDay,
          teacherRowCounts,
        );

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
}

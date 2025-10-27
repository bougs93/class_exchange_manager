import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/logger.dart';

/// 엑셀 내보내기 서비스
/// 
/// 템플릿 파일을 읽고 데이터를 채워 새로운 엑셀 파일을 생성합니다.
class ExcelExportService {
  /// 결보강 계획서 내보내기
  /// 
  /// [templatePath]: 템플릿 파일 경로
  /// [planData]: 내보낼 데이터 리스트
  /// [outputPath]: 저장할 파일 경로
  static Future<bool> exportSubstitutionPlan({
    required String templatePath,
    required List<SubstitutionPlanData> planData,
    required String outputPath,
    required BuildContext context,
  }) async {
    try {
      AppLogger.info('엑셀 내보내기 시작: $templatePath');

      // 1) 템플릿 파일 읽기
      final templateFile = File(templatePath);
      if (!templateFile.existsSync()) {
        throw Exception('템플릿 파일을 찾을 수 없습니다: $templatePath');
      }

      final bytes = await templateFile.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        throw Exception('워크시트가 없습니다.');
      }

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      AppLogger.info('✅ 워크시트 로드: $sheetName');

      // 2) 테그 위치 찾기
      final tagLocations = _findTagLocations(sheet);
      if (tagLocations.isEmpty) {
        throw Exception('템플릿에서 테그를 찾을 수 없습니다.');
      }

      AppLogger.info('✅ 인식된 테그: ${tagLocations.keys.join(', ')}');

      // 3) 데이터 쓰기
      final dataStartRow = _findDataStartRow(sheet, tagLocations);
      _writeDataToSheet(sheet, tagLocations, planData, dataStartRow);

      AppLogger.info('✅ 데이터 입력 완료: ${planData.length}개 레코드');

      // 4) 파일 저장
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      
      final encodedBytes = excel.encode();
      if (encodedBytes == null) {
        throw Exception('엑셀 파일 인코딩 실패');
      }

      await outputFile.writeAsBytes(encodedBytes, flush: true);

      AppLogger.info('✅ 파일 저장 완료: $outputPath');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('엑셀 내보내기 실패: $e\n$stackTrace');
      return false;
    }
  }

  /// 테그 위치 찾기
  /// 
  /// 시트의 모든 셀을 순회하며 테그를 찾습니다.
  static Map<String, CellIndex> _findTagLocations(Sheet sheet) {
    final tagLocations = <String, CellIndex>{};
    final supportedTags = {
      'date(day)', 'period', 'grade', 'class', 'subject', 'teacher',
      'subject2', 'teacher2',
      'date3(day3)', 'period3', 'subject3', 'teacher3',
      'remarks'
    };

    for (final row in sheet.rows) {
      for (final cell in row) {
        if (cell == null || cell.value == null) continue;

        final cellValue = cell.value;
        if (cellValue is! TextCellValue) continue;

        final text = cellValue.value.toString().toLowerCase().trim();
        
        if (supportedTags.contains(text)) {
          tagLocations[text] = cell.cellIndex;
          AppLogger.debug('테그 발견: $text at (${cell.rowIndex}, ${cell.columnIndex})');
        }
      }
    }

    return tagLocations;
  }

  /// 데이터 시작 행 찾기
  /// 
  /// 테그가 있는 행의 다음 행을 반환합니다.
  static int _findDataStartRow(Sheet sheet, Map<String, CellIndex> tagLocations) {
    if (tagLocations.isEmpty) return 0;
    
    // 첫 테그의 행 인덱스를 기준으로 함
    final firstTagRow = tagLocations.values.first.rowIndex;
    return firstTagRow + 1;
  }

  /// 데이터를 시트에 쓰기
  static void _writeDataToSheet(
    Sheet sheet,
    Map<String, CellIndex> tagLocations,
    List<SubstitutionPlanData> planData,
    int dataStartRow,
  ) {
    for (int i = 0; i < planData.length; i++) {
      final data = planData[i];
      final currentRow = dataStartRow + i;

      // 각 테그에 맞는 값 입력
      _writeCellValue(sheet, tagLocations, 'date(day)', currentRow,
          '${data.absenceDate}(${data.absenceDay})');
      _writeCellValue(sheet, tagLocations, 'period', currentRow,
          data.period.toString());
      _writeCellValue(sheet, tagLocations, 'grade', currentRow,
          data.grade.toString());
      _writeCellValue(sheet, tagLocations, 'class', currentRow,
          data.className.toString());
      _writeCellValue(sheet, tagLocations, 'subject', currentRow,
          data.subject);
      _writeCellValue(sheet, tagLocations, 'teacher', currentRow,
          data.teacher);
      _writeCellValue(sheet, tagLocations, 'subject2', currentRow,
          data.supplementSubject);
      _writeCellValue(sheet, tagLocations, 'teacher2', currentRow,
          data.supplementTeacher);
      _writeCellValue(sheet, tagLocations, 'date3(day3)', currentRow,
          '${data.substitutionDate}(${data.substitutionDay})');
      _writeCellValue(sheet, tagLocations, 'period3', currentRow,
          data.substitutionPeriod.toString());
      _writeCellValue(sheet, tagLocations, 'subject3', currentRow,
          data.substitutionSubject);
      _writeCellValue(sheet, tagLocations, 'teacher3', currentRow,
          data.substitutionTeacher);
      _writeCellValue(sheet, tagLocations, 'remarks', currentRow,
          data.remarks);

      AppLogger.debug('행 ${currentRow + 1} 데이터 입력 완료');
    }
  }

  /// 셀에 값 쓰기
  /// 
  /// 테그 위치를 기반으로 해당 열의 현재 행에 값을 입력합니다.
  static void _writeCellValue(
    Sheet sheet,
    Map<String, CellIndex> tagLocations,
    String tag,
    int rowIndex,
    String value,
  ) {
    final cellIndex = tagLocations[tag];
    if (cellIndex == null) {
      AppLogger.warning('테그 없음: $tag');
      return;
    }

    final cell = sheet.cell(CellIndex.indexByColumnRow(
      columnIndex: cellIndex.columnIndex,
      rowIndex: rowIndex,
    ));

    // 공식 문서의 권장 방식: TextCellValue 사용
    cell.value = TextCellValue(value);
  }
}

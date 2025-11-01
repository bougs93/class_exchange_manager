import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/logger.dart';
import '../utils/date_format_utils.dart';

/// 엑셀 내보내기 서비스
/// 
/// 동적으로 결보강 계획서 엑셀 파일을 생성합니다.
class ExcelExportService {
  /// 결보강 계획서 내보내기
  /// 
  /// [planData]: 내보낼 데이터 리스트
  /// [outputPath]: 저장할 파일 경로
  static Future<bool> exportSubstitutionPlan({
    required List<SubstitutionPlanData> planData,
    required String outputPath,
    required BuildContext context,
  }) async {
    try {
      AppLogger.info('엑셀 내보내기 시작');

      // 새로운 엑셀 파일 생성
      final excel = Excel.createExcel();
      final sheetName = '결보강계획서';
      
      // 기본 시트 제거 후 새로운 시트 생성
      excel.delete('Sheet1');
      final sheet = excel[sheetName];

      AppLogger.info('✅ 워크시트 생성: $sheetName');

      // 레이아웃 생성
      _createLayout(sheet, planData);

      AppLogger.info('✅ 데이터 입력 완료: ${planData.length}개 레코드');

      // 파일 저장
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

  /// 엑셀 레이아웃 생성
  /// 
  /// 결보강 계획서 양식에 맞게 시트를 구성합니다.
  static void _createLayout(Sheet sheet, List<SubstitutionPlanData> planData) {
    int rowIndex = 0;

    // 1) 제목: "결·보강 계획서"
    _setTitle(sheet, rowIndex);
    rowIndex += 2;

    // 2) 정보 입력 섹션
    rowIndex = _setInfoSection(sheet, rowIndex, planData);
    rowIndex += 1;

    // 3) 테이블 헤더
    rowIndex = _setTableHeader(sheet, rowIndex);
    rowIndex += 1;

    // 4) 데이터 입력
    _setDataRows(sheet, rowIndex, planData);
  }

  /// 제목 설정
  static void _setTitle(Sheet sheet, int rowIndex) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(
      columnIndex: 0,
      rowIndex: rowIndex,
    ));
    cell.value = TextCellValue('결·보강 계획서');
    
    // 제목 스타일
    cell.cellStyle = CellStyle(
      fontSize: 16,
      bold: true,
    );

    // 열 병합
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
    );
  }

  /// 정보 입력 섹션 설정
  /// 
  /// 결강교사, 결강기간, 근무상황, 결강사유, 질보강 조치 사항
  static int _setInfoSection(Sheet sheet, int startRowIndex, List<SubstitutionPlanData> planData) {
    int rowIndex = startRowIndex;
    const infoLabels = [
      '1. 결강교사 :',
      '2. 결강기간 :',
      '3. 근무상황 :',
      '4. 결강사유(장소) :',
      '5. 결 · 보강 조치 사항',
    ];

    for (int i = 0; i < infoLabels.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: rowIndex + i,
      ));
      cell.value = TextCellValue(infoLabels[i]);
      cell.cellStyle = CellStyle(
        fontSize: 11,
        bold: true,
      );
    }

    // 🔥 결강기간 자동 계산 및 입력 (옆 셀에 입력)
    final absenceDates = planData.map((data) => data.absenceDate).toList();
    final absencePeriod = DateFormatUtils.calculateAbsencePeriod(absenceDates);
    if (absencePeriod.isNotEmpty) {
      final periodCell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRowIndex + 1, // "2. 결강기간 :" 행
      ));
      periodCell.value = TextCellValue(absencePeriod);
      periodCell.cellStyle = CellStyle(
        fontSize: 11,
      );
    }

    // 우측 정보 박스 (조업계, 교감)
    final rightBoxRow = startRowIndex;
    final labels = ['수업계', '교감'];
    for (int i = 0; i < labels.length; i++) {
      final labelCell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 7,
        rowIndex: rightBoxRow + i,
      ));
      labelCell.value = TextCellValue(labels[i]);
      labelCell.cellStyle = CellStyle(
        fontSize: 11,
        bold: true,
      );
    }

    return startRowIndex + 5;
  }

  /// 테이블 헤더 설정
  static int _setTableHeader(Sheet sheet, int startRowIndex) {
    // 큰 헤더 (결강, 보강/수업변경, 수업 교체, 비고)
    const mainHeaders = [
      ('결강', 0, 6),      // 열 0-6
      ('보강/수업변경', 7, 8),  // 열 7-8
      ('수업 교체', 9, 12,),  // 열 9-11
      ('비고', 13, 13),    // 열 12
    ];

    for (final (title, startCol, endCol) in mainHeaders) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: startCol,
        rowIndex: startRowIndex,
      ));
      cell.value = TextCellValue(title);
      _applyHeaderStyle(cell);

      // 열 병합
      if (startCol != endCol) {
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: startRowIndex),
          CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: startRowIndex),
        );
      }
    }

    // 소 헤더
    const subHeaders = [
      '결강일',
      '교시',
      '학년',
      '반',
      '과목',
      '성명',
      '과목',
      '성명',
      '교체일',
      '교시',
      '과목',
      '성명',
      '비고\n(담교사책)',
    ];

    for (int i = 0; i < subHeaders.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: i,
        rowIndex: startRowIndex + 1,
      ));
      cell.value = TextCellValue(subHeaders[i]);
      _applyHeaderStyle(cell);
    }

    return startRowIndex + 2;
  }

  /// 헤더 셀 스타일 적용
  static void _applyHeaderStyle(Data cell) {
    cell.cellStyle = CellStyle(
      fontSize: 10,
      bold: true,
    );
  }

  /// 데이터 행 설정
  static void _setDataRows(Sheet sheet, int startRowIndex, List<SubstitutionPlanData> planData) {
    for (int i = 0; i < planData.length; i++) {
      final data = planData[i];
      final rowIndex = startRowIndex + i;

      final rowData = [
        DateFormatUtils.toMonthDay(data.absenceDate),            // 결강일 (월.일 형식으로 변환)
        data.period,                 // 교시
        data.grade,                  // 학년
        data.className,              // 반
        data.subject,                // 과목 (결강)
        data.teacher,                // 성명 (결강)
        '',                          // 명
        data.supplementSubject,      // 과목 (보강)
        data.supplementTeacher,      // 성명 (보강)
        DateFormatUtils.toMonthDay(data.substitutionDate),       // 교체일 (월.일 형식으로 변환)
        data.substitutionPeriod,     // 교치
        data.substitutionSubject,    // 과목 (교체)
        data.substitutionTeacher,    // 성명 (교체)
        data.remarks,                // 비고
      ];

      for (int col = 0; col < rowData.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: rowIndex,
        ));
        cell.value = TextCellValue(rowData[col]);
        _applyDataCellStyle(cell);
      }
    }
  }

  /// 데이터 셀 스타일 적용
  static void _applyDataCellStyle(Data cell) {
    cell.cellStyle = CellStyle(
      fontSize: 10,
    );
  }
}

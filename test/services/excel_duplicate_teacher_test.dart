import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/teacher.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/excel_service.dart';
import 'package:class_exchange_manager/services/excel_parsing/excel_teacher_extractor.dart';

/// 교사 열(A열)에 [names]를 [startRow](1-based)부터 한 줄씩 채운 시트를 만든다.
Sheet _sheetWithTeachers(List<String> names, {int startRow = 4}) {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];
  for (var i = 0; i < names.length; i++) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow - 1 + i),
      TextCellValue(names[i]),
    );
  }
  return sheet;
}

void main() {
  const config = ExcelParsingConfig();

  group('동명이인 교사 추출', () {
    test('같은 이름 2행도 예외 없이 구분된 이름으로 추출된다', () {
      final sheet = _sheetWithTeachers(['김철수(20)', '이영희(21)', '김철수(22)']);

      final teachers = ExcelTeacherExtractor.extractTeacherInfo(sheet, config);

      expect(teachers.map((t) => t.name), ['김철수①', '이영희', '김철수②']);
      expect(teachers.map((t) => t.sourceRow), [4, 5, 6]);
    });

    test('같은 이름 3행은 ①②③이 붙고 나머지 교사는 그대로다', () {
      final sheet = _sheetWithTeachers(['김철수', '박민수', '김철수', '김철수']);

      final teachers = ExcelTeacherExtractor.extractTeacherInfo(sheet, config);

      expect(teachers.map((t) => t.name), ['김철수①', '박민수', '김철수②', '김철수③']);
    });

    test('동명이인이 없으면 이름도 sourceRow 외에는 달라지지 않는다', () {
      final sheet = _sheetWithTeachers(['김철수', '이영희']);

      final teachers = ExcelTeacherExtractor.extractTeacherInfo(sheet, config);

      expect(teachers.map((t) => t.name), ['김철수', '이영희']);
    });

    test('동명이인도 Teacher 동등성에서 서로 다르다(Map 키 충돌 없음)', () {
      final sheet = _sheetWithTeachers(['김철수', '김철수']);

      final teachers = ExcelTeacherExtractor.extractTeacherInfo(sheet, config);
      final counts = <Teacher, int>{for (final t in teachers) t: t.sourceRow!};

      expect(counts.length, 2);
    });
  });

  group('findTeacherNameRow', () {
    test('sourceRow가 있으면 동명이인도 각자의 행을 찾는다', () {
      final sheet = _sheetWithTeachers(['김철수', '이영희', '김철수']);
      final teachers = ExcelTeacherExtractor.extractTeacherInfo(sheet, config);

      int rowOf(Teacher t, int from) =>
          ExcelTeacherExtractor.findTeacherNameRow(sheet, config, t, from);

      expect(rowOf(teachers[0], config.dataStartRow), 4);
      expect(rowOf(teachers[2], config.dataStartRow), 6);
    });

    test('startSearchRow보다 앞선 sourceRow는 찾지 못한 것으로 본다', () {
      final sheet = _sheetWithTeachers(['김철수', '김철수']);
      final teachers = ExcelTeacherExtractor.extractTeacherInfo(sheet, config);

      expect(
        ExcelTeacherExtractor.findTeacherNameRow(
          sheet,
          config,
          teachers[0],
          teachers[0].sourceRow! + 1,
        ),
        0,
      );
    });

    test('sourceRow가 없는 Teacher는 기존처럼 이름으로 검색한다', () {
      final sheet = _sheetWithTeachers(['김철수', '이영희']);
      final legacy = Teacher(name: '이영희', subject: '');

      expect(
        ExcelTeacherExtractor.findTeacherNameRow(
          sheet,
          config,
          legacy,
          config.dataStartRow,
        ),
        5,
      );
    });
  });

  group('전체 파싱', () {
    test('동명이인의 시간표 칸이 섞이지 않고 각자의 행에서 읽힌다', () {
      final excel = _timetableExcel([
        ('김철수(20)', '1-1\n수학'),
        ('이영희(21)', '1-2\n국어'),
        ('김철수(22)', '2-3\n영어'),
      ]);

      final data = ExcelService.parseTimetableData(excel);

      expect(data, isNotNull, reason: ExcelService.lastParseFailureReason);
      expect(data!.teachers.map((t) => t.name), ['김철수①', '이영희', '김철수②']);

      TimeSlot mondayFirst(String teacher) => data.timeSlots.firstWhere(
        (s) => s.teacher == teacher && s.dayOfWeek == 1 && s.period == 1,
      );

      expect(mondayFirst('김철수①').subject, '수학');
      expect(mondayFirst('김철수①').className, '1-1');
      expect(mondayFirst('김철수②').subject, '영어');
      expect(mondayFirst('김철수②').className, '2-3');
      expect(mondayFirst('이영희').subject, '국어');
    });

    test('동명이인이 없는 시간표는 이름이 그대로다', () {
      final excel = _timetableExcel([
        ('김철수(20)', '1-1\n수학'),
        ('이영희(21)', '1-2\n국어'),
      ]);

      final data = ExcelService.parseTimetableData(excel);

      expect(data, isNotNull, reason: ExcelService.lastParseFailureReason);
      expect(data!.teachers.map((t) => t.name), ['김철수', '이영희']);
    });
  });
}

/// 월~금 × 1~3교시, 교사 열(A열) 구성의 합성 시간표를 만든다.
/// [rows]의 각 항목은 (교사 셀 값, 월요일 1교시 셀 값)이고 나머지 칸은 비운다.
Excel _timetableExcel(List<(String, String)> rows) {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];
  const days = ['월', '화', '수', '목', '금'];
  const periods = 3;
  // 파서가 교사 열을 찾는 기준이 되는 헤더
  sheet.updateCell(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
    TextCellValue('교사'),
  );
  for (var d = 0; d < days.length; d++) {
    for (var p = 0; p < periods; p++) {
      final col = 1 + d * periods + p;
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1),
        TextCellValue(p == 0 ? days[d] : ''),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2),
        IntCellValue(p + 1),
      );
    }
  }
  for (var i = 0; i < rows.length; i++) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3 + i),
      TextCellValue(rows[i].$1),
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3 + i),
      TextCellValue(rows[i].$2),
    );
  }
  return excel;
}

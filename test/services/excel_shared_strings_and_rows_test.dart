import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/services/excel_service.dart';

/// 월계중 2학기 시간표 파일 — sharedStrings 정규화 + 교사당 3행 파싱 검증
void main() {
  // 개발 PC에만 있는 실제 파일 경로 (없으면 테스트 스킵)
  const samplePath =
      r'd:\Users\user\Documents\WONGIL_2026\01 월계중(2026)\8.21 2학기 확정시간표\2학기 전체시간표 확정(0820).xlsx';

  test('sharedStrings 정규화 후 엑셀 디코딩 성공', () async {
    final file = File(samplePath);
    if (!await file.exists()) {
      // ignore: avoid_print
      print('샘플 파일 없음 — 스킵: $samplePath');
      return;
    }

    final excel = await ExcelService.readExcelFile(file);
    expect(excel, isNotNull, reason: '정규화 후 디코딩되어야 함');
    expect(excel!.tables.isNotEmpty, isTrue);
  });

  test('교사당 3행 시간표 파싱 (과목행+학급행+빈행)', () async {
    final file = File(samplePath);
    if (!await file.exists()) {
      // ignore: avoid_print
      print('샘플 파일 없음 — 스킵: $samplePath');
      return;
    }

    final excel = await ExcelService.readExcelFile(file);
    expect(excel, isNotNull);

    final data = ExcelService.parseTimetableData(excel!);
    expect(data, isNotNull, reason: '시간표 파싱 성공해야 함');
    expect(data!.teachers.length, greaterThan(10));
    expect(data.timeSlots.length, greaterThan(50));

    // 이윤희: 월 3교시 = 국어 / 1-1 (과목행+학급행)
    final filled =
        data.timeSlots
            .where(
              (s) =>
                  s.teacher == '이윤희' &&
                  s.isNotEmpty &&
                  (s.className?.isNotEmpty ?? false) &&
                  (s.subject?.isNotEmpty ?? false),
            )
            .toList();
    expect(filled, isNotEmpty, reason: '과목·학급이 채워진 슬롯이 있어야 함');

    // ignore: avoid_print
    print(
      '파싱 결과: 교사 ${data.teachers.length}명, 슬롯 ${data.timeSlots.length}개, '
      '이윤희 수업 ${filled.length}개',
    );
    final sample = filled.first;
    // ignore: avoid_print
    print(
      '샘플 슬롯: ${sample.teacher} 요일=${sample.dayOfWeek} '
      '${sample.period}교시 ${sample.className}/${sample.subject}',
    );

    // 월 3교시(요일1, 교시3)가 있으면 1-1/국어 확인
    final mon3 = filled.where((s) => s.dayOfWeek == 1 && s.period == 3);
    if (mon3.isNotEmpty) {
      final slot = mon3.first;
      expect(slot.className, '1-1');
      expect(slot.subject, '국어');
    }
  });
}

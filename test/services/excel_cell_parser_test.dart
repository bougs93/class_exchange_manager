import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/teacher.dart';
import 'package:class_exchange_manager/services/excel_service.dart';
import 'package:class_exchange_manager/services/excel_parsing/excel_cell_parser.dart';

void main() {
  final teacher = Teacher(name: '테스트교사', subject: '');

  group('ExcelCellParser.classifyByContent', () {
    test('과목행 → 학급행 순서', () {
      final result = ExcelCellParser.classifyByContent(['국어', '1-1']);
      expect(result['subject'], '국어');
      expect(result['className'], '1-1');
    });

    test('학급행 → 과목행 순서 (바뀐 경우)', () {
      final result = ExcelCellParser.classifyByContent(['1-2', '수학']);
      expect(result['subject'], '수학');
      expect(result['className'], '1-2');
    });

    test('중간 빈 줄 무시', () {
      final result = ExcelCellParser.classifyByContent(['영어', '', '2-3']);
      expect(result['subject'], '영어');
      expect(result['className'], '2-3');
    });
  });

  group('ExcelCellParser.parseTimeSlotCell', () {
    test('한 셀: 학급\\n과목', () {
      final slot = ExcelCellParser.parseTimeSlotCell(
        '1-1\n국어',
        teacher,
        1,
        3,
      );
      expect(slot.className, '1-1');
      expect(slot.subject, '국어');
    });

    test('한 셀: 과목\\n학급 (바뀐 순서)', () {
      final slot = ExcelCellParser.parseTimeSlotCell(
        '국어\n1-1',
        teacher,
        1,
        3,
        orderPattern: CellOrderPattern.unknown,
      );
      expect(slot.className, '1-1');
      expect(slot.subject, '국어');
    });

    test('전역 normal 패턴이어도 과목\\n학급 셀은 내용 기준으로 해석', () {
      final slot = ExcelCellParser.parseTimeSlotCell(
        '국어\n1-1',
        teacher,
        1,
        3,
        orderPattern: CellOrderPattern.normal,
      );
      expect(slot.className, '1-1');
      expect(slot.subject, '국어');
    });
  });
}

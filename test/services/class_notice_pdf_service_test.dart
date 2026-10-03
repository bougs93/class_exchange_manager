import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/notice_message.dart';
import 'package:class_exchange_manager/services/class_notice_pdf_service.dart';

void main() {
  group('ClassNoticePdfService.splitExchangeLine', () {
    test('<-> 앞에서 2줄로 분리한다', () {
      const line =
          '3/10 월 1교시 3-1 수학 김교사 <-> 3/11 화 2교시 3-1 영어 이교사';
      final parts = ClassNoticePdfService.splitExchangeLine(line);
      expect(parts, [
        '3/10 월 1교시 3-1 수학 김교사',
        '<-> 3/11 화 2교시 3-1 영어 이교사',
      ]);
    });

    test('-> 앞에서 2줄로 분리한다 (순환)', () {
      const line = 'A쪽 -> B쪽';
      final parts = ClassNoticePdfService.splitExchangeLine(line);
      expect(parts, ['A쪽', '-> B쪽']);
    });

    test('화살표 없으면 1줄 유지', () {
      const line = "'3/10 월 1교시 3-1 수학 보강교사' 수업입니다.";
      expect(ClassNoticePdfService.splitExchangeLine(line), [line]);
    });
  });

  group('ClassNoticePdfService.buildLines', () {
    test('교체안내는 본문 화살표 줄을 분리한다', () {
      final group = NoticeMessageGroup(
        groupIdentifier: '3-1',
        groupType: GroupType.classGroup,
        messages: [
          NoticeMessage(
            identifier: '3-1',
            content: '3-1 수업변경 안내\n'
                '3/10 월 1교시 3-1 수학 김 <-> 3/11 화 2교시 3-1 영어 이',
            exchangeType: ExchangeType.substitution,
            messageOption: MessageOption.option2,
            exchangeId: 'test-1',
          ),
        ],
      );

      final lines = ClassNoticePdfService.buildLines(
        group,
        MessageOption.option2,
      );
      expect(lines.length, 3);
      expect(lines[0], '3-1 수업변경 안내');
      expect(lines[1], '3/10 월 1교시 3-1 수학 김');
      expect(lines[2], startsWith('<->'));
    });

    test('수업안내는 줄을 그대로 유지한다', () {
      final group = NoticeMessageGroup(
        groupIdentifier: '3-1',
        groupType: GroupType.classGroup,
        messages: [
          NoticeMessage(
            identifier: '3-1',
            content: '3-1 수업변경 안내\n첫째줄\n둘째줄',
            exchangeType: ExchangeType.substitution,
            messageOption: MessageOption.option3,
            exchangeId: 'test-2',
          ),
        ],
      );

      final lines = ClassNoticePdfService.buildLines(
        group,
        MessageOption.option3,
      );
      expect(lines, ['3-1 수업변경 안내', '첫째줄', '둘째줄']);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/exchange_arrow_step.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/exchange_arrow_draw_helper.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/timetable_grid_constants.dart';

/// drawArrow 콜백 1회 호출을 기록하는 구조체
class _DrawCall {
  final ExchangeNode from;
  final ExchangeNode to;
  final String? text;
  final ArrowDirection direction;
  final double? arrowHeadSize;

  _DrawCall({
    required this.from,
    required this.to,
    required this.text,
    required this.direction,
    required this.arrowHeadSize,
  });
}

ExchangeNode _node(String teacher) {
  return ExchangeNode(
    teacherName: teacher,
    day: '월',
    period: 1,
    className: '1-1',
  );
}

void main() {
  late List<_DrawCall> calls;
  late ArrowDrawCallback recorder;

  setUp(() {
    calls = [];
    recorder = (
      ExchangeNode from,
      ExchangeNode to, {
      ArrowPriority priority = ArrowPriority.verticalFirst,
      double? arrowHeadSize,
      String? text,
      ArrowDirection direction = ArrowDirection.forward,
    }) {
      calls.add(
        _DrawCall(
          from: from,
          to: to,
          text: text,
          direction: direction,
          arrowHeadSize: arrowHeadSize,
        ),
      );
    };
  });

  group('drawSplitUnidirectional', () {
    test('A→B, B→A 2개의 단방향 화살표를 텍스트 없이 그린다', () {
      final a = _node('교사A');
      final b = _node('교사B');

      ExchangeArrowDrawHelper.drawSplitUnidirectional(
        nodeA: a,
        nodeB: b,
        drawArrow: recorder,
        arrowHeadSize: 12.0,
      );

      expect(calls.length, 2);

      // 첫 번째: A → B
      expect(calls[0].from.teacherName, '교사A');
      expect(calls[0].to.teacherName, '교사B');
      expect(calls[0].direction, ArrowDirection.forward);
      expect(calls[0].text, isNull);
      expect(calls[0].arrowHeadSize, 12.0);

      // 두 번째: B → A
      expect(calls[1].from.teacherName, '교사B');
      expect(calls[1].to.teacherName, '교사A');
      expect(calls[1].direction, ArrowDirection.forward);
      expect(calls[1].text, isNull);
    });
  });

  group('drawStepArrows', () {
    test('각 단계를 1선으로 그리고 중간 숫자를 순서대로 표시한다', () {
      final steps = [
        ExchangeArrowStep(fromNode: _node('A'), toNode: _node('B'), stepNumber: 1),
        ExchangeArrowStep(fromNode: _node('C'), toNode: _node('D'), stepNumber: 2),
      ];

      ExchangeArrowDrawHelper.drawStepArrows(
        steps: steps,
        direction: ArrowDirection.bidirectional,
        drawArrow: recorder,
        arrowHeadSize: 8.0,
      );

      expect(calls.length, 2);
      expect(calls[0].text, '1');
      expect(calls[0].direction, ArrowDirection.bidirectional);
      expect(calls[0].arrowHeadSize, 8.0);
      expect(calls[1].text, '2');
      expect(calls[1].direction, ArrowDirection.bidirectional);
    });

    test('direction이 forward면 단방향으로 전달된다', () {
      final steps = [
        ExchangeArrowStep(fromNode: _node('A'), toNode: _node('B'), stepNumber: 1),
      ];

      ExchangeArrowDrawHelper.drawStepArrows(
        steps: steps,
        direction: ArrowDirection.forward,
        drawArrow: recorder,
      );

      expect(calls.single.direction, ArrowDirection.forward);
      expect(calls.single.text, '1');
    });

    test('showStepNumbers가 false면 텍스트를 표시하지 않는다', () {
      final steps = [
        ExchangeArrowStep(fromNode: _node('A'), toNode: _node('B'), stepNumber: 1),
      ];

      ExchangeArrowDrawHelper.drawStepArrows(
        steps: steps,
        direction: ArrowDirection.bidirectional,
        drawArrow: recorder,
        showStepNumbers: false,
      );

      expect(calls.single.text, isNull);
    });
  });
}

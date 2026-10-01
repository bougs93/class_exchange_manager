import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/ui/widgets/exchanged_cell_status_overlay.dart';
import 'package:class_exchange_manager/ui/widgets/plain_timetable_cell_painter.dart';
import 'package:class_exchange_manager/ui/widgets/simplified_timetable_cell.dart';

/// 셀 렌더링 경로 분기 테스트
///
/// 교체 화면은 한 화면에 셀이 1000개 넘게 뜬다. 오버레이·툴팁이 없는
/// 평범한 셀은 위젯을 쌓지 않고 CustomPaint로 한 번에 그려야 스크롤이
/// 버틴다. 반대로 특수 셀은 기존 위젯 트리를 그대로 써서 모습이 변하지
/// 않아야 한다. 이 분기가 깨지면 성능이나 겉모습 중 하나가 무너지므로
/// 테스트로 고정한다.
void main() {
  Future<void> pumpCell(WidgetTester tester, Widget cell) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 35, height: 25, child: cell)),
        ),
      ),
    );
  }

  group('SimplifiedTimetableCell 렌더링 경로', () {
    testWidgets('평범한 셀은 CustomPaint 한 개로 그린다', (tester) async {
      await pumpCell(
        tester,
        const SimplifiedTimetableCell(
          content: '3-1\n수학',
          isTeacherColumn: false,
          isSelected: false,
          isExchangeable: false,
        ),
      );

      final painters = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );
      expect(
        painters.any((p) => p.painter is PlainTimetableCellPainter),
        isTrue,
        reason: '평범한 셀은 전용 Painter로 그려져야 한다',
      );

      // 위젯을 쌓는 경로로 새지 않았는지 확인
      expect(find.byType(FittedBox), findsNothing);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('빈 셀도 CustomPaint 경로를 탄다', (tester) async {
      await pumpCell(
        tester,
        const SimplifiedTimetableCell(
          content: '',
          isTeacherColumn: false,
          isSelected: false,
          isExchangeable: false,
        ),
      );

      final painters = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );
      expect(
        painters.any((p) => p.painter is PlainTimetableCellPainter),
        isTrue,
      );
    });

    testWidgets('교체된 소스 셀은 오버레이·툴팁이 있는 위젯 트리로 그린다', (tester) async {
      await pumpCell(
        tester,
        const SimplifiedTimetableCell(
          content: '3-1\n수학',
          isTeacherColumn: false,
          isSelected: false,
          isExchangeable: false,
          isExchangedSourceCell: true,
        ),
      );

      expect(find.byType(FittedBox), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.byType(ExchangedCellStatusOverlay), findsOneWidget);
    });

    testWidgets('교체불가 셀도 위젯 트리 경로를 탄다', (tester) async {
      await pumpCell(
        tester,
        const SimplifiedTimetableCell(
          content: '3-1\n수학',
          isTeacherColumn: false,
          isSelected: false,
          isExchangeable: false,
          isNonExchangeable: true,
        ),
      );

      expect(find.byType(ExchangedCellStatusOverlay), findsOneWidget);
    });

    testWidgets('상태 심볼을 끄면 교체된 셀의 X·O 오버레이를 그리지 않는다', (tester) async {
      await pumpCell(
        tester,
        const SimplifiedTimetableCell(
          content: '3-1\n수학',
          isTeacherColumn: false,
          isSelected: false,
          isExchangeable: false,
          isExchangedSourceCell: true,
          showStatusSymbols: false,
        ),
      );

      expect(find.byType(ExchangedCellStatusOverlay), findsNothing);
    });
  });

  group('PlainTimetableCellPainter', () {
    test('같은 내용·스타일이면 다시 그릴 필요가 없다', () {
      const style = TextStyle(fontSize: 11, color: Colors.black);
      const border = Border(left: BorderSide(width: 0.2));

      const a = PlainTimetableCellPainter(
        content: '3-1',
        backgroundColor: Colors.white,
        textStyle: style,
        border: border,
      );
      const b = PlainTimetableCellPainter(
        content: '3-1',
        backgroundColor: Colors.white,
        textStyle: style,
        border: border,
      );
      const c = PlainTimetableCellPainter(
        content: '3-1',
        backgroundColor: Colors.yellow, // 선택 등으로 배경이 바뀐 경우
        textStyle: style,
        border: border,
      );

      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });
}

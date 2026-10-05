import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/ui/widgets/week_navigator_strip.dart';
import 'package:class_exchange_manager/utils/week_date_calculator.dart';

/// 교체 화면·시간표 화면이 함께 쓰는 주 이동 띠 (`◀ [이번주] | 칩 ▶`)
void main() {
  final thisWeek = WeekDateCalculator.getThisWeekMonday();
  final nextWeek = thisWeek.add(const Duration(days: 7));

  Future<List<DateTime>> pumpStrip(
    WidgetTester tester, {
    required DateTime selectedWeek,
    List<String>? navLog,
  }) async {
    final selected = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: WeekNavigatorStrip(
                  weeks: [thisWeek, nextWeek],
                  selectedWeek: selectedWeek,
                  countOf: (week) => week == nextWeek ? 2 : 1,
                  onSelectWeek: selected.add,
                  onPrevious: () => navLog?.add('prev'),
                  onNext: () => navLog?.add('next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    return selected;
  }

  testWidgets('[이번주] 버튼과 "N월N주" 칩·건수 배지를 그린다', (tester) async {
    await pumpStrip(tester, selectedWeek: nextWeek);

    expect(find.text('이번주'), findsOneWidget);
    expect(find.byType(WeekChip), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget); // 다음 주 칩 배지
  });

  testWidgets('다른 주를 보고 있으면 [이번주]가 이번 주 월요일을 넘긴다', (tester) async {
    final selected = await pumpStrip(tester, selectedWeek: nextWeek);

    await tester.tap(find.text('이번주'));
    // 버튼 내부의 누름 효과 타이머가 끝나도록 시간을 흘려보낸다
    await tester.pump(const Duration(seconds: 1));

    expect(selected, [thisWeek]);
  });

  testWidgets('이번 주를 보고 있으면 [이번주]는 눌러도 아무 일도 없다', (tester) async {
    final selected = await pumpStrip(tester, selectedWeek: thisWeek);

    await tester.tap(find.text('이번주'));
    await tester.pump();

    expect(selected, isEmpty);
  });

  testWidgets('◀ ▶가 이전·다음 콜백을 부른다', (tester) async {
    final log = <String>[];
    await pumpStrip(tester, selectedWeek: thisWeek, navLog: log);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(log, ['prev', 'next']);
  });
}

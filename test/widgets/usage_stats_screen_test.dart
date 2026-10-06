import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/usage_event.dart';
import 'package:class_exchange_manager/providers/web_services_provider.dart';
import 'package:class_exchange_manager/services/usage_stats_service.dart';
import 'package:class_exchange_manager/ui/screens/web_admin/usage_stats_screen.dart';
import 'package:class_exchange_manager/utils/usage_stats_aggregator.dart';

import '../helpers/fake_usage_backend.dart';

Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late FakeUsageBackend backend;

  Future<void> pumpScreen(WidgetTester tester, {double width = 800}) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final today = UsageStatsAggregator.todayKstId();
    backend = FakeUsageBackend(
      days: [
        UsageDay(
          date: today,
          totals: const {UsageKeys.visits: 5, UsageKeys.planPdfSave: 2, 'tab_1': 4},
          teachers: const {
            '김교사': {UsageKeys.visits: 3, UsageKeys.planPdfSave: 2},
            kUsageUnnamedTeacher: {UsageKeys.visits: 2},
          },
          visitors: const {'a', 'b'},
        ),
      ],
    );
    final service = UsageStatsService(enabled: true, backend: backend);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [usageStatsServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: UsageStatsScreen()),
      ),
    );
    await pumpFrames(tester);
  }

  testWidgets('요약 수치와 교사 표를 보여 준다', (tester) async {
    await pumpScreen(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('usage-card-접속 수'))).data,
      '5',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('usage-card-고유 접속자'))).data,
      '2',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('usage-card-사용 교사 수')))
          .data,
      '2',
    );
    expect(find.text('김교사'), findsOneWidget);
    expect(find.text(kUsageUnnamedTeacher), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('전체 초기화는 확인 대화상자에 문서 수를 보여 주고 삭제한다', (tester) async {
    await pumpScreen(tester);
    await tester.scrollUntilVisible(
      find.text('전체 초기화'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('전체 초기화'));
    await pumpFrames(tester);
    expect(find.textContaining('문서 1개'), findsOneWidget);

    await tester.tap(find.text('삭제'));
    await pumpFrames(tester);
    expect(backend.days, isEmpty);
    expect(tester.takeException(), isNull);
    // 스낵바 타이머 정리
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('좁은 폭에서도 오버플로가 없다', (tester) async {
    await pumpScreen(tester, width: 320);
    expect(tester.takeException(), isNull);
    // 잘린 표 쪽으로 스크롤할 수 있음이 드러나야 한다
    expect(find.byType(Scrollbar), findsWidgets);
  });

  testWidgets('새로고침 버튼을 누르면 다시 불러와도 수치가 유지된다', (tester) async {
    await pumpScreen(tester);
    expect(find.text('새로고침'), findsOneWidget);

    await tester.tap(find.text('새로고침'));
    await pumpFrames(tester);

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('usage-card-접속 수'))).data,
      '5',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('교사 행 삭제는 확인 후 해당 교사만 지우고 합계를 차감한다', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('김교사'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byTooltip("'김교사' 통계 삭제"),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip("'김교사' 통계 삭제"));
    await pumpFrames(tester);
    expect(find.textContaining("'김교사'"), findsWidgets);

    await tester.tap(find.text('삭제'));
    await pumpFrames(tester);

    expect(find.text('김교사'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('usage-card-접속 수'))).data,
      '2',
    );
    expect(backend.days.single.teachers.keys, isNot(contains('김교사')));
    expect(tester.takeException(), isNull);
    // 스낵바 타이머 정리
    await tester.pump(const Duration(seconds: 10));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/ui/widgets/header_segmented_toggle.dart';

/// [HeaderSegmentedToggle] (헤더용 `[원본 | 날짜·교체]` 세그먼트) 검증
///
/// Riverpod·디스크 I/O 없이 그려지므로 ProviderScope 없이 MaterialApp만
/// 감싸면 된다. `pumpAndSettle()`은 쓰지 않고 경계 있는 `pump()`만 쓴다.
void main() {
  Future<void> pumpToggle(
    WidgetTester tester,
    HeaderSegmentedToggle toggle, {
    double width = 650,
  }) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: toggle)));
    await tester.pump();
  }

  HeaderSegmentedToggle buildToggle({
    bool value = false,
    ValueChanged<bool>? onChanged,
  }) {
    return HeaderSegmentedToggle(
      value: value,
      offLabel: '원본',
      onLabel: '날짜·교체',
      onChanged: onChanged ?? (_) {},
      height: 34,
    );
  }

  group('HeaderSegmentedToggle', () {
    testWidgets('양쪽 라벨이 항상 보인다', (tester) async {
      await pumpToggle(tester, buildToggle());

      expect(tester.takeException(), isNull);
      expect(find.text('원본'), findsOneWidget);
      expect(find.text('날짜·교체'), findsOneWidget);
    });

    testWidgets('미선택 쪽을 누르면 onChanged가 호출된다', (tester) async {
      bool? changed;
      await pumpToggle(
        tester,
        buildToggle(value: false, onChanged: (v) => changed = v),
      );

      await tester.tap(find.text('날짜·교체'));
      await tester.pump();

      expect(changed, isTrue);
    });

    testWidgets('선택된 쪽을 눌러도 onChanged가 호출되지 않는다', (tester) async {
      var called = false;
      await pumpToggle(
        tester,
        buildToggle(value: true, onChanged: (_) => called = true),
      );

      await tester.tap(find.text('날짜·교체'));
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('420px 좁은 너비에서도 오버플로가 없다', (tester) async {
      await pumpToggle(tester, buildToggle(), width: 420);

      expect(tester.takeException(), isNull);
    });
  });
}

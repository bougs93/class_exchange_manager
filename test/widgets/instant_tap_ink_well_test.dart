import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/ui/widgets/instant_tap_ink_well.dart';

/// 단일 탭 지연 제거 테스트
///
/// `InkWell`에 `onTap`과 `onDoubleTap`을 함께 주면 Flutter가 두 번째 탭을
/// 기다리느라 단일 탭을 `kDoubleTapTimeout`(300ms)만큼 늦게 실행한다.
/// 사이드바에서 교체 경로를 눌렀을 때 하이라이트·시간표 반영이 늦던 원인이라,
/// 즉시 실행되는지와 더블탭이 여전히 동작하는지를 함께 고정한다.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onTap,
    VoidCallback? onDoubleTap,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InstantTapInkWell(
              onTap: onTap,
              onDoubleTap: onDoubleTap,
              child: const SizedBox(width: 120, height: 40, child: Text('경로')),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('더블탭 콜백이 있어도 단일 탭은 기다리지 않고 바로 실행된다', (tester) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++, onDoubleTap: () {});

    await tester.tap(find.text('경로'));
    // pump 없이 바로 확인 — 타이머를 기다리지 않는다는 뜻
    expect(taps, 1);
  });

  testWidgets('더블탭 시간 안에 다시 누르면 더블탭 콜백이 실행된다', (tester) async {
    var taps = 0;
    var doubleTaps = 0;
    await pump(tester, onTap: () => taps++, onDoubleTap: () => doubleTaps++);

    await tester.tap(find.text('경로'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('경로'));
    await tester.pump();

    // 첫 탭은 이미 선택을 끝냈고, 두 번째 탭이 실행을 맡는다
    expect(taps, 1);
    expect(doubleTaps, 1);
  });

  testWidgets('더블탭 시간이 지난 뒤 누르면 단일 탭으로 처리된다', (tester) async {
    var taps = 0;
    var doubleTaps = 0;
    await pump(tester, onTap: () => taps++, onDoubleTap: () => doubleTaps++);

    await tester.tap(find.text('경로'));
    // 연속 탭 판정은 실제 시각(DateTime.now)으로 하므로 가짜 시계를 돌리는
    // pump(Duration)로는 시간이 흐르지 않는다. 실제로 기다린다.
    await tester.runAsync(
      () => Future<void>.delayed(
        kDoubleTapTimeout + const Duration(milliseconds: 50),
      ),
    );
    await tester.tap(find.text('경로'));
    await tester.pump();

    expect(taps, 2);
    expect(doubleTaps, 0);
  });

  testWidgets('세 번 연속 눌러도 더블탭이 두 번 겹쳐 실행되지 않는다', (tester) async {
    var doubleTaps = 0;
    await pump(tester, onTap: () {}, onDoubleTap: () => doubleTaps++);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('경로'));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(doubleTaps, 1);
  });

  testWidgets('더블탭 콜백이 없으면 매번 단일 탭으로 처리된다', (tester) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);

    await tester.tap(find.text('경로'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('경로'));
    await tester.pump();

    expect(taps, 2);
  });
}

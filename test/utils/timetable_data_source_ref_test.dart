import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/teacher.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/timetable_data_source.dart';

/// 화면보다 오래 사는 데이터소스의 ref 재연결 테스트
///
/// `TimetableDataSource`는 전역 `exchangeScreenProvider`에 담겨 있어서
/// 그것을 만든 화면보다 오래 산다. 웹 로그인 게이트가 로그아웃/재로그인으로
/// 화면 트리를 통째로 새로 만들면 이미 사라진 화면의 WidgetRef가 남고,
/// 그 상태로 그리드를 그리면
/// `Bad state: Cannot use "ref" after the widget was disposed`로 앱이 멈춘다.
/// 새 화면이 빌드될 때 ref를 다시 붙이면 복구되어야 한다.
void main() {
  TimetableDataSource buildSource(WidgetRef ref) {
    return TimetableDataSource(
      timeSlots: [
        TimeSlot(
          teacher: '김교사',
          dayOfWeek: 1,
          period: 1,
          subject: '수학',
          className: '3-1',
        ),
      ],
      teachers: [Teacher(name: '김교사', subject: '수학')],
      ref: ref,
    );
  }

  testWidgets('화면이 사라진 뒤에도 새 ref를 붙이면 행을 그릴 수 있다', (tester) async {
    TimetableDataSource? source;

    // 1) 첫 화면에서 데이터소스를 만든다
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            source ??= buildSource(ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(source, isNotNull);
    expect(source!.buildRow(source!.rows.first), isNotNull);

    // 2) 로그인 게이트가 트리를 통째로 갈아끼운 상황 — 첫 화면이 사라진다
    await tester.pumpWidget(const ProviderScope(child: SizedBox.shrink()));

    // 셀 상태 스냅샷을 버리게 해 실제로 ref를 다시 읽는 상황을 만든다
    // (앱에서는 셀 선택·경로 변경 등으로 늘 일어난다)
    source!.notifyDataChanged();

    // 사라진 화면의 ref로는 더 이상 셀 상태를 읽을 수 없다(원래 증상)
    expect(() => source!.buildRow(source!.rows.first), throwsStateError);

    // 3) 새 화면이 뜨면서 현재 ref를 다시 붙인다
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            source!.attachRef(ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // 복구되어야 한다
    expect(source!.buildRow(source!.rows.first), isNotNull);
  });

  testWidgets('같은 ref를 다시 붙이면 아무 일도 하지 않는다', (tester) async {
    TimetableDataSource? source;
    WidgetRef? captured;

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            source ??= buildSource(ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    source!.attachRef(captured!);
    expect(identical(source!.ref, captured), isTrue);
    expect(source!.buildRow(source!.rows.first), isNotNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:class_exchange_manager/models/timetable_registry.dart';
import 'package:class_exchange_manager/providers/print_profile_provider.dart';
import 'package:class_exchange_manager/providers/timetable_registry_provider.dart';
import 'package:class_exchange_manager/providers/timetable_teachers_provider.dart';
import 'package:class_exchange_manager/theme/app_theme.dart';
import 'package:class_exchange_manager/theme/app_theme_type.dart';
import 'package:class_exchange_manager/ui/screens/start_content/timetable_summary_card.dart';

/// 홈 시간표 카드 레이아웃 검증
///
/// 라벨 칼럼이 좁으면 '학교명'·'계획서' 라벨에서 RenderFlex 오버플로가 발생한다.
/// 실제 창 너비(약 650px)와 좁은 폭 모두에서 오버플로가 없어야 한다.
void main() {
  TimetableRegistryEntry makeEntry({String? teacherName, String? schoolName}) {
    return TimetableRegistryEntry(
      id: 'tt_1',
      name: '월계중2학기',
      fileName: '2학기 전체시간표 확정(0820).xlsx',
      filePath: 'D:/시간표.xlsx',
      hash: 'h',
      contentHash: 'c',
      teacherName: teacherName,
      schoolName: schoolName,
      registeredAt: DateTime(2026, 8, 26),
    );
  }

  Widget buildCard({
    required TimetableRegistryEntry? entry,
    List<String> teachers = const ['김철수', '이영희', '정원길'],
  }) {
    return ProviderScope(
      overrides: [
        activeTimetableEntryProvider.overrideWithValue(entry),
        activeTimetableTeachersProvider.overrideWithValue(teachers),
        // 디스크 접근 없이 빈 스토어를 쓰도록 스코프를 null로 둔다
        printProfileStoreProvider.overrideWith(
          (ref) => PrintProfileStoreNotifier(null),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.of(AppThemeType.classic),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimetableSummaryCard(
              onAddTimetable: () async {},
              onOpenManager: () async {},
              onOpenProfiles: () {},
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpAt(
    WidgetTester tester,
    Widget widget, {
    required double width,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    await tester.pump();
  }

  group('TimetableSummaryCard 레이아웃', () {
    testWidgets('교사 미선택 상태에서 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildCard(entry: makeEntry()),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('교사'), findsOneWidget);
      expect(find.text('학교명'), findsOneWidget);
      expect(find.text('계획서'), findsOneWidget);
      // 교사 미선택 안내가 보인다
      expect(find.textContaining('선택하면 교체 화면에서'), findsOneWidget);
    });

    testWidgets('교사·학교명이 채워진 상태에서 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildCard(entry: makeEntry(teacherName: '정원길', schoolName: '월계중학교')),
        width: 650,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('좁은 창(420px)에서도 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildCard(entry: makeEntry(teacherName: '정원길', schoolName: '월계중학교')),
        width: 420,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('시간표가 없으면 교사·학교명 영역을 그리지 않는다', (tester) async {
      await pumpAt(tester, buildCard(entry: null), width: 650);

      expect(tester.takeException(), isNull);
      expect(find.text('등록된 시간표가 없습니다'), findsOneWidget);
      expect(find.text('교사'), findsNothing);
      expect(find.text('학교명'), findsNothing);
      expect(find.text('계획서'), findsNothing);
    });

    testWidgets('교사 미선택이면 계획서 관리 버튼이 비활성이다', (tester) async {
      await pumpAt(tester, buildCard(entry: makeEntry()), width: 650);

      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('관리 >'),
          matching: find.byType(TextButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });
}

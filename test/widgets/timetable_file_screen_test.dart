import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:class_exchange_manager/models/print_profile.dart';
import 'package:class_exchange_manager/models/timetable_registry.dart';
import 'package:class_exchange_manager/providers/print_profile_provider.dart';
import 'package:class_exchange_manager/providers/timetable_registry_provider.dart';
import 'package:class_exchange_manager/providers/timetable_summary_provider.dart';
import 'package:class_exchange_manager/services/timetable_registry_service.dart';
import 'package:class_exchange_manager/theme/app_theme.dart';
import 'package:class_exchange_manager/theme/app_theme_type.dart';
import 'package:class_exchange_manager/ui/screens/timetable_file_screen.dart';

import '../helpers/in_memory_json_storage.dart';

/// TimetableFileScreen 레이아웃·렌더링 검증
///
/// 레지스트리 서비스를 인메모리 저장소로 교체해 실제 파일 I/O 없이
/// 등록된 시간표 목록을 주입합니다. 계획서 스토어는 항상 null 스코프로
/// 오버라이드해 디스크 접근 없는 빈 상태를 사용합니다(§timetable_summary_card_test
/// 와 동일한 패턴). timetableSummaryProvider는 family Provider를 직접
/// 오버라이드해 실제 교체/결보강/계획서 저장소를 읽지 않도록 합니다.
void main() {
  TimetableRegistryEntry makeEntry({
    required String id,
    String name = '월계중2학기',
    String fileName = '2학기 전체시간표 확정(0820).xlsx',
    String filePath = 'D:/시간표.xlsx',
    String? teacherName,
    String? schoolName,
  }) {
    return TimetableRegistryEntry(
      id: id,
      name: name,
      fileName: fileName,
      filePath: filePath,
      hash: 'h_$id',
      contentHash: 'c_$id',
      teacherName: teacherName,
      schoolName: schoolName,
      registeredAt: DateTime(2026, 8, 26),
    );
  }

  List<Override> buildOverrides({
    required TimetableRegistry registry,
    List<PrintProfile> profiles = const [],
    TimetableSummary Function(String id)? summaryBuilder,
  }) {
    final storage = InMemoryJsonStorage();
    storage.seedJson(TimetableRegistryService.filename, registry.toJson());

    return [
      timetableRegistryServiceProvider.overrideWith(
        (ref) => TimetableRegistryService(storage: storage),
      ),
      // 디스크 접근 없이 빈(또는 지정된) 스토어를 쓰도록 스코프를 null로 둔다
      printProfileStoreProvider.overrideWith(
        (ref) =>
            PrintProfileStoreNotifier(null)
              ..state = PrintProfileStore(profiles: profiles),
      ),
      timetableSummaryProvider.overrideWith(
        (ref, id) async => summaryBuilder?.call(id) ?? const TimetableSummary(),
      ),
    ];
  }

  Widget buildScreen({required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.of(AppThemeType.classic),
        home: const TimetableFileScreen(),
      ),
    );
  }

  /// 레지스트리 로드(인메모리, 실제 디스크 I/O 없음)가 끝날 때까지 흘려보낸다.
  Future<void> pumpAt(
    WidgetTester tester,
    Widget widget, {
    required double width,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  group('TimetableFileScreen 빈 상태', () {
    testWidgets('등록된 시간표가 없으면 빈 상태 안내가 보인다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(registry: const TimetableRegistry()),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('등록된 시간표가 없습니다'), findsOneWidget);
      expect(find.textContaining('엑셀 시간표를 등록하세요'), findsOneWidget);
      expect(find.text('시간표 추가'), findsOneWidget);
    });

    testWidgets('빈 상태에서는 시간표 카드가 그려지지 않는다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(registry: const TimetableRegistry()),
        ),
        width: 650,
      );

      expect(find.text('사용 중'), findsNothing);
      expect(find.textContaining('등록 '), findsNothing);
    });
  });

  group('TimetableFileScreen 카드 렌더링', () {
    testWidgets('등록된 시간표 1건이 활성 카드로 렌더링된다', (tester) async {
      final entry = makeEntry(
        id: 'tt_1',
        teacherName: '정원길',
        schoolName: '월계중학교',
      );
      final registry = const TimetableRegistry().withEntry(entry);

      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(registry: registry)),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('등록된 시간표 (1개)'), findsOneWidget);
      expect(find.text('월계중2학기'), findsOneWidget);
      expect(find.text('사용 중'), findsOneWidget);
      expect(find.textContaining('월계중학교'), findsOneWidget);
      expect(find.textContaining('교사: 정원길'), findsOneWidget);
    });

    testWidgets('교사 미지정 활성 시간표는 경고 안내를 보여준다', (tester) async {
      final entry = makeEntry(id: 'tt_1');
      final registry = const TimetableRegistry().withEntry(entry);

      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(registry: registry)),
        width: 650,
      );

      expect(find.textContaining('교사 미지정 — 홈 화면에서 선택하세요'), findsOneWidget);
    });

    testWidgets('두 번째 항목은 비활성 카드(접힌 본문)로 렌더링된다', (tester) async {
      final active = makeEntry(id: 'tt_1', teacherName: '정원길');
      final inactive = makeEntry(
        id: 'tt_2',
        name: '월계중1학기',
        teacherName: '김철수',
      );
      var registry = const TimetableRegistry().withEntry(active);
      registry = registry.withEntry(inactive);

      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(registry: registry)),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('등록된 시간표 (2개)'), findsOneWidget);
      expect(find.text('월계중1학기'), findsOneWidget);
      // 활성 카드 배지는 하나만 존재
      expect(find.text('사용 중'), findsOneWidget);
      // 비활성 카드는 접힌 한 줄 요약(교사명)만 보인다
      expect(find.textContaining('김철수'), findsOneWidget);
    });

    testWidgets('활성 카드는 계획서 트리를 표시한다', (tester) async {
      final entry = makeEntry(id: 'tt_1', teacherName: '정원길');
      final registry = const TimetableRegistry().withEntry(entry);
      final profiles = [
        const PrintProfile(
          id: 'pp_1',
          name: '계획서1',
          teacherName: '정원길',
          templateIndex: 0,
          fontSize: 10,
          remarksFontSize: 9,
          selectedFont: 'NotoSansKR',
          includeRemarks: true,
        ),
      ];

      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(registry: registry, profiles: profiles),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('정원길'), findsWidgets);
      expect(find.textContaining('계획서1'), findsOneWidget);
    });

    testWidgets('요약 정보가 활성 카드 하단에 표시된다', (tester) async {
      final entry = makeEntry(id: 'tt_1', teacherName: '정원길');
      final registry = const TimetableRegistry().withEntry(entry);

      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(
            registry: registry,
            summaryBuilder:
                (id) =>
                    const TimetableSummary(exchangeCount: 3, planEntryCount: 2),
          ),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('교체 3건'), findsOneWidget);
      expect(find.textContaining('결보강 입력 2건'), findsOneWidget);
    });

    testWidgets('비활성 카드도 요약 정보를 한 줄로 보여준다', (tester) async {
      final active = makeEntry(id: 'tt_1', teacherName: '정원길');
      final inactive = makeEntry(id: 'tt_2', name: '월계중1학기');
      var registry = const TimetableRegistry().withEntry(active);
      registry = registry.withEntry(inactive);

      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(
            registry: registry,
            summaryBuilder: (id) {
              if (id == 'tt_2') {
                return const TimetableSummary(profileCount: 1);
              }
              return const TimetableSummary();
            },
          ),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('계획서 1개'), findsOneWidget);
      expect(find.textContaining('교사 미지정'), findsOneWidget);
    });
  });

  group('TimetableFileScreen 액션 버튼', () {
    testWidgets('활성 카드에는 전환 버튼이 없고 비활성 카드에는 있다', (tester) async {
      final active = makeEntry(id: 'tt_1');
      final inactive = makeEntry(id: 'tt_2', name: '월계중1학기');
      var registry = const TimetableRegistry().withEntry(active);
      registry = registry.withEntry(inactive);

      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(registry: registry)),
        width: 650,
      );

      // 비활성 카드 1개에만 '전환' 버튼이 있다
      expect(find.text('전환'), findsOneWidget);
      // 이름 변경·삭제는 모든 카드(2개)에 존재
      expect(find.text('이름 변경'), findsNWidgets(2));
      expect(find.text('삭제'), findsNWidgets(2));
    });

    testWidgets('시간표 추가 버튼이 활성화되어 있다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(registry: const TimetableRegistry()),
        ),
        width: 650,
      );

      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('시간표 추가'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('전환 버튼을 누르면 전환 확인 다이얼로그가 뜬다', (tester) async {
      final active = makeEntry(id: 'tt_1');
      final inactive = makeEntry(id: 'tt_2', name: '월계중1학기');
      var registry = const TimetableRegistry().withEntry(active);
      registry = registry.withEntry(inactive);

      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(registry: registry)),
        width: 650,
      );

      await tester.tap(find.text('전환'));
      await tester.pump();

      expect(find.textContaining("'월계중1학기'(으)로 전환"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('TimetableFileScreen 오버플로', () {
    testWidgets('650px 너비에서 카드 2개 모두 오버플로가 없다', (tester) async {
      final active = makeEntry(
        id: 'tt_1',
        teacherName: '정원길',
        schoolName: '월계중학교',
      );
      final inactive = makeEntry(
        id: 'tt_2',
        name: '월계중1학기',
        teacherName: '김철수',
        schoolName: '월계중학교',
      );
      var registry = const TimetableRegistry().withEntry(active);
      registry = registry.withEntry(inactive);

      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(registry: registry)),
        width: 650,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('420px 좁은 너비에서도 오버플로가 없다', (tester) async {
      final active = makeEntry(
        id: 'tt_1',
        teacherName: '정원길',
        schoolName: '월계중학교',
      );
      final inactive = makeEntry(
        id: 'tt_2',
        name: '월계중1학기',
        teacherName: '김철수',
        schoolName: '월계중학교',
      );
      var registry = const TimetableRegistry().withEntry(active);
      registry = registry.withEntry(inactive);

      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(registry: registry)),
        width: 420,
      );

      expect(tester.takeException(), isNull);
    });
  });
}

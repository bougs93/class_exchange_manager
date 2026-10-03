import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:class_exchange_manager/providers/app_settings_provider.dart';
import 'package:class_exchange_manager/providers/theme_provider.dart';
import 'package:class_exchange_manager/providers/timetable_registry_provider.dart';
import 'package:class_exchange_manager/services/app_settings_storage_service.dart';
import 'package:class_exchange_manager/services/timetable_registry_service.dart';
import 'package:class_exchange_manager/theme/app_theme.dart';
import 'package:class_exchange_manager/theme/app_theme_type.dart';
import 'package:class_exchange_manager/ui/screens/start_content/start_settings_card.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/timetable_grid_constants.dart';

import '../helpers/in_memory_json_storage.dart';

/// 홈 "기타 설정" 카드 레이아웃·토글 검증
///
/// 시간표 레지스트리를 빈 상태로 오버라이드하여 SemesterPeriodSection·
/// DatedDataInspectorSection이 SQLite에 접근하지 않도록 한다(§문서: 디스크
/// 접근 없는 위젯 테스트). 2중/순환 교체·화살표 방향·디자인 테마 Provider는
/// `skipInitialLoad: true`로 저장소 접근 없이 원하는 초기값을 주입한다.
void main() {
  // StartSettingsCard.initState()은 AppSettingsStorageService(싱글톤)를 통해 실제
  // 디스크에서 언어·하이라이트 색상을 읽는다(Provider로 주입되지 않는 직접 호출이라
  // 테스트에서 오버라이드할 수 없다). 첫 접근 시 데이터 폴더 생성 등 콜드 스타트
  // 지연이 있어, 실제 테스트 실행 전에 한 번 미리 호출해 캐시를 예열해 둔다.
  setUpAll(() async {
    await AppSettingsStorageService().getLanguageCode();
    await AppSettingsStorageService().getHighlightedTeacherColor();
  });

  List<Override> buildOverrides({
    bool dualExchangeEnabled = true,
    bool circularExchangeEnabled = false,
    ArrowDirection oneToOneDirection = ArrowDirection.bidirectional,
    ArrowDirection dualDirection = ArrowDirection.bidirectional,
    AppThemeType themeType = AppThemeType.modern,
  }) {
    return [
      // 레지스트리 서비스를 인메모리 저장소로 교체 → 실제 파일 I/O 없이 빈 레지스트리로 시작
      timetableRegistryServiceProvider.overrideWith(
        (ref) => TimetableRegistryService(storage: InMemoryJsonStorage()),
      ),
      dualExchangeEnabledProvider.overrideWith(
        (ref) => DualExchangeEnabledNotifier(
          skipInitialLoad: true,
          initialValue: dualExchangeEnabled,
        ),
      ),
      circularExchangeEnabledProvider.overrideWith(
        (ref) => CircularExchangeEnabledNotifier(
          skipInitialLoad: true,
          initialValue: circularExchangeEnabled,
        ),
      ),
      oneToOneArrowDirectionProvider.overrideWith(
        (ref) => ArrowDirectionNotifier(
          initialDirection: ArrowDirection.bidirectional,
          loader: () async => oneToOneDirection,
          saver: (_) async => true,
          skipInitialLoad: true,
          initialValue: oneToOneDirection,
        ),
      ),
      dualArrowDirectionProvider.overrideWith(
        (ref) => ArrowDirectionNotifier(
          initialDirection: ArrowDirection.bidirectional,
          loader: () async => dualDirection,
          saver: (_) async => true,
          skipInitialLoad: true,
          initialValue: dualDirection,
        ),
      ),
      appThemeTypeProvider.overrideWith(
        (ref) => AppThemeNotifier(
          loader: () async => themeType,
          saver: (_) async => true,
          skipInitialLoad: true,
          initialValue: themeType,
        ),
      ),
    ];
  }

  Widget buildCard({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides.isEmpty ? buildOverrides() : overrides,
      child: MaterialApp(
        theme: AppTheme.of(AppThemeType.classic),
        home: Scaffold(body: SingleChildScrollView(child: StartSettingsCard())),
      ),
    );
  }

  Future<void> pumpAt(
    WidgetTester tester,
    Widget widget, {
    required double width,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    // initState의 실제 디스크 I/O(언어·하이라이트 색상 로드)가 끝날 때까지 흘려보낸다.
    // 일반 pump()만으로는 실제(dart:io) Future가 흐르지 않을 수 있어
    // runAsync로 진짜 이벤트 루프에 양보한 뒤 pump로 화면을 갱신한다.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  Future<void> expandCard(WidgetTester tester) async {
    await tester.tap(find.text('기타 설정'));
    // ExpansionTile 확장 애니메이션 + 하위 섹션 initState의 비동기 작업을 흘려보낸다.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('StartSettingsCard 레이아웃', () {
    testWidgets('기본 상태(650px)에서 오버플로 없이 렌더링된다', (tester) async {
      await pumpAt(tester, buildCard(), width: 650);
      await expandCard(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('기타 설정'), findsOneWidget);
      expect(find.text('언어 설정'), findsOneWidget);
      expect(find.text('디자인 테마'), findsOneWidget);
    });

    testWidgets('좁은 폭(420px)에서도 오버플로가 없다', (tester) async {
      await pumpAt(tester, buildCard(), width: 420);
      await expandCard(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('2중교체 활성 상태에서도 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildCard(
          overrides: buildOverrides(
            dualExchangeEnabled: true,
            circularExchangeEnabled: true,
          ),
        ),
        width: 650,
      );
      await expandCard(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('StartSettingsCard 섹션·토글', () {
    testWidgets('펼치면 주요 섹션 제목들이 모두 보인다', (tester) async {
      await pumpAt(tester, buildCard(), width: 650);
      await expandCard(tester);

      expect(find.text('언어 설정'), findsOneWidget);
      expect(find.text('디자인 테마'), findsOneWidget);
      expect(find.text('간접교체'), findsOneWidget);
      expect(find.text('화살표 표시'), findsOneWidget);
      expect(find.text('데이터 저장 위치'), findsOneWidget);
      // 등록된 시간표가 없을 때는 "학기 기간" 제목 대신 안내 문구만 보인다.
      expect(find.textContaining('등록된 시간표가 없습니다'), findsOneWidget);
      // 섹션 제목과 버튼 라벨이 같은 문자열("기본값 복원")을 공유한다.
      expect(find.text('기본값 복원'), findsWidgets);
      expect(find.text('데이터 초기화'), findsOneWidget);
    });

    testWidgets('접혀 있으면 내부 섹션이 보이지 않는다', (tester) async {
      await pumpAt(tester, buildCard(), width: 650);

      expect(find.text('언어 설정'), findsNothing);
      expect(find.text('디자인 테마'), findsNothing);
    });

    testWidgets('시간표가 없으면 학기 기간 섹션에 등록 안내가 보인다', (tester) async {
      await pumpAt(tester, buildCard(), width: 650);
      await expandCard(tester);

      expect(
        find.textContaining('등록된 시간표가 없습니다. 시간표를 먼저 등록하면'),
        findsOneWidget,
      );
    });

    testWidgets('시간표가 없으면 날짜 기반 설정 패널은 그려지지 않는다', (tester) async {
      await pumpAt(tester, buildCard(), width: 650);
      await expandCard(tester);

      expect(find.text('날짜 반영·교체 스위치 통합'), findsNothing);
    });

    testWidgets('2중교체 비활성 시 2중 교체 화살표 선택 카드가 흐리게 표시된다', (tester) async {
      await pumpAt(
        tester,
        buildCard(overrides: buildOverrides(dualExchangeEnabled: false)),
        width: 650,
      );
      await expandCard(tester);

      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('2중 교체'), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, lessThan(1.0));
    });

    testWidgets('2중교체 활성 시 2중 교체 화살표 선택 카드가 정상 표시된다', (tester) async {
      await pumpAt(
        tester,
        buildCard(overrides: buildOverrides(dualExchangeEnabled: true)),
        width: 650,
      );
      await expandCard(tester);

      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('2중 교체'), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 1.0);
    });

    testWidgets('디자인 테마 카드가 표시된 테마 개수만큼 그려진다', (tester) async {
      await pumpAt(tester, buildCard(), width: 650);
      await expandCard(tester);

      for (final type in AppThemeType.displayOrder) {
        expect(find.text(type.displayName), findsOneWidget);
      }
    });

    testWidgets('기본값 복원·데이터 초기화 버튼이 활성 상태로 보인다', (tester) async {
      await pumpAt(tester, buildCard(), width: 650);
      await expandCard(tester);

      final restoreButton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('기본값 복원').last,
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(restoreButton.onPressed, isNotNull);

      final resetButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('모든 데이터 삭제'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(resetButton.onPressed, isNotNull);
    });
  });
}

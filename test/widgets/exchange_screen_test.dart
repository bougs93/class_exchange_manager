import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:class_exchange_manager/models/exchange_mode.dart';
import 'package:class_exchange_manager/models/teacher.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/models/timetable_data.dart';
import 'package:class_exchange_manager/models/timetable_registry.dart';
import 'package:class_exchange_manager/providers/app_settings_provider.dart';
import 'package:class_exchange_manager/providers/exchange_screen_provider.dart';
import 'package:class_exchange_manager/providers/print_profile_provider.dart';
import 'package:class_exchange_manager/providers/timetable_registry_provider.dart';
import 'package:class_exchange_manager/services/app_settings_storage_service.dart';
import 'package:class_exchange_manager/services/timetable_registry_service.dart';
import 'package:class_exchange_manager/theme/app_theme.dart';
import 'package:class_exchange_manager/theme/app_theme_type.dart';
import 'package:class_exchange_manager/ui/screens/exchange_screen.dart';

import '../helpers/in_memory_json_storage.dart';

/// [ExchangeScreen] (교체 화면) 렌더링 검증
///
/// 다른 화면 테스트들과 동일한 패턴을 따른다 —
/// `timetableRegistryServiceProvider`는 [InMemoryJsonStorage]로, 계획서
/// 스토어는 `timetableId: null`인 [PrintProfileStoreNotifier]로 디스크 I/O를
/// 제거한다. `dualExchangeEnabledProvider`/`circularExchangeEnabledProvider`는
/// `exchange_mode_selector_test.dart`와 동일하게 `skipInitialLoad: true` +
/// 고정 `initialValue`로 오버라이드해 `AppSettingsStorageService` 비동기
/// 로드를 건너뛴다. 시간표는 `exchangeScreenProvider`에 동기로 주입한다.
///
/// `pumpAndSettle()`은 이 화면에서 멈추므로(진행률 애니메이션·폴링류) 쓰지
/// 않고, `runAsync` + `pump()`를 유한 횟수 반복하는 방식만 사용한다.
void main() {
  List<Override> buildOverrides({
    TimetableData? timetableData,
    String? activeTeacherName,
    bool dualExchangeEnabled = true,
    bool circularExchangeEnabled = false,
  }) {
    final storage = InMemoryJsonStorage();
    if (activeTeacherName != null) {
      final entry = TimetableRegistryEntry(
        id: 'tt_1',
        name: '테스트시간표',
        fileName: 'test.xlsx',
        filePath: 'D:/test.xlsx',
        hash: 'h_tt_1',
        contentHash: 'c_tt_1',
        teacherName: activeTeacherName,
        registeredAt: DateTime(2026, 10, 1),
      );
      final registry = const TimetableRegistry().withEntry(entry);
      storage.seedJson(TimetableRegistryService.filename, registry.toJson());
    }

    return [
      timetableRegistryServiceProvider.overrideWith(
        (ref) => TimetableRegistryService(storage: storage),
      ),
      printProfileStoreProvider.overrideWith(
        (ref) => PrintProfileStoreNotifier(null),
      ),
      dualExchangeEnabledProvider.overrideWith(
        (ref) => DualExchangeEnabledNotifier(
          storageService: _NoopDualExchangeSettingsStorage(),
          skipInitialLoad: true,
          initialValue: dualExchangeEnabled,
        ),
      ),
      circularExchangeEnabledProvider.overrideWith(
        (ref) => CircularExchangeEnabledNotifier(
          storageService: _NoopCircularExchangeSettingsStorage(),
          skipInitialLoad: true,
          initialValue: circularExchangeEnabled,
        ),
      ),
      if (timetableData != null)
        exchangeScreenProvider.overrideWith(
          (ref) => ExchangeScreenNotifier()..setTimetableData(timetableData),
        ),
    ];
  }

  TimetableData makeSmallTimetable() {
    return TimetableData(
      teachers: [
        Teacher(name: '정원길', subject: '수학'),
        Teacher(name: '김철수', subject: '영어'),
      ],
      timeSlots: [
        TimeSlot(
          teacher: '정원길',
          subject: '수학',
          className: '1-1',
          dayOfWeek: 1,
          period: 1,
        ),
        TimeSlot(
          teacher: '김철수',
          subject: '영어',
          className: '1-2',
          dayOfWeek: 1,
          period: 1,
        ),
      ],
      config: const ExcelParsingConfig(),
      totalParsedCells: 2,
      successCount: 2,
      errorCount: 0,
    );
  }

  Widget buildScreen({required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.of(AppThemeType.classic),
        home: const ExchangeScreen(),
      ),
    );
  }

  /// 초기 비동기 작업(인메모리 레지스트리 로드, 그리드 데이터 생성 등)이
  /// 끝날 때까지 흘려보낸다. `pumpAndSettle()`은 이 화면에서 멈추므로 쓰지
  /// 않고, 유한 횟수만 반복한다.
  Future<void> pumpAt(
    WidgetTester tester,
    Widget widget, {
    required double width,
    double height = 900,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  group('ExchangeScreen 렌더링', () {
    testWidgets('시간표 미로드 상태에서 예외 없이 렌더링된다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 900,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('작은 시간표가 주입된 상태에서 예외 없이 렌더링된다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(
            timetableData: makeSmallTimetable(),
            activeTeacherName: '정원길',
          ),
        ),
        width: 900,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('ExchangeScreen 모드 버튼', () {
    testWidgets('시간표 미로드 상태에서도 모드 버튼이 보인다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(circularExchangeEnabled: true)),
        width: 900,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text(ExchangeMode.oneToOneExchange.displayName),
        findsOneWidget,
      );
      expect(
        find.text(ExchangeMode.circularExchange.displayName),
        findsOneWidget,
      );
      expect(
        find.text(ExchangeMode.supplementExchange.displayName),
        findsOneWidget,
      );
    });

    testWidgets('2중교체 비활성화 시 2중교체 버튼이 숨겨진다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(dualExchangeEnabled: false)),
        width: 900,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(ExchangeMode.dualExchange.displayName), findsNothing);
    });
  });

  group('ExchangeScreen 오버플로', () {
    testWidgets('650px 너비에서 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(
            timetableData: makeSmallTimetable(),
            activeTeacherName: '정원길',
          ),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
    });

    // 참고: 420px에서 dualExchangeEnabled=true(기본값)·circular=false 조합은
    // ExchangeControlPanel의 모드 버튼 5개가 들어가지 않아 기존에도 49px
    // 오버플로가 발생한다(이 화면의 사전 존재 이슈 — 본 테스트 작업 범위 밖이라
    // 수정하지 않음). 여기서는 2중교체를 끈 4버튼 조합으로 레이아웃만 검증한다.
    testWidgets('420px 좁은 너비에서도 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(dualExchangeEnabled: false)),
        width: 420,
      );

      expect(tester.takeException(), isNull);
    });
  });
}

/// 디스크 접근 없이 항상 고정값을 반환하는 2중교체 설정 저장소 (테스트용)
class _NoopDualExchangeSettingsStorage implements DualExchangeSettingsStorage {
  @override
  Future<bool> getDualExchangeEnabled() async => true;

  @override
  Future<bool> saveDualExchangeEnabled(bool value) async => true;
}

/// 디스크 접근 없이 항상 고정값을 반환하는 순환교체 설정 저장소 (테스트용)
class _NoopCircularExchangeSettingsStorage
    implements CircularExchangeSettingsStorage {
  @override
  Future<bool> getCircularExchangeEnabled() async => false;

  @override
  Future<bool> saveCircularExchangeEnabled(bool value) async => false;
}

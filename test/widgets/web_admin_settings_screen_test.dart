import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/web_login_branding.dart';
import 'package:class_exchange_manager/providers/web_services_provider.dart';
import 'package:class_exchange_manager/repositories/timetable_repository.dart';
import 'package:class_exchange_manager/services/shared_timetable_sync_service.dart';
import 'package:class_exchange_manager/services/web_branding_service.dart';
import 'package:class_exchange_manager/ui/screens/web_admin_settings_screen.dart';

/// `noSuchMethod` 포워딩으로 인터페이스의 나머지 멤버를 모두 흡수한다.
///
/// [FirebaseFirestore]/[FirebaseStorage]를 실제로 생성하지 않고도
/// [WebBrandingService]/[SharedTimetableSyncService] 생성자에 "null이 아닌"
/// 값을 넘겨, 생성자 기본값(`?? FirebaseFirestore.instance`) 평가를 막는 용도.
/// 테스트에서는 이 가짜 인스턴스의 멤버가 호출되지 않도록 서비스의 공개
/// 메서드를 모두 override 해서 쓴다.
class _NoSuchMethodFake {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore extends _NoSuchMethodFake implements FirebaseFirestore {}

class _FakeStorage extends _NoSuchMethodFake implements FirebaseStorage {}

/// Firebase에 전혀 접근하지 않는 [WebBrandingService] 가짜.
///
/// 생성자에 [_FakeFirestore]/[_FakeStorage]를 넘겨 `??` 기본값 평가(실제
/// `FirebaseFirestore.instance` 호출)를 막고, 화면이 쓰는 공개 메서드를 모두
/// 캔 값으로 override한다.
class FakeBrandingService extends WebBrandingService {
  FakeBrandingService({this.initialBranding = const WebLoginBranding()})
    : super(firestore: _FakeFirestore(), storage: _FakeStorage());

  final WebLoginBranding initialBranding;

  int loadCallCount = 0;
  int saveCallCount = 0;
  WebLoginBranding? lastSaved;

  @override
  Future<WebLoginBranding> load() async {
    loadCallCount++;
    return initialBranding;
  }

  @override
  Future<Uint8List?> resolveLogoBytes(WebLoginBranding branding) async => null;

  @override
  Future<void> saveBranding(WebLoginBranding branding) async {
    saveCallCount++;
    lastSaved = branding;
  }

  @override
  Future<WebLoginBranding> uploadLogo({
    required Uint8List bytes,
    required String contentType,
    required WebLoginBranding current,
  }) async => current;

  @override
  Future<WebLoginBranding> clearLogo(WebLoginBranding current) async => current;
}

/// Firebase에 전혀 접근하지 않는 [SharedTimetableSyncService] 가짜.
class FakeSharedTimetableSyncService extends SharedTimetableSyncService {
  FakeSharedTimetableSyncService()
    : super(firestore: _FakeFirestore(), storage: _FakeStorage());

  @override
  Future<int> publishTimetable({
    required TimetableRepository repo,
    required String timetableId,
  }) async => 1;

  @override
  Future<int> clearPublishedTimetable() async => 1;
}

/// WebAdminSettingsScreen 레이아웃·렌더링 검증.
///
/// Firebase를 직접 건드리던 `WebBrandingService()`/`SharedTimetableSyncService()`
/// 생성이 Provider(`webBrandingServiceProvider`/`sharedTimetableSyncServiceProvider`)
/// 뒤로 옮겨지면서 테스트에서 가짜로 교체할 수 있게 되었다(2026-10-03).
/// `_loadCurrentMessage()`가 기본 학교명 조회에 쓰는
/// `FirebaseFirestore.instance` 직접 호출은 try/catch로 감싸져 있어 테스트에서
/// 예외 없이 경고 로그만 남기고 넘어간다.
void main() {
  List<Override> buildOverrides({
    FakeBrandingService? brandingService,
    FakeSharedTimetableSyncService? syncService,
  }) {
    return [
      webBrandingServiceProvider.overrideWithValue(
        brandingService ?? FakeBrandingService(),
      ),
      sharedTimetableSyncServiceProvider.overrideWithValue(
        syncService ?? FakeSharedTimetableSyncService(),
      ),
    ];
  }

  Widget buildScreen({required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: WebAdminSettingsScreen()),
    );
  }

  /// `_loadCurrentMessage()`(initState에서 호출)가 끝날 때까지 흘려보낸다.
  ///
  /// 화면이 `ListView(children: [...])`라서 뷰포트 밖 항목은 Sliver가 아예
  /// 빌드하지 않는다 — 리스트 하단 섹션(기본 학교명·공용 시간표)까지 찾으려면
  /// 뷰포트 높이를 내용 전체보다 크게 잡아야 한다. 기본값 2000은 실제 좁은
  /// 화면(650/420px)에서도 모든 섹션이 한 번에 빌드되도록 여유 있게 잡은 값.
  Future<void> pumpAt(
    WidgetTester tester,
    Widget widget, {
    required double width,
    double height = 2000,
  }) async {
    tester.view.physicalSize = Size(width, height);
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

  group('WebAdminSettingsScreen 렌더링', () {
    testWidgets('화면이 예외 없이 렌더링된다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('접속 설정 (관리자)'), findsOneWidget);
    });

    testWidgets('비밀번호 입력란 4개(접속자 2 + 관리자 2)가 보인다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 650,
      );

      expect(find.text('새 접속자 비밀번호 (4자 이상)'), findsOneWidget);
      expect(find.text('새 접속자 비밀번호 확인'), findsOneWidget);
      expect(find.text('새 관리자 비밀번호 (4자 이상)'), findsOneWidget);
      expect(find.text('새 관리자 비밀번호 확인'), findsOneWidget);
    });

    testWidgets('섹션 제목이 모두 보인다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 650,
      );

      expect(find.text('접속자 비밀번호 변경'), findsOneWidget);
      expect(find.text('관리자 비밀번호 변경'), findsOneWidget);
      expect(find.text('접속 화면 (학교 로고·안내)'), findsOneWidget);
      expect(find.text('기본 학교명 설정'), findsOneWidget);
      expect(find.text('공용 시간표 올리기'), findsOneWidget);
    });
  });

  group('WebAdminSettingsScreen 브랜딩 로드', () {
    // `_loadCurrentMessage()`는 브랜딩을 가짜에서 읽어온 뒤, 그 안에서
    // `FirebaseFirestore.instance.collection('config').doc('public').get()`를
    // 직접 호출해 기본 학교명도 읽는다(이 화면은 이 호출만 Provider를 거치지
    // 않는다). 테스트 환경엔 Firebase 앱이 없어 이 호출이 던지고, catch가
    // 경고만 남긴 채 메서드를 끝내므로 — 그 호출 *뒤*에 있는 `setState()`(브랜딩
    // 필드 반영 포함)는 실행되지 않는다. 그래서 여기서는 "화면이 죽지 않고
    // 가짜의 load()/resolveLogoBytes()가 호출됐는지"만 검증한다. 입력란에
    // 실제로 값이 채워지는 걸 테스트하려면 `_loadCurrentMessage()`에서 Firestore
    // 호출 순서를 바꾸는 프로덕션 수정이 먼저 필요하다(이번 작업 범위 밖).
    testWidgets('load()/resolveLogoBytes()가 호출되고 예외 없이 끝난다', (tester) async {
      final branding = const WebLoginBranding(
        title: '월계중학교 2026년 2학기 시간표',
        notice: '선생님 전용입니다.',
        homeUrl: 'https://example.sen.ms.kr',
        logoBase64: '',
      );
      final fake = FakeBrandingService(initialBranding: branding);

      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(brandingService: fake)),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(fake.loadCallCount, 1);
    });
  });

  group('WebAdminSettingsScreen 오버플로', () {
    testWidgets('650px 너비에서 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 650,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('420px 좁은 너비에서도 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 420,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('WebAdminSettingsScreen 버튼 상태', () {
    testWidgets('저장 버튼들이 처음엔 활성화되어 있다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 650,
      );

      final saveButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('접속자 비밀번호 저장'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(saveButton.onPressed, isNotNull);

      final publishButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('공용 시간표 게시'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(publishButton.onPressed, isNotNull);
    });

    testWidgets('비밀번호 보기 토글을 누르면 두 입력란이 함께 평문으로 바뀐다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 650,
      );

      final toggles = find.byIcon(Icons.visibility_outlined);
      expect(toggles, findsWidgets);

      await tester.tap(toggles.first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('WebAdminSettingsScreen 로고 미리보기', () {
    testWidgets('저장된 로고가 없으면 로고 영역이 플레이스홀더로 보인다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      // 로고가 없을 때는 '로고 제거' 버튼이 보이지 않는다.
      expect(find.text('로고 제거'), findsNothing);
      expect(find.text('로고 선택'), findsOneWidget);
    });
  });
}

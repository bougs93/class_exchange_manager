import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/firebase_app_config.dart';
import '../services/shared_timetable_sync_service.dart';
import '../services/usage_stats_service.dart';
import '../services/web_branding_service.dart';
import 'timetable_registry_provider.dart';

/// 웹 전용 서비스 Provider 모음.
///
/// ## 왜 Provider로 빼는가 (2026-10-03)
///
/// 예전에는 화면이 `final _brandingService = WebBrandingService();`처럼 **State
/// 필드 초기화자**에서 직접 생성했다. 그런데 [WebBrandingService]의 생성자는
/// 기본값으로 `FirebaseFirestore.instance` / `FirebaseStorage.instance`를
/// 평가한다 — 즉 **State 객체가 만들어지는 순간, `initState`보다도 먼저,
/// 어떤 try/catch 밖에서** Firebase에 접근한다.
///
/// 그 결과 위젯 테스트에서 화면을 띄우기만 해도 `FirebaseException
/// [core/no-app]`로 즉시 터졌고, 가짜를 끼워 넣을 틈이 없어 **접속 설정 화면은
/// 테스트를 단 하나도 쓸 수 없었다.** Provider를 거치면 테스트가
/// `overrideWithValue(...)`로 가짜를 넣을 수 있다.
///
/// 생성은 **지연**된다 — 실제로 `ref.read`를 하기 전까지 Firebase를 건드리지
/// 않으므로, 화면을 띄우는 것만으로는 터지지 않는다.
final webBrandingServiceProvider = Provider<WebBrandingService>((ref) {
  return WebBrandingService();
});

/// 공용 시간표 게시·삭제 서비스 Provider.
///
/// 같은 이유로 Provider를 거친다. 호출부가 `SharedTimetableSyncService()`를
/// 직접 만들면 테스트에서 실제 Firebase를 때리게 된다.
final sharedTimetableSyncServiceProvider = Provider<SharedTimetableSyncService>(
  (ref) {
    return SharedTimetableSyncService();
  },
);

/// 웹 사용 통계 수집·조회 서비스 Provider.
///
/// 같은 이유로 **지연 생성**한다. 비웹이거나 Firebase 설정이 없으면 아무 것도
/// 하지 않는 no-op 서비스를 돌려주므로 데스크톱 빌드·테스트는 Firebase를
/// 건드리지 않는다. 브라우저 탭이 숨겨질 때(앱 수명주기 hidden/paused) 남은
/// 버퍼를 즉시 쓴다.
final usageStatsServiceProvider = Provider<UsageStatsService>((ref) {
  if (!kIsWeb || !FirebaseAppConfig.isConfigured) {
    return UsageStatsService.disabled();
  }
  final service = UsageStatsService(
    enabled: true,
    backend: FirestoreUsageBackend(),
    // 기록 시점에 읽는다 — 활성 시간표(교사)가 바뀌어도 그때 값을 쓴다.
    teacherName: () => ref.read(activeTeacherNameProvider),
    uid: currentFirebaseUid,
  );
  final observer = _UsageFlushObserver(service);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    service.dispose();
  });
  return service;
});

class _UsageFlushObserver with WidgetsBindingObserver {
  _UsageFlushObserver(this._service);
  final UsageStatsService _service;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _service.flush();
    }
  }
}

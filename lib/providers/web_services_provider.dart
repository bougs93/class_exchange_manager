import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/shared_timetable_sync_service.dart';
import '../services/web_branding_service.dart';

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

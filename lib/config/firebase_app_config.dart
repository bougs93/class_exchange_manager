import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase 연결 설정 (웹 전환 2단계)
///
/// 실제 값은 소스코드에 커밋하지 않고, 빌드 시 `--dart-define`으로 주입한다
/// (계획서 9장 5단계, CI Secret 연동 예정).
/// 값이 비어 있으면 Firebase를 초기화하지 않고, 웹에서는 접속 화면 진입
/// 전에 설정 누락 안내를 보여준다. PC/모바일은 Firebase를 쓰지 않는다.
///
/// 예: flutter build web --dart-define=FIREBASE_API_KEY=... ...
class FirebaseAppConfig {
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');

  /// 접속 흐름에서 서버 응답을 기다리는 최대 시간 (2026-10-03 사용자 확정: 3초).
  ///
  /// 접속 게이트에서 쓰는 Firebase 호출은 **전부** 이 값으로 끊는다. 예전에는
  /// 타임아웃이 아예 없어서, 서버가 응답하지 않으면 "서버 연결 준비 중"에서
  /// 무한정 멈춰 있었다. 공용 시간표·브랜딩·비밀번호 설정은 모두 "없으면
  /// 없는 대로 진행"할 수 있는 값이므로, 오래 기다리느니 로컬 캐시로 바로
  /// 들여보내는 쪽이 낫다.
  static const Duration networkTimeout = Duration(seconds: 3);

  /// 웹에서 Firebase를 쓸 준비가 됐는지 (필수 값 존재 여부).
  static bool get isConfigured {
    return apiKey.isNotEmpty &&
        projectId.isNotEmpty &&
        appId.isNotEmpty;
  }

  static FirebaseOptions get options => const FirebaseOptions(
    apiKey: apiKey,
    authDomain: authDomain,
    projectId: projectId,
    storageBucket: storageBucket,
    messagingSenderId: messagingSenderId,
    appId: appId,
  );

  /// Firebase 초기화 (웹 전용, 설정이 있을 때만).
  ///
  /// PC/모바일에서는 호출하지 않는다. 중복 호출 시 기존 앱을 재사용한다.
  static Future<void> ensureInitialized() async {
    if (!kIsWeb || !isConfigured) return;
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(options: options).timeout(networkTimeout);
  }
}

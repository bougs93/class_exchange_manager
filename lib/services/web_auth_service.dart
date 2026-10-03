import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/firebase_app_config.dart';
import '../config/master_credentials.dart';
import '../utils/logger.dart';

/// 비밀번호 확인 결과.
///
/// "틀렸다"와 "확인할 수 없었다"를 구분해야 안내 문구를 제대로 고를 수 있다.
enum WebPasswordResult {
  /// 비밀번호 일치.
  ok,

  /// 비밀번호 불일치.
  wrong,

  /// 서버 설정을 받지 못했거나(네트워크·타임아웃) 비밀번호가 미설정이다.
  unavailable,
}

/// 웹 전용 인증 서비스 (웹 전환 2단계, 계획서 4장)
///
/// - 접속자: 비밀번호 1개 (Firestore `config/auth`의 salted SHA-256 해시 비교)
/// - 관리자: 관리자 비밀번호 또는 마스터 ID+비밀번호
/// - 편의성 우선이 확정되어 있어, 통과 후 세션을 로컬에 저장해 재방문 시
///   자동 통과한다. 진짜 보안이 아니라 "사회적 장벽" 수준이다.
class WebAuthService {
  static const String _sessionViewerKey = 'webauth_viewer_ok';
  static const String _sessionAdminKey = 'webauth_admin_ok';

  /// salted SHA-256 해시 계산.
  static String hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt$password')).toString();
  }

  /// Firestore 규칙(`request.auth != null`) 만족용 익명 로그인.
  ///
  /// 이미 로그인돼 있으면 아무 일도 하지 않는다. 실패해도 예외를 던지지
  /// 않고 false에 해당하는 null auth 상태를 그대로 둔다 — 공개 문서
  /// (`config/public`) 조회는 비로그인으로도 가능해야 하기 때문이다.
  static Future<void> ensureAnonymousSignIn() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously().timeout(
          FirebaseAppConfig.networkTimeout,
        );
      }
    } catch (e) {
      AppLogger.warning('익명 로그인 실패 (공개 조회만 가능): $e');
    }
  }

  /// `config/auth` 문서 조회 (salt + 해시).
  static Future<Map<String, dynamic>?> loadAuthConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('auth')
          .get()
          .timeout(FirebaseAppConfig.networkTimeout);
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      AppLogger.warning('인증 설정 조회 실패: $e');
      return null;
    }
  }

  /// 접속자 비밀번호 확인.
  static Future<WebPasswordResult> verifyViewerPassword(String password) {
    return _verifyPassword(
      password,
      saltField: 'viewerSalt',
      hashField: 'viewerPasswordHash',
      label: '접속자',
    );
  }

  /// 관리자 비밀번호 확인.
  static Future<WebPasswordResult> verifyAdminPassword(String password) {
    return _verifyPassword(
      password,
      saltField: 'adminSalt',
      hashField: 'adminPasswordHash',
      label: '관리자',
    );
  }

  /// 비밀번호 대조 공통 로직.
  ///
  /// "설정을 못 받음"과 "비밀번호 틀림"을 반드시 구분한다. 예전에는 둘 다
  /// false였는데, 접속 흐름에 3초 타임아웃이 생기면서(2026-10-03) 네트워크가
  /// 느릴 때마다 **맞는 비밀번호에도 "비밀번호가 맞지 않습니다"**가 뜰 수
  /// 있게 됐다. 교사가 비밀번호를 의심하며 계속 다시 치게 만드는 안내다.
  static Future<WebPasswordResult> _verifyPassword(
    String password, {
    required String saltField,
    required String hashField,
    required String label,
  }) async {
    try {
      final config = await loadAuthConfig();
      if (config == null) return WebPasswordResult.unavailable;
      final salt = (config[saltField] ?? '') as String;
      final hash = (config[hashField] ?? '') as String;
      // 비밀번호가 아직 설정되지 않은 상태 — 틀린 게 아니라 못 쓰는 상태다.
      if (salt.isEmpty || hash.isEmpty) return WebPasswordResult.unavailable;
      return hashPassword(password, salt) == hash
          ? WebPasswordResult.ok
          : WebPasswordResult.wrong;
    } catch (e) {
      AppLogger.warning('$label 비밀번호 확인 실패: $e');
      return WebPasswordResult.unavailable;
    }
  }

  /// 마스터 ID + 비밀번호 확인 (관리자 비밀번호 분실 대비, 계획서 4.2절).
  static bool verifyMaster(String id, String password) {
    if (!MasterCredentials.isConfigured) return false;
    if (id != MasterCredentials.masterId) return false;
    final hash = sha256.convert(utf8.encode(password)).toString();
    return hash == MasterCredentials.masterPasswordHash;
  }

  /// 세션 저장 (통과 후 호출).
  static Future<void> saveSession({
    required bool viewer,
    bool admin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (viewer) await prefs.setBool(_sessionViewerKey, true);
    if (admin) {
      await prefs.setBool(_sessionViewerKey, true);
      await prefs.setBool(_sessionAdminKey, true);
    }
  }

  /// 저장된 세션 조회.
  static Future<({bool viewer, bool admin})> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      viewer: prefs.getBool(_sessionViewerKey) ?? false,
      admin: prefs.getBool(_sessionAdminKey) ?? false,
    );
  }

  /// 세션 삭제 (로그아웃).
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionViewerKey);
    await prefs.remove(_sessionAdminKey);
  }

  /// Firebase가 설정됐는지 (미설정 시 접속 화면에서 안내).
  static bool get isFirebaseConfigured => FirebaseAppConfig.isConfigured;
}

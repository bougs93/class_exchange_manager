import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/firebase_app_config.dart';
import '../config/master_credentials.dart';
import '../utils/logger.dart';

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
        await auth.signInAnonymously();
      }
    } catch (e) {
      AppLogger.warning('익명 로그인 실패 (공개 조회만 가능): $e');
    }
  }

  /// `config/auth` 문서 조회 (salt + 해시).
  static Future<Map<String, dynamic>?> loadAuthConfig() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('config')
              .doc('auth')
              .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      AppLogger.warning('인증 설정 조회 실패: $e');
      return null;
    }
  }

  /// 접속자 비밀번호 확인.
  static Future<bool> verifyViewerPassword(String password) async {
    try {
      final config = await loadAuthConfig();
      if (config == null) return false;
      final salt = (config['viewerSalt'] ?? '') as String;
      final hash = (config['viewerPasswordHash'] ?? '') as String;
      if (salt.isEmpty || hash.isEmpty) return false;
      return hashPassword(password, salt) == hash;
    } catch (e) {
      AppLogger.warning('접속자 비밀번호 확인 실패: $e');
      return false;
    }
  }

  /// 관리자 비밀번호 확인.
  static Future<bool> verifyAdminPassword(String password) async {
    try {
      final config = await loadAuthConfig();
      if (config == null) return false;
      final salt = (config['adminSalt'] ?? '') as String;
      final hash = (config['adminPasswordHash'] ?? '') as String;
      if (salt.isEmpty || hash.isEmpty) return false;
      return hashPassword(password, salt) == hash;
    } catch (e) {
      AppLogger.warning('관리자 비밀번호 확인 실패: $e');
      return false;
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

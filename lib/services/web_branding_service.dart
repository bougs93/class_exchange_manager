import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../config/firebase_app_config.dart';
import '../models/web_login_branding.dart';
import '../utils/logger.dart';
import 'web_auth_service.dart';

/// 웹 접속 화면 학교 브랜딩(로고·홈페이지·안내) 저장/조회.
class WebBrandingService {
  WebBrandingService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  /// 공용 시간표와 같은 Storage 규칙을 쓰는 경로.
  static const String storagePath = 'shared_timetable/school_logo';
  static const int maxLogoBytes = 2 * 1024 * 1024;

  /// Firestore 문서(1MB) 여유를 남겨 두고 base64로 같이 저장하는 상한.
  static const int maxLogoBase64Bytes = 400 * 1024;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> get _publicDoc =>
      _firestore.collection('config').doc('public');

  /// 공개 설정에서 브랜딩을 읽는다 (로그인 전에도 가능).
  Future<WebLoginBranding> load() async {
    try {
      final doc = await _publicDoc.get().timeout(
        FirebaseAppConfig.networkTimeout,
      );
      return WebLoginBranding.fromMap(doc.data());
    } catch (e) {
      AppLogger.warning('학교 브랜딩 조회 실패: $e');
      return const WebLoginBranding();
    }
  }

  /// 로고 바이트를 가져온다. base64 → Storage getData → HTTP URL 순.
  Future<Uint8List?> resolveLogoBytes(WebLoginBranding branding) async {
    final embedded = branding.logoBytes;
    if (embedded != null && embedded.isNotEmpty) return embedded;
    return downloadLogoBytes(logoUrl: branding.logoUrl);
  }

  /// Storage/URL에서 로고 바이트를 받는다.
  Future<Uint8List?> downloadLogoBytes({String? logoUrl}) async {
    try {
      final data = await _storage
          .ref(storagePath)
          .getData(maxLogoBytes)
          .timeout(FirebaseAppConfig.networkTimeout);
      if (data != null && data.isNotEmpty) return data;
    } catch (e) {
      AppLogger.warning('학교 로고 getData 실패: $e');
    }

    final url = logoUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(FirebaseAppConfig.networkTimeout);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      AppLogger.warning(
        '학교 로고 HTTP 실패: HTTP ${response.statusCode}',
      );
    } catch (e) {
      AppLogger.warning('학교 로고 HTTP 다운로드 실패: $e');
    }
    return null;
  }

  /// 제목·안내·홈페이지 URL·로고 메타를 저장한다.
  Future<void> saveBranding(WebLoginBranding branding) async {
    await WebAuthService.ensureAnonymousSignIn();
    await _publicDoc.set(branding.toPublicFields(), SetOptions(merge: true));
  }

  /// 로고 이미지를 Storage(+가능하면 base64)에 올리고 공개 문서를 갱신한다.
  Future<WebLoginBranding> uploadLogo({
    required Uint8List bytes,
    required String contentType,
    required WebLoginBranding current,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('로고 파일이 비어 있습니다.');
    }
    if (bytes.length > maxLogoBytes) {
      throw StateError('로고는 2MB 이하만 올릴 수 있습니다.');
    }
    await WebAuthService.ensureAnonymousSignIn();
    final type =
        contentType.startsWith('image/') ? contentType : 'image/png';
    try {
      await _storage
          .ref(storagePath)
          .putData(bytes, SettableMetadata(contentType: type));
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized') {
        throw StateError(
          'Storage 업로드 권한이 없습니다. '
          'Firebase 익명 로그인·Storage 규칙을 확인하세요.',
        );
      }
      rethrow;
    }
    final url = await _storage.ref(storagePath).getDownloadURL();
    // 웹 표시용 — Storage URL 이미지 로딩이 막혀도 Firestore만으로 보이게.
    final embedded =
        bytes.length <= maxLogoBase64Bytes ? base64Encode(bytes) : '';
    if (embedded.isEmpty) {
      AppLogger.warning(
        '로고가 ${bytes.length}B라 base64 생략(상한 ${maxLogoBase64Bytes}B). '
        'Storage 다운로드로 표시합니다.',
      );
    }
    final updated = current.copyWith(
      logoUrl: url,
      logoBase64: embedded,
      logoUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await saveBranding(updated);
    return updated;
  }

  /// Storage 로고와 공개 문서의 로고 필드를 지운다.
  Future<WebLoginBranding> clearLogo(WebLoginBranding current) async {
    await WebAuthService.ensureAnonymousSignIn();
    try {
      await _storage.ref(storagePath).delete();
    } catch (e) {
      AppLogger.warning('학교 로고 Storage 삭제 무시: $e');
    }
    final updated = current.copyWith(
      logoUrl: '',
      logoBase64: '',
      logoUpdatedAt: 0,
    );
    await saveBranding(updated);
    return updated;
  }
}

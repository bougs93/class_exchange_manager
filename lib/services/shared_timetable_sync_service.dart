import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lesson.dart';
import '../models/dated_timetable.dart';
import 'shared_timetable_installer.dart';
import '../repositories/timetable_repository.dart';
import '../utils/logger.dart';

/// 공용 시간표 동기화 결과.
enum SharedTimetableSyncStatus {
  /// 최신 상태라 다운로드 생략.
  upToDate,

  /// 다운로드 후 로컬 DB 반영 완료.
  downloaded,
}

/// 공용 시간표 동기화 서비스 (웹 전환 3단계, 계획서 3.2·3.3절).
///
/// - 전송 포맷은 SQLite 파일이 아니라 JSON이다. 받는 쪽은 이미 열려 있는
///   로컬 SQLite의 별도 `shared_lessons` 테이블에 표준 insert로 반영한다.
/// - 버전 증가 → JSON 업로드 순서로 진행한다 (업로드 실패 시 클라이언트가
///   재확인하는 쪽이 구버전 고착보다 안전).
/// - Firebase가 필요한 `publishTimetable`/`syncSharedTimetable`은 통합
///   테스트 대상이 아니며, 순수 로직(`encode/decode/shouldDownload`)만
///   단위 테스트한다.
class SharedTimetableSyncService {
  /// Storage 저장 경로 (공용 시간표 JSON).
  static const String storagePath = 'shared_timetable/timetable.json';

  /// 로컬에 캐시된 공용 시간표 버전 (SharedPreferences).
  static const String localVersionKey = 'shared_timetable_version';

  /// 다운로드 최대 크기 (20MB).
  static const int maxDownloadBytes = 20 * 1024 * 1024;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  SharedTimetableSyncService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _versionDoc =>
      _firestore.collection('config').doc('sharedTimetable');

  /// 수업 목록 → JSON 문자열 (`Lesson.toMap` 재사용).
  static String encodeLessons(List<Lesson> lessons) {
    return jsonEncode(lessons.map((e) => e.toMap()).toList());
  }

  /// JSON 문자열 → 수업 목록 (`Lesson.fromMap` 재사용).
  static List<Lesson> decodeLessons(String jsonString) {
    final decoded = jsonDecode(jsonString) as List;
    return decoded
        .map((e) => Lesson.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
  }

  /// 다운로드 조건 (계획서 3.3절): 캐시가 없거나 버전이 다르면 다운로드.
  static bool shouldDownload({
    required int? localVersion,
    required int remoteVersion,
  }) {
    if (localVersion == null) return true;
    return localVersion != remoteVersion;
  }

  /// 버전을 1 올리고 새 버전을 반환한다.
  ///
  /// [rawBytes]는 **압축 전** JSON 크기다. 받는 쪽이 진행률 막대를 그릴 때
  /// 쓴다 — gzip으로 올리면 HTTP의 `content-length`는 압축된 크기라서
  /// 브라우저가 풀어 주는 바이트 수와 단위가 맞지 않는다.
  Future<int> _bumpVersion({DatedTimetable? timetable, int? rawBytes}) {
    return _firestore.runTransaction((txn) async {
      final snap = await txn.get(_versionDoc);
      final current = (snap.data()?['version'] as int?) ?? 0;
      final next = current + 1;
      txn.set(_versionDoc, {
        'version': next,
        'bytes': rawBytes,
        'timetable':
            timetable == null
                ? null
                : (timetable.toMap()..remove('teacher_name')),
      }, SetOptions(merge: true));
      return next;
    });
  }

  /// Storage에 JSON을 **gzip으로 압축해서** 올린다.
  ///
  /// 수업 JSON은 같은 필드 이름이 수만 번 반복돼 압축률이 매우 높다.
  /// 실측에서 9.49MB를 받는 데 2.79초가 걸렸는데(2026-10-02), 첫 접속 지연의
  /// 가장 큰 몫이었다.
  ///
  /// `contentEncoding: gzip`을 붙여 두면 받는 쪽은 아무것도 바꿀 필요가 없다 —
  /// 브라우저가 HTTP 단계에서 알아서 풀어 주고, `Accept-Encoding: gzip`을
  /// 보내지 않는 클라이언트에게는 GCS가 서버에서 풀어 보낸다. 압축 이전에
  /// 올려 둔 파일도 그대로 읽힌다.
  ///
  /// `dart:io`의 gzip은 웹에서 쓸 수 없어 순수 Dart인 `archive`를 쓴다
  /// (관리자도 웹에서 업로드한다).
  ///
  /// 버전은 이미 증가한 뒤이므로 실패를 그대로 전달한다.
  Future<void> _uploadJson(String jsonString, int version) async {
    try {
      final raw = utf8.encode(jsonString);
      final compressed = Uint8List.fromList(GZipEncoder().encode(raw)!);
      AppLogger.info(
        '공용 시간표 압축: ${raw.length}B → ${compressed.length}B '
        '(${(compressed.length / raw.length * 100).toStringAsFixed(1)}%)',
      );
      await _storage
          .ref(storagePath)
          .putData(
            compressed,
            SettableMetadata(
              contentType: 'application/json',
              contentEncoding: 'gzip',
            ),
          );
    } catch (e) {
      AppLogger.error('공용 시간표 업로드 실패 (버전 $version은 이미 증가됨): $e', e);
      rethrow;
    }
  }

  /// 공용 시간표 JSON 내려받기
  ///
  /// `Reference.getData()`를 쓰지 않는다. 웹 구현은 내부적으로
  /// **메타데이터 조회 → 다운로드 URL 조회 → 실제 다운로드**로 왕복을 세 번
  /// 하는데, 실측에서 앞의 두 번만 약 0.96초를 썼다(2026-10-02).
  /// 크기 제한은 내려받은 뒤 바이트 수로 확인하면 충분하므로 왕복을 한 번 줄인다.
  ///
  /// 받는 동안 [onReceived]로 지금까지 받은 바이트 수를 알린다. `http` 1.5의
  /// 웹 구현은 `fetch` + `ReadableStream`이라 조각 단위로 흘러오므로 진행률
  /// 막대를 실제 수신량에 맞춰 그릴 수 있다.
  Future<Uint8List> _downloadJsonBytes({
    void Function(int receivedBytes)? onReceived,
  }) async {
    final url = await _storage.ref(storagePath).getDownloadURL();
    final client = http.Client();
    try {
      final response = await client.send(
        http.Request('GET', Uri.parse(url)),
      );
      if (response.statusCode != 200) {
        throw StateError('공용 시간표 다운로드 실패: HTTP ${response.statusCode}');
      }

      final chunks = <List<int>>[];
      var received = 0;
      await for (final chunk in response.stream) {
        chunks.add(chunk);
        received += chunk.length;
        if (received > maxDownloadBytes) {
          throw StateError(
            '공용 시간표가 너무 큽니다: ${received}B 초과 (최대 ${maxDownloadBytes}B)',
          );
        }
        onReceived?.call(received);
      }

      final bytes = Uint8List(received);
      var offset = 0;
      for (final chunk in chunks) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      return bytes;
    } finally {
      client.close();
    }
  }

  /// [_downloadJsonBytes]를 짧은 간격으로 최대 3번 시도한다.
  ///
  /// 관리자가 막 게시를 끝낸 직후 접속하면 "Failed to fetch"로 다운로드가
  /// 실패하는 경우가 실제로 보고됐다(2026-10-02) — 원인 문구만 보면
  /// CORS 미설정과 똑같지만, 버킷 CORS는 이미 적용·확인됐고 매번 재현되는
  /// 것도 아니라 CORS 자체의 문제는 아니다. `_bumpVersion()`(Firestore 버전
  /// 증가)이 `_uploadJson()`(Storage 업로드)보다 먼저 끝나므로, 그 틈에
  /// 들어온 클라이언트는 "새 버전이 있다"는 걸 알면서도 아직 완전히
  /// 준비되지 않은 객체를 내려받으려다 생기는 일시적 경합으로 보인다.
  /// 몇 초 안에 안정되므로 가볍게 재시도로 흡수한다. 그래도 실패하면
  /// 기존처럼 오류 화면의 [다시 시도] 버튼으로 넘어간다.
  Future<Uint8List> _downloadJsonBytesWithRetry({
    void Function(int receivedBytes)? onReceived,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _downloadJsonBytes(onReceived: onReceived);
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        AppLogger.warning(
          '공용 시간표 다운로드 재시도 ($attempt/$maxAttempts): $e',
        );
        await Future.delayed(Duration(milliseconds: 600 * attempt));
      }
    }
    // 위 루프는 반드시 return 또는 rethrow로 끝나지만, 컴파일러를 위해 둔다.
    throw StateError('공용 시간표 다운로드 재시도 로직 오류');
  }

  /// 공용 시간표 게시 (관리자용).
  ///
  /// [timetableId] 시간표의 전체 수업을 JSON으로 Storage에 올리고,
  /// 그 전에 버전부터 증가시킨다. 반환값은 새 버전이다.
  Future<int> publishTimetable({
    required TimetableRepository repo,
    required String timetableId,
  }) async {
    final lessons = await repo.getAllLessons(timetableId);
    final metadata = await repo.getTimetable(timetableId);
    final jsonString = encodeLessons(lessons);
    // 압축 전 크기를 버전 문서에 함께 적어 둔다 — 받는 쪽 진행률 계산용.
    final newVersion = await _bumpVersion(
      timetable: metadata,
      rawBytes: utf8.encode(jsonString).length,
    );
    await _uploadJson(jsonString, newVersion);
    AppLogger.info('공용 시간표 게시 완료: 버전 $newVersion, ${lessons.length}건');
    return newVersion;
  }

  /// 서버의 공용 시간표를 비운다.
  ///
  /// 버전을 올린 뒤 빈 목록을 올린다. 접속자는 다음 동기화에서 빈 시간표를 받는다.
  Future<int> clearPublishedTimetable() async {
    final newVersion = await _bumpVersion(rawBytes: 2); // '[]'
    await _uploadJson('[]', newVersion);
    AppLogger.info('공용 시간표 삭제 완료: 버전 $newVersion');
    return newVersion;
  }

  /// 공용 시간표 동기화 (웹 클라이언트용).
  ///
  /// 로컬 캐시가 없거나 버전이 다르면 다운로드 후 로컬 DB에 반영하고,
  /// 최신이면 다운로드을 생략한다.
  Future<({SharedTimetableSyncStatus status, int version, int count})>
  syncSharedTimetable({
    required TimetableRepository repo,
    void Function(String stage)? onStage,
    void Function(double? progress)? onDownloadProgress,
  }) async {
    onStage?.call('브라우저 저장 정보 읽기');
    final prefs = await SharedPreferences.getInstance();
    final localVersion = prefs.getInt(localVersionKey);

    onStage?.call('서버 시간표 정보 조회');
    final remoteSnap = await _versionDoc.get();
    final remoteVersion = (remoteSnap.data()?['version'] as int?) ?? 0;
    if (!remoteSnap.exists) {
      return (status: SharedTimetableSyncStatus.upToDate, version: 0, count: 0);
    }
    final installer = SharedTimetableInstaller();

    onStage?.call('저장된 시간표 확인');
    final hasCache =
        localVersion != null && await installer.isReady(remoteVersion, repo);
    if (hasCache &&
        !shouldDownload(
          localVersion: localVersion,
          remoteVersion: remoteVersion,
        )) {
      return (
        status: SharedTimetableSyncStatus.upToDate,
        version: remoteVersion,
        count: 0,
      );
    }

    onStage?.call('공용 시간표 다운로드');
    // 게시할 때 적어 둔 **압축 전** 크기. 예전 업로드에는 없을 수 있고,
    // 그때는 진행률을 알 수 없으므로 막대를 비확정으로 둔다.
    final expectedBytes = (remoteSnap.data()?['bytes'] as num?)?.toInt();
    onDownloadProgress?.call(expectedBytes == null ? null : 0);
    final data = await _downloadJsonBytesWithRetry(
      onReceived:
          expectedBytes == null || expectedBytes <= 0
              ? null
              : (received) => onDownloadProgress?.call(
                (received / expectedBytes).clamp(0.0, 1.0),
              ),
    );
    onDownloadProgress?.call(null);
    if (data.isEmpty) {
      throw StateError('공용 시간표 다운로드 결과가 비어 있습니다.');
    }
    onStage?.call('공용 시간표 데이터 읽기');
    final lessons = decodeLessons(utf8.decode(data));
    final metadata = remoteSnap.data()?['timetable'];
    final timetableMetadata =
        metadata is Map
            ? DatedTimetable.fromMap(Map<String, Object?>.from(metadata))
            : null;
    onStage?.call('브라우저에 시간표 저장');
    // `install`이 수업 전체를 `lessons`·`lesson_snapshots`에 넣는다.
    //
    // 예전에는 여기서 `repo.replaceSharedLessons(lessons)`로 `shared_lessons`
    // 테이블에도 같은 수업을 한 벌 더 적었는데, 그 테이블을 읽는 코드가 앱에는
    // 없다(테스트만 저장소 API를 직접 검증한다). 첫 접속 때 수업 수만큼의
    // insert를 한 번 더 치르는 순수한 낭비라 제거했다(2026-10-02).
    await installer.install(
      lessons: lessons,
      version: remoteVersion,
      repo: repo,
      metadata: timetableMetadata,
    );
    onStage?.call('동기화 완료 정보 저장');
    await prefs.setInt(localVersionKey, remoteVersion);

    AppLogger.info('공용 시간표 동기화 완료: 버전 $remoteVersion, ${lessons.length}건');
    return (
      status: SharedTimetableSyncStatus.downloaded,
      version: remoteVersion,
      count: lessons.length,
    );
  }
}

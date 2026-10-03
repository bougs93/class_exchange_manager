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

/// Firestore `config/sharedTimetable` 메타 (Storage 없이 유무·변경 판정용).
class SharedTimetableRemoteMeta {
  final bool exists;
  final int version;
  final int? bytes;
  final int? lessonCount;
  final Map<String, Object?>? timetable;

  const SharedTimetableRemoteMeta({
    required this.exists,
    required this.version,
    this.bytes,
    this.lessonCount,
    this.timetable,
  });

  /// 공용 시간표가 없거나 비어 있음.
  bool get isEmpty => SharedTimetableSyncService.isRemoteEmpty(
    exists: exists,
    lessonCount: lessonCount,
    bytes: bytes,
  );
}

/// 공용 시간표 동기화 서비스 (웹 전환 3단계, 계획서 3.2·3.3절).
///
/// - 전송 포맷은 SQLite 파일이 아니라 JSON이다.
/// - 버전 증가 → JSON 업로드 순서로 진행한다.
/// - 접속 시에는 Firestore 메타를 먼저 보고, 없거나 변경 없으면 Storage/DB를
///   건너뛴다.
class SharedTimetableSyncService {
  /// Storage 저장 경로 (공용 시간표 JSON).
  static const String storagePath = 'shared_timetable/timetable.json';

  /// 로컬에 캐시된 공용 시간표 버전 (SharedPreferences).
  static const String localVersionKey = 'shared_timetable_version';

  /// 다운로드 최대 크기 (20MB).
  static const int maxDownloadBytes = 20 * 1024 * 1024;

  /// Firestore 버전 조회 타임아웃.
  static const Duration metaTimeout = Duration(seconds: 5);

  /// Storage 다운로드 전체 상한 (재시도 포함).
  static const Duration downloadTimeout = Duration(seconds: 60);

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

  /// 원격에 공용 시간표가 없는지 판정.
  ///
  /// - 문서 없음
  /// - `lessonCount == 0` (신규 게시/삭제 메타)
  /// - 구문서: `bytes == 2` (`[]` 압축 전 크기)
  static bool isRemoteEmpty({
    required bool exists,
    int? lessonCount,
    int? bytes,
  }) {
    if (!exists) return true;
    if (lessonCount != null) return lessonCount <= 0;
    // 예전 clearPublishedTimetable은 bytes: 2만 남겼다.
    if (bytes == 2) return true;
    return false;
  }

  /// Firestore 버전 문서만 읽는다 (Storage/DB 없음).
  Future<SharedTimetableRemoteMeta> fetchRemoteMeta() async {
    try {
      final snap = await _versionDoc.get().timeout(metaTimeout);
      if (!snap.exists) {
        return const SharedTimetableRemoteMeta(exists: false, version: 0);
      }
      final data = snap.data();
      final rawTimetable = data?['timetable'];
      return SharedTimetableRemoteMeta(
        exists: true,
        version: (data?['version'] as num?)?.toInt() ?? 0,
        bytes: (data?['bytes'] as num?)?.toInt(),
        lessonCount: (data?['lessonCount'] as num?)?.toInt(),
        timetable:
            rawTimetable is Map
                ? Map<String, Object?>.from(rawTimetable)
                : null,
      );
    } catch (e) {
      AppLogger.warning('공용 시간표 메타 조회 실패: $e');
      rethrow;
    }
  }

  /// 로컬 prefs 버전.
  Future<int?> loadLocalVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(localVersionKey);
  }

  /// Storage 다운로드 없이 바로 들어가도 되는지.
  ///
  /// true면 repo 열기·다운로드를 생략해도 된다.
  Future<bool> canSkipFullSync(SharedTimetableRemoteMeta meta) async {
    if (meta.isEmpty) return true;
    final localVersion = await loadLocalVersion();
    if (shouldDownload(
      localVersion: localVersion,
      remoteVersion: meta.version,
    )) {
      return false;
    }
    return SharedTimetableInstaller().hasTrustedCache(meta.version);
  }

  /// 버전을 1 올리고 새 버전을 반환한다.
  Future<int> _bumpVersion({
    DatedTimetable? timetable,
    int? rawBytes,
    int lessonCount = 0,
    bool clearTimetable = false,
  }) {
    return _firestore.runTransaction((txn) async {
      final snap = await txn.get(_versionDoc);
      final current = (snap.data()?['version'] as int?) ?? 0;
      final next = current + 1;
      final data = <String, dynamic>{
        'version': next,
        'bytes': rawBytes,
        'lessonCount': lessonCount,
      };
      if (clearTimetable) {
        data['timetable'] = FieldValue.delete();
      } else if (timetable != null) {
        data['timetable'] = timetable.toMap()..remove('teacher_name');
      }
      txn.set(_versionDoc, data, SetOptions(merge: true));
      return next;
    });
  }

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

  Future<Uint8List> _downloadJsonBytesWithRetry({
    void Function(int receivedBytes)? onReceived,
  }) async {
    const maxAttempts = 3;
    final started = DateTime.now();
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final remaining = downloadTimeout - DateTime.now().difference(started);
      if (remaining.isNegative || remaining == Duration.zero) {
        throw StateError('공용 시간표 다운로드 시간 초과');
      }
      try {
        return await _downloadJsonBytes(
          onReceived: onReceived,
        ).timeout(remaining);
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        AppLogger.warning(
          '공용 시간표 다운로드 재시도 ($attempt/$maxAttempts): $e',
        );
        await Future.delayed(Duration(milliseconds: 600 * attempt));
      }
    }
    throw StateError('공용 시간표 다운로드 재시도 로직 오류');
  }

  /// 공용 시간표 게시 (관리자용).
  Future<int> publishTimetable({
    required TimetableRepository repo,
    required String timetableId,
  }) async {
    final lessons = await repo.getAllLessons(timetableId);
    final metadata = await repo.getTimetable(timetableId);
    final jsonString = encodeLessons(lessons);
    final newVersion = await _bumpVersion(
      timetable: metadata,
      rawBytes: utf8.encode(jsonString).length,
      lessonCount: lessons.length,
    );
    await _uploadJson(jsonString, newVersion);
    AppLogger.info('공용 시간표 게시 완료: 버전 $newVersion, ${lessons.length}건');
    return newVersion;
  }

  /// 서버의 공용 시간표를 비운다.
  Future<int> clearPublishedTimetable() async {
    final newVersion = await _bumpVersion(
      rawBytes: 2, // '[]'
      lessonCount: 0,
      clearTimetable: true,
    );
    await _uploadJson('[]', newVersion);
    AppLogger.info('공용 시간표 삭제 완료: 버전 $newVersion');
    return newVersion;
  }

  /// 공용 시간표 동기화 (웹 클라이언트용).
  ///
  /// [prefetchedMeta]가 있으면 Firestore를 다시 읽지 않는다.
  Future<({SharedTimetableSyncStatus status, int version, int count})>
  syncSharedTimetable({
    required TimetableRepository repo,
    SharedTimetableRemoteMeta? prefetchedMeta,
    void Function(String stage)? onStage,
    void Function(double? progress)? onDownloadProgress,
  }) async {
    onStage?.call('브라우저 저장 정보 읽기');
    final prefs = await SharedPreferences.getInstance();
    final localVersion = prefs.getInt(localVersionKey);
    final installer = SharedTimetableInstaller();

    onStage?.call('서버 시간표 정보 조회');
    final meta = prefetchedMeta ?? await fetchRemoteMeta();
    final remoteVersion = meta.version;

    if (meta.isEmpty) {
      onStage?.call('공용 시간표 없음');
      // 문서가 아예 없으면 로컬 정리도 최소로 끝낸다.
      if (!meta.exists) {
        return (
          status: SharedTimetableSyncStatus.upToDate,
          version: 0,
          count: 0,
        );
      }
      // 빈 목록으로 게시·삭제된 경우: Storage 없이 로컬만 비운다.
      if (localVersion != remoteVersion ||
          !await installer.hasTrustedCache(remoteVersion)) {
        onStage?.call('빈 시간표 반영');
        await installer.install(
          lessons: const [],
          version: remoteVersion,
          repo: repo,
        );
        await prefs.setInt(localVersionKey, remoteVersion);
        return (
          status: SharedTimetableSyncStatus.downloaded,
          version: remoteVersion,
          count: 0,
        );
      }
      return (
        status: SharedTimetableSyncStatus.upToDate,
        version: remoteVersion,
        count: 0,
      );
    }

    onStage?.call('저장된 시간표 확인');
    final trusted =
        localVersion != null && await installer.hasTrustedCache(remoteVersion);
    if (trusted &&
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

    // 버전은 같은데 trusted가 아니면 DB까지 확인 후, 깨졌을 때만 다시 받는다.
    if (!shouldDownload(
          localVersion: localVersion,
          remoteVersion: remoteVersion,
        ) &&
        await installer.isReady(remoteVersion, repo)) {
      return (
        status: SharedTimetableSyncStatus.upToDate,
        version: remoteVersion,
        count: 0,
      );
    }

    onStage?.call('공용 시간표 다운로드');
    final expectedBytes = meta.bytes;
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
    final timetableMetadata =
        meta.timetable == null
            ? null
            : DatedTimetable.fromMap(meta.timetable!);
    onStage?.call('브라우저에 시간표 저장');
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

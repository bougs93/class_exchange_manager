import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  Future<int> _bumpVersion({DatedTimetable? timetable}) {
    return _firestore.runTransaction((txn) async {
      final snap = await txn.get(_versionDoc);
      final current = (snap.data()?['version'] as int?) ?? 0;
      final next = current + 1;
      txn.set(_versionDoc, {
        'version': next,
        'timetable':
            timetable == null
                ? null
                : (timetable.toMap()..remove('teacher_name')),
      }, SetOptions(merge: true));
      return next;
    });
  }

  /// Storage에 JSON을 올린다. 버전은 이미 증가한 뒤이므로 실패를 그대로 전달한다.
  Future<void> _uploadJson(String jsonString, int version) async {
    try {
      await _storage
          .ref(storagePath)
          .putData(Uint8List.fromList(utf8.encode(jsonString)));
    } catch (e) {
      AppLogger.error('공용 시간표 업로드 실패 (버전 $version은 이미 증가됨): $e', e);
      rethrow;
    }
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
    final newVersion = await _bumpVersion(timetable: metadata);
    await _uploadJson(encodeLessons(lessons), newVersion);
    AppLogger.info('공용 시간표 게시 완료: 버전 $newVersion, ${lessons.length}건');
    return newVersion;
  }

  /// 서버의 공용 시간표를 비운다.
  ///
  /// 버전을 올린 뒤 빈 목록을 올린다. 접속자는 다음 동기화에서 빈 시간표를 받는다.
  Future<int> clearPublishedTimetable() async {
    final newVersion = await _bumpVersion();
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
    final data = await _storage.ref(storagePath).getData(maxDownloadBytes);
    if (data == null) {
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
    await installer.install(
      lessons: lessons,
      version: remoteVersion,
      repo: repo,
      metadata: timetableMetadata,
    );
    await repo.replaceSharedLessons(lessons);
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

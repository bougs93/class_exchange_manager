import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lesson.dart';
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
  static bool shouldDownload({required int? localVersion, required int remoteVersion}) {
    if (localVersion == null) return true;
    return localVersion != remoteVersion;
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
    final jsonString = encodeLessons(lessons);

    final newVersion = await _firestore.runTransaction((txn) async {
      final snap = await txn.get(_versionDoc);
      final current = (snap.data()?['version'] as int?) ?? 0;
      final next = current + 1;
      txn.set(_versionDoc, {'version': next}, SetOptions(merge: true));
      return next;
    });

    try {
      await _storage
          .ref(storagePath)
          .putData(Uint8List.fromList(utf8.encode(jsonString)));
    } catch (e) {
      AppLogger.error('공용 시간표 업로드 실패 (버전 $newVersion은 이미 증가됨): $e', e);
      rethrow;
    }

    AppLogger.info('공용 시간표 게시 완료: 버전 $newVersion, ${lessons.length}건');
    return newVersion;
  }

  /// 공용 시간표 동기화 (웹 클라이언트용).
  ///
  /// 로컬 캐시가 없거나 버전이 다르면 다운로드 후 로컬 DB에 반영하고,
  /// 최신이면 다운로드을 생략한다.
  Future<({SharedTimetableSyncStatus status, int version, int count})>
  syncSharedTimetable({required TimetableRepository repo}) async {
    final prefs = await SharedPreferences.getInstance();
    final localVersion = prefs.getInt(localVersionKey);

    final remoteSnap = await _versionDoc.get();
    final remoteVersion = (remoteSnap.data()?['version'] as int?) ?? 0;

    final hasCache =
        localVersion != null && await repo.getSharedLessonCount() > 0;
    if (hasCache &&
        !shouldDownload(localVersion: localVersion, remoteVersion: remoteVersion)) {
      return (status: SharedTimetableSyncStatus.upToDate, version: remoteVersion, count: 0);
    }

    final data = await _storage.ref(storagePath).getData(maxDownloadBytes);
    if (data == null) {
      throw StateError('공용 시간표 다운로드 결과가 비어 있습니다.');
    }
    final lessons = decodeLessons(utf8.decode(data));
    await repo.replaceSharedLessons(lessons);
    await prefs.setInt(localVersionKey, remoteVersion);

    AppLogger.info('공용 시간표 동기화 완료: 버전 $remoteVersion, ${lessons.length}건');
    return (
      status: SharedTimetableSyncStatus.downloaded,
      version: remoteVersion,
      count: lessons.length,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/lesson.dart';
import 'package:class_exchange_manager/repositories/timetable_repository.dart';
import 'package:class_exchange_manager/services/shared_timetable_sync_service.dart';

void main() {
  Lesson lesson({
    required String id,
    required String date,
    required int period,
    String teacher = '정원길',
  }) {
    final parts = date.split('-').map(int.parse).toList();
    return Lesson(
      id: id,
      timetableId: 'tt1',
      date: DateTime(parts[0], parts[1], parts[2]),
      period: period,
      teacher: teacher,
      subject: '기술가정',
      className: '3-7',
    );
  }

  group('SharedTimetableSyncService 순수 로직', () {
    test('encode → decode 왕복하면 내용이 같다', () {
      final lessons = [
        lesson(id: 'a', date: '2026-10-07', period: 2),
        lesson(id: 'b', date: '2026-10-06', period: 6, teacher: '정호성'),
      ];
      final json = SharedTimetableSyncService.encodeLessons(lessons);
      final restored = SharedTimetableSyncService.decodeLessons(json);
      expect(restored.length, 2);
      expect(restored[0].id, 'a');
      expect(restored[0].date, DateTime(2026, 10, 7));
      expect(restored[1].teacher, '정호성');
      expect(restored[1].subject, '기술가정');
    });

    test('shouldDownload — 캐시 없음/버전 다름이면 true, 같으면 false', () {
      expect(
        SharedTimetableSyncService.shouldDownload(
          localVersion: null,
          remoteVersion: 3,
        ),
        isTrue,
      );
      expect(
        SharedTimetableSyncService.shouldDownload(
          localVersion: 2,
          remoteVersion: 3,
        ),
        isTrue,
      );
      expect(
        SharedTimetableSyncService.shouldDownload(
          localVersion: 3,
          remoteVersion: 3,
        ),
        isFalse,
      );
    });
  });

  group('공용 시간표 로컬 반영 (shared_lessons)', () {
    late Database db;
    late TimetableRepository repo;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      db = await TimetableDatabase.open(path: inMemoryDatabasePath);
      repo = TimetableRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('테이블이 없으면 조회는 빈 목록·개수는 0', () async {
      expect(await repo.getSharedLessons(), isEmpty);
      expect(await repo.getSharedLessonCount(), 0);
    });

    test('replace하면 통째로 교체되고 날짜·교시 순으로 조회된다', () async {
      await repo.replaceSharedLessons([
        lesson(id: 'a', date: '2026-10-07', period: 2),
        lesson(id: 'b', date: '2026-10-06', period: 6),
      ]);
      expect(await repo.getSharedLessonCount(), 2);

      await repo.replaceSharedLessons([
        lesson(id: 'c', date: '2026-10-08', period: 1),
      ]);
      final rows = await repo.getSharedLessons();
      expect(rows.map((e) => e.id).toList(), ['c']);

      // 기존 lessons 테이블과 섞이지 않는다
      expect(await repo.getAllLessons('tt1'), isEmpty);
    });
  });
}

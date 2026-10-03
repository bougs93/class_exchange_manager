import 'package:sqflite_common/sqlite_api.dart';

import '../../models/lesson.dart';

/// 공용 시간표(`shared_lessons`) 전용 저장소.
///
/// 원래 `TimetableRepository`의 일부였던 메서드를 분리했다 — 별도
/// `shared_lessons` 테이블을 쓰므로 날짜 기반 시간표(`lessons`)와는 독립적인
/// 책임이다. `TimetableRepository`는 이 클래스에 위임하는 thin 메서드만
/// 유지한다.
class SharedLessonsRepository {
  final Database db;

  const SharedLessonsRepository(this.db);

  /// 공용 시간표 개수 조회 (동기화 시 로컬 캐시 유무 판단용).
  Future<int> getSharedLessonCount() async {
    if (!await _hasSharedLessonsTable()) return 0;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM shared_lessons');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// 공용 시간표를 통째로 교체한다 (웹 클라이언트 다운로드 반영용).
  ///
  /// 별도 `shared_lessons` 테이블을 쓰므로 기존 시간표 데이터와 섞이지
  /// 않는다. 테이블이 없으면 트랜잭션 안에서 먼저 만든다 (별도 마이그레이션
  /// 없이 `IF NOT EXISTS`로 처리 — 기존 스키마 버전에는 손대지 않는다).
  Future<void> replaceSharedLessons(List<Lesson> lessons) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS shared_lessons (
          id TEXT PRIMARY KEY,
          timetable_id TEXT NOT NULL,
          date TEXT NOT NULL,
          period INTEGER NOT NULL,
          teacher TEXT NOT NULL,
          subject TEXT,
          class_name TEXT,
          is_exchangeable INTEGER NOT NULL DEFAULT 1,
          exchange_reason TEXT,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await txn.delete('shared_lessons');
      final batch = txn.batch();
      for (final lesson in lessons) {
        batch.insert('shared_lessons', lesson.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  /// 공용 시간표 전체를 조회한다 (날짜·교시 순, 테이블이 없으면 빈 목록).
  Future<List<Lesson>> getSharedLessons() async {
    if (!await _hasSharedLessonsTable()) return const [];
    final rows = await db.query(
      'shared_lessons',
      orderBy: 'date ASC, period ASC',
    );
    return rows.map(Lesson.fromMap).toList();
  }

  Future<bool> _hasSharedLessonsTable() async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'shared_lessons'",
    );
    return rows.isNotEmpty;
  }
}

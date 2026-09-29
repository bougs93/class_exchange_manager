import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/dated_timetable.dart';
import '../models/lesson.dart';

/// 날짜 기반 시간표 SQLite 저장소 (S2)
///
/// 기존 JSON 저장(`TimetableStorageService` 등)과 병행하는 새 저장소다.
/// 이 단계에서는 어떤 화면도 이 클래스를 사용하지 않는다 — 저장소 계층만
/// 준비해 두고, 실제 연결은 이후 단계(등록 UI·조회 화면)에서 진행한다.
class TimetableRepository {
  final Database db;

  TimetableRepository(this.db);

  // ==================== 시간표(학기) ====================

  Future<void> insertTimetable(DatedTimetable timetable) async {
    await db.insert('timetables', timetable.toMap());
  }

  Future<DatedTimetable?> getTimetable(String id) async {
    final rows = await db.query(
      'timetables',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DatedTimetable.fromMap(rows.first);
  }

  Future<List<DatedTimetable>> getAllTimetables() async {
    final rows = await db.query('timetables', orderBy: 'registered_at ASC');
    return rows.map(DatedTimetable.fromMap).toList();
  }

  /// 시간표와 그 아래 모든 수업·스냅샷을 함께 삭제한다.
  ///
  /// 외래키 `ON DELETE CASCADE`에 의존하지 않고 명시적으로 지운다 — sqflite는
  /// 기본적으로 외래키 제약을 강제하지 않으므로(`PRAGMA foreign_keys` 별도
  /// 설정 필요), 플랫폼 설정에 의존하지 않는 편이 안전하다.
  Future<void> deleteTimetable(String timetableId) async {
    await db.transaction((txn) async {
      await txn.delete(
        'lessons',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
      );
      await txn.delete(
        'lesson_snapshots',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
      );
      await txn.delete(
        'timetables',
        where: 'id = ?',
        whereArgs: [timetableId],
      );
    });
  }

  // ==================== 수업(현재 배치) ====================

  /// 여러 수업을 한 트랜잭션으로 저장한다 (학기 전체 생성 시 대량 삽입용).
  Future<void> insertLessons(List<Lesson> lessons) async {
    if (lessons.isEmpty) return;
    final batch = db.batch();
    for (final lesson in lessons) {
      batch.insert('lessons', lesson.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// 최초 배치를 `lesson_snapshots`에 그대로 복제해 보존한다 (원본 비교 기준).
  Future<void> insertSnapshot(List<Lesson> lessons) async {
    if (lessons.isEmpty) return;
    final batch = db.batch();
    for (final lesson in lessons) {
      batch.insert('lesson_snapshots', lesson.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// 날짜 범위 안의 현재 배치를 조회한다 (양 끝 포함).
  Future<List<Lesson>> getLessonsForDateRange(
    String timetableId,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await db.query(
      'lessons',
      where: 'timetable_id = ? AND date >= ? AND date <= ?',
      whereArgs: [timetableId, _formatDate(start), _formatDate(end)],
      orderBy: 'date ASC, period ASC',
    );
    return rows.map(Lesson.fromMap).toList();
  }

  /// 특정 교사의 특정 날짜 수업만 조회한다 (개인 시간표·교체 검증용).
  Future<List<Lesson>> getLessonsForTeacherAndDate(
    String timetableId,
    String teacher,
    DateTime date,
  ) async {
    final rows = await db.query(
      'lessons',
      where: 'timetable_id = ? AND teacher = ? AND date = ?',
      whereArgs: [timetableId, teacher, _formatDate(date)],
      orderBy: 'period ASC',
    );
    return rows.map(Lesson.fromMap).toList();
  }

  /// 수업 하나를 갱신한다(교체 실행 시 사용 예정 — S5에서 실제로 연결).
  Future<void> updateLesson(Lesson lesson) async {
    await db.update(
      'lessons',
      lesson.toMap(),
      where: 'id = ?',
      whereArgs: [lesson.id],
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

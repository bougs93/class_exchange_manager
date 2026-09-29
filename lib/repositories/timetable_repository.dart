import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/dated_timetable.dart';
import '../models/exchange_event_record.dart';
import '../models/lesson.dart';
import '../models/school_semester.dart';
import '../utils/semester_date_generator.dart';

/// 학기 기간 반영([TimetableRepository.applyPeriodChange]) 결과 요약 (S3a).
///
/// "준비 > 기타 설정"의 반영 다이얼로그·완료 메시지에서 추가·보관 건수를
/// 보여주기 위한 값이다.
class PeriodChangeResult {
  /// 새로 생성된 날짜 수 (기간 확장)
  final int addedCount;

  /// 기간 밖으로 나가 비활성 처리된 날짜 수 (기간 축소, 삭제 아님 — 보관)
  final int deactivatedCount;

  /// 기간 안으로 다시 들어와 재활성화된 날짜 수 (축소 후 재확장)
  final int reactivatedCount;

  const PeriodChangeResult({
    required this.addedCount,
    required this.deactivatedCount,
    required this.reactivatedCount,
  });
}

/// 시간표 한 건의 SQLite 저장 현황 요약 (S4.0 — 읽기 전용 확인 패널).
///
/// S2·S3·S3a가 실제로 무엇을 저장했는지 사람이 직접 확인할 수 있게 하기 위한
/// 값이다. 집계 쿼리(`COUNT`/`MIN`/`MAX`)로만 구하며 행 전체를 메모리에
/// 올리지 않는다.
class LessonStats {
  final int totalCount;
  final int activeCount;
  final int inactiveCount;
  final int snapshotCount;
  final DateTime? earliestDate;
  final DateTime? latestDate;

  const LessonStats({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
    required this.snapshotCount,
    required this.earliestDate,
    required this.latestDate,
  });
}

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

  /// 시간표 한 건의 저장 현황 집계 (S4.0, 읽기 전용).
  ///
  /// 확인 패널에서 "실제로 몇 건이 저장됐는지"를 보여주기 위한 것으로, 검증·
  /// 화면 표시 로직에는 관여하지 않는다. 집계만 하므로 행 전체를 읽지 않는다.
  Future<LessonStats> getLessonStats(String timetableId) async {
    Future<int> count(String table, {String? extraWhere}) async {
      final where = StringBuffer('timetable_id = ?');
      if (extraWhere != null) where.write(' AND $extraWhere');
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $table WHERE $where',
        [timetableId],
      );
      return (rows.first['c'] as int?) ?? 0;
    }

    final totalCount = await count('lessons');
    final activeCount = await count('lessons', extraWhere: 'is_active = 1');
    final snapshotCount = await count('lesson_snapshots');

    final rangeRows = await db.rawQuery(
      'SELECT MIN(date) AS minDate, MAX(date) AS maxDate FROM lessons WHERE timetable_id = ?',
      [timetableId],
    );
    final minDateStr = rangeRows.isEmpty ? null : rangeRows.first['minDate'] as String?;
    final maxDateStr = rangeRows.isEmpty ? null : rangeRows.first['maxDate'] as String?;

    return LessonStats(
      totalCount: totalCount,
      activeCount: activeCount,
      inactiveCount: totalCount - activeCount,
      snapshotCount: snapshotCount,
      earliestDate: minDateStr == null ? null : DateTime.parse(minDateStr),
      latestDate: maxDateStr == null ? null : DateTime.parse(maxDateStr),
    );
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
        'exchange_events',
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
  ///
  /// 기본은 활성(`is_active = 1`) 수업만 반환한다 — 학기 기간 축소로 보관된
  /// 날짜는 제외된다(S3a). [includeInactive]를 true로 넘기면 보관분도 포함한다.
  Future<List<Lesson>> getLessonsForDateRange(
    String timetableId,
    DateTime start,
    DateTime end, {
    bool includeInactive = false,
  }) async {
    final where = StringBuffer('timetable_id = ? AND date >= ? AND date <= ?');
    final whereArgs = [timetableId, _formatDate(start), _formatDate(end)];
    if (!includeInactive) where.write(' AND is_active = 1');

    final rows = await db.query(
      'lessons',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'date ASC, period ASC',
    );
    return rows.map(Lesson.fromMap).toList();
  }

  /// 특정 교사의 특정 날짜 수업만 조회한다 (개인 시간표·교체 검증용).
  ///
  /// [getLessonsForDateRange]와 동일하게 기본은 활성 수업만 반환한다.
  Future<List<Lesson>> getLessonsForTeacherAndDate(
    String timetableId,
    String teacher,
    DateTime date, {
    bool includeInactive = false,
  }) async {
    final where = StringBuffer('timetable_id = ? AND teacher = ? AND date = ?');
    final whereArgs = [timetableId, teacher, _formatDate(date)];
    if (!includeInactive) where.write(' AND is_active = 1');

    final rows = await db.query(
      'lessons',
      where: where.toString(),
      whereArgs: whereArgs,
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

  // ==================== 학기 기간 반영 (S3a) ====================

  /// 시간표의 학기 범위를 [newSemester]로 바꾸고, 그에 맞춰 날짜별 수업을
  /// 늘리거나(보관분 재활성화 또는 새로 생성) 줄인다(삭제하지 않고 보관).
  ///
  /// - **확장**: 새로 포함되는 날짜는 `lesson_snapshots`에 이미 있는 같은
  ///   교사·같은 요일·같은 교시의 내용을 그대로 복사해 만든다(원본 엑셀을
  ///   다시 읽지 않는다 — 등록 시 생성한 스냅샷이 주간 템플릿 역할을 한다).
  ///   스냅샷은 등록 시점 그대로 유지하며 이 함수가 스냅샷을 늘리지 않는다.
  /// - **축소**: 범위 밖으로 나가는 날짜는 삭제하지 않고 `is_active = 0`으로
  ///   표시만 한다. 나중에 다시 확장하면 그 값을 재사용한다(재생성하지 않음).
  /// - 트랜잭션으로 처리한다 — 중간에 실패하면 이전 상태가 유지된다.
  ///
  /// 스냅샷에 아예 없는 요일(원래 그 요일에 수업이 하나도 없던 시간표)은
  /// 확장해도 새 수업을 만들 수 없다 — 만들 원본 내용이 없기 때문이다.
  Future<PeriodChangeResult> applyPeriodChange({
    required String timetableId,
    required SchoolSemester newSemester,
  }) async {
    return db.transaction((txn) async {
      final snapshotRows = await txn.query(
        'lesson_snapshots',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
      );
      final snapshots = snapshotRows.map(Lesson.fromMap).toList();

      // (교사, 요일) → 그 요일의 대표 내용(교시별로 여러 개일 수 있음)
      final templateByTeacherWeekday = <String, List<Lesson>>{};
      for (final snapshot in snapshots) {
        final key = '${snapshot.teacher}_${snapshot.date.weekday}';
        templateByTeacherWeekday.putIfAbsent(key, () => []).add(snapshot);
      }
      // 같은 (교사, 요일, 교시) 조합이 여러 번 나오면 하나만 대표로 쓴다.
      final templates = <Lesson>[];
      final seenTeacherWeekdayPeriod = <String>{};
      for (final list in templateByTeacherWeekday.values) {
        for (final lesson in list) {
          final key = '${lesson.teacher}_${lesson.date.weekday}_${lesson.period}';
          if (seenTeacherWeekdayPeriod.add(key)) templates.add(lesson);
        }
      }

      final currentRows = await txn.query(
        'lessons',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
      );
      final currentByKey = <String, Lesson>{
        for (final row in currentRows.map(Lesson.fromMap))
          '${row.teacher}_${_formatDate(row.date)}_${row.period}': row,
      };

      final keepKeys = <String>{};
      var addedCount = 0;
      var reactivatedCount = 0;

      final batch = txn.batch();

      for (final template in templates) {
        final dates = SemesterDateGenerator.datesForWeekday(
          newSemester,
          template.date.weekday,
        );
        for (final date in dates) {
          final key = '${template.teacher}_${_formatDate(date)}_${template.period}';
          keepKeys.add(key);

          final existing = currentByKey[key];
          if (existing == null) {
            batch.insert(
              'lessons',
              Lesson(
                id: Lesson.generateId(),
                timetableId: timetableId,
                date: date,
                period: template.period,
                teacher: template.teacher,
                subject: template.subject,
                className: template.className,
                isExchangeable: template.isExchangeable,
                exchangeReason: template.exchangeReason,
              ).toMap(),
            );
            addedCount++;
          } else if (!existing.isActive) {
            batch.update(
              'lessons',
              {'is_active': 1},
              where: 'id = ?',
              whereArgs: [existing.id],
            );
            reactivatedCount++;
          }
        }
      }

      var deactivatedCount = 0;
      for (final entry in currentByKey.entries) {
        if (keepKeys.contains(entry.key)) continue;
        if (!entry.value.isActive) continue; // 이미 보관 상태
        batch.update(
          'lessons',
          {'is_active': 0},
          where: 'id = ?',
          whereArgs: [entry.value.id],
        );
        deactivatedCount++;
      }

      batch.update(
        'timetables',
        {
          'school_year': newSemester.schoolYear,
          'semester': newSemester.semester,
          'start_date': _formatDate(newSemester.startDate),
          'end_date': _formatDate(newSemester.endDate),
        },
        where: 'id = ?',
        whereArgs: [timetableId],
      );

      await batch.commit(noResult: true);

      return PeriodChangeResult(
        addedCount: addedCount,
        deactivatedCount: deactivatedCount,
        reactivatedCount: reactivatedCount,
      );
    });
  }

  // ==================== 교체 이벤트 저널 (S5.0) ====================
  //
  // 이 절의 메서드들은 S5.0 시점에는 어떤 화면·서비스에서도 호출되지 않는다.
  // "언제 누가 무엇을 바꿨는가"만 기록하는 저널 CRUD이며, `lessons`(현재
  // 배치)에는 아무 영향을 주지 않는다 — S5 설계 검토서 §4 S5.0 참조.

  /// 한 시간표의 활성 교체 이벤트 전체를 upsert한다 (S5.1에서 사용 예정).
  ///
  /// 같은 `id`가 이미 있으면 덮어쓴다(`ConflictAlgorithm.replace`) — 기존
  /// JSON 저장(`ExchangeListStorageService`)이 "리스트 전체를 매번 다시
  /// 쓰기" 방식이라 멱등인 것과 동일한 성질을 유지하기 위해서다.
  Future<void> upsertExchangeEvents(List<ExchangeEventRecord> events) async {
    if (events.isEmpty) return;
    final batch = db.batch();
    for (final event in events) {
      batch.insert(
        'exchange_events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 시간표의 교체 이벤트를 [events]로 완전히 교체한다 (S5.1 미러 쓰기).
  ///
  /// 기존 JSON 저장(`ExchangeListStorageService`)의 "리스트 전체를 매번
  /// 다시 쓰기"와 같은 의미론을 한 트랜잭션으로 재현한다 — 삭제 후 삽입을
  /// 묶어서, 메모리에서 삭제된 교체 건(`removeFromExchangeList`)이 저널에
  /// 유령처럼 남지 않게 한다.
  Future<void> replaceExchangeEventsFor(
    String timetableId,
    List<ExchangeEventRecord> events,
  ) async {
    await db.transaction((txn) async {
      await txn.delete(
        'exchange_events',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
      );
      if (events.isEmpty) return;
      final batch = txn.batch();
      for (final event in events) {
        batch.insert('exchange_events', event.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  /// 한 시간표의 교체 이벤트를 적용 순서(`seq`)대로 조회한다.
  Future<List<ExchangeEventRecord>> getExchangeEvents(
    String timetableId,
  ) async {
    final rows = await db.query(
      'exchange_events',
      where: 'timetable_id = ?',
      whereArgs: [timetableId],
      orderBy: 'seq ASC',
    );
    return rows.map(ExchangeEventRecord.fromMap).toList();
  }

  /// 한 시간표의 교체 이벤트를 전부 지운다(시간표 삭제 시 [deleteTimetable]이
  /// 이미 처리하므로, 그 외에 저널만 초기화하고 싶을 때 사용).
  Future<void> deleteExchangeEventsFor(String timetableId) async {
    await db.delete(
      'exchange_events',
      where: 'timetable_id = ?',
      whereArgs: [timetableId],
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/dated_timetable.dart';
import '../models/exchange_event_record.dart';
import '../models/lesson.dart';
import '../models/school_semester.dart';
import '../models/time_slot.dart';
import '../services/exchange_event_mirror.dart';
import '../services/semester_timetable_generator.dart';
import '../utils/lesson_projection.dart';
import '../utils/semester_date_generator.dart';

/// `lessons` 좌표 한 칸(교사·날짜·교시) — [TimetableRepository.replayInto]가
/// "건드린 범위"를 계산할 때 쓰는 내부 레코드 타입.
typedef _CellCoord = ({String teacher, String date, int period});

/// 이 시간표의 `lessons`가 `exchange_events` 저널을 얼마나 최신으로
/// 반영하고 있는지 요약 (S5.5.0 — 조회 전환 준비).
///
/// `replayInto`가 매번 정확히 호출된다면 [isStale]은 항상 false여야 한다.
/// 다만 로드 경로(`ExchangeHistoryService.loadFromLocalStorage`가 SQLite를
/// 바로 쓸 때)는 `mirrorSink`를 거치지 않으므로 재생이 밀릴 수 있다 — S5.5
/// 설계 검토에서 발견한 실제 간극이다. 화면이 SQLite를 읽기 전에 반드시
/// 이 값을 확인해야 한다.
class ProjectionStatus {
  /// `timetables.projected_seq` — 마지막으로 반영이 끝난 시점의 최대 seq(-1=없음)
  final int projectedSeq;

  /// 현재 활성(`is_reverted=0`) 이벤트 중 최대 seq(-1=활성 이벤트 없음)
  final int maxActiveSeq;

  /// 이 시간표의 `lessons` 총 행 수
  final int lessonRowCount;

  /// `timetables`에 이 id로 등록된 행이 있는지 (S3 이전 등록 시간표는 없을 수 있음)
  final bool hasTimetableRow;

  const ProjectionStatus({
    required this.projectedSeq,
    required this.maxActiveSeq,
    required this.lessonRowCount,
    required this.hasTimetableRow,
  });

  /// 재생이 밀려 있는지 — 화면이 SQLite를 읽기 전 반드시 확인해야 하는 값.
  bool get isStale => projectedSeq != maxActiveSeq;
}

/// 학기 기간 반영이 활성 교체 이벤트와 충돌할 때 던진다 (S5.4a — D5/OQ-7).
///
/// 기간을 줄이면 그 활성 교체의 결강일·교체일 중 하나가 새 범위 밖으로
/// 나가버리는 경우다 — 이 경우만 **유일하게 차단**한다(다른 모든 안내는
/// 비차단이지만, 여기서는 사용자 데이터가 조용히 유실될 수 있어 예외다).
class PeriodChangeConflictException implements Exception {
  final List<String> conflictingDescriptions;

  const PeriodChangeConflictException(this.conflictingDescriptions);

  @override
  String toString() {
    return '학기 기간을 줄이면 활성 교체 ${conflictingDescriptions.length}건과 충돌합니다: '
        '${conflictingDescriptions.join(', ')}';
  }
}

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

  /// `replayInto`가 매번 `lesson_snapshots`를 통째로 다시 읽지 않도록 하는
  /// 인스턴스 단위 캐시 (S5.4a 성능 수정, 2026-09-29).
  ///
  /// 스냅샷은 시간표 등록 시점에 한 번만 만들어지고 이후 바뀌지 않으므로
  /// (계획서 §10.4), 같은 `TimetableRepository` 인스턴스가 살아있는 동안은
  /// 한 번만 읽어도 된다. 앱에서는 Provider가 인스턴스를 하나만 유지하므로
  /// 앱 실행 중 한 번만 채워진다. 테스트마다 새 인스턴스를 만들므로
  /// (인스턴스 필드라 static이 아님) 테스트 간 오염도 없다.
  final Map<String, Map<String, Lesson>> _templateCacheByTimetable = {};

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

  /// S3 이전에 등록된 시간표를 위한 최초 1회 지연 백필 (S5.5.4 회귀 체크리스트에서
  /// 발견한 문제의 근본 수정).
  ///
  /// [replayInto]는 `lesson_snapshots`(원본 스냅샷)가 있어야 교체된 칸의
  /// 과목명·학급명을 정확히 복원할 수 있다. S3 이전에 등록된 시간표는 이
  /// 스냅샷이 아예 없어서, 그런 시간표에서 SQLite 조회 경로([lessonReadPathEnabledProvider])를
  /// 켜고 교체를 실행하면 그 칸의 과목명이 `null`로 사라지는 회귀가 있었다
  /// (`resolved_timetable_provider_pre_s3_test.dart`로 재현됨).
  ///
  /// 이 메서드는 `timetables`에 이 id로 등록된 행이 아직 없으면, S3 등록
  /// 흐름(`timetable_file_screen.dart` 4.5단계)과 완전히 동일한 절차 —
  /// [base]로 학기 전체 lessons 생성 + `timetables`/`lessons`/`lesson_snapshots`
  /// 저장 — 를 트랜잭션 안에서 딱 한 번 수행한다. 이미 등록돼 있으면 즉시
  /// 반환한다(idempotent) — 트랜잭션 안에서 존재 여부를 다시 확인하므로,
  /// 같은 프레임에서 여러 조회 경로가 동시에 호출해도 이중으로 생성되지 않는다.
  Future<void> ensureDatedBackfill({
    required String timetableId,
    required List<TimeSlot> base,
    required DateTime registeredAt,
    String? name,
    String? teacherName,
    String? schoolName,
  }) async {
    await db.transaction((txn) async {
      final existing = await txn.query(
        'timetables',
        where: 'id = ?',
        whereArgs: [timetableId],
        limit: 1,
      );
      if (existing.isNotEmpty) return;

      final semester = SchoolSemester.containing(registeredAt);
      final lessons = SemesterTimetableGenerator.generate(
        timetableId: timetableId,
        timeSlots: base,
        semester: semester,
      );

      await txn.insert(
        'timetables',
        DatedTimetable(
          id: timetableId,
          name: name ?? timetableId,
          semester: semester,
          teacherName: teacherName,
          schoolName: schoolName,
          registeredAt: registeredAt,
        ).toMap(),
      );

      final batch = txn.batch();
      for (final lesson in lessons) {
        batch.insert('lessons', lesson.toMap());
        batch.insert('lesson_snapshots', lesson.toMap());
      }
      await batch.commit(noResult: true);
    });
    _templateCacheByTimetable.remove(timetableId);
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
        'dirty_lesson_keys',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
      );
      await txn.delete(
        'timetables',
        where: 'id = ?',
        whereArgs: [timetableId],
      );
    });
    _templateCacheByTimetable.remove(timetableId);
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
    // OQ-7: 활성 교체 이벤트의 결강일·교체일 중 하나가 새 범위 밖으로 나가면
    // 차단한다 — 트랜잭션 시작 전에 미리 검사해, 걸리면 아무것도 바꾸지 않는다.
    final activeEventRows = await db.query(
      'exchange_events',
      where: 'timetable_id = ? AND is_reverted = 0',
      whereArgs: [timetableId],
    );
    final conflicts = <String>[];
    for (final row in activeEventRows) {
      final absenceDate = DateTime.parse(row['absence_date'] as String);
      final substitutionDate = DateTime.parse(row['substitution_date'] as String);
      if (!newSemester.contains(absenceDate) ||
          !newSemester.contains(substitutionDate)) {
        conflicts.add(row['description'] as String? ?? row['id'] as String);
      }
    }
    if (conflicts.isNotEmpty) {
      throw PeriodChangeConflictException(conflicts);
    }

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

  // ==================== 투영 재생 (S5.4a) ====================

  /// 이 시간표의 `exchange_events`를 재생(replay)해 `lessons`를 다시 계산한다.
  ///
  /// `lessons`는 저널의 **파생 뷰**다 — 이 함수 밖에서 `lessons`의 교사·과목을
  /// 직접 고치는 코드 경로를 두지 않는다(S5 설계 검토 R1).
  ///
  /// **범위를 "건드린 좌표"로 좁힌다**(2026-09-29 성능 수정 — 처음 구현은 매번
  /// 학기 전체 `lessons`(수만 행)를 통째로 다시 읽어, 사용자가 "교체 실행 시
  /// 스낵바가 뜨는 동안 화면이 멈춘다"고 보고할 정도로 느렸다). 실제 교체가
  /// 건드리는 칸은 보통 학기 전체의 극히 일부일 뿐이므로:
  /// ① 이 시간표의 **모든** 이벤트(활성+되돌림 — 되돌린 이벤트가 예전에 건드린
  ///    칸도 다시 템플릿으로 되돌려야 한다)가 건드리는 좌표를 계산하고,
  ///    지금까지 누적된 `dirty_lesson_keys`(한 번이라도 건드린 적 있는 좌표 —
  ///    삭제된 이벤트의 흔적도 여기 남아 있다)와 합쳐 "이번에 계산할 범위"를
  ///    정한다.
  /// ② 그 범위에 해당하는 `lessons` 행만 조회해 템플릿으로 리셋한다.
  /// ③ 활성 이벤트를 `seq` 순으로 [project]에 재생시켜 최종 내용을 계산한다.
  /// ④ 리셋 상태와 달라진 행만 갱신하고(불필요한 쓰기 방지) 새 칸만 삽입,
  ///    `dirty_lesson_keys`(누적)와 `timetables.projected_seq`를 갱신한다.
  ///
  /// 어떤 화면도 아직 이 결과를 읽지 않는다(조회 전환은 S5.5) — 이 함수는
  /// `lessons`를 미리 최신 상태로 맞춰 두는 역할만 한다. 날짜·교시·활성 여부는
  /// 절대 건드리지 않는다 — 학기 기간 관리([applyPeriodChange])의 책임이다.
  Future<void> replayInto(String timetableId) async {
    final templateByKey = await _templateForTimetable(timetableId);

    await db.transaction((txn) async {
      final allEventRows = await txn.query(
        'exchange_events',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
        orderBy: 'seq ASC',
      );
      final allEvents = allEventRows.map(ExchangeEventRecord.fromMap).toList();

      // ① 지금 이벤트들이 건드리는 좌표 + 예전에 건드렸던 좌표(dirty_lesson_keys)
      final newTouched = <_CellCoord>{};
      for (final record in allEvents) {
        for (final cell in touchedCellsFor(toExchangeHistoryItem(record))) {
          newTouched.add((
            teacher: cell.teacher,
            date: _formatDate(cell.date),
            period: cell.period,
          ));
        }
      }

      final dirtyRows = await txn.query(
        'dirty_lesson_keys',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
      );
      final workingSet = <_CellCoord>{
        for (final row in dirtyRows)
          (
            teacher: row['teacher'] as String,
            date: row['date'] as String,
            period: row['period'] as int,
          ),
        ...newTouched,
      };

      if (workingSet.isEmpty) {
        // 이 시간표에 교체가 한 번도 없었다(또는 전부 지워졌고 흔적도 없다) —
        // 재계산할 것이 없다.
        await txn.update(
          'timetables',
          {'projected_seq': -1},
          where: 'id = ?',
          whereArgs: [timetableId],
        );
        return;
      }

      // dirty_lesson_keys는 계속 쌓기만 한다(grow-only) — 나중에 이 좌표를
      // 건드리던 교체가 지워져도, 다음 재생 때 이 표 덕분에 여전히 리셋 대상에
      // 포함된다.
      final dirtyBatch = txn.batch();
      for (final coord in workingSet) {
        dirtyBatch.insert('dirty_lesson_keys', {
          'timetable_id': timetableId,
          'teacher': coord.teacher,
          'date': coord.date,
          'period': coord.period,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await dirtyBatch.commit(noResult: true);

      // ② 건드릴 교사·날짜로만 좁혀 조회 — 학기 전체를 훑지 않는다.
      final touchedTeachers = workingSet.map((c) => c.teacher).toSet().toList();
      final touchedDates = workingSet.map((c) => c.date).toSet().toList();
      final teacherPlaceholders = List.filled(touchedTeachers.length, '?').join(',');
      final datePlaceholders = List.filled(touchedDates.length, '?').join(',');
      final currentRows = await txn.rawQuery(
        'SELECT * FROM lessons WHERE timetable_id = ? '
        'AND teacher IN ($teacherPlaceholders) AND date IN ($datePlaceholders)',
        [timetableId, ...touchedTeachers, ...touchedDates],
      );
      final currentByCoord = <_CellCoord, Lesson>{
        for (final row in currentRows.map(Lesson.fromMap))
          (teacher: row.teacher, date: _formatDate(row.date), period: row.period): row,
      };

      // 리셋 — id·date·period·teacher·isActive는 유지(있으면), 내용만 원복.
      // 해당 좌표에 실제 lessons 행이 아직 없으면(이론상 드묾 — 등록 시 모든
      // 요일·교시 조합이 이미 채워진다) 결정적 id로 새로 만든다.
      final resetLessons =
          workingSet.map((coord) {
            final existing = currentByCoord[coord];
            final date = existing?.date ?? DateTime.parse(coord.date);
            final template = templateByKey['${coord.teacher}_${date.weekday}_${coord.period}'];
            return Lesson(
              id: existing?.id ?? 'proj_${timetableId}_${coord.teacher}_'
                  '${coord.date.replaceAll('-', '')}_${coord.period}',
              timetableId: timetableId,
              date: date,
              period: coord.period,
              teacher: coord.teacher,
              subject: template?.subject,
              className: template?.className,
              isExchangeable: template?.isExchangeable ?? true,
              exchangeReason: template?.exchangeReason,
              isActive: existing?.isActive ?? true,
            );
          }).toList();

      // ③ 활성 이벤트를 seq 순으로 재생
      final activeEvents =
          allEvents
              .where((record) => !record.isReverted)
              .map(toExchangeHistoryItem)
              .toList();

      final projected = project(
        snapshot: resetLessons,
        activeEvents: activeEvents,
        timetableId: timetableId,
      );

      // ④ **실제 DB에 지금 저장된 내용** 대비 달라진 행만 갱신, 새 칸만 삽입.
      //
      // 반드시 `currentByCoord`(DB에서 방금 읽어온 실제 값)와 비교해야 한다 —
      // `resetLessons`는 이번 호출에서만 쓰는 메모리상의 중간 값이라 DB에
      // 한 번도 쓰인 적이 없다. 만약 이 값과 비교하면(과거 버전의 버그),
      // 활성 이벤트가 하나도 이 칸을 건드리지 않는 한 `projected`가
      // `resetLessons`와 항상 같아 보여 "변경 없음"으로 오판하고, 실제로는
      // DB에 남아 있는 옛 스왑 내용을 절대 지우지 못한다(교체를 완전히
      // 삭제해도 그 흔적이 영원히 남는 버그로 재현됨).
      final batch = txn.batch();
      for (final lesson in projected) {
        final coord = (
          teacher: lesson.teacher,
          date: _formatDate(lesson.date),
          period: lesson.period,
        );
        final before = currentByCoord[coord];
        if (before == null) {
          batch.insert('lessons', lesson.toMap());
        } else if (before.subject != lesson.subject ||
            before.className != lesson.className ||
            before.isExchangeable != lesson.isExchangeable ||
            before.exchangeReason != lesson.exchangeReason) {
          batch.update(
            'lessons',
            lesson.toMap(),
            where: 'id = ?',
            whereArgs: [lesson.id],
          );
        }
      }

      final activeSeqs =
          allEventRows
              .where((row) => (row['is_reverted'] as int) == 0)
              .map((row) => row['seq'] as int);
      final maxSeq = activeSeqs.isEmpty ? -1 : activeSeqs.reduce((a, b) => a > b ? a : b);
      batch.update(
        'timetables',
        {'projected_seq': maxSeq},
        where: 'id = ?',
        whereArgs: [timetableId],
      );

      await batch.commit(noResult: true);
    });
  }

  /// [ProjectionStatus] 조회 (S5.5.0 — 조회 전환 준비, 집계만 사용).
  ///
  /// `getLessonStats`와 같은 방식으로 `COUNT(*)`/`MAX(seq)` 집계만 실행하고
  /// 행 전체를 읽지 않는다. 이 값 자체는 아직 어떤 화면에도 연결되지 않는다.
  Future<ProjectionStatus> getProjectionStatus(String timetableId) async {
    final timetableRows = await db.query(
      'timetables',
      columns: ['projected_seq'],
      where: 'id = ?',
      whereArgs: [timetableId],
      limit: 1,
    );
    final hasTimetableRow = timetableRows.isNotEmpty;
    final projectedSeq =
        hasTimetableRow ? (timetableRows.first['projected_seq'] as int? ?? -1) : -1;

    final maxSeqRows = await db.rawQuery(
      'SELECT MAX(seq) AS m FROM exchange_events '
      'WHERE timetable_id = ? AND is_reverted = 0',
      [timetableId],
    );
    final maxActiveSeq = (maxSeqRows.first['m'] as int?) ?? -1;

    final lessonCountRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM lessons WHERE timetable_id = ?',
      [timetableId],
    );
    final lessonRowCount = (lessonCountRows.first['c'] as int?) ?? 0;

    return ProjectionStatus(
      projectedSeq: projectedSeq,
      maxActiveSeq: maxActiveSeq,
      lessonRowCount: lessonRowCount,
      hasTimetableRow: hasTimetableRow,
    );
  }

  /// [weekMonday]가 속한 주(월~금)에서, 지금까지 한 번이라도 교체가 건드린
  /// 적 있는 칸(`dirty_lesson_keys`에 기록된 좌표)만 `lessons`와 조인해
  /// 조회한다 (S5.5.0 — 조회 전환 준비).
  ///
  /// "건드린 적 있는 칸만" 좁히는 이유는 S5.5 설계의 오버레이 전략 때문이다 —
  /// 화면은 기존 `TimeSlot` 위에 이 칸들만 덮어쓸 예정이라, 건드리지 않은
  /// 칸까지 가져올 필요가 없다. 아직 어떤 화면도 이 값을 읽지 않는다.
  /// 기본은 활성(`is_active = 1`) 수업만 반환한다 — 학기 기간 축소로 보관된
  /// 칸은 제외한다.
  Future<List<Lesson>> getTouchedLessonsForWeek(
    String timetableId,
    DateTime weekMonday,
  ) async {
    final friday = weekMonday.add(const Duration(days: 4));
    final rows = await db.rawQuery(
      'SELECT lessons.* FROM lessons '
      'INNER JOIN dirty_lesson_keys '
      'ON lessons.timetable_id = dirty_lesson_keys.timetable_id '
      'AND lessons.teacher = dirty_lesson_keys.teacher '
      'AND lessons.date = dirty_lesson_keys.date '
      'AND lessons.period = dirty_lesson_keys.period '
      'WHERE lessons.timetable_id = ? '
      'AND lessons.date >= ? AND lessons.date <= ? '
      'AND lessons.is_active = 1',
      [timetableId, _formatDate(weekMonday), _formatDate(friday)],
    );
    return rows.map(Lesson.fromMap).toList();
  }

  /// (교사, 요일, 교시) → 대표 스냅샷 한 건. 인스턴스 캐시에 없으면 한 번만
  /// `lesson_snapshots`를 읽어 채운다 — 자세한 이유는 [_templateCacheByTimetable] 참고.
  Future<Map<String, Lesson>> _templateForTimetable(String timetableId) async {
    final cached = _templateCacheByTimetable[timetableId];
    if (cached != null) return cached;

    final snapshotRows = await db.query(
      'lesson_snapshots',
      where: 'timetable_id = ?',
      whereArgs: [timetableId],
    );
    final templateByKey = <String, Lesson>{};
    for (final snapshot in snapshotRows.map(Lesson.fromMap)) {
      final key = '${snapshot.teacher}_${snapshot.date.weekday}_${snapshot.period}';
      templateByKey.putIfAbsent(key, () => snapshot);
    }
    // 스냅샷이 아직 없으면(예: 등록 직후 타이밍) 캐시하지 않는다 — 다음 호출이
    // 다시 시도해 실제 데이터가 생긴 뒤에는 정상적으로 캐시되도록 한다.
    if (templateByKey.isNotEmpty) {
      _templateCacheByTimetable[timetableId] = templateByKey;
    }
    return templateByKey;
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

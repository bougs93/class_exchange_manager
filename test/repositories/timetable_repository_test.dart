import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/dated_timetable.dart';
import 'package:class_exchange_manager/models/lesson.dart';
import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/repositories/timetable_repository.dart';
import 'package:class_exchange_manager/services/semester_timetable_generator.dart';

Lesson _lesson({
  required String timetableId,
  required DateTime date,
  required int period,
  required String teacher,
  String? subject,
  String? className,
}) {
  return Lesson(
    id: Lesson.generateId(),
    timetableId: timetableId,
    date: date,
    period: period,
    teacher: teacher,
    subject: subject,
    className: className,
  );
}

void main() {
  // 테스트마다 격리된 인메모리 DB를 새로 연다.
  Future<Database> openTestDb() => TimetableDatabase.open(
    path: inMemoryDatabasePath,
  );

  group('TimetableRepository — 시간표(학기) CRUD', () {
    test('저장 후 조회하면 같은 값을 돌려준다', () async {
      final db = await openTestDb();
      final repo = TimetableRepository(db);

      final timetable = DatedTimetable(
        id: 'tt_test_1',
        name: '월계중1학기',
        semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 1),
        teacherName: '정원길',
        schoolName: '월계중',
        registeredAt: DateTime(2026, 3, 1, 9, 0),
      );

      await repo.insertTimetable(timetable);
      final restored = await repo.getTimetable('tt_test_1');

      expect(restored, isNotNull);
      expect(restored!.name, '월계중1학기');
      expect(restored.semester.schoolYear, 2026);
      expect(restored.semester.startDate, DateTime(2026, 3, 1));
      expect(restored.teacherName, '정원길');

      await db.close();
    });

    test('없는 id를 조회하면 null을 반환한다', () async {
      final db = await openTestDb();
      final repo = TimetableRepository(db);

      final result = await repo.getTimetable('없는_id');

      expect(result, isNull);
      await db.close();
    });

    test('getAllTimetables는 등록 순서대로 반환한다', () async {
      final db = await openTestDb();
      final repo = TimetableRepository(db);

      await repo.insertTimetable(
        DatedTimetable(
          id: 'tt_a',
          name: 'A',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 1),
          registeredAt: DateTime(2026, 3, 1, 9, 0),
        ),
      );
      await repo.insertTimetable(
        DatedTimetable(
          id: 'tt_b',
          name: 'B',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
          registeredAt: DateTime(2026, 3, 1, 10, 0),
        ),
      );

      final all = await repo.getAllTimetables();

      expect(all.map((t) => t.id).toList(), ['tt_a', 'tt_b']);
      await db.close();
    });
  });

  group('TimetableRepository — 수업(현재 배치) 저장·조회', () {
    test('날짜 범위로 조회하면 그 범위 안의 수업만 반환한다', () async {
      final db = await openTestDb();
      final repo = TimetableRepository(db);
      const timetableId = 'tt_lessons';

      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
          registeredAt: DateTime(2026, 8, 1),
        ),
      );

      final lessons = [
        _lesson(
          timetableId: timetableId,
          date: DateTime(2026, 9, 28),
          period: 1,
          teacher: '정원길',
          subject: '기술가정',
          className: '3-8',
        ),
        _lesson(
          timetableId: timetableId,
          date: DateTime(2026, 10, 5),
          period: 1,
          teacher: '정원길',
          subject: '기술가정',
          className: '3-8',
        ),
        _lesson(
          timetableId: timetableId,
          date: DateTime(2026, 10, 12),
          period: 1,
          teacher: '정원길',
          subject: '기술가정',
          className: '3-8',
        ),
      ];
      await repo.insertLessons(lessons);

      final inRange = await repo.getLessonsForDateRange(
        timetableId,
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 10),
      );

      expect(inRange.length, 1);
      expect(inRange.first.date, DateTime(2026, 10, 5));

      await db.close();
    });

    test('교사·날짜로 조회하면 그 교사의 그 날짜 수업만 반환한다 (교시 순 정렬)', () async {
      final db = await openTestDb();
      final repo = TimetableRepository(db);
      const timetableId = 'tt_teacher_date';

      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
          registeredAt: DateTime(2026, 8, 1),
        ),
      );

      await repo.insertLessons([
        _lesson(
          timetableId: timetableId,
          date: DateTime(2026, 9, 28),
          period: 3,
          teacher: '박은선',
          subject: '수학',
        ),
        _lesson(
          timetableId: timetableId,
          date: DateTime(2026, 9, 28),
          period: 1,
          teacher: '박은선',
          subject: '기술가정',
        ),
        // 다른 교사 — 섞이면 안 된다
        _lesson(
          timetableId: timetableId,
          date: DateTime(2026, 9, 28),
          period: 1,
          teacher: '정원길',
          subject: '음악',
        ),
      ]);

      final result = await repo.getLessonsForTeacherAndDate(
        timetableId,
        '박은선',
        DateTime(2026, 9, 28),
      );

      expect(result.length, 2);
      expect(result[0].period, 1);
      expect(result[0].subject, '기술가정');
      expect(result[1].period, 3);
      expect(result.every((l) => l.teacher == '박은선'), isTrue);

      await db.close();
    });

    test('updateLesson으로 수정하면 조회 결과에 반영된다', () async {
      final db = await openTestDb();
      final repo = TimetableRepository(db);
      const timetableId = 'tt_update';

      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
          registeredAt: DateTime(2026, 8, 1),
        ),
      );

      final lesson = _lesson(
        timetableId: timetableId,
        date: DateTime(2026, 9, 28),
        period: 1,
        teacher: '정원길',
        subject: '기술가정',
      );
      await repo.insertLessons([lesson]);

      await repo.updateLesson(
        lesson.copyWith(subject: '음악', className: '2-1'),
      );

      final result = await repo.getLessonsForTeacherAndDate(
        timetableId,
        '정원길',
        DateTime(2026, 9, 28),
      );

      expect(result.single.id, lesson.id); // 수업 ID는 유지된다
      expect(result.single.subject, '음악');
      expect(result.single.className, '2-1');

      await db.close();
    });

    test('insertSnapshot으로 저장한 원본은 lessons와 별도로 보존된다', () async {
      final db = await openTestDb();
      final repo = TimetableRepository(db);
      const timetableId = 'tt_snapshot';

      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
          registeredAt: DateTime(2026, 8, 1),
        ),
      );

      final lesson = _lesson(
        timetableId: timetableId,
        date: DateTime(2026, 9, 28),
        period: 1,
        teacher: '정원길',
        subject: '기술가정',
      );
      await repo.insertLessons([lesson]);
      await repo.insertSnapshot([lesson]);

      // 현재 배치를 변경해도 스냅샷 테이블은 직접 조회 쿼리가 없으므로(S2 범위
      // 밖) raw query로 확인한다 — Repository에 조회 API가 아직 없다는 것 자체가
      // "원본은 현재 배치와 분리 저장된다"는 계약을 보여준다.
      await repo.updateLesson(lesson.copyWith(subject: '변경됨'));

      final snapshotRows = await db.query(
        'lesson_snapshots',
        where: 'id = ?',
        whereArgs: [lesson.id],
      );
      expect(snapshotRows.single['subject'], '기술가정');

      final currentRows = await db.query(
        'lessons',
        where: 'id = ?',
        whereArgs: [lesson.id],
      );
      expect(currentRows.single['subject'], '변경됨');

      await db.close();
    });
  });

  group('TimetableRepository — 시간표 삭제', () {
    test('deleteTimetable은 시간표·수업·스냅샷을 모두 지운다', () async {
      final db = await openTestDb();
      final repo = TimetableRepository(db);
      const timetableId = 'tt_delete';

      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
          registeredAt: DateTime(2026, 8, 1),
        ),
      );
      final lesson = _lesson(
        timetableId: timetableId,
        date: DateTime(2026, 9, 28),
        period: 1,
        teacher: '정원길',
      );
      await repo.insertLessons([lesson]);
      await repo.insertSnapshot([lesson]);

      await repo.deleteTimetable(timetableId);

      expect(await repo.getTimetable(timetableId), isNull);
      final lessons = await repo.getLessonsForDateRange(
        timetableId,
        DateTime(2000, 1, 1),
        DateTime(2100, 1, 1),
      );
      expect(lessons, isEmpty);
      final snapshotRows = await db.query(
        'lesson_snapshots',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
      );
      expect(snapshotRows, isEmpty);

      await db.close();
    });

    test('다른 시간표의 수업은 삭제 대상에서 제외된다', () async {
      final db = await openTestDb();
      final repo = TimetableRepository(db);

      await repo.insertTimetable(
        DatedTimetable(
          id: 'tt_keep',
          name: 'keep',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
          registeredAt: DateTime(2026, 8, 1),
        ),
      );
      await repo.insertTimetable(
        DatedTimetable(
          id: 'tt_remove',
          name: 'remove',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
          registeredAt: DateTime(2026, 8, 1),
        ),
      );
      await repo.insertLessons([
        _lesson(
          timetableId: 'tt_keep',
          date: DateTime(2026, 9, 28),
          period: 1,
          teacher: 'A',
        ),
      ]);
      await repo.insertLessons([
        _lesson(
          timetableId: 'tt_remove',
          date: DateTime(2026, 9, 28),
          period: 1,
          teacher: 'B',
        ),
      ]);

      await repo.deleteTimetable('tt_remove');

      expect(await repo.getTimetable('tt_keep'), isNotNull);
      final keepLessons = await repo.getLessonsForDateRange(
        'tt_keep',
        DateTime(2000, 1, 1),
        DateTime(2100, 1, 1),
      );
      expect(keepLessons.length, 1);

      await db.close();
    });
  });

  group('TimetableRepository — 학기 기간 반영 (S3a)', () {
    /// 월요일 1교시(정원길, 기술가정)만 있는 시간표를 [initialSemester] 범위로
    /// 등록한 상태를 만든다 (S3 흐름 재현: 생성 → lessons + snapshot 저장).
    Future<(Database, TimetableRepository, String)> setUpRegisteredTimetable(
      SchoolSemester initialSemester,
    ) async {
      final db = await TimetableDatabase.open(path: inMemoryDatabasePath);
      // 테스트 도중 assert 실패로 아래 수동 close()에 못 미치더라도, sqflite의
      // in-memory 단일 인스턴스 캐시 때문에 다음 테스트가 이 연결을 그대로
      // 재사용해 "UNIQUE constraint" 오류로 번지지 않도록 항상 정리한다.
      addTearDown(db.close);
      final repo = TimetableRepository(db);
      const timetableId = 'tt_period';

      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: initialSemester,
          registeredAt: DateTime(2026, 3, 1),
        ),
      );

      final lessons = SemesterTimetableGenerator.generate(
        timetableId: timetableId,
        timeSlots: [
          TimeSlot(
            teacher: '정원길',
            subject: '기술가정',
            className: '3-8',
            dayOfWeek: DateTime.monday,
            period: 1,
          ),
        ],
        semester: initialSemester,
      );
      await repo.insertLessons(lessons);
      await repo.insertSnapshot(lessons);

      return (db, repo, timetableId);
    }

    test('기간을 확장하면 새 날짜에 스냅샷 기준으로 수업이 새로 생성된다', () async {
      final initial = SchoolSemester(
        schoolYear: 2026,
        semester: 1,
        startDate: DateTime(2026, 3, 2), // 월요일
        endDate: DateTime(2026, 3, 9),
      );
      final (db, repo, timetableId) = await setUpRegisteredTimetable(initial);

      final expanded = initial.copyWith(endDate: DateTime(2026, 3, 30));
      final result = await repo.applyPeriodChange(
        timetableId: timetableId,
        newSemester: expanded,
      );

      // 확장된 범위(03-02~03-30)의 월요일: 03-02, 09, 16, 23, 30 = 5개.
      // 이미 있던 03-02, 03-09를 뺀 3개(03-16, 23, 30)가 새로 생긴다.
      expect(result.addedCount, 3);
      expect(result.reactivatedCount, 0);

      final all = await repo.getLessonsForDateRange(
        timetableId,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );
      expect(all.length, 5);
      final newLesson = all.firstWhere(
        (l) => l.date == DateTime(2026, 3, 23),
      );
      expect(newLesson.teacher, '정원길');
      expect(newLesson.subject, '기술가정'); // 스냅샷에서 복사된 내용
      expect(newLesson.className, '3-8');

      final updatedTimetable = await repo.getTimetable(timetableId);
      expect(updatedTimetable!.semester.endDate, DateTime(2026, 3, 30));
    });

    test('기간을 축소하면 범위 밖 수업은 삭제 대신 비활성화되어 기본 조회에서 빠진다', () async {
      final initial = SchoolSemester(
        schoolYear: 2026,
        semester: 1,
        startDate: DateTime(2026, 3, 2),
        endDate: DateTime(2026, 3, 30), // 03-02, 09, 16, 23, 30
      );
      final (db, repo, timetableId) = await setUpRegisteredTimetable(initial);

      final shrunk = initial.copyWith(endDate: DateTime(2026, 3, 9));
      final result = await repo.applyPeriodChange(
        timetableId: timetableId,
        newSemester: shrunk,
      );

      expect(result.deactivatedCount, 3); // 03-16, 03-23, 03-30

      final active = await repo.getLessonsForDateRange(
        timetableId,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );
      expect(active.length, 2); // 03-02, 03-09만 활성

      final withInactive = await repo.getLessonsForDateRange(
        timetableId,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
        includeInactive: true,
      );
      expect(withInactive.length, 5); // 보관된 3건 포함 전부 남아있음(삭제 안 됨)
    });

    test('축소 후 다시 확장하면 보관된 수업을 재사용하고 새로 만들지 않는다', () async {
      final initial = SchoolSemester(
        schoolYear: 2026,
        semester: 1,
        startDate: DateTime(2026, 3, 2),
        endDate: DateTime(2026, 3, 30),
      );
      final (db, repo, timetableId) = await setUpRegisteredTimetable(initial);

      final shrunk = initial.copyWith(endDate: DateTime(2026, 3, 9));
      await repo.applyPeriodChange(timetableId: timetableId, newSemester: shrunk);

      final beforeReexpand = await repo.getLessonsForDateRange(
        timetableId,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
        includeInactive: true,
      );
      final idBefore = beforeReexpand
          .firstWhere((l) => l.date == DateTime(2026, 3, 16))
          .id;

      final reExpanded = initial; // 원래 범위로 복귀
      final result = await repo.applyPeriodChange(
        timetableId: timetableId,
        newSemester: reExpanded,
      );

      expect(result.addedCount, 0); // 전부 기존 레코드 재사용
      expect(result.reactivatedCount, 3);

      final active = await repo.getLessonsForDateRange(
        timetableId,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );
      expect(active.length, 5);
      final idAfter = active.firstWhere((l) => l.date == DateTime(2026, 3, 16)).id;
      expect(idAfter, idBefore); // 같은 수업 ID 재사용 — 새로 만들지 않음
    });

    test('스냅샷에 없는 요일로는 확장해도 수업이 생기지 않는다', () async {
      // 원본 시간표가 월요일뿐이라, 화요일로 확장해도 만들 원본 내용이 없다.
      final initial = SchoolSemester(
        schoolYear: 2026,
        semester: 1,
        startDate: DateTime(2026, 3, 2),
        endDate: DateTime(2026, 3, 2),
      );
      final (db, repo, timetableId) = await setUpRegisteredTimetable(initial);

      final expanded = initial.copyWith(endDate: DateTime(2026, 3, 10)); // 화요일 03-03, 03-10 포함
      final result = await repo.applyPeriodChange(
        timetableId: timetableId,
        newSemester: expanded,
      );

      // 월요일(03-09)만 추가되고, 화요일 칸은 원본에 없으므로 생성되지 않는다
      expect(result.addedCount, 1);
      final all = await repo.getLessonsForDateRange(
        timetableId,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 11),
      );
      expect(all.every((l) => l.date.weekday == DateTime.monday), isTrue);
    });
  });

  group('TimetableRepository.getLessonStats (S4.0)', () {
    test('저장된 수업·스냅샷 개수와 날짜 범위를 집계한다', () async {
      final db = await openTestDb();
      addTearDown(db.close);
      final repo = TimetableRepository(db);
      const timetableId = 'tt_stats';

      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 1),
          registeredAt: DateTime(2026, 3, 1),
        ),
      );

      final lessons = [
        _lesson(
          timetableId: timetableId,
          date: DateTime(2026, 3, 2),
          period: 1,
          teacher: 'A',
        ),
        _lesson(
          timetableId: timetableId,
          date: DateTime(2026, 3, 9),
          period: 1,
          teacher: 'A',
        ),
        _lesson(
          timetableId: timetableId,
          date: DateTime(2026, 3, 16),
          period: 1,
          teacher: 'A',
        ),
      ];
      await repo.insertLessons(lessons);
      await repo.insertSnapshot(lessons);

      // 하나는 비활성화(보관) 처리
      await db.update(
        'lessons',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [lessons.last.id],
      );

      final stats = await repo.getLessonStats(timetableId);

      expect(stats.totalCount, 3);
      expect(stats.activeCount, 2);
      expect(stats.inactiveCount, 1);
      expect(stats.snapshotCount, 3);
      expect(stats.earliestDate, DateTime(2026, 3, 2));
      expect(stats.latestDate, DateTime(2026, 3, 16));
    });

    test('저장된 수업이 없으면 개수는 0, 날짜는 null이다', () async {
      final db = await openTestDb();
      addTearDown(db.close);
      final repo = TimetableRepository(db);
      const timetableId = 'tt_empty_stats';

      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 1),
          registeredAt: DateTime(2026, 3, 1),
        ),
      );

      final stats = await repo.getLessonStats(timetableId);

      expect(stats.totalCount, 0);
      expect(stats.activeCount, 0);
      expect(stats.inactiveCount, 0);
      expect(stats.snapshotCount, 0);
      expect(stats.earliestDate, isNull);
      expect(stats.latestDate, isNull);
    });

    test('다른 시간표의 수업은 집계에 섞이지 않는다', () async {
      final db = await openTestDb();
      addTearDown(db.close);
      final repo = TimetableRepository(db);

      await repo.insertTimetable(
        DatedTimetable(
          id: 'tt_x',
          name: 'X',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 1),
          registeredAt: DateTime(2026, 3, 1),
        ),
      );
      await repo.insertTimetable(
        DatedTimetable(
          id: 'tt_y',
          name: 'Y',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 1),
          registeredAt: DateTime(2026, 3, 1),
        ),
      );
      await repo.insertLessons([
        _lesson(
          timetableId: 'tt_x',
          date: DateTime(2026, 3, 2),
          period: 1,
          teacher: 'A',
        ),
      ]);
      await repo.insertLessons([
        _lesson(
          timetableId: 'tt_y',
          date: DateTime(2026, 3, 2),
          period: 1,
          teacher: 'B',
        ),
        _lesson(
          timetableId: 'tt_y',
          date: DateTime(2026, 3, 9),
          period: 1,
          teacher: 'B',
        ),
      ]);

      final statsX = await repo.getLessonStats('tt_x');
      final statsY = await repo.getLessonStats('tt_y');

      expect(statsX.totalCount, 1);
      expect(statsY.totalCount, 2);
    });
  });
}

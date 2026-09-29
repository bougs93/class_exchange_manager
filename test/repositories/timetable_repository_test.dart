import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/dated_timetable.dart';
import 'package:class_exchange_manager/models/lesson.dart';
import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/repositories/timetable_repository.dart';

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
}

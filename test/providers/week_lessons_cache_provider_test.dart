import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/dated_timetable.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/providers/week_lessons_cache_provider.dart';
import 'package:class_exchange_manager/repositories/timetable_repository.dart';
import 'package:class_exchange_manager/services/exchange_event_mirror.dart';
import 'package:class_exchange_manager/services/semester_timetable_generator.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

OneToOneExchangePath _oneToOnePath() {
  final targetSlot = TimeSlot(
    teacher: '박은선',
    subject: '기술가정',
    className: '3-8',
    dayOfWeek: 1,
    period: 1,
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: '정원길',
      day: '수',
      period: 1,
      className: '3-8',
      subjectName: '기술가정',
    ),
    targetNode: ExchangeNode(
      teacherName: '박은선',
      day: '월',
      period: 1,
      className: '3-8',
      subjectName: '기술가정',
    ),
    option: ExchangeOption(
      timeSlot: targetSlot,
      teacherName: '박은선',
      type: ExchangeType.sameClass,
      priority: 1,
      reason: 'test',
    ),
  );
}

void main() {
  Future<TimetableRepository> setUpTimetableWithLessons(
    String timetableId,
  ) async {
    final db = await TimetableDatabase.open(path: inMemoryDatabasePath);
    addTearDown(db.close);
    final repo = TimetableRepository(db);
    final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);

    await repo.insertTimetable(
      DatedTimetable(
        id: timetableId,
        name: '테스트',
        semester: semester,
        registeredAt: DateTime(2026, 8, 1),
      ),
    );

    final base = [
      TimeSlot(
        teacher: '정원길',
        subject: '기술가정',
        className: '3-8',
        dayOfWeek: 3,
        period: 1,
      ),
      TimeSlot(teacher: '정원길', dayOfWeek: 1, period: 1),
      TimeSlot(
        teacher: '박은선',
        subject: '기술가정',
        className: '3-8',
        dayOfWeek: 1,
        period: 1,
      ),
      TimeSlot(teacher: '박은선', dayOfWeek: 3, period: 1),
    ];
    final lessons = SemesterTimetableGenerator.generate(
      timetableId: timetableId,
      timeSlots: base,
      semester: semester,
    );
    await repo.insertLessons(lessons);
    await repo.insertSnapshot(lessons);

    return repo;
  }

  group('WeekLessonsCache', () {
    test('ensureLoaded 전에는 lessonsFor가 null이고, 호출 후에는 빈 리스트라도 채워진다', () async {
      const timetableId = 'tt_cache_empty';
      final repo = await setUpTimetableWithLessons(timetableId);
      final cache = WeekLessonsCache(
        repository: () async => repo,
        flushPendingWrites: () async {},
      );
      final weekMonday = DateTime(2026, 10, 12);

      expect(cache.lessonsFor(timetableId, weekMonday), isNull);

      await cache.ensureLoaded(timetableId, weekMonday);

      expect(cache.lessonsFor(timetableId, weekMonday), isEmpty);
    });

    test('재생이 밀려 있으면(replayInto 미실행) ensureLoaded가 자동으로 재생한 뒤 캐시한다', () async {
      const timetableId = 'tt_cache_stale';
      final repo = await setUpTimetableWithLessons(timetableId);

      final item = ExchangeHistoryItem.fromExchangePath(
        _oneToOnePath(),
        absenceDate: DateTime(2026, 10, 14), // 수, 10월2주
        substitutionDate: DateTime(2026, 10, 12), // 월, 같은 주
      );
      // 일부러 replayInto를 호출하지 않고 저널만 갱신한다 — "SQLite에서
      // 곧바로 이력을 불러온 시간표는 로드 시 replayInto를 타지 않는다"는
      // S5.5 설계 검토에서 발견한 간극을 재현한다.
      await repo.replaceExchangeEventsFor(
        timetableId,
        toExchangeEventRecords([item], timetableId),
      );
      expect((await repo.getProjectionStatus(timetableId)).isStale, isTrue);

      final cache = WeekLessonsCache(
        repository: () async => repo,
        flushPendingWrites: () async {},
      );
      final weekMonday = DateTime(2026, 10, 12);

      await cache.ensureLoaded(timetableId, weekMonday);

      expect((await repo.getProjectionStatus(timetableId)).isStale, isFalse);
      final touched = cache.lessonsFor(timetableId, weekMonday)!;
      expect(
        touched.any(
          (l) =>
              l.teacher == '정원길' &&
              l.date == DateTime(2026, 10, 12) &&
              l.subject == '기술가정',
        ),
        isTrue,
        reason: '정원길이 월요일 자리로 옮겨간 스왑 결과가 캐시에 반영돼야 한다',
      );
    });

    test('동시에 여러 번 ensureLoaded를 호출해도 실제 조회는 한 번만 수행된다', () async {
      const timetableId = 'tt_cache_dedupe';
      final repo = await setUpTimetableWithLessons(timetableId);
      var flushCallCount = 0;
      final cache = WeekLessonsCache(
        repository: () async => repo,
        flushPendingWrites: () async {
          flushCallCount++;
          // 두 호출이 겹치도록 약간의 지연을 준다.
          await Future.delayed(const Duration(milliseconds: 20));
        },
      );
      final weekMonday = DateTime(2026, 10, 12);

      final first = cache.ensureLoaded(timetableId, weekMonday);
      final second = cache.ensureLoaded(timetableId, weekMonday);
      await Future.wait([first, second]);

      expect(flushCallCount, 1);
    });

    test('invalidateTimetable은 그 시간표의 캐시만 지운다', () async {
      // repository 클로저는 timetableId를 받지 않는다 — ensureLoaded가 이미
      // timetableId를 repo 메서드 인자로 넘기므로, 같은 DB(같은 repo)
      // 안에 시간표 두 개를 두고 캐시 키(timetableId 접두어)만으로
      // 구분되는지를 검증한다.
      const timetableA = 'tt_cache_inv_a';
      const timetableB = 'tt_cache_inv_b';
      final db = await TimetableDatabase.open(path: inMemoryDatabasePath);
      addTearDown(db.close);
      final repo = TimetableRepository(db);
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);
      final base = [
        TimeSlot(
          teacher: '정원길',
          subject: '기술가정',
          className: '3-8',
          dayOfWeek: 3,
          period: 1,
        ),
      ];
      for (final timetableId in [timetableA, timetableB]) {
        await repo.insertTimetable(
          DatedTimetable(
            id: timetableId,
            name: '테스트',
            semester: semester,
            registeredAt: DateTime(2026, 8, 1),
          ),
        );
        final lessons = SemesterTimetableGenerator.generate(
          timetableId: timetableId,
          timeSlots: base,
          semester: semester,
        );
        await repo.insertLessons(lessons);
        await repo.insertSnapshot(lessons);
      }

      final cache = WeekLessonsCache(
        repository: () async => repo,
        flushPendingWrites: () async {},
      );
      final weekMonday = DateTime(2026, 10, 12);

      await cache.ensureLoaded(timetableA, weekMonday);
      await cache.ensureLoaded(timetableB, weekMonday);
      expect(cache.lessonsFor(timetableA, weekMonday), isNotNull);
      expect(cache.lessonsFor(timetableB, weekMonday), isNotNull);

      cache.invalidateTimetable(timetableA);

      expect(cache.lessonsFor(timetableA, weekMonday), isNull);
      expect(cache.lessonsFor(timetableB, weekMonday), isNotNull);
    });
  });
}

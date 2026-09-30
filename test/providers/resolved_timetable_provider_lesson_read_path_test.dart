import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/dated_timetable.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/models/teacher.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/providers/exchange_screen_provider.dart';
import 'package:class_exchange_manager/providers/resolved_timetable_provider.dart';
import 'package:class_exchange_manager/providers/selected_week_provider.dart';
import 'package:class_exchange_manager/providers/services_provider.dart';
import 'package:class_exchange_manager/providers/show_week_header_provider.dart';
import 'package:class_exchange_manager/providers/timetable_repository_provider.dart';
import 'package:class_exchange_manager/providers/week_lessons_cache_provider.dart';
import 'package:class_exchange_manager/services/excel_service.dart';
import 'package:class_exchange_manager/services/semester_timetable_generator.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

/// S5.5.4 통합 검증: [lessonReadPathEnabledProvider]가 꺼져 있으면(기본값)
/// 기존 회귀 스위트가 이미 증명하듯 동작이 하나도 바뀌지 않는다. 이 파일은
/// 그 반대편 — **켰을 때** 실제로 SQLite 오버레이가 걸리는지, 그리고 캐시가
/// 준비되기 전까지는 자동으로 `dateAware`로 폴백하는지를 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OneToOneExchangePath oneToOnePath() {
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

  List<TimeSlot> baseTimetable() {
    return [
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
  }

  test(
    'lessonReadPathEnabledProvider가 꺼져 있으면 캐시를 전혀 건드리지 않고 dateAware 결과 그대로다',
    () async {
      const timetableId = 'tt_resolved_flag_off';
      final container = ProviderContainer(
        overrides: [
          timetableDatabaseProvider.overrideWith(
            (ref) => TimetableDatabase.open(path: inMemoryDatabasePath),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo = await container.read(timetableRepositoryProvider.future);
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);
      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: semester,
          registeredAt: DateTime(2026, 8, 1),
        ),
      );
      final base = baseTimetable();
      final seedLessons = SemesterTimetableGenerator.generate(
        timetableId: timetableId,
        timeSlots: base,
        semester: semester,
      );
      await repo.insertLessons(seedLessons);
      await repo.insertSnapshot(seedLessons);

      final history = container.read(exchangeHistoryServiceProvider);
      history.timetableId = timetableId;
      addTearDown(() async {
        await history.clearStoredDataForTimetable(timetableId);
        history.resetForTesting();
      });

      container.read(exchangeScreenProvider.notifier).setTimetableData(
        TimetableData(
          teachers: [
            Teacher(name: '정원길', subject: '기술가정'),
            Teacher(name: '박은선', subject: '기술가정'),
          ],
          timeSlots: base,
          config: const ExcelParsingConfig(),
          totalParsedCells: base.length,
          successCount: base.length,
          errorCount: 0,
        ),
      );
      container.read(showWeekHeaderProvider.notifier).state = true;
      container.read(selectedWeekProvider.notifier).state = DateTime(2026, 10, 12);

      history.addExchange(
        oneToOnePath(),
        absenceDate: DateTime(2026, 10, 14),
        substitutionDate: DateTime(2026, 10, 12),
      );
      await history.flushPendingWrites();

      // 플래그 기본값(false) — 캐시를 아예 참조하지 않는다.
      final result = container.read(resolvedTimetableProvider);
      final jung = result.firstWhere(
        (s) => s.teacher == '정원길' && s.dayOfWeek == 1 && s.period == 1,
      );
      expect(jung.subject, '기술가정');

      final cache = container.read(weekLessonsCacheProvider);
      expect(
        cache.lessonsFor(timetableId, DateTime(2026, 10, 12)),
        isNull,
        reason: '플래그가 꺼져 있으면 ensureLoaded를 호출하지 않아야 한다',
      );
    },
  );

  test(
    'lessonReadPathEnabledProvider가 켜져 있으면 처음엔 dateAware로 폴백하고, 캐시가 준비되면 SQLite 값으로 갱신된다',
    () async {
      const timetableId = 'tt_resolved_flag_on';
      final container = ProviderContainer(
        overrides: [
          timetableDatabaseProvider.overrideWith(
            (ref) => TimetableDatabase.open(path: inMemoryDatabasePath),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo = await container.read(timetableRepositoryProvider.future);
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);
      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: semester,
          registeredAt: DateTime(2026, 8, 1),
        ),
      );
      final base = baseTimetable();
      final seedLessons = SemesterTimetableGenerator.generate(
        timetableId: timetableId,
        timeSlots: base,
        semester: semester,
      );
      await repo.insertLessons(seedLessons);
      await repo.insertSnapshot(seedLessons);

      final history = container.read(exchangeHistoryServiceProvider);
      history.timetableId = timetableId;
      addTearDown(() async {
        await history.clearStoredDataForTimetable(timetableId);
        history.resetForTesting();
      });

      container.read(exchangeScreenProvider.notifier).setTimetableData(
        TimetableData(
          teachers: [
            Teacher(name: '정원길', subject: '기술가정'),
            Teacher(name: '박은선', subject: '기술가정'),
          ],
          timeSlots: base,
          config: const ExcelParsingConfig(),
          totalParsedCells: base.length,
          successCount: base.length,
          errorCount: 0,
        ),
      );
      container.read(showWeekHeaderProvider.notifier).state = true;
      container.read(selectedWeekProvider.notifier).state = DateTime(2026, 10, 12);

      history.addExchange(
        oneToOnePath(),
        absenceDate: DateTime(2026, 10, 14),
        substitutionDate: DateTime(2026, 10, 12),
      );
      await history.flushPendingWrites();

      container.read(lessonReadPathEnabledProvider.notifier).state = true;

      // 캐시가 아직 채워지지 않은 첫 조회 — dateAware로 폴백해도 같은 결과가
      // 나와야 한다(이 시나리오는 같은 주 교체라 두 경로 결과가 같다).
      final firstRead = container.read(resolvedTimetableProvider);
      final jungFirst = firstRead.firstWhere(
        (s) => s.teacher == '정원길' && s.dayOfWeek == 1 && s.period == 1,
      );
      expect(jungFirst.subject, '기술가정');

      // ensureLoaded가 폴백 경로에서 백그라운드로 걸렸다 — 끝날 때까지 기다린다.
      final cache = container.read(weekLessonsCacheProvider);
      await cache.ensureLoaded(timetableId, DateTime(2026, 10, 12));

      // ticker가 올라갔으므로 다시 읽으면 SQLite(fromLessons) 경로를 탄다.
      final secondRead = container.read(resolvedTimetableProvider);
      final jungSecond = secondRead.firstWhere(
        (s) => s.teacher == '정원길' && s.dayOfWeek == 1 && s.period == 1,
      );
      expect(jungSecond.subject, '기술가정');
      expect(
        cache.lessonsFor(timetableId, DateTime(2026, 10, 12)),
        isNotNull,
      );
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/dated_timetable.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/providers/services_provider.dart';
import 'package:class_exchange_manager/providers/timetable_repository_provider.dart';
import 'package:class_exchange_manager/providers/week_lessons_cache_provider.dart';
import 'package:class_exchange_manager/services/semester_timetable_generator.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

/// 회귀 재현: 사용자가 실 앱에서 "교체 여러 건 실행 → 전체 초기화 → 같은 칸
/// 재선택 → 교체 경로 탐색 사이드바가 안 뜸"을 발견했다. 근본 원인은
/// [WeekLessonsCache]가 한 번 채운 (시간표, 주)를 [exchangeListVersionProvider]가
/// 바뀌어도(교체 추가·삭제·되돌리기) 전혀 다시 읽지 않던 것 — 이 테스트는 그
/// 간극이 다시 생기지 않는지 확인한다.
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
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    '캐시가 채워진 뒤 교체가 추가되면(exchangeListVersion 변경) 캐시가 즉시 무효화된다',
    () async {
      const timetableId = 'tt_cache_invalidation';
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

      final cache = container.read(weekLessonsCacheProvider);
      final weekMonday = DateTime(2026, 10, 12);

      // 1) 교체가 없는 상태로 캐시를 먼저 채운다 (빈 리스트로 캐시됨).
      await cache.ensureLoaded(timetableId, weekMonday);
      expect(cache.lessonsFor(timetableId, weekMonday), isEmpty);

      // 2) 교체를 추가한다 — exchangeListVersionProvider가 증가해야 한다.
      history.addExchange(
        _oneToOnePath(),
        absenceDate: DateTime(2026, 10, 14),
        substitutionDate: DateTime(2026, 10, 12),
      );

      // 3) 캐시가 곧바로(비동기 쓰기 완료를 기다리지 않고도) 무효화돼야 한다 —
      //    옛 버그에서는 여기서 여전히 빈 리스트가 캐시된 채 남아있었다.
      expect(
        cache.lessonsFor(timetableId, weekMonday),
        isNull,
        reason: '교체 이력이 바뀌면 캐시가 즉시 비워져야 한다(다음 조회가 새로 읽도록)',
      );

      // 4) 다시 ensureLoaded하면 새 교체가 반영된 값이 채워진다.
      await history.flushPendingWrites();
      await cache.ensureLoaded(timetableId, weekMonday);
      final touched = cache.lessonsFor(timetableId, weekMonday)!;
      expect(
        touched.any(
          (l) =>
              l.teacher == '정원길' &&
              l.date == DateTime(2026, 10, 12) &&
              l.subject == '기술가정',
        ),
        isTrue,
        reason: '재조회 후에는 새로 추가된 교체가 반영돼야 한다',
      );
    },
  );
}

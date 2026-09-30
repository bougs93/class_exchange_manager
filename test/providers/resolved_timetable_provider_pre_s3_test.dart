import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
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
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

/// S5.5.4 회귀 체크리스트: "S3 이전 시간표" (2026-09-30, 수정 완료).
///
/// S3 이전에 등록된 시간표는 SQLite `timetables`/`lessons`/`lesson_snapshots`
/// 행이 하나도 없다 — 다만 S5.1의 `mirrorSink`는 `timetables` 행이 있는지와
/// 무관하게 항상 `exchange_events`에 기록하고 `replayInto`까지 호출하므로,
/// 처음 발견 당시에는 이런 시간표에서 교체를 실행하면 그 칸만 `lessons`에
/// (스냅샷 템플릿이 없어 subject·className이 비어 있는 채로) 새로 생성되는
/// 회귀가 있었다.
///
/// **수정**: `WeekLessonsCache`가 재생 여부를 확인하기 전에
/// `TimetableRepository.ensureDatedBackfill`을 먼저 호출하도록 연결했다 —
/// `timetables` 행이 없으면 현재 화면에 열려 있는 원본 [TimeSlot] 목록으로
/// S3 등록과 동일한 절차(시간표 메타데이터 + 전체 학기 lessons + 원본
/// 스냅샷)를 그 자리에서 딱 한 번 수행한다. 이 테스트는 그 결과 교체된 칸의
/// 과목명이 더 이상 사라지지 않고 `dateAware`(OFF 모드)와 같은 값을
/// 보여주는지 확인한다.
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
    'S3 이전 시간표(SQLite timetables/lessons 행 없음)에서 플래그 OFF면 기존 dateAware 결과 그대로다',
    () async {
      const timetableId = 'tt_pre_s3_flag_off';
      final container = ProviderContainer(
        overrides: [
          timetableDatabaseProvider.overrideWith(
            (ref) => TimetableDatabase.open(path: inMemoryDatabasePath),
          ),
        ],
      );
      addTearDown(container.dispose);

      // 의도적으로 insertTimetable/insertLessons/insertSnapshot을 하지 않는다
      // — S3 이전 시간표를 흉내낸다.
      final base = baseTimetable();
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

      // S5.5.5부터 기본값이 true이므로, "꺼짐" 동작을 확인하려면 명시적으로 꺼야 한다.
      container.read(lessonReadPathEnabledProvider.notifier).state = false;

      final result = container.read(resolvedTimetableProvider);
      final jung = result.firstWhere(
        (s) => s.teacher == '정원길' && s.dayOfWeek == 1 && s.period == 1,
      );
      expect(jung.subject, '기술가정');
    },
  );

  test(
    'S3 이전 시간표에서 플래그 ON이어도 자동 백필로 교체된 칸의 과목명이 정확히 보인다',
    () async {
      const timetableId = 'tt_pre_s3_flag_on';
      final container = ProviderContainer(
        overrides: [
          timetableDatabaseProvider.overrideWith(
            (ref) => TimetableDatabase.open(path: inMemoryDatabasePath),
          ),
        ],
      );
      addTearDown(container.dispose);

      final base = baseTimetable();
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

      final cache = container.read(weekLessonsCacheProvider);
      await cache.ensureLoaded(timetableId, DateTime(2026, 10, 12));

      final result = container.read(resolvedTimetableProvider);
      final jung = result.firstWhere(
        (s) => s.teacher == '정원길' && s.dayOfWeek == 1 && s.period == 1,
      );

      // 자동 백필이 스냅샷을 채워줬으므로 원본 과목명이 정확히 복원된다
      // (dateAware/OFF 모드와 동일한 값).
      expect(jung.subject, '기술가정');

      final repo = await container.read(timetableRepositoryProvider.future);
      final backfilled = await repo.getTimetable(timetableId);
      expect(backfilled, isNotNull, reason: '백필로 timetables 행이 생성돼야 한다');
    },
  );
}

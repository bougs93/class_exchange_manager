import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/dated_timetable.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/providers/services_provider.dart';
import 'package:class_exchange_manager/providers/timetable_repository_provider.dart';
import 'package:class_exchange_manager/services/exchange_event_mirror.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

OneToOneExchangePath _path(String label) {
  final targetSlot = TimeSlot(
    teacher: '교사B-$label',
    subject: '국어',
    className: '1-2',
    dayOfWeek: 2,
    period: 2,
  );
  final option = ExchangeOption(
    timeSlot: targetSlot,
    teacherName: '교사B-$label',
    type: ExchangeType.sameClass,
    priority: 1,
    reason: 'test',
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: '교사A-$label',
      day: '월',
      period: 1,
      className: '1-1',
      subjectName: '수학',
    ),
    targetNode: ExchangeNode(
      teacherName: '교사B-$label',
      day: '화',
      period: 2,
      className: '1-2',
      subjectName: '국어',
    ),
    option: option,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// S5.4b: SQLite 저널이 이미 있는 시간표는 그걸 진실 원본으로 쓴다 —
  /// JSON에 그와 다른(더 오래됐거나 어긋난) 내용이 있어도 무시해야 한다.
  test(
    'SQLite에 이미 저널이 있으면 JSON 내용과 달라도 SQLite를 진실 원본으로 쓴다',
    () async {
      const timetableId = 'tt_sqlite_source_test';
      final container = ProviderContainer(
        overrides: [
          timetableDatabaseProvider.overrideWith(
            (ref) => TimetableDatabase.open(path: inMemoryDatabasePath),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo = await container.read(timetableRepositoryProvider.future);
      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
          registeredAt: DateTime(2026, 8, 1),
        ),
      );

      final history = container.read(exchangeHistoryServiceProvider);
      history.timetableId = timetableId;
      addTearDown(() async {
        await history.clearStoredDataForTimetable(timetableId);
        history.resetForTesting();
      });

      // JSON에는 "old"만 있는 상황을 흉내낸다(마이그레이션 전 상태).
      final loadSink = history.loadSink;
      history.loadSink = null;
      history.addExchange(
        _path('json-only'),
        absenceDate: DateTime(2026, 9, 3),
        substitutionDate: DateTime(2026, 9, 5),
      );
      await Future.delayed(const Duration(milliseconds: 200));
      history.loadSink = loadSink;

      // SQLite 저널에는 이미 다른("sqlite-only") 이력이 들어가 있는 상황을
      // 직접 만든다 — 실제로는 이전 세션에서 mirrorSink가 성공해 이관이
      // 끝난 상태를 재현한다.
      final sqliteItem = ExchangeHistoryItem.fromExchangePath(
        _path('sqlite-only'),
        absenceDate: DateTime(2026, 10, 1),
        substitutionDate: DateTime(2026, 10, 3),
        customId: 'evt_sqlite_only',
      );
      await repo.replaceExchangeEventsFor(
        timetableId,
        toExchangeEventRecords([sqliteItem], timetableId),
      );

      await history.loadFromLocalStorage();

      final loaded = history.getActiveExchangeList();
      expect(loaded.map((e) => e.id), ['evt_sqlite_only']);
    },
  );

  /// S5.4b: SQLite에 아직 아무것도 없으면(최초 이관 전) 기존 JSON 경로로
  /// 폴백해야 한다 — 사용자의 기존 교체 이력이 갑자기 사라지면 안 된다.
  test('SQLite 저널이 비어 있으면 JSON 경로로 폴백해 기존 이력을 그대로 불러온다', () async {
    const timetableId = 'tt_sqlite_fallback_test';
    final container = ProviderContainer(
      overrides: [
        timetableDatabaseProvider.overrideWith(
          (ref) => TimetableDatabase.open(path: inMemoryDatabasePath),
        ),
      ],
    );
    addTearDown(container.dispose);

    final repo = await container.read(timetableRepositoryProvider.future);
    await repo.insertTimetable(
      DatedTimetable(
        id: timetableId,
        name: '테스트',
        semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
        registeredAt: DateTime(2026, 8, 1),
      ),
    );

    final history = container.read(exchangeHistoryServiceProvider);
    history.timetableId = timetableId;
    addTearDown(() async {
      await history.clearStoredDataForTimetable(timetableId);
      history.resetForTesting();
    });

    // JSON에만 이력을 만든다(mirrorSink는 그대로 두되, SQLite는 아직
    // 비어 있는 "최초 이관 전" 상태를 재현하기 위해 loadSink만 잠시 끈다 —
    // mirrorSink가 이미 SQLite로 이관해버리면 폴백 시나리오를 재현할 수
    // 없으므로, mirrorSink도 함께 꺼서 JSON에만 남긴다).
    final mirrorSink = history.mirrorSink;
    final loadSink = history.loadSink;
    history.mirrorSink = null;
    history.loadSink = null;
    history.addExchange(
      _path('pre-migration'),
      absenceDate: DateTime(2026, 9, 3),
      substitutionDate: DateTime(2026, 9, 5),
    );
    await Future.delayed(const Duration(milliseconds: 200));
    history.mirrorSink = mirrorSink;
    history.loadSink = loadSink;

    expect(await repo.getExchangeEvents(timetableId), isEmpty);

    await history.loadFromLocalStorage();

    final loaded = history.getActiveExchangeList();
    expect(loaded, hasLength(1));
    expect(loaded.single.originalPath.nodes.first.teacherName, contains('pre-migration'));

    // 폴백 후 최초 이관도 함께 일어나야 한다(S5.1 보완 로직 재사용).
    await Future.delayed(const Duration(milliseconds: 200));
    final migratedEvents = await repo.getExchangeEvents(timetableId);
    expect(migratedEvents, hasLength(1));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/dated_timetable.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/providers/node_date_edit_provider.dart';
import 'package:class_exchange_manager/providers/services_provider.dart';
import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/providers/timetable_repository_provider.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

/// S5.6.5 검증: [nodeDateEditEnabledProvider]가 꺼져 있으면(기본값) 순환·2중
/// 계획서 행의 날짜 표시가 기존과 완전히 동일하고, 켜져 있으면 노드(슬롯)
/// 기준으로 정확한 날짜(확정 또는 그 슬롯 요일에 맞는 추정)를 보여준다.
CircularExchangePath _circularPath() {
  final a = ExchangeNode(
    teacherName: 'A',
    day: '월',
    period: 1,
    className: '1-1',
    subjectName: '수학',
  );
  final b = ExchangeNode(
    teacherName: 'B',
    day: '화',
    period: 2,
    className: '1-1',
    subjectName: '영어',
  );
  final c = ExchangeNode(
    teacherName: 'C',
    day: '수',
    period: 3,
    className: '1-1',
    subjectName: '과학',
  );
  return CircularExchangePath.fromNodes([a, b, c, a]);
}

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

  test('플래그 OFF — 순환교체 모든 행이 item의 결강일/교체일을 그대로 보여준다 (S5.6 이전과 동일)', () async {
    const timetableId = 'tt_plan_node_flag_off';
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

    history.addExchange(
      _circularPath(),
      absenceDate: DateTime(2026, 8, 24), // 월
      substitutionDate: DateTime(2026, 8, 25),
    );
    final id = history.getExchangeList().single.id;
    history.updateNodeDate(id, dayName: '화', period: 2, date: DateTime(2026, 9, 8));
    await history.flushPendingWrites();

    // S5.6.8부터 기본값이 true이므로, "꺼짐" 동작을 확인하려면 명시적으로 꺼야 한다.
    container.read(nodeDateEditEnabledProvider.notifier).state = false;

    final state = container.read(substitutionPlanViewModelProvider);
    expect(state.planData, isNotEmpty);
    for (final row in state.planData) {
      expect(row.absenceDate, '2026.08.24');
      expect(row.substitutionDate, '2026.08.25');
    }
  });

  test('플래그 ON — 확정 노드는 확정 날짜, 나머지는 그 슬롯 요일에 맞는 추정 날짜를 보여준다', () async {
    const timetableId = 'tt_plan_node_flag_on';
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

    history.addExchange(
      _circularPath(),
      absenceDate: DateTime(2026, 8, 24), // 월
      substitutionDate: DateTime(2026, 8, 25),
    );
    final id = history.getExchangeList().single.id;
    // B(화,2)만 9월2주 화요일로 확정 — A·C는 여전히 미확정(추정)이다.
    history.updateNodeDate(id, dayName: '화', period: 2, date: DateTime(2026, 9, 8));
    await history.flushPendingWrites();

    container.read(nodeDateEditEnabledProvider.notifier).state = true;

    final state = container.read(substitutionPlanViewModelProvider);
    final byRemarks = {for (final row in state.planData) row.remarks: row};

    // 순환교체3: A(월,1) → C(수,3) — 둘 다 미확정, 결강일 주(8월4주) 추정.
    expect(byRemarks['순환교체3']!.absenceDate, '2026.08.24'); // 월
    expect(byRemarks['순환교체3']!.substitutionDate, '2026.08.26'); // 수

    // 순환교체2: C(수,3) → B(화,2) — target(B)만 확정.
    expect(byRemarks['순환교체2']!.absenceDate, '2026.08.26'); // 수, 추정
    expect(byRemarks['순환교체2']!.substitutionDate, '2026.09.08'); // 화, 확정

    // 순환교체1: B(화,2) → A(월,1) — source(B)만 확정.
    expect(byRemarks['순환교체1']!.absenceDate, '2026.09.08'); // 화, 확정
    expect(byRemarks['순환교체1']!.substitutionDate, '2026.08.24'); // 월, 추정
  });

  test('플래그 ON이어도 1:1 교체 행은 영향받지 않는다', () async {
    const timetableId = 'tt_plan_node_flag_on_121';
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

    history.addExchange(
      _oneToOnePath(),
      absenceDate: DateTime(2026, 10, 14),
      substitutionDate: DateTime(2026, 10, 12),
    );
    await history.flushPendingWrites();

    container.read(nodeDateEditEnabledProvider.notifier).state = true;

    final state = container.read(substitutionPlanViewModelProvider);
    final row = state.planData.single;
    expect(row.absenceDate, '2026.10.14');
    expect(row.substitutionDate, '2026.10.12');
  });
}

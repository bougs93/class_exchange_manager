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
import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/providers/timetable_repository_provider.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

/// 회귀 재현: 사용자가 실 앱에서 "2중교체를 되돌렸더니 '교체' 화면에서는
/// 사라졌는데 저장된 '계획서'에는 그대로 남아있다"를 발견했다. 원인은
/// `SubstitutionPlanViewModel.loadPlanData()`가 `getExchangeList()`(되돌린
/// 건도 포함)를 쓰고 있던 것 — `getActiveExchangeList()`로 바꿔 수정했다.
/// SQLite/S5.5 조회 경로와는 무관한, 순수 JSON 기반 로직의 기존 버그다.
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

  test('되돌린(isReverted) 교체는 계획서 데이터에서도 함께 사라진다', () async {
    const timetableId = 'tt_plan_reverted_test';
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

    final beforeUndo = container.read(substitutionPlanViewModelProvider);
    expect(beforeUndo.planData, isNotEmpty);

    history.undoLastExchange();

    final afterUndo = container.read(substitutionPlanViewModelProvider);
    expect(
      afterUndo.planData,
      isEmpty,
      reason: '되돌린 교체는 "교체" 화면뿐 아니라 계획서에서도 사라져야 한다',
    );
  });
}

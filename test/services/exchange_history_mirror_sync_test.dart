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

  /// S5.1 보완(2026-09-29): mirrorSink는 "쓰기" 시점에만 호출되므로, 이
  /// 싱크가 연결되기 전부터 JSON에 있던 이력은 새 저장이 한 번도 없으면
  /// SQLite 저널에 영원히 반영되지 않는다. 실제 앱에서 사용자가 이 문제로
  /// 확인 패널에 "불일치"만 계속 뜨는 것을 발견했다 — loadFromLocalStorage()
  /// 직후 한 번 미러를 밀어 넣도록 고쳐서 해결했다.
  test(
    'loadFromLocalStorage 직후 mirrorSink가 없던 시절의 기존 이력도 SQLite에 반영된다',
    () async {
      const timetableId = 'tt_mirror_sync_test';
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

      // mirrorSink가 없던 시절을 흉내낸다 — JSON에만 저장되고 SQLite는
      // 전혀 모르는 상태.
      final sink = history.mirrorSink;
      history.mirrorSink = null;
      history.addExchange(
        _path('old'),
        absenceDate: DateTime(2026, 9, 3),
        substitutionDate: DateTime(2026, 9, 5),
      );
      await Future.delayed(const Duration(milliseconds: 200));
      history.mirrorSink = sink;

      expect(await repo.getExchangeEvents(timetableId), isEmpty);

      // 스코프 재로드(예: 시간표 전환 후 복귀, 또는 앱 재시작 재현)
      await history.loadFromLocalStorage();
      await Future.delayed(const Duration(milliseconds: 200));

      final events = await repo.getExchangeEvents(timetableId);
      expect(events.length, 1);
      expect(events.single.isReverted, isFalse);
    },
  );
}

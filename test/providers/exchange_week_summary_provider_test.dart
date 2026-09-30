import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/providers/exchange_week_summary_provider.dart';
import 'package:class_exchange_manager/providers/services_provider.dart';
import 'package:class_exchange_manager/providers/timetable_repository_provider.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/utils/week_date_calculator.dart';

/// 2026-09-30 버그 수정 회귀: 교체일이 결강일과 다른 주로 넘어가면, 그
/// 주차 바 칩이 "지금 선택된 주"일 때만 임시로 떴다가 다른 칩을 누르는
/// 순간 사라지던 문제. 원인은 주차 바가 결강일 기준 집계
/// ([exchangeWeeksProvider], §10.5 A안)만 칩 목록으로 썼기 때문 —
/// 그리드 화면은 결강일·교체일 중 하나라도 걸리면 그 주에 반영하는데
/// (§10.5 표), 칩 목록 기준은 더 좁았다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OneToOneExchangePath crossWeekPath() {
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
        day: '금',
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

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        timetableDatabaseProvider.overrideWith(
          (ref) => TimetableDatabase.open(path: inMemoryDatabasePath),
        ),
      ],
    );
    return container;
  }

  test(
    '결강일과 교체일이 서로 다른 주면, 배지 집계는 결강일 주에만(A안) 되지만 칩 목록에는 두 주 다 포함된다',
    () {
      final container = buildContainer();
      addTearDown(container.dispose);

      final history = container.read(exchangeHistoryServiceProvider);
      addTearDown(() => history.resetForTesting());

      // 결강일: 10월 2주 금요일(10/9), 교체일: 10월 3주 월요일(10/12) — 주가 갈린다.
      history.addExchange(
        crossWeekPath(),
        absenceDate: DateTime(2026, 10, 9),
        substitutionDate: DateTime(2026, 10, 12),
      );

      final absenceWeek = WeekDateCalculator.getWeekMonday(DateTime(2026, 10, 9));
      final substitutionWeek = WeekDateCalculator.getWeekMonday(
        DateTime(2026, 10, 12),
      );
      expect(absenceWeek, isNot(substitutionWeek));

      // 집계(배지 숫자 합계 = 실제 건수)는 여전히 결강일 주에만 1건.
      final counts = container.read(exchangeWeekCountsProvider);
      expect(counts[absenceWeek], 1);
      expect(counts.containsKey(substitutionWeek), isFalse);
      expect(container.read(exchangeWeeksProvider), [absenceWeek]);

      // 칩 목록(exchangeVisibleWeeksProvider)에는 두 주 다 있어야
      // 사용자가 다른 칩을 눌러도 교체일 쪽 주로 다시 돌아올 수 있다.
      final visibleWeeks = container.read(exchangeVisibleWeeksProvider);
      expect(visibleWeeks, containsAll([absenceWeek, substitutionWeek]));
    },
  );

  test('같은 주 안에서 끝나는 교체는 칩 목록에 그 주 하나만 있다', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final history = container.read(exchangeHistoryServiceProvider);
    addTearDown(() => history.resetForTesting());

    final samWeekPath = OneToOneExchangePath(
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
        timeSlot: TimeSlot(
          teacher: '박은선',
          subject: '기술가정',
          className: '3-8',
          dayOfWeek: 1,
          period: 1,
        ),
        teacherName: '박은선',
        type: ExchangeType.sameClass,
        priority: 1,
        reason: 'test',
      ),
    );

    history.addExchange(
      samWeekPath,
      absenceDate: DateTime(2026, 10, 14), // 수
      substitutionDate: DateTime(2026, 10, 12), // 같은 주 월
    );

    final week = WeekDateCalculator.getWeekMonday(DateTime(2026, 10, 12));
    expect(container.read(exchangeVisibleWeeksProvider), [week]);
  });
}

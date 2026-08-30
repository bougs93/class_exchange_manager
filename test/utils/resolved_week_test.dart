import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/supplement_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/utils/resolved_week.dart';

/// 기본 시간표: 홍길동 월1(수학), 김철수 화2(음악). 나머지는 빈 슬롯.
List<TimeSlot> _baseTimetable() {
  return [
    TimeSlot(
      teacher: '홍길동',
      subject: '수학',
      className: '1-1',
      dayOfWeek: 1,
      period: 1,
    ),
    TimeSlot(teacher: '홍길동', dayOfWeek: 2, period: 2), // 화2 비어있음
    TimeSlot(
      teacher: '김철수',
      subject: '음악',
      className: '2-1',
      dayOfWeek: 2,
      period: 2,
    ),
    TimeSlot(teacher: '김철수', dayOfWeek: 1, period: 1), // 월1 비어있음
  ];
}

OneToOneExchangePath _oneToOnePath({
  String teacherA = '홍길동',
  String dayA = '월',
  int periodA = 1,
  String classA = '1-1',
  String subjectA = '수학',
  String teacherB = '김철수',
  String dayB = '화',
  int periodB = 2,
  String classB = '2-1',
  String subjectB = '음악',
}) {
  final targetSlot = TimeSlot(
    teacher: teacherB,
    subject: subjectB,
    className: classB,
    dayOfWeek: 2,
    period: periodB,
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: teacherA,
      day: dayA,
      period: periodA,
      className: classA,
      subjectName: subjectA,
    ),
    targetNode: ExchangeNode(
      teacherName: teacherB,
      day: dayB,
      period: periodB,
      className: classB,
      subjectName: subjectB,
    ),
    option: ExchangeOption(
      timeSlot: targetSlot,
      teacherName: teacherB,
      type: ExchangeType.sameClass,
      priority: 1,
      reason: 'test',
    ),
  );
}

SupplementExchangePath _supplementPath({
  String sourceTeacher = '홍길동',
  String sourceDay = '월',
  int sourcePeriod = 1,
  String targetTeacher = '이영희',
  String targetDay = '월',
  int targetPeriod = 1,
}) {
  return SupplementExchangePath.simple(
    id: 'supplement_test',
    sourceTeacher: sourceTeacher,
    sourceDay: sourceDay,
    sourcePeriod: sourcePeriod,
    targetTeacher: targetTeacher,
    targetDay: targetDay,
    targetPeriod: targetPeriod,
    className: '1-1',
    subject: '수학',
  );
}

ExchangeHistoryItem _historyItem({
  required OneToOneExchangePath path,
  required DateTime absenceDate,
  required DateTime substitutionDate,
}) {
  return ExchangeHistoryItem.fromExchangePath(
    path,
    absenceDate: absenceDate,
    substitutionDate: substitutionDate,
  );
}

void main() {
  group('ResolvedWeek — 원본 불변 보장', () {
    test('base 리스트의 TimeSlot 객체는 합성 후에도 값이 바뀌지 않는다', () {
      final base = _baseTimetable();
      final hongBefore = base[0]; // 홍길동 월1, 수학

      final events = [
        _historyItem(
          path: _oneToOnePath(),
          absenceDate: DateTime(2026, 8, 24), // 월요일
          substitutionDate: DateTime(2026, 8, 25),
        ),
      ];

      ResolvedWeek.of(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 8, 24),
      );

      // 원본 TimeSlot은 여전히 수학을 가진 채로 남아 있어야 한다
      expect(hongBefore.subject, '수학');
      expect(hongBefore.teacher, '홍길동');
      expect(base.length, 4);
    });
  });

  group('ResolvedWeek — 주 간 독립 보장 (§10.5 핵심 주장)', () {
    test('이벤트가 속한 주에서는 교체가 반영되고, 다른 주에서는 원본 그대로다', () {
      final base = _baseTimetable();
      final events = [
        _historyItem(
          path: _oneToOnePath(),
          absenceDate: DateTime(2026, 8, 24), // 8월4주 월요일
          substitutionDate: DateTime(2026, 8, 25),
        ),
      ];

      final eventWeek = ResolvedWeek.of(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 8, 24),
      );
      final otherWeek = ResolvedWeek.of(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 8, 31), // 9월1주 — 이 이벤트와 무관
      );

      // 이벤트가 속한 주: 홍길동 월1은 비고, 화2에 수학이 채워진다
      expect(eventWeek.cellFor('홍길동', 1, 1)?.subject, isNull);
      expect(eventWeek.cellFor('홍길동', 2, 2)?.subject, '수학');
      // 김철수도 대칭적으로 이동
      expect(eventWeek.cellFor('김철수', 2, 2)?.subject, isNull);
      expect(eventWeek.cellFor('김철수', 1, 1)?.subject, '음악');

      // 다른 주: 완전히 원본 그대로 (P1·P3가 해소되었다는 직접적 증거)
      expect(otherWeek.cellFor('홍길동', 1, 1)?.subject, '수학');
      expect(otherWeek.cellFor('홍길동', 2, 2)?.subject, isNull);
      expect(otherWeek.cellFor('김철수', 2, 2)?.subject, '음악');
      expect(otherWeek.cellFor('김철수', 1, 1)?.subject, isNull);
    });

    test('같은 요일·교시라도 이벤트가 없는 주는 항상 원본과 동일하다 (P2 회귀 방지)', () {
      final base = _baseTimetable();
      // 8월4주에 교체 이벤트가 있어도, 9월1주는 원본 그대로여야
      // "같은 칸에 다른 날짜로 재교체"가 가능해진다.
      final events = [
        _historyItem(
          path: _oneToOnePath(),
          absenceDate: DateTime(2026, 8, 27), // 목요일
          substitutionDate: DateTime(2026, 8, 28),
        ),
      ];

      final nextWeek = ResolvedWeek.of(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 9, 7),
      );

      expect(nextWeek.cellFor('홍길동', 1, 1)?.subject, '수학');
    });
  });

  group('ResolvedWeek — 보강(교사 간 이동)', () {
    test('보강은 source 교사를 비우고 target 교사에 내용을 채운다', () {
      final base = [
        ..._baseTimetable(),
        TimeSlot(teacher: '이영희', dayOfWeek: 1, period: 1), // 이영희 월1 비어있음
      ];
      final events = [
        ExchangeHistoryItem.fromExchangePath(
          _supplementPath(),
          absenceDate: DateTime(2026, 8, 24),
          substitutionDate: DateTime(2026, 8, 24),
        ),
      ];

      final resolved = ResolvedWeek.of(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 8, 24),
      );

      expect(resolved.cellFor('홍길동', 1, 1)?.subject, isNull);
      expect(resolved.cellFor('이영희', 1, 1)?.subject, '수학');
      expect(resolved.cellFor('이영희', 1, 1)?.className, '1-1');
    });
  });

  group('ResolvedWeek — 되돌린 이벤트 제외', () {
    test('isReverted가 true인 이벤트는 합성에서 제외된다', () {
      final base = _baseTimetable();
      final item = _historyItem(
        path: _oneToOnePath(),
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      ).copyWithReverted(true);

      final resolved = ResolvedWeek.of(
        base: base,
        events: [item],
        weekMonday: DateTime(2026, 8, 24),
      );

      expect(resolved.cellFor('홍길동', 1, 1)?.subject, '수학');
    });
  });

  group('ResolvedWeek — 미구현 경로 타입', () {
    test('CircularExchangePath는 아직 지원하지 않아 명시적으로 예외를 던진다', () {
      final nodes = [
        ExchangeNode(
          teacherName: 'A',
          day: '월',
          period: 1,
          className: '1-1',
          subjectName: '수학',
        ),
        ExchangeNode(
          teacherName: 'B',
          day: '화',
          period: 2,
          className: '1-2',
          subjectName: '영어',
        ),
        ExchangeNode(
          teacherName: 'C',
          day: '수',
          period: 3,
          className: '1-3',
          subjectName: '과학',
        ),
      ];
      final path = CircularExchangePath.fromNodes([...nodes, nodes.first]);

      expect(() => exchangePathMoves(path), throwsA(isA<UnimplementedError>()));
    });
  });
}

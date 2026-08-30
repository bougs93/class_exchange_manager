import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/dual_exchange_path.dart';
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

  group('ResolvedWeek — 순환 교체 (§10.8 4단계)', () {
    ExchangeNode node(String teacher, String day, int period, String subject) {
      return ExchangeNode(
        teacherName: teacher,
        day: day,
        period: period,
        className: '1-1',
        subjectName: subject,
      );
    }

    test('각 교사가 자기 행 안에서 다음 노드의 시간으로 이동한다', () {
      // A월1 → B화2 → C수3 → (A월1로 복귀)
      final a = node('A', '월', 1, '수학');
      final b = node('B', '화', 2, '영어');
      final c = node('C', '수', 3, '과학');
      final path = CircularExchangePath.fromNodes([a, b, c, a]);

      final moves = exchangePathMoves(path);

      // 마지막 복귀 노드는 이동을 만들지 않으므로 3건
      expect(moves.length, 3);

      // A는 자기 월1 → 자기 화2 (다음 노드의 '시간'만 가져오고 교사는 자기 자신)
      expect(moves[0].fromTeacher, 'A');
      expect(moves[0].toTeacher, 'A');
      expect(moves[0].fromDay, 1);
      expect(moves[0].fromPeriod, 1);
      expect(moves[0].toDay, 2);
      expect(moves[0].toPeriod, 2);

      // B는 자기 화2 → 자기 수3
      expect(moves[1].fromTeacher, 'B');
      expect(moves[1].toTeacher, 'B');
      expect(moves[1].toDay, 3);
      expect(moves[1].toPeriod, 3);

      // C는 자기 수3 → 자기 월1 (복귀 노드의 시간)
      expect(moves[2].fromTeacher, 'C');
      expect(moves[2].toTeacher, 'C');
      expect(moves[2].toDay, 1);
      expect(moves[2].toPeriod, 1);
    });

    test('3인 순환 교체가 합성 결과에 올바르게 반영된다', () {
      final a = node('A', '월', 1, '수학');
      final b = node('B', '화', 2, '영어');
      final c = node('C', '수', 3, '과학');
      final path = CircularExchangePath.fromNodes([a, b, c, a]);

      final base = [
        TimeSlot(
          teacher: 'A',
          subject: '수학',
          className: '1-1',
          dayOfWeek: 1,
          period: 1,
        ),
        TimeSlot(teacher: 'A', dayOfWeek: 2, period: 2),
        TimeSlot(
          teacher: 'B',
          subject: '영어',
          className: '1-1',
          dayOfWeek: 2,
          period: 2,
        ),
        TimeSlot(teacher: 'B', dayOfWeek: 3, period: 3),
        TimeSlot(
          teacher: 'C',
          subject: '과학',
          className: '1-1',
          dayOfWeek: 3,
          period: 3,
        ),
        TimeSlot(teacher: 'C', dayOfWeek: 1, period: 1),
      ];

      final resolved = ResolvedWeek.of(
        base: base,
        events: [
          ExchangeHistoryItem.fromExchangePath(
            path,
            absenceDate: DateTime(2026, 8, 24),
            substitutionDate: DateTime(2026, 8, 25),
          ),
        ],
        weekMonday: DateTime(2026, 8, 24),
      );

      // 각 교사의 수업이 다음 노드의 시간으로 옮겨가고 원래 자리는 빈다
      expect(resolved.cellFor('A', 1, 1)?.subject, isNull);
      expect(resolved.cellFor('A', 2, 2)?.subject, '수학');
      expect(resolved.cellFor('B', 2, 2)?.subject, isNull);
      expect(resolved.cellFor('B', 3, 3)?.subject, '영어');
      expect(resolved.cellFor('C', 3, 3)?.subject, isNull);
      expect(resolved.cellFor('C', 1, 1)?.subject, '과학');
    });
  });

  group('ResolvedWeek — 2중 교체 (§10.8 4단계)', () {
    test('1단계(node1↔node2) 다음 2단계(nodeA↔nodeB) 순서로 분해된다', () {
      // nodeA(이숙희 월1 결강) / nodeB(손혜옥 월4 대체)
      // node2 = A교사(이숙희)의 B시간(월4) 수업 → 1단계로 비워야 함
      // node1 = node2와 교체할 상대(박지혜 월5)
      final nodeA = ExchangeNode(
        teacherName: '이숙희',
        day: '월',
        period: 1,
        className: '1-1',
        subjectName: '국어',
      );
      final nodeB = ExchangeNode(
        teacherName: '손혜옥',
        day: '월',
        period: 4,
        className: '1-1',
        subjectName: '국어',
      );
      final node2 = ExchangeNode(
        teacherName: '이숙희',
        day: '월',
        period: 4,
        className: '2-1',
        subjectName: '국어',
      );
      final node1 = ExchangeNode(
        teacherName: '박지혜',
        day: '월',
        period: 5,
        className: '2-1',
        subjectName: '국어',
      );

      final path = DualExchangePath.build(
        nodeA: nodeA,
        nodeB: nodeB,
        node1: node1,
        node2: node2,
      );

      final moves = exchangePathMoves(path);

      // 1:1 스왑 2회 = 자기-이동 4건
      expect(moves.length, 4);

      // 앞 2건은 1단계(node1 ↔ node2)
      expect(moves[0].fromTeacher, '박지혜');
      expect(moves[1].fromTeacher, '이숙희');
      expect(moves[1].fromPeriod, 4); // node2 자리를 비운다
      expect(moves[1].toPeriod, 5);

      // 뒤 2건은 2단계(nodeA ↔ nodeB)
      expect(moves[2].fromTeacher, '이숙희');
      expect(moves[2].fromPeriod, 1); // 결강 셀
      expect(moves[2].toPeriod, 4); // 1단계에서 비워진 자리로
      expect(moves[3].fromTeacher, '손혜옥');
    });
  });
}

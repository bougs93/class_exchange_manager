import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/supplement_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/utils/resolved_week.dart';

/// 정원길 수1(기술가정), 박은선 월1(기술가정). 나머지는 빈 슬롯.
List<TimeSlot> _baseTimetable() {
  return [
    TimeSlot(
      teacher: '정원길',
      subject: '기술가정',
      className: '3-8',
      dayOfWeek: 3, // 수
      period: 1,
    ),
    TimeSlot(teacher: '정원길', dayOfWeek: 1, period: 1), // 월1 비어있음
    TimeSlot(
      teacher: '박은선',
      subject: '기술가정',
      className: '3-8',
      dayOfWeek: 1, // 월
      period: 1,
    ),
    TimeSlot(teacher: '박은선', dayOfWeek: 3, period: 1), // 수1 비어있음
  ];
}

OneToOneExchangePath _oneToOnePath({
  required String sourceDay,
  required String targetDay,
}) {
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
      day: sourceDay,
      period: 1,
      className: '3-8',
      subjectName: '기술가정',
    ),
    targetNode: ExchangeNode(
      teacherName: '박은선',
      day: targetDay,
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

TimeSlot? _find(List<TimeSlot> slots, String teacher, int day, int period) {
  for (final s in slots) {
    if (s.teacher == teacher && s.dayOfWeek == day && s.period == period) {
      return s;
    }
  }
  return null;
}

void main() {
  group('ResolvedWeek.dateAware — 같은 주 케이스는 of()와 완전히 동일하다', () {
    test('1:1 교체 — 결강일·교체일이 모두 같은 주에 있으면 결과가 100% 동일하다', () {
      final base = _baseTimetable();
      final path = _oneToOnePath(sourceDay: '수', targetDay: '월');
      final events = [
        ExchangeHistoryItem.fromExchangePath(
          path,
          absenceDate: DateTime(2026, 10, 14), // 수, 10월2주
          substitutionDate: DateTime(2026, 10, 12), // 월, 같은 10월2주
        ),
      ];

      final ofResult = ResolvedWeek.of(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 10, 12),
      ).toTimeSlots(base);
      final dateAwareResult = ResolvedWeek.dateAware(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 10, 12),
      ).toTimeSlots(base);

      expect(dateAwareResult.length, ofResult.length);
      for (var i = 0; i < ofResult.length; i++) {
        expect(dateAwareResult[i].teacher, ofResult[i].teacher);
        expect(dateAwareResult[i].dayOfWeek, ofResult[i].dayOfWeek);
        expect(dateAwareResult[i].period, ofResult[i].period);
        expect(dateAwareResult[i].subject, ofResult[i].subject);
        expect(dateAwareResult[i].className, ofResult[i].className);
      }
    });

    test('보강 — 결강일·교체일이 같은 주면 결과가 동일하다', () {
      final base = _baseTimetable();
      final path = SupplementExchangePath.simple(
        id: 'supplement-same-week',
        sourceTeacher: '정원길',
        sourceDay: '수',
        sourcePeriod: 1,
        targetTeacher: '박은선',
        targetDay: '월',
        targetPeriod: 1,
        className: '3-8',
        subject: '기술가정',
      );
      final events = [
        ExchangeHistoryItem.fromExchangePath(
          path,
          absenceDate: DateTime(2026, 10, 14),
          substitutionDate: DateTime(2026, 10, 12),
        ),
      ];

      final ofResult = ResolvedWeek.of(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 10, 12),
      ).toTimeSlots(base);
      final dateAwareResult = ResolvedWeek.dateAware(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 10, 12),
      ).toTimeSlots(base);

      for (var i = 0; i < ofResult.length; i++) {
        expect(dateAwareResult[i].subject, ofResult[i].subject);
        expect(dateAwareResult[i].teacher, ofResult[i].teacher);
      }
    });
  });

  group('ResolvedWeek.dateAware — 다른 주로 넘어가는 1:1 교체', () {
    // 결강 10.14(수, 10월2주=월요일10.12) / 교체 10.26(월, 10월4주=월요일10.26)
    final base = _baseTimetable();
    final path = _oneToOnePath(sourceDay: '수', targetDay: '월');
    final events = [
      ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 10, 14),
        substitutionDate: DateTime(2026, 10, 26),
      ),
    ];

    test('결강일 주(10월2주)에는 빠지는 쪽만 반영되고 채워지는 쪽은 없다', () {
      final result = ResolvedWeek.dateAware(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 10, 12),
      ).toTimeSlots(base);

      // 정원길 수1(본인 자리)은 비워진다
      final jung = _find(result, '정원길', 3, 1)!;
      expect(jung.subject, isNull);
      expect(jung.isEmpty, isTrue);

      // 박은선 월1(본인 자리)은 이 주에서는 아직 그대로다 — 채워지는 쪽은
      // 실제 날짜(10.26)가 속한 다른 주에서만 나타나야 한다
      final park = _find(result, '박은선', 1, 1)!;
      expect(park.subject, '기술가정');
      expect(park.teacher, '박은선');

      // 박은선 자신의 수1 자리(base에 빈 placeholder 행)에는 정원길의 내용이
      // 채워진다 — "박은선이 정원길 대신 수요일 수업을 맡는다"를 박은선 자신의
      // 행 안에서 표현하는 방식
      final parkAtOwnWed = _find(result, '박은선', 3, 1)!;
      expect(parkAtOwnWed.subject, '기술가정');
      expect(parkAtOwnWed.teacher, '박은선');
    });

    test('교체일 주(10월4주)에는 채워지는 쪽만 반영되고 빠지는 쪽은 없다', () {
      final result = ResolvedWeek.dateAware(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 10, 26),
      ).toTimeSlots(base);

      // 정원길 수1(본인 자리)은 이 주에서는 원본 그대로(비워지지 않음) —
      // 빠지는 쪽은 실제 날짜(10.14)가 속한 다른 주에서만 나타나야 한다
      final jung = _find(result, '정원길', 3, 1)!;
      expect(jung.subject, '기술가정');
      expect(jung.teacher, '정원길');

      // 박은선 월1(본인 자리)은 비워진다
      final parkSlot = _find(result, '박은선', 1, 1)!;
      expect(parkSlot.isEmpty, isTrue);

      // 정원길 자신의 월1 자리(base에 빈 자리로 이미 있던 placeholder 행)에
      // 박은선의 내용(기술가정)이 채워진다 — "정원길이 박은선 시간으로 이동"을
      // 정원길 자신의 행 안에서 표현하는 방식(§10.4 자기-이동 규칙)
      final jungAtOwnMonday = _find(result, '정원길', 1, 1)!;
      expect(jungAtOwnMonday.subject, '기술가정');
      expect(jungAtOwnMonday.teacher, '정원길');
    });

    test('관계없는 주(10월3주)에는 아무 변화도 없다 — 원본 그대로', () {
      final result = ResolvedWeek.dateAware(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 10, 19),
      ).toTimeSlots(base);

      final jung = _find(result, '정원길', 3, 1)!;
      final park = _find(result, '박은선', 1, 1)!;
      expect(jung.subject, '기술가정');
      expect(park.subject, '기술가정');
    });
  });

  group('ResolvedWeek.dateAware — 순환 교체(날짜 미확정)는 of()와 동일하게 동작한다', () {
    test('결강일 주에 양쪽이 함께 적용되고, 다른 주는 영향받지 않는다', () {
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
      final path = CircularExchangePath.fromNodes([a, b, c, a]);
      final events = [
        ExchangeHistoryItem.fromExchangePath(
          path,
          absenceDate: DateTime(2026, 8, 24), // 월, 8월4주
          substitutionDate: DateTime(2026, 8, 25),
        ),
      ];

      final ofResult = ResolvedWeek.of(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 8, 24),
      ).toTimeSlots(base);
      final dateAwareResult = ResolvedWeek.dateAware(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 8, 24),
      ).toTimeSlots(base);

      for (var i = 0; i < ofResult.length; i++) {
        expect(dateAwareResult[i].subject, ofResult[i].subject);
        expect(dateAwareResult[i].teacher, ofResult[i].teacher);
      }

      // 다른 주는 영향받지 않는다 (원본 그대로)
      final otherWeek = ResolvedWeek.dateAware(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 9, 7),
      ).toTimeSlots(base);
      expect(otherWeek[0].subject, '수학'); // A 월1 원본 그대로
    });
  });

  group('ResolvedWeek.dateAware — 요일과 실제 날짜가 어긋나면 of()와 동일하게 폴백한다', () {
    test('sourceDay와 absenceDate의 요일이 다르면 unsupported로 폴백', () {
      final base = _baseTimetable();
      // sourceDay는 '수'인데 absenceDate 실제 요일은 월요일 — 불일치
      final path = _oneToOnePath(sourceDay: '수', targetDay: '월');
      final events = [
        ExchangeHistoryItem.fromExchangePath(
          path,
          absenceDate: DateTime(2026, 10, 12), // 월요일 — sourceDay('수')와 불일치
          substitutionDate: DateTime(2026, 10, 14),
        ),
      ];

      final ofResult = ResolvedWeek.of(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 10, 12),
      ).toTimeSlots(base);
      final dateAwareResult = ResolvedWeek.dateAware(
        base: base,
        events: events,
        weekMonday: DateTime(2026, 10, 12),
      ).toTimeSlots(base);

      for (var i = 0; i < ofResult.length; i++) {
        expect(dateAwareResult[i].subject, ofResult[i].subject);
        expect(dateAwareResult[i].teacher, ofResult[i].teacher);
      }
    });
  });
}

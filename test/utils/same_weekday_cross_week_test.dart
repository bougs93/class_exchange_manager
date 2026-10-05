import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/lesson.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/supplement_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/event_date_resolver.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/utils/lesson_projection.dart';
import 'package:class_exchange_manager/utils/resolved_week.dart';

/// 회귀 테스트 (2026-10-05): 결강일과 교체일이 **다른 주의 같은 요일**인 교체.
///
/// 예전에는 확정 날짜를 요일 → 날짜 맵으로 찾아서 한쪽 날짜가 다른 쪽을
/// 덮어썼다. 그 결과 날짜 반영 ON 화면에서 결강일 주의 교체가 통째로
/// 사라지고, 교체일 주에는 교체 전체가 한꺼번에 반영됐다.
///
/// 실제 사례: 정원길 10.07(수) 4교시 3-3 기술가정 ↔ 이민숙 10.14(수) 6교시 3-3 사회.

final _wed1007 = DateTime(2026, 10, 7);
final _wed1014 = DateTime(2026, 10, 14);
final _week1005 = DateTime(2026, 10, 5);
final _week1012 = DateTime(2026, 10, 12);

List<TimeSlot> _base() => [
  TimeSlot(teacher: '정원길', subject: '기술가정', className: '3-3', dayOfWeek: 3, period: 4),
  TimeSlot(teacher: '정원길', dayOfWeek: 3, period: 6),
  TimeSlot(teacher: '이민숙', dayOfWeek: 3, period: 4),
  TimeSlot(teacher: '이민숙', subject: '사회', className: '3-3', dayOfWeek: 3, period: 6),
];

OneToOneExchangePath _path({int sourcePeriod = 4, int targetPeriod = 6}) {
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: '정원길',
      day: '수',
      period: sourcePeriod,
      className: '3-3',
      subjectName: '기술가정',
    ),
    targetNode: ExchangeNode(
      teacherName: '이민숙',
      day: '수',
      period: targetPeriod,
      className: '3-3',
      subjectName: '사회',
    ),
    option: ExchangeOption(
      timeSlot: TimeSlot(
        teacher: '이민숙',
        subject: '사회',
        className: '3-3',
        dayOfWeek: 3,
        period: targetPeriod,
      ),
      teacherName: '이민숙',
      type: ExchangeType.sameClass,
      priority: 1,
      reason: 'test',
    ),
  );
}

ExchangeHistoryItem _item({int sourcePeriod = 4, int targetPeriod = 6}) =>
    ExchangeHistoryItem.fromExchangePath(
      _path(sourcePeriod: sourcePeriod, targetPeriod: targetPeriod),
      absenceDate: _wed1007,
      substitutionDate: _wed1014,
    );

TimeSlot _cell(ResolvedWeek week, String teacher, int period) =>
    week.cellFor(teacher, 3, period)!;

Lesson? _lessonAt(List<Lesson> lessons, String teacher, DateTime date, int period) {
  for (final l in lessons) {
    if (l.teacher == teacher && l.date == date && l.period == period) return l;
  }
  return null;
}

void main() {
  group('resolveEventDates.forMove — 같은 요일, 다른 주', () {
    test('각 이동의 빠지는 쪽·채워지는 쪽 날짜가 섞이지 않는다', () {
      final resolution = resolveEventDates(_item());
      final moves = exchangePathMoves(_item().originalPath);

      // 1: 정원길 수4(10.07) → 정원길 수6(10.14)
      final m1 = resolution.forMove(moves[0]);
      expect(m1.from!.date, _wed1007);
      expect(m1.to!.date, _wed1014);
      expect(m1.from!.source, CellDateSource.confirmedPair);

      // 2: 이민숙 수6(10.14) → 이민숙 수4(10.07)
      final m2 = resolution.forMove(moves[1]);
      expect(m2.from!.date, _wed1014);
      expect(m2.to!.date, _wed1007);
    });

    test('forSlot은 요일이 같아도 교시로 구분한다', () {
      final resolution = resolveEventDates(_item());
      expect(resolution.forSlot(3, 4)!.date, _wed1007);
      expect(resolution.forSlot(3, 6)!.date, _wed1014);
    });

    test('같은 요일·같은 교시끼리의 교체도 forMove는 정확하다 (forSlot은 구분 불가 → null)', () {
      final item = _item(sourcePeriod: 4, targetPeriod: 4);
      final resolution = resolveEventDates(item);
      final moves = exchangePathMoves(item.originalPath);

      final m1 = resolution.forMove(moves[0]);
      expect(m1.from!.date, _wed1007);
      expect(m1.to!.date, _wed1014);
      final m2 = resolution.forMove(moves[1]);
      expect(m2.from!.date, _wed1014);
      expect(m2.to!.date, _wed1007);

      expect(resolution.forSlot(3, 4), isNull);
    });
  });

  group('ResolvedWeek.dateAware — 같은 요일, 다른 주', () {
    test('결강일 주: 정원길 수4가 비고, 이민숙 수4에 3-3 사회가 들어온다', () {
      final week = ResolvedWeek.dateAware(
        base: _base(),
        events: [_item()],
        weekMonday: _week1005,
      );

      expect(_cell(week, '정원길', 4).subject, isNull);
      expect(_cell(week, '이민숙', 4).subject, '사회');
      expect(_cell(week, '이민숙', 4).className, '3-3');
      // 6교시는 이 주와 무관 — 원본 그대로
      expect(_cell(week, '정원길', 6).subject, isNull);
      expect(_cell(week, '이민숙', 6).subject, '사회');
    });

    test('교체일 주: 이민숙 수6이 비고, 정원길 수6에 3-3 기술가정이 들어온다', () {
      final week = ResolvedWeek.dateAware(
        base: _base(),
        events: [_item()],
        weekMonday: _week1012,
      );

      expect(_cell(week, '이민숙', 6).subject, isNull);
      expect(_cell(week, '정원길', 6).subject, '기술가정');
      // 4교시는 이 주와 무관 — 원본 그대로
      expect(_cell(week, '정원길', 4).subject, '기술가정');
      expect(_cell(week, '이민숙', 4).subject, isNull);
    });

    test('보강도 같은 요일·다른 주를 정확히 나눈다', () {
      final item = ExchangeHistoryItem.fromExchangePath(
        SupplementExchangePath.simple(
          id: 'supplement-same-weekday',
          sourceTeacher: '정원길',
          sourceDay: '수',
          sourcePeriod: 4,
          targetTeacher: '이민숙',
          targetDay: '수',
          targetPeriod: 6,
          className: '3-3',
          subject: '기술가정',
        ),
        absenceDate: _wed1007,
        substitutionDate: _wed1014,
      );

      final w1 = ResolvedWeek.dateAware(base: _base(), events: [item], weekMonday: _week1005);
      expect(_cell(w1, '정원길', 4).subject, isNull);
      expect(_cell(w1, '이민숙', 6).subject, '사회'); // 아직 안 채워짐

      final w2 = ResolvedWeek.dateAware(base: _base(), events: [item], weekMonday: _week1012);
      expect(_cell(w2, '정원길', 4).subject, '기술가정'); // 이 주엔 안 빠짐
      expect(_cell(w2, '이민숙', 6).subject, '기술가정');
    });
  });

  group('lesson_projection — 같은 요일, 다른 주', () {
    List<Lesson> snapshot() => [
      for (final date in [_wed1007, _wed1014])
        for (final slot in _base())
          Lesson(
            id: '${slot.teacher}_${date.day}_${slot.period}',
            timetableId: 't',
            date: date,
            period: slot.period!,
            teacher: slot.teacher!,
            subject: slot.subject,
            className: slot.className,
          ),
    ];

    test('project가 결강일·교체일 칸을 각각 맞는 날짜에 배치한다', () {
      final projected = project(
        snapshot: snapshot(),
        activeEvents: [_item()],
        timetableId: 't',
      );

      expect(_lessonAt(projected, '정원길', _wed1007, 4)!.subject, isNull);
      expect(_lessonAt(projected, '이민숙', _wed1007, 4)!.subject, '사회');
      expect(_lessonAt(projected, '이민숙', _wed1014, 6)!.subject, isNull);
      expect(_lessonAt(projected, '정원길', _wed1014, 6)!.subject, '기술가정');
      // 관계없는 칸은 원본 그대로
      expect(_lessonAt(projected, '정원길', _wed1014, 4)!.subject, '기술가정');
      expect(_lessonAt(projected, '이민숙', _wed1007, 6)!.subject, '사회');
    });

    test('touchedCellsFor가 실제로 건드리는 날짜를 돌려준다', () {
      final touched = {
        for (final c in touchedCellsFor(_item()))
          '${c.teacher}|${c.date.day}|${c.period}',
      };
      expect(touched, {'정원길|7|4', '이민숙|7|4', '이민숙|14|6', '정원길|14|6'});
    });
  });
}

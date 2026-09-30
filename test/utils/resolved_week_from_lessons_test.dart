import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/dual_exchange_path.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/lesson.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/models/supplement_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/semester_timetable_generator.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/utils/lesson_projection.dart';
import 'package:class_exchange_manager/utils/resolved_week.dart';

// lesson_projection_test.dart(S5.3)와 정확히 같은 픽스처를 재사용한다 —
// project()가 이미 dateAware와 동등함을 증명했으므로, fromLessons가
// project()의 결과를 "덮어쓰기"만 해도 같은 결과가 나오는지 확인하면
// fromLessons ≡ dateAware(같은 주 한정)임이 증명된다(S5.5.1).
const _timetableId = 'tt_from_lessons_test';
final _semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);

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

List<Lesson> _snapshotFor(List<TimeSlot> base) {
  return SemesterTimetableGenerator.generate(
    timetableId: _timetableId,
    timeSlots: base,
    semester: _semester,
  );
}

bool _sameWeek(DateTime date, DateTime weekMonday) {
  final friday = weekMonday.add(const Duration(days: 4));
  return !date.isBefore(weekMonday) && !date.isAfter(friday);
}

/// `getTouchedLessonsForWeek`의 계약(그 주 Mon~Fri만) 을 메모리에서 흉내낸다 —
/// Repository 없이 project()의 순수 결과만으로 fromLessons를 검증하기 위한
/// 어댑터.
List<Lesson> _touchedInWeek(List<Lesson> projected, DateTime weekMonday) {
  return projected.where((l) => _sameWeek(l.date, weekMonday)).toList();
}

void main() {
  group('ResolvedWeek.fromLessons — project()·getTouchedLessonsForWeek 결과로 dateAware와 동등함을 증명', () {
    test('1:1 교체 — 같은 주(결강·교체일 모두 10월2주)', () {
      final base = _baseTimetable();
      final path = _oneToOnePath(sourceDay: '수', targetDay: '월');
      final events = [
        ExchangeHistoryItem.fromExchangePath(
          path,
          absenceDate: DateTime(2026, 10, 14),
          substitutionDate: DateTime(2026, 10, 12),
        ),
      ];
      final weekMonday = DateTime(2026, 10, 12);

      final expected = ResolvedWeek.dateAware(
        base: base,
        events: events,
        weekMonday: weekMonday,
      ).toTimeSlots(base);

      final projected = project(
        snapshot: _snapshotFor(base),
        activeEvents: events,
        timetableId: _timetableId,
      );
      final actual = ResolvedWeek.fromLessons(
        base: base,
        touchedLessons: _touchedInWeek(projected, weekMonday),
        weekMonday: weekMonday,
      ).toTimeSlots(base);

      for (var i = 0; i < base.length; i++) {
        expect(actual[i].subject, expected[i].subject, reason: 'index $i');
        expect(actual[i].className, expected[i].className, reason: 'index $i');
        expect(actual[i].teacher, expected[i].teacher, reason: 'index $i');
      }
    });

    test('보강 — 같은 주', () {
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
      final weekMonday = DateTime(2026, 10, 12);

      final expected = ResolvedWeek.dateAware(
        base: base,
        events: events,
        weekMonday: weekMonday,
      ).toTimeSlots(base);

      final projected = project(
        snapshot: _snapshotFor(base),
        activeEvents: events,
        timetableId: _timetableId,
      );
      final actual = ResolvedWeek.fromLessons(
        base: base,
        touchedLessons: _touchedInWeek(projected, weekMonday),
        weekMonday: weekMonday,
      ).toTimeSlots(base);

      for (var i = 0; i < base.length; i++) {
        expect(actual[i].subject, expected[i].subject, reason: 'index $i');
        expect(actual[i].teacher, expected[i].teacher, reason: 'index $i');
      }
    });

    test('다른 주로 넘어가는 1:1 교체 — 결강일 주·교체일 주·관계없는 주 전부 일치', () {
      final base = _baseTimetable();
      final path = _oneToOnePath(sourceDay: '수', targetDay: '월');
      final events = [
        ExchangeHistoryItem.fromExchangePath(
          path,
          absenceDate: DateTime(2026, 10, 14), // 10월2주
          substitutionDate: DateTime(2026, 10, 26), // 10월4주
        ),
      ];
      final projected = project(
        snapshot: _snapshotFor(base),
        activeEvents: events,
        timetableId: _timetableId,
      );

      for (final weekMonday in [
        DateTime(2026, 10, 12), // 결강일 주
        DateTime(2026, 10, 19), // 관계없는 주
        DateTime(2026, 10, 26), // 교체일 주
      ]) {
        final expected = ResolvedWeek.dateAware(
          base: base,
          events: events,
          weekMonday: weekMonday,
        ).toTimeSlots(base);
        final actual = ResolvedWeek.fromLessons(
          base: base,
          touchedLessons: _touchedInWeek(projected, weekMonday),
          weekMonday: weekMonday,
        ).toTimeSlots(base);

        for (var i = 0; i < base.length; i++) {
          expect(
            actual[i].subject,
            expected[i].subject,
            reason: '주 $weekMonday, index $i',
          );
          expect(
            actual[i].teacher,
            expected[i].teacher,
            reason: '주 $weekMonday, index $i',
          );
        }
      }
    });

    test('순환 교체(날짜 미확정) — 결강일 주에 반영, 다른 주는 원본 그대로', () {
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

      final projected = project(
        snapshot: _snapshotFor(base),
        activeEvents: events,
        timetableId: _timetableId,
      );

      for (final weekMonday in [
        DateTime(2026, 8, 24), // 결강일 주
        DateTime(2026, 9, 7), // 관계없는 주
      ]) {
        final expected = ResolvedWeek.dateAware(
          base: base,
          events: events,
          weekMonday: weekMonday,
        ).toTimeSlots(base);
        final actual = ResolvedWeek.fromLessons(
          base: base,
          touchedLessons: _touchedInWeek(projected, weekMonday),
          weekMonday: weekMonday,
        ).toTimeSlots(base);

        for (var i = 0; i < base.length; i++) {
          expect(
            actual[i].subject,
            expected[i].subject,
            reason: '주 $weekMonday, index $i',
          );
          expect(
            actual[i].teacher,
            expected[i].teacher,
            reason: '주 $weekMonday, index $i',
          );
        }
      }
    });

    test('순환 교체 — 노드 하나만 확정 날짜(다른 주)로 지정해도 fromLessons ≡ dateAware (S5.6)', () {
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
          absenceDate: DateTime(2026, 8, 24),
          substitutionDate: DateTime(2026, 8, 25),
        ).copyWithNodeDate('화', 2, DateTime(2026, 9, 8)),
      ];

      final projected = project(
        snapshot: _snapshotFor(base),
        activeEvents: events,
        timetableId: _timetableId,
      );

      for (final weekMonday in [
        DateTime(2026, 8, 24),
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 14),
      ]) {
        final expected = ResolvedWeek.dateAware(
          base: base,
          events: events,
          weekMonday: weekMonday,
        ).toTimeSlots(base);
        final actual = ResolvedWeek.fromLessons(
          base: base,
          touchedLessons: _touchedInWeek(projected, weekMonday),
          weekMonday: weekMonday,
        ).toTimeSlots(base);

        for (var i = 0; i < base.length; i++) {
          expect(
            actual[i].subject,
            expected[i].subject,
            reason: '주 $weekMonday, index $i',
          );
          expect(
            actual[i].teacher,
            expected[i].teacher,
            reason: '주 $weekMonday, index $i',
          );
        }
      }
    });

    test('2중 교체 — 두 단계가 서로 다른 주로 확정돼도 fromLessons ≡ dateAware (S5.6, R7 게이트)', () {
      final base = [
        TimeSlot(
          teacher: '박지혜',
          subject: '수학',
          className: '1-1',
          dayOfWeek: 1,
          period: 1,
        ),
        TimeSlot(teacher: '박지혜', dayOfWeek: 2, period: 4),
        TimeSlot(
          teacher: '이숙희',
          subject: '영어',
          className: '1-1',
          dayOfWeek: 2,
          period: 4,
        ),
        TimeSlot(teacher: '이숙희', dayOfWeek: 1, period: 4),
        TimeSlot(
          teacher: '손혜옥',
          subject: '국어',
          className: '1-1',
          dayOfWeek: 2,
          period: 5,
        ),
      ];
      final nodeA = ExchangeNode(
        teacherName: '박지혜',
        day: '월',
        period: 1,
        className: '1-1',
        subjectName: '수학',
      );
      final nodeB = ExchangeNode(
        teacherName: '이숙희',
        day: '화',
        period: 4,
        className: '1-1',
        subjectName: '영어',
      );
      final node1 = ExchangeNode(
        teacherName: '이숙희',
        day: '월',
        period: 4,
        className: '1-1',
        subjectName: '영어',
      );
      final node2 = ExchangeNode(
        teacherName: '손혜옥',
        day: '화',
        period: 5,
        className: '1-1',
        subjectName: '국어',
      );
      final path = DualExchangePath.build(
        nodeA: nodeA,
        nodeB: nodeB,
        node1: node1,
        node2: node2,
      );
      final events = [
        ExchangeHistoryItem.fromExchangePath(
          path,
          absenceDate: DateTime(2026, 8, 24),
          substitutionDate: DateTime(2026, 8, 25),
        ).copyWithNodeDate('월', 1, DateTime(2026, 9, 7))
            .copyWithNodeDate('화', 4, DateTime(2026, 9, 8)),
      ];

      final projected = project(
        snapshot: _snapshotFor(base),
        activeEvents: events,
        timetableId: _timetableId,
      );

      for (final weekMonday in [
        DateTime(2026, 8, 24),
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 14),
      ]) {
        final expected = ResolvedWeek.dateAware(
          base: base,
          events: events,
          weekMonday: weekMonday,
        ).toTimeSlots(base);
        final actual = ResolvedWeek.fromLessons(
          base: base,
          touchedLessons: _touchedInWeek(projected, weekMonday),
          weekMonday: weekMonday,
        ).toTimeSlots(base);

        for (var i = 0; i < base.length; i++) {
          expect(
            actual[i].subject,
            expected[i].subject,
            reason: '주 $weekMonday, index $i',
          );
          expect(
            actual[i].teacher,
            expected[i].teacher,
            reason: '주 $weekMonday, index $i',
          );
        }
      }
    });

    test('이벤트가 없으면 fromLessons는 base 그대로다 (건드린 칸 없음)', () {
      final base = _baseTimetable();
      final weekMonday = DateTime(2026, 10, 12);

      final actual = ResolvedWeek.fromLessons(
        base: base,
        touchedLessons: const [],
        weekMonday: weekMonday,
      ).toTimeSlots(base);

      for (var i = 0; i < base.length; i++) {
        expect(actual[i].subject, base[i].subject);
        expect(actual[i].className, base[i].className);
      }
    });

    test('isExchangeable·exchangeReason은 SQLite 값이 아니라 base 값을 유지한다', () {
      final base = [
        TimeSlot(
          teacher: '정원길',
          subject: '기술가정',
          className: '3-8',
          dayOfWeek: 3,
          period: 1,
          isExchangeable: false,
          exchangeReason: '특별교실',
        ),
      ];
      final touchedLessons = [
        Lesson(
          id: 'l1',
          timetableId: _timetableId,
          date: DateTime(2026, 10, 14), // 수
          period: 1,
          teacher: '정원길',
          subject: '변경된과목',
          className: '9-9',
          isExchangeable: true, // SQLite 쪽 값이 true라도 base의 false가 이겨야 한다
        ),
      ];

      final actual = ResolvedWeek.fromLessons(
        base: base,
        touchedLessons: touchedLessons,
        weekMonday: DateTime(2026, 10, 12),
      ).toTimeSlots(base);

      expect(actual.single.subject, '변경된과목');
      expect(actual.single.isExchangeable, isFalse);
      expect(actual.single.exchangeReason, '특별교실');
    });
  });
}

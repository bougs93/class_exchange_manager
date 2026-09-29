import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/circular_exchange_path.dart';
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

const _timetableId = 'tt_projection_test';
final _semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);

/// 정원길 수1(기술가정), 박은선 월1(기술가정). 나머지는 빈 슬롯.
/// resolved_week_date_aware_test.dart와 동일한 픽스처.
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

Lesson? _lessonAt(List<Lesson> lessons, String teacher, DateTime date, int period) {
  for (final lesson in lessons) {
    if (lesson.teacher == teacher &&
        lesson.date.year == date.year &&
        lesson.date.month == date.month &&
        lesson.date.day == date.day &&
        lesson.period == period) {
      return lesson;
    }
  }
  return null;
}

/// [project] 결과를 [weekMonday]가 속한 주로 필터해, [base]의 각 TimeSlot
/// 좌표에 대응하는 실제 날짜의 Lesson을 찾아 [ResolvedWeek]와 같은 순서의
/// 리스트로 만든다 — 두 결과를 나란히 비교하기 위한 어댑터.
List<Lesson?> _projectWeek(
  List<Lesson> projected,
  List<TimeSlot> base,
  DateTime weekMonday,
) {
  return base.map((slot) {
    final day = slot.dayOfWeek!;
    final period = slot.period!;
    final date = weekMonday.add(Duration(days: day - 1));
    return _lessonAt(projected, slot.teacher!, date, period);
  }).toList();
}

void main() {
  group('project — ResolvedWeek.dateAware와 결과가 일치한다', () {
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
      final actual = _projectWeek(projected, base, weekMonday);

      for (var i = 0; i < base.length; i++) {
        expect(actual[i]?.subject, expected[i].subject, reason: 'index $i');
        expect(actual[i]?.className, expected[i].className, reason: 'index $i');
        expect(actual[i]?.teacher, expected[i].teacher, reason: 'index $i');
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
      final actual = _projectWeek(projected, base, weekMonday);

      for (var i = 0; i < base.length; i++) {
        expect(actual[i]?.subject, expected[i].subject, reason: 'index $i');
        expect(actual[i]?.teacher, expected[i].teacher, reason: 'index $i');
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
        final actual = _projectWeek(projected, base, weekMonday);

        for (var i = 0; i < base.length; i++) {
          expect(
            actual[i]?.subject,
            expected[i].subject,
            reason: '주 $weekMonday, index $i',
          );
          expect(
            actual[i]?.teacher,
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
        final actual = _projectWeek(projected, base, weekMonday);

        for (var i = 0; i < base.length; i++) {
          expect(
            actual[i]?.subject,
            expected[i].subject,
            reason: '주 $weekMonday, index $i',
          );
          expect(
            actual[i]?.teacher,
            expected[i].teacher,
            reason: '주 $weekMonday, index $i',
          );
        }
      }
    });

    test('요일과 실제 날짜가 어긋나면 결강일 주 기준으로 안전하게 폴백한다', () {
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
      final actual = _projectWeek(projected, base, weekMonday);

      for (var i = 0; i < base.length; i++) {
        expect(actual[i]?.subject, expected[i].subject, reason: 'index $i');
        expect(actual[i]?.teacher, expected[i].teacher, reason: 'index $i');
      }
    });

    test('이벤트가 없으면 project는 원본 스냅샷과 동일하다', () {
      final base = _baseTimetable();
      final snapshot = _snapshotFor(base);

      final projected = project(
        snapshot: snapshot,
        activeEvents: const [],
        timetableId: _timetableId,
      );

      expect(projected.length, snapshot.length);
    });
  });
}

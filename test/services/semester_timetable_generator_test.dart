import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/semester_timetable_generator.dart';

void main() {
  group('SemesterTimetableGenerator.generate', () {
    test('한 칸을 학기 안의 모든 해당 요일 날짜로 펼친다', () {
      final semester = SchoolSemester(
        schoolYear: 2026,
        semester: 1,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 15),
      );
      final timeSlots = [
        TimeSlot(
          teacher: '정원길',
          subject: '기술가정',
          className: '3-8',
          dayOfWeek: DateTime.monday,
          period: 1,
        ),
      ];

      final lessons = SemesterTimetableGenerator.generate(
        timetableId: 'tt1',
        timeSlots: timeSlots,
        semester: semester,
      );

      // 2026-03-01(일)~03-15(일) 사이의 월요일: 03-02, 03-09
      expect(lessons.length, 2);
      expect(lessons[0].date, DateTime(2026, 3, 2));
      expect(lessons[1].date, DateTime(2026, 3, 9));
      for (final lesson in lessons) {
        expect(lesson.timetableId, 'tt1');
        expect(lesson.teacher, '정원길');
        expect(lesson.subject, '기술가정');
        expect(lesson.className, '3-8');
        expect(lesson.period, 1);
      }
    });

    test('각 날짜의 수업은 서로 다른 고유 ID를 가진다', () {
      final semester = SchoolSemester(
        schoolYear: 2026,
        semester: 1,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
      );
      final timeSlots = [
        TimeSlot(
          teacher: 'A',
          subject: '수학',
          dayOfWeek: DateTime.monday,
          period: 1,
        ),
      ];

      final lessons = SemesterTimetableGenerator.generate(
        timetableId: 'tt1',
        timeSlots: timeSlots,
        semester: semester,
      );

      expect(lessons.map((l) => l.id).toSet().length, lessons.length);
    });

    test('요일·교시·교사 중 하나라도 없으면 건너뛴다', () {
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 1);
      final timeSlots = [
        TimeSlot(subject: '수학', dayOfWeek: 1, period: 1), // 교사 없음
        TimeSlot(teacher: 'A', subject: '수학', period: 1), // 요일 없음
        TimeSlot(teacher: 'A', subject: '수학', dayOfWeek: 1), // 교시 없음
      ];

      final lessons = SemesterTimetableGenerator.generate(
        timetableId: 'tt1',
        timeSlots: timeSlots,
        semester: semester,
      );

      expect(lessons, isEmpty);
    });

    test('토·일(6, 7) 칸은 건너뛴다', () {
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 1);
      final timeSlots = [
        TimeSlot(teacher: 'A', subject: '수학', dayOfWeek: 6, period: 1),
        TimeSlot(teacher: 'A', subject: '수학', dayOfWeek: 7, period: 1),
      ];

      final lessons = SemesterTimetableGenerator.generate(
        timetableId: 'tt1',
        timeSlots: timeSlots,
        semester: semester,
      );

      expect(lessons, isEmpty);
    });

    test('빈 칸(과목·학급 없음)도 빈 교시로 생성된다 — 이후 교체 대상 조회에 필요', () {
      final semester = SchoolSemester(
        schoolYear: 2026,
        semester: 1,
        startDate: DateTime(2026, 3, 2),
        endDate: DateTime(2026, 3, 2),
      );
      final timeSlots = [
        TimeSlot(teacher: 'A', dayOfWeek: DateTime.monday, period: 1),
      ];

      final lessons = SemesterTimetableGenerator.generate(
        timetableId: 'tt1',
        timeSlots: timeSlots,
        semester: semester,
      );

      expect(lessons.length, 1);
      expect(lessons.single.isEmpty, isTrue);
    });

    test('학기 밖 요일 반복은 생성되지 않는다 (연말·연초 경계)', () {
      final semester = SchoolSemester.defaultFor(schoolYear: 2026, semester: 2);
      final timeSlots = [
        TimeSlot(
          teacher: 'A',
          subject: '수학',
          dayOfWeek: DateTime.friday,
          period: 1,
        ),
      ];

      final lessons = SemesterTimetableGenerator.generate(
        timetableId: 'tt1',
        timeSlots: timeSlots,
        semester: semester,
      );

      expect(lessons.every((l) => semester.contains(l.date)), isTrue);
      expect(lessons.last.date.isBefore(DateTime(2027, 2, 1)), isTrue);
    });
  });
}

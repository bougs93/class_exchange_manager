import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/lesson.dart';

void main() {
  group('Lesson', () {
    test('시각이 있는 DateTime을 넣어도 날짜만 남긴다', () {
      final lesson = Lesson(
        id: 'l1',
        timetableId: 'tt1',
        date: DateTime(2026, 9, 28, 13, 45, 30),
        period: 1,
        teacher: '정원길',
      );

      expect(lesson.date, DateTime(2026, 9, 28));
    });

    test('과목·학급이 모두 없으면 isEmpty가 true다', () {
      final lesson = Lesson(
        id: 'l1',
        timetableId: 'tt1',
        date: DateTime(2026, 9, 28),
        period: 1,
        teacher: '정원길',
      );

      expect(lesson.isEmpty, isTrue);
      expect(lesson.canExchange, isFalse); // 빈 수업은 교체 대상 아님
    });

    test('toMap/fromMap 왕복 시 값이 보존된다 (id는 날짜·교시가 바뀌어도 유지)', () {
      final lesson = Lesson(
        id: 'l1',
        timetableId: 'tt1',
        date: DateTime(2026, 9, 28),
        period: 3,
        teacher: '정원길',
        subject: '기술가정',
        className: '3-8',
        isExchangeable: false,
        exchangeReason: '고정 수업',
      );

      final restored = Lesson.fromMap(lesson.toMap());

      expect(restored.id, lesson.id);
      expect(restored.date, lesson.date);
      expect(restored.period, lesson.period);
      expect(restored.teacher, lesson.teacher);
      expect(restored.subject, lesson.subject);
      expect(restored.className, lesson.className);
      expect(restored.isExchangeable, isFalse);
      expect(restored.exchangeReason, '고정 수업');
    });

    test('copyWith로 날짜·교시가 바뀌어도 id는 그대로다', () {
      final lesson = Lesson(
        id: 'l1',
        timetableId: 'tt1',
        date: DateTime(2026, 9, 28),
        period: 1,
        teacher: '정원길',
      );

      final moved = lesson.copyWith(
        date: DateTime(2026, 10, 5),
        period: 2,
      );

      expect(moved.id, lesson.id);
      expect(moved.date, DateTime(2026, 10, 5));
      expect(moved.period, 2);
    });

    test('generateId는 연속 호출 시 서로 다른 값을 반환한다', () {
      final ids = List.generate(50, (_) => Lesson.generateId());
      expect(ids.toSet().length, ids.length);
    });
  });
}

import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/non_exchangeable_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// 그리드 복사본에서 찍은 교체불가가 원본(경로 탐색 입력)에 반영되는지 검증
void main() {
  TimeSlot lesson(String teacher, int day, int period) => TimeSlot(
    teacher: teacher,
    subject: '수학',
    className: '1-1',
    dayOfWeek: day,
    period: period,
  );

  bool isBlocked(TimeSlot slot) =>
      !slot.isExchangeable && slot.exchangeReason == '교체불가';

  TimeSlot? find(List<TimeSlot> slots, String teacher, int day, int period) {
    for (final s in slots) {
      if (s.teacher == teacher && s.dayOfWeek == day && s.period == period) {
        return s;
      }
    }
    return null;
  }

  test('수업 있는 칸을 교체불가로 찍으면 원본에 반영되고, 해제하면 복구된다', () {
    final base = [lesson('구길동', 2, 5)];
    final grid = base.map((s) => s.copy()).toList();
    final manager = NonExchangeableManager()..setTimeSlots(grid);

    manager.setCellAsNonExchangeable('구길동', '화', 5);
    NonExchangeableManager.syncToBase(base, grid);
    expect(isBlocked(base.single), isTrue);
    expect(base.single.subject, '수학'); // 과목은 건드리지 않는다

    manager.setCellAsNonExchangeable('구길동', '화', 5);
    NonExchangeableManager.syncToBase(base, grid);
    expect(base.single.isExchangeable, isTrue);
    expect(base.single.exchangeReason, isNull);
  });

  test('빈 칸을 교체불가로 찍으면 원본에 빈 교체불가 TimeSlot이 추가된다', () {
    final base = [lesson('구길동', 2, 5)];
    final grid = base.map((s) => s.copy()).toList();
    final manager = NonExchangeableManager()..setTimeSlots(grid);

    manager.setCellAsNonExchangeable('구길동', '화', 3);
    NonExchangeableManager.syncToBase(base, grid);

    final added = find(base, '구길동', 2, 3);
    expect(added, isNotNull);
    expect(isBlocked(added!), isTrue);
    expect(added.isEmpty, isTrue);
    expect(base.length, 2);

    // 다시 동기화해도 중복 추가되지 않는다
    NonExchangeableManager.syncToBase(base, grid);
    expect(base.length, 2);
  });

  test('where로 좁히면 다른 칸의 플래그는 반영하지 않는다', () {
    final base = [lesson('구길동', 2, 5), lesson('홍길순', 2, 3)];
    final grid = base.map((s) => s.copy()).toList();
    final manager = NonExchangeableManager()..setTimeSlots(grid);

    manager.setCellAsNonExchangeable('구길동', '화', 5);
    manager.setCellAsNonExchangeable('홍길순', '화', 3);
    NonExchangeableManager.syncToBase(
      base,
      grid,
      where: (s) => s.teacher == '구길동',
    );

    expect(isBlocked(find(base, '구길동', 2, 5)!), isTrue);
    expect(find(base, '홍길순', 2, 3)!.isExchangeable, isTrue);
  });
}

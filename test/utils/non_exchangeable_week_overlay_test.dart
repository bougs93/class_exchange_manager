import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/non_exchangeable_data_storage_service.dart';
import 'package:class_exchange_manager/utils/non_exchangeable_week_overlay.dart';

List<TimeSlot> _baseSlots() {
  return [
    TimeSlot(
      teacher: '홍길동',
      subject: '수학',
      className: '1-1',
      dayOfWeek: 1,
      period: 3,
    ),
    TimeSlot(
      teacher: '김철수',
      subject: '음악',
      className: '2-1',
      dayOfWeek: 2,
      period: 2,
    ),
  ];
}

void main() {
  group('applyDatedNonExchangeable (§10.6 7단계)', () {
    test('그 주에 속한 날짜 지정 셀은 교체불가로 바뀐다', () {
      final base = _baseSlots();
      final datedCells = [
        NonExchangeableCell(
          teacher: '홍길동',
          dayOfWeek: 1,
          period: 3,
          date: DateTime(2026, 9, 1), // 화요일이지만 주 판정은 월요일 기준
        ),
      ];

      final result = applyDatedNonExchangeable(
        base,
        datedCells,
        DateTime(2026, 8, 31), // 9/1이 속한 주의 월요일
      );

      final hong = result.firstWhere((s) => s.teacher == '홍길동');
      expect(hong.isExchangeable, isFalse);
      expect(hong.exchangeReason, '교체불가');
      // 과목·학급 정보는 그대로 유지
      expect(hong.subject, '수학');
    });

    test('다른 주에서는 적용되지 않는다 — 원본 그대로', () {
      final base = _baseSlots();
      final datedCells = [
        NonExchangeableCell(
          teacher: '홍길동',
          dayOfWeek: 1,
          period: 3,
          date: DateTime(2026, 9, 1),
        ),
      ];

      final result = applyDatedNonExchangeable(
        base,
        datedCells,
        DateTime(2026, 9, 7), // 다음 주 월요일
      );

      final hong = result.firstWhere((s) => s.teacher == '홍길동');
      expect(hong.isExchangeable, isTrue);
      expect(hong.exchangeReason, isNull);
    });

    test('매주 반복 셀(date == null)은 대상에서 제외된다', () {
      final base = _baseSlots();
      const datedCells = [
        NonExchangeableCell(teacher: '홍길동', dayOfWeek: 1, period: 3),
      ];

      final result = applyDatedNonExchangeable(
        base,
        datedCells,
        DateTime(2026, 8, 31),
      );

      final hong = result.firstWhere((s) => s.teacher == '홍길동');
      // isRecurring 셀은 base에 이미 구워져 있어야 하는 것이지, 이 함수가
      // 다루는 대상이 아니다 — base 그대로 유지된다
      expect(hong.isExchangeable, isTrue);
    });

    test('원본 리스트의 TimeSlot 객체는 변경되지 않는다', () {
      final base = _baseSlots();
      final original = base[0];
      final datedCells = [
        NonExchangeableCell(
          teacher: '홍길동',
          dayOfWeek: 1,
          period: 3,
          date: DateTime(2026, 8, 31),
        ),
      ];

      applyDatedNonExchangeable(base, datedCells, DateTime(2026, 8, 31));

      expect(original.isExchangeable, isTrue);
      expect(original.exchangeReason, isNull);
    });

    test('대상 주에 걸리는 날짜 지정 셀이 없으면 리스트를 그대로(새 리스트 생성 없이) 반환한다', () {
      final base = _baseSlots();

      final result = applyDatedNonExchangeable(base, const [], DateTime(2026, 8, 31));

      expect(identical(result, base), isTrue);
    });
  });
}

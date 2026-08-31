import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/services/non_exchangeable_data_storage_service.dart';

void main() {
  group('NonExchangeableCell — 날짜 스코프 (§10.6 7단계)', () {
    test('date 없이 생성하면 isRecurring이 true다 (기존 매주 반복 동작)', () {
      const cell = NonExchangeableCell(teacher: '홍길동', dayOfWeek: 1, period: 1);

      expect(cell.isRecurring, isTrue);
      expect(cell.date, isNull);
    });

    test('date가 있으면 isRecurring이 false다', () {
      final cell = NonExchangeableCell(
        teacher: '홍길동',
        dayOfWeek: 1,
        period: 1,
        date: DateTime(2026, 9, 1),
      );

      expect(cell.isRecurring, isFalse);
    });

    test('toJson/fromJson 왕복 시 date가 보존된다', () {
      final cell = NonExchangeableCell(
        teacher: '홍길동',
        dayOfWeek: 3,
        period: 5,
        date: DateTime(2026, 9, 1),
      );

      final restored = NonExchangeableCell.fromJson(cell.toJson());

      expect(restored.teacher, cell.teacher);
      expect(restored.dayOfWeek, cell.dayOfWeek);
      expect(restored.period, cell.period);
      expect(restored.date, cell.date);
    });

    test('date가 null이면 toJson에 date 키 자체가 없다 (구 형식과 동일한 모양)', () {
      const cell = NonExchangeableCell(teacher: '홍길동', dayOfWeek: 1, period: 1);

      expect(cell.toJson().containsKey('date'), isFalse);
    });

    test('구 형식 JSON(date 키 없음)은 매주 반복으로 해석된다 — 마이그레이션 없이 호환', () {
      final restored = NonExchangeableCell.fromJson({
        'teacher': '홍길동',
        'dayOfWeek': 1,
        'period': 1,
      });

      expect(restored.isRecurring, isTrue);
      expect(restored.date, isNull);
    });
  });
}

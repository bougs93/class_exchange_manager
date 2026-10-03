import '../models/time_slot.dart';

/// 교체 옵션을 나타내는 클래스
class ExchangeOption {
  final TimeSlot timeSlot;
  final String teacherName;
  final ExchangeType type;
  final int priority;
  final String reason;

  ExchangeOption({
    required this.timeSlot,
    required this.teacherName,
    required this.type,
    required this.priority,
    required this.reason,
  });

  /// 교체 가능 여부
  bool get isExchangeable => type != ExchangeType.notExchangeable;
}

/// 교체 유형
enum ExchangeType {
  sameClass, // 동일 학급 (교체 가능)
  notExchangeable, // 교체 불가능
}

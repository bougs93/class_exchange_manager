/// 교체 결과를 나타내는 클래스
class ExchangeResult {
  final bool isSelected;
  final bool isDeselected;
  final bool isNoAction;
  final String? teacherName;
  final String? day;
  final int? period;

  ExchangeResult._({
    required this.isSelected,
    required this.isDeselected,
    required this.isNoAction,
    this.teacherName,
    this.day,
    this.period,
  });

  /// 교체 대상이 선택됨
  factory ExchangeResult.selected(String teacherName, String day, int period) {
    return ExchangeResult._(
      isSelected: true,
      isDeselected: false,
      isNoAction: false,
      teacherName: teacherName,
      day: day,
      period: period,
    );
  }

  /// 교체 대상이 해제됨
  factory ExchangeResult.deselected() {
    return ExchangeResult._(
      isSelected: false,
      isDeselected: true,
      isNoAction: false,
    );
  }

  /// 아무 동작하지 않음
  factory ExchangeResult.noAction() {
    return ExchangeResult._(
      isSelected: false,
      isDeselected: false,
      isNoAction: true,
    );
  }
}

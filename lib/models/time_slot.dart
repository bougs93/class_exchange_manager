/// 시간표의 각 칸을 나타내는 모델 클래스
class TimeSlot {
  String? teacher;    // 교사명: "김영희", null
  String? subject;    // 과목명: "수학", null  
  String? className;  // 학급명: "1-1", null
  int? dayOfWeek;    // 요일: 1(월) ~ 5(금)
  int? period;       // 교시: 1 ~ 7
  bool isExchangeable; // 교체 가능 여부: true(교체 가능), false(교체 불가능)
  String? exchangeReason; // 교체 불가능한 사유: "같은 학급", "같은 교사", "빈 시간" 등
  
  TimeSlot({
    this.teacher, 
    this.subject, 
    this.className, 
    this.dayOfWeek, 
    this.period,
    this.isExchangeable = true, // 기본값: 교체 가능
    this.exchangeReason, // 교체 불가능한 사유 (기본값: null)
  });
  
  /// 빈 슬롯인지 확인
  bool get isEmpty => teacher == null && subject == null && className == null;
  
  /// 비어있지 않은 슬롯인지 확인
  bool get isNotEmpty => !isEmpty;
  
  /// 빈 TimeSlot 생성
  static TimeSlot empty() {
    return TimeSlot();
  }
  
  /// 교체 가능한 슬롯인지 확인
  bool get canExchange => isExchangeable && isNotEmpty;
  
  /// 표시용 문자열 생성 (UI에서 사용)
  String get displayText {
    if (isEmpty) return '';
    return '${className ?? ''}\n${subject ?? ''}';
  }

  /// 교체 불가능한 사유를 반환하는 메서드
  String? get exchangeBlockReason {
    if (isExchangeable) return null; // 교체 가능한 경우 사유 없음
    return exchangeReason ?? '교체 불가능'; // 기본 사유
  }

  /// 교체 불가능한 사유를 설정하는 메서드
  void setExchangeBlockReason(String reason) {
    exchangeReason = reason;
    isExchangeable = false; // 사유가 있으면 교체 불가능으로 설정
  }
}

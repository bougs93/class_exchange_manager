/// 시간표의 각 칸을 나타내는 모델 클래스
class TimeSlot {
  String? teacher;    // 교사명: "김영희", null
  String? subject;    // 과목명: "수학", null  
  String? className;  // 학급명: "1-1", null
  int? dayOfWeek;    // 요일: 1(월) ~ 5(금)
  int? period;       // 교시: 1 ~ 7
  bool isExchangeable; // 교체 가능 여부: true(교체 가능), false(교체 불가능)
  
  TimeSlot({
    this.teacher, 
    this.subject, 
    this.className, 
    this.dayOfWeek, 
    this.period,
    this.isExchangeable = true, // 기본값: 교체 가능
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
  
  /// 교체 불가능한 슬롯인지 확인
  bool get cannotExchange => !isExchangeable;
  
  /// 표시용 문자열 생성 (UI에서 사용)
  String get displayText {
    if (isEmpty) return '';
    return '${className ?? ''}\n${subject ?? ''}';
  }
  
  /// 복사본 생성
  TimeSlot copyWith({
    String? teacher,
    String? subject,
    String? className,
    int? dayOfWeek,
    int? period,
    bool? isExchangeable,
  }) {
    return TimeSlot(
      teacher: teacher ?? this.teacher,
      subject: subject ?? this.subject,
      className: className ?? this.className,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      period: period ?? this.period,
      isExchangeable: isExchangeable ?? this.isExchangeable,
    );
  }
  
  @override
  String toString() {
    return 'TimeSlot(teacher: $teacher, subject: $subject, className: $className, dayOfWeek: $dayOfWeek, period: $period, isExchangeable: $isExchangeable)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeSlot &&
        other.teacher == teacher &&
        other.subject == subject &&
        other.className == className &&
        other.dayOfWeek == dayOfWeek &&
        other.period == period &&
        other.isExchangeable == isExchangeable;
  }
  
  @override
  int get hashCode {
    return teacher.hashCode ^ 
           subject.hashCode ^ 
           className.hashCode ^ 
           dayOfWeek.hashCode ^ 
           period.hashCode ^ 
           isExchangeable.hashCode;
  }
}


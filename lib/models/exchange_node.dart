import '../models/time_slot.dart';

/// 교체 노드를 나타내는 모델 클래스
/// 순환 교체에서 각 교사의 시간 정보를 나타냄
class ExchangeNode {
  final String teacherName;  // 교사명
  final String day;           // 요일 (월, 화, 수, 목, 금)
  final int period;           // 교시 (1-7)
  final String className;     // 학급명 (1-1, 2-3 등)
  final String subjectName;   // 과목명 (수학, 국어 등)

  ExchangeNode({
    required this.teacherName,
    required this.day,
    required this.period,
    required this.className,
    this.subjectName = '과목',  // 기본값 설정
  });

  /// TimeSlot에서 ExchangeNode 생성
  factory ExchangeNode.fromTimeSlot(TimeSlot timeSlot, String day) {
    return ExchangeNode(
      teacherName: timeSlot.teacher ?? '',
      day: day,
      period: timeSlot.period ?? 0,
      className: timeSlot.className ?? '',
      subjectName: timeSlot.subject ?? '과목',
    );
  }

  /// 노드의 고유 식별자 생성
  String get nodeId => '${teacherName}_${day}_$period교시_$className';

  /// 노드의 표시용 문자열 생성
  String get displayText => '$teacherName($day$period교시, $className)';

  /// 두 노드가 같은지 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExchangeNode &&
        other.teacherName == teacherName &&
        other.day == day &&
        other.period == period &&
        other.className == className &&
        other.subjectName == subjectName;
  }

  /// 해시코드 생성
  /// 
  /// 해시코드가 필요한 이유:
  /// 1. Set, Map 등의 해시 기반 컬렉션에서 객체를 효율적으로 저장/검색하기 위해 필요
  /// 2. operator == 메서드를 오버라이드 할 때는 반드시 hashCode도 함께 오버라이드 해야 함
  /// 3. 동일한 객체는 동일한 해시코드를 반환해야 하는 규칙을 지키기 위해
  /// 4. CircularExchangePath 클래스에서 Set을 사용해 중복 교사 제거 시 필요
  @override 
  int get hashCode {
    return teacherName.hashCode ^
        day.hashCode ^
        period.hashCode ^
        className.hashCode ^
        subjectName.hashCode;
  }

  /// 문자열 표현
  @override
  String toString() {
    return 'ExchangeNode(teacher: $teacherName, day: $day, period: $period, class: $className, subject: $subjectName)';
  }

}
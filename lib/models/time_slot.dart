import '../utils/logger.dart';

/// 시간표의 각 칸을 나타내는 모델 클래스
/// 
/// 교체 불가 검사 방법:
/// - 기본 검사: isExchangeable && isNotEmpty  
/// - 교체 시 검증: 교사가 목적지 시간대에 교체 불가 셀이 있는지 확인
/// - 모든 교체 유형(1:1, 순환, 연쇄)에서 동일하게 적용
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
  
  /// 빈 슬롯인지 확인 (과목이나 학급이 없는 경우)
  bool get isEmpty => subject == null && className == null;
  
  /// 비어있지 않은 슬롯인지 확인 (과목이나 학급이 있는 경우)
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
  
  /// TimeSlot을 비우기 (모든 정보를 null로 설정)
  void clear() {
    // teacher = null;
    subject = null;
    className = null;
    // dayOfWeek와 period는 유지 (시간 정보는 그대로)
    // isExchangeable과 exchangeReason도 유지
  }
  
  /// 다른 TimeSlot의 정보를 복사하되 요일과 시간은 목적지의 것으로 설정
  /// 
  /// 매개변수:
  /// - `sourceSlot`: 복사할 원본 TimeSlot
  /// - `targetDayOfWeek`: 목적지 요일
  /// - `targetPeriod`: 목적지 교시
  void copyFromWithNewTime(TimeSlot sourceSlot) {
    // teacher = sourceSlot.teacher;
    subject = sourceSlot.subject;
    className = sourceSlot.className;
    // dayOfWeek = targetDayOfWeek;  // 목적지 요일로 설정
    // period = targetPeriod;         // 목적지 교시로 설정
    isExchangeable = sourceSlot.isExchangeable;
    exchangeReason = sourceSlot.exchangeReason;
  }
  
  /// TimeSlot 이동 함수
  /// 
  /// 이동 방식:
  /// 1. 원본 TimeSlot을 비우기
  /// 2. 목적지 TimeSlot에 원본의 정보를 복사하되 요일과 시간은 목적지의 것으로 설정
  /// 
  /// 매개변수:
  /// - `sourceSlot`: 이동할 원본 TimeSlot
  /// - `targetSlot`: 목적지 TimeSlot
  /// 
  /// 반환값:
  /// - `bool`: 이동 성공 여부
  static bool moveTime(TimeSlot sourceSlot, TimeSlot targetSlot) {
    try {
      AppLogger.exchangeDebug('TimeSlot.moveTime 시작:');
      AppLogger.exchangeDebug('  sourceSlot: ${sourceSlot.debugInfo}');
      AppLogger.exchangeDebug('  targetSlot: ${targetSlot.debugInfo}');
      
      // 교체 가능성 검증
      if (!sourceSlot.canExchange) {
        AppLogger.exchangeDebug('교체 불가능: canExchange=false');
        return false;
      }
      
      if (sourceSlot.isEmpty) {
        AppLogger.exchangeDebug('빈 슬롯: isEmpty=true');
        return false;
      }
      
      AppLogger.exchangeDebug('검증 통과, 이동 시작');
      
      // 1단계: 목적지 TimeSlot에 원본의 정보를 복사하되 "요일과 시간"은 목적지의 것으로 설정
      targetSlot.copyFromWithNewTime(sourceSlot);
      AppLogger.exchangeDebug('목적지에 복사 완료: ${targetSlot.debugInfo}');
      
      // 2단계: 원본 TimeSlot을 비우기 (복사 후에 비우기)
      sourceSlot.clear();
      AppLogger.exchangeDebug('원본 비우기 완료: ${sourceSlot.debugInfo}');
      
      return true;
    } catch (e) {
      AppLogger.error('TimeSlot.moveTime 오류: $e', e);
      return false;
    }
  }
  
  /// TimeSlot의 정보를 문자열로 반환 (디버깅용)
  String get debugInfo {
    return 'TimeSlot(teacher: $teacher, subject: $subject, className: $className, dayOfWeek: $dayOfWeek, period: $period, isExchangeable: $isExchangeable)';
  }
  
  /// TimeSlot의 복사본 생성 (교체 히스토리용)
  TimeSlot copy() {
    return TimeSlot(
      teacher: teacher,
      subject: subject,
      className: className,
      dayOfWeek: dayOfWeek,
      period: period,
      isExchangeable: isExchangeable,
      exchangeReason: exchangeReason,
    );
  }
  
  /// 다른 TimeSlot의 값으로 복원
  void restoreFrom(TimeSlot other) {
    teacher = other.teacher;
    subject = other.subject;
    className = other.className;
    dayOfWeek = other.dayOfWeek;
    period = other.period;
    isExchangeable = other.isExchangeable;
    exchangeReason = other.exchangeReason;
  }
}

/// 교체 히스토리를 관리하는 클래스
class ExchangeHistory {
  static final List<List<TimeSlot>> _history = [];
  
  /// 교체 히스토리 추가
  /// 
  /// 매개변수:
  /// - `beforeSlots`: 교체 전 TimeSlot 리스트
  /// - `afterSlots`: 교체 후 TimeSlot 리스트
  static void addExchange(List<TimeSlot> beforeSlots, List<TimeSlot> afterSlots) {
    List<TimeSlot> historyEntry = [];
    
    // 교체 전 상태 추가
    for (TimeSlot slot in beforeSlots) {
      historyEntry.add(slot.copy());
    }
    
    // 교체 후 상태 추가
    for (TimeSlot slot in afterSlots) {
      historyEntry.add(slot.copy());
    }
    
    _history.add(historyEntry);
  }
  
  /// 마지막 교체를 되돌리기
  /// 
  /// 반환값:
  /// - `List<TimeSlot>`: 되돌린 TimeSlot 리스트 (교체 전 상태)
  /// - `null`: 되돌릴 히스토리가 없는 경우
  static List<TimeSlot>? undo() {
    if (_history.isEmpty) return null;
    
    List<TimeSlot> lastEntry = _history.removeLast();
    int halfLength = lastEntry.length ~/ 2;
    
    // 교체 전 상태만 반환
    return lastEntry.take(halfLength).toList();
  }
  
  /// 히스토리 확인
  static List<List<TimeSlot>> get history => List.unmodifiable(_history);
  
  /// 히스토리 초기화
  static void clear() {
    _history.clear();
  }
  
  /// 히스토리 개수
  static int get length => _history.length;
}

import '../models/time_slot.dart';
import '../models/teacher.dart';
import 'day_utils.dart';

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
  sameClass,           // 동일 학급 (교체 가능)
  notExchangeable,     // 교체 불가능
}

/// 시간표 교체 알고리즘
class ExchangeAlgorithm {
  /// 교체 가능한 시간을 찾는 메인 알고리즘
  static List<ExchangeOption> findExchangeableTimes(
    List<TimeSlot> allTimeSlots,
    List<Teacher> teachers,
    String targetTeacher,
    String targetDay,
    int targetPeriod,
  ) {
    List<ExchangeOption> exchangeOptions = [];
    
    // 대상 교사의 시간표 정보 가져오기
    TimeSlot? targetSlot = _findTargetSlot(allTimeSlots, targetTeacher, targetDay, targetPeriod);
    if (targetSlot == null) return exchangeOptions;
    
    // 모든 교사에 대해 교체 가능성 검사
    for (Teacher teacher in teachers) {
      if (teacher.name == targetTeacher) continue; // 자기 자신 제외
      
      // 해당 교사의 모든 시간표 슬롯 검사
      List<TimeSlot> teacherSlots = allTimeSlots
          .where((slot) => slot.teacher == teacher.name)
          .toList();
      
      for (TimeSlot slot in teacherSlots) {
        ExchangeOption? option = _evaluateExchangeOption(
          slot, teacher, targetSlot, targetDay, targetPeriod
        );
        
        if (option != null) {
          exchangeOptions.add(option);
        }
      }
    }
    
    // 우선순위별로 정렬
    return _sortByPriority(exchangeOptions);
  }
  
  /// 대상 슬롯 찾기
  static TimeSlot? _findTargetSlot(
    List<TimeSlot> allTimeSlots,
    String targetTeacher,
    String targetDay,
    int targetPeriod,
  ) {
    int targetDayNumber = DayUtils.getDayNumber(targetDay);
    
    try {
      return allTimeSlots.firstWhere(
        (slot) => slot.teacher == targetTeacher &&
                  slot.dayOfWeek == targetDayNumber &&
                  slot.period == targetPeriod,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// 교체 옵션 평가
  static ExchangeOption? _evaluateExchangeOption(
    TimeSlot slot,
    Teacher teacher,
    TimeSlot targetSlot,
    String targetDay,
    int targetPeriod,
  ) {
    // 기본 교체 가능 여부 확인
    if (!slot.canExchange) return null;
    
    // 동일한 시간대인지 확인 (자기 자신 제외)
    if (slot.dayOfWeek == DayUtils.getDayNumber(targetDay) && slot.period == targetPeriod) {
      return null;
    }
    
    // 교체 가능성 판단
    ExchangeType type = _determineExchangeType(slot, targetSlot);
    
    if (type == ExchangeType.notExchangeable) return null;
    
    // 우선순위와 이유 설정
    int priority = _getPriority(type);
    String reason = _getReason(type, slot, teacher);
    
    return ExchangeOption(
      timeSlot: slot,
      teacherName: teacher.name,
      type: type,
      priority: priority,
      reason: reason,
    );
  }
  
  /// 교체 유형 결정
  static ExchangeType _determineExchangeType(TimeSlot slot, TimeSlot targetSlot) {
    // 동일 학급인 경우만 교체 가능
    bool hasSameClass = slot.className == targetSlot.className && 
                       slot.className != null && 
                       slot.className!.isNotEmpty;
    
    if (hasSameClass) {
      return ExchangeType.sameClass;
    }
    
    return ExchangeType.notExchangeable;
  }
  
  /// 우선순위 점수 계산
  static int _getPriority(ExchangeType type) {
    switch (type) {
      case ExchangeType.sameClass:
        return 1; // 교체 가능
      case ExchangeType.notExchangeable:
        return 999; // 교체 불가능
    }
  }
  
  /// 교체 이유 생성
  static String _getReason(ExchangeType type, TimeSlot slot, Teacher teacher) {
    switch (type) {
      case ExchangeType.sameClass:
        return '${teacher.name} 교사 - 동일 학급 (${slot.className})';
      case ExchangeType.notExchangeable:
        return '교체 불가능';
    }
  }
  
  /// 교체 옵션들을 우선순위별로 정렬
  static List<ExchangeOption> _sortByPriority(List<ExchangeOption> options) {
    return options..sort((a, b) {
      // 우선순위 점수로 정렬 (낮은 점수가 높은 우선순위)
      int priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) return priorityComparison;
      
      // 동일한 우선순위인 경우 교사명으로 정렬
      return a.teacherName.compareTo(b.teacherName);
    });
  }
}

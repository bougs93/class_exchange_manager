import '../models/time_slot.dart';
import '../services/exchange_service.dart';
import '../utils/day_utils.dart';
import '../utils/logger.dart';

/// 새로운 이동 방식 사용 예시
/// 
/// 이동 방식:
/// 1. 원본 TimeSlot을 비우기 (clear)
/// 2. 목적지 TimeSlot에 원본의 정보를 복사하되 요일과 시간은 목적지의 것으로 설정
/// 
/// 기존 방식과의 차이점:
/// - 기존: 두 셀의 정보를 서로 교환 (A ↔ B)
/// - 새로운: 원본을 비우고 목적지에 복사 (A → B, A는 빈셀)
class NewMoveMethodExample {
  
  /// 새로운 이동 방식 예시 실행
  static void runNewMoveMethodExample() {
    AppLogger.exchangeInfo('=== 새로운 이동 방식 예시 ===');
    
    // 교체 전 상태
    List<TimeSlot> timeSlots = [
      // 문유란 교사의 월요일 3교시 국어 수업
      TimeSlot(
        teacher: '문유란',
        subject: '국어',
        className: '1-8',
        dayOfWeek: DayUtils.getDayNumber('월'),
        period: 3,
        isExchangeable: true,
      ),
      // 이숙기 교사의 금요일 5교시 과학 수업
      TimeSlot(
        teacher: '이숙기',
        subject: '과학',
        className: '1-8',
        dayOfWeek: DayUtils.getDayNumber('금'),
        period: 5,
        isExchangeable: true,
      ),
    ];
    
    AppLogger.exchangeDebug('이동 전 상태:');
    AppLogger.exchangeDebug('월|3|1-8|문유란|국어');
    AppLogger.exchangeDebug('금|5|1-8|이숙기|과학');
    
    // ExchangeService를 사용한 새로운 방식 이동
    ExchangeService exchangeService = ExchangeService();
    bool success = exchangeService.performOneToOneExchange(
      timeSlots,
      '문유란', '월', 3,  // 첫 번째 교사 (목적지 셀)
      '이숙기', '금', 5,  // 두 번째 교사 (원본 셀)
    );
    
    if (success) {
      AppLogger.exchangeDebug('\n이동 후 상태 (새로운 방식):');
      AppLogger.exchangeDebug('월|3|1-8|이숙기|과학  ← 이숙기의 정보가 문유란 셀로 이동 (요일/시간은 목적지의 것)');
      AppLogger.exchangeDebug('금|5|1-8|빈셀         ← 이숙기 셀은 빈 셀이 됨');
      AppLogger.exchangeInfo('✅ 새로운 이동 방식 성공!');
    } else {
      AppLogger.warning('❌ 이동 실패');
    }
  }
  
  /// TimeSlot 모델의 새로운 이동 방식 사용 예시
  static void runTimeSlotNewMoveExample() {
    AppLogger.exchangeInfo('\n=== TimeSlot 새로운 이동 방식 예시 ===');
    
    // 두 개의 TimeSlot 생성
    TimeSlot sourceSlot = TimeSlot(
      teacher: '문유란',
      subject: '국어',
      className: '1-8',
      dayOfWeek: DayUtils.getDayNumber('월'),
      period: 3,
      isExchangeable: true,
    );
    
    TimeSlot targetSlot = TimeSlot(
      teacher: '이숙기',
      subject: '과학',
      className: '1-8',
      dayOfWeek: DayUtils.getDayNumber('금'),
      period: 5,
      isExchangeable: true,
    );
    
    AppLogger.exchangeDebug('이동 전:');
    AppLogger.exchangeDebug('Source: ${sourceSlot.debugInfo}');
    AppLogger.exchangeDebug('Target: ${targetSlot.debugInfo}');
    
    // TimeSlot의 새로운 moveTime 메서드 사용
    bool success = TimeSlot.moveTime(sourceSlot, targetSlot);
    
    if (success) {
      AppLogger.exchangeDebug('\n이동 후 (새로운 방식):');
      AppLogger.exchangeDebug('Source: ${sourceSlot.debugInfo}  ← 빈 셀이 됨');
      AppLogger.exchangeDebug('Target: ${targetSlot.debugInfo}  ← 문유란의 정보로 채워짐 (요일/시간은 목적지의 것)');
      AppLogger.exchangeInfo('✅ 새로운 이동 방식 성공!');
    } else {
      AppLogger.warning('❌ 이동 실패');
    }
  }
  
  /// 개별 메서드 사용 예시
  static void runIndividualMethodExample() {
    AppLogger.exchangeInfo('\n=== 개별 메서드 사용 예시 ===');
    
    // 원본 TimeSlot 생성
    TimeSlot originalSlot = TimeSlot(
      teacher: '김영희',
      subject: '수학',
      className: '2-1',
      dayOfWeek: DayUtils.getDayNumber('화'),
      period: 2,
      isExchangeable: true,
    );
    
    // 목적지 TimeSlot 생성 (빈 셀)
    TimeSlot destinationSlot = TimeSlot(
      teacher: null,
      subject: null,
      className: null,
      dayOfWeek: DayUtils.getDayNumber('목'),
      period: 4,
      isExchangeable: true,
    );
    
    AppLogger.exchangeDebug('개별 메서드 사용 전:');
    AppLogger.exchangeDebug('Original: ${originalSlot.debugInfo}');
    AppLogger.exchangeDebug('Destination: ${destinationSlot.debugInfo}');
    
    // 1단계: 원본을 비우기
    originalSlot.clear();
    AppLogger.exchangeDebug('\n1단계 - 원본 비우기 후:');
    AppLogger.exchangeDebug('Original: ${originalSlot.debugInfo}');
    
    // 2단계: 목적지에 원본 정보 복사 (요일/시간은 목적지의 것)
    destinationSlot.copyFromWithNewTime(
      TimeSlot(
        teacher: '김영희',
        subject: '수학',
        className: '2-1',
        dayOfWeek: DayUtils.getDayNumber('화'),
        period: 2,
        isExchangeable: true,
      ),
    );
    
    AppLogger.exchangeDebug('\n2단계 - 목적지에 복사 후:');
    AppLogger.exchangeDebug('Original: ${originalSlot.debugInfo}');
    AppLogger.exchangeDebug('Destination: ${destinationSlot.debugInfo}');
    
    AppLogger.exchangeInfo('✅ 개별 메서드 사용 성공!');
  }
  
  /// 기존 방식과 새로운 방식 비교 예시
  static void runComparisonExample() {
    AppLogger.exchangeInfo('\n=== 기존 방식 vs 새로운 이동 방식 비교 ===');
    
    // 기존 방식 예시
    AppLogger.exchangeInfo('\n[기존 방식]');
    AppLogger.exchangeDebug('이동 전: A(문유란|국어|월3교시), B(이숙기|과학|금5교시)');
    AppLogger.exchangeDebug('이동 후: A(이숙기|과학|월3교시), B(문유란|국어|금5교시)  ← 서로 교환');
    
    // 새로운 이동 방식 예시
    AppLogger.exchangeInfo('\n[새로운 이동 방식]');
    AppLogger.exchangeDebug('이동 전: A(문유란|국어|월3교시), B(이숙기|과학|금5교시)');
    AppLogger.exchangeDebug('이동 후: A(이숙기|과학|월3교시), B(빈셀|금5교시)  ← A로 이동, B는 빈셀');
    
    AppLogger.exchangeInfo('\n새로운 이동 방식의 장점:');
    AppLogger.exchangeInfo('1. 이동 과정이 더 명확하고 직관적');
    AppLogger.exchangeInfo('2. 원본을 비우고 목적지에 복사하는 명시적 과정');
    AppLogger.exchangeInfo('3. 요일과 시간은 목적지의 것을 유지');
    AppLogger.exchangeInfo('4. 이동 로직이 단순하고 이해하기 쉬움');
  }
  
  /// 모든 예시 실행
  static void runAllExamples() {
    runNewMoveMethodExample();
    runTimeSlotNewMoveExample();
    runIndividualMethodExample();
    runComparisonExample();
  }
}

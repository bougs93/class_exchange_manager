import '../models/time_slot.dart';
import '../services/exchange_service.dart';
import '../utils/day_utils.dart';
import '../utils/logger.dart';

/// 1:1 교체 사용 예시
/// 
/// 이 파일은 실제 수업 교체 함수의 사용법을 보여줍니다.
class ExchangeExample {
  
  /// 1:1 교체 예시 실행
  static void runOneToOneExchangeExample() {
    AppLogger.exchangeInfo('=== 1:1 교체 예시 ===');
    
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
    
    AppLogger.exchangeDebug('교체 전:');
    AppLogger.exchangeDebug('월|3|1-8|문유란|국어');
    AppLogger.exchangeDebug('금|5|1-8|이숙기|과학');
    
    // ExchangeService를 사용한 교체
    ExchangeService exchangeService = ExchangeService();
    bool success = exchangeService.performOneToOneExchange(
      timeSlots,
      '문유란', '월', 3,  // 첫 번째 교사
      '이숙기', '금', 5,  // 두 번째 교사
    );
    
    if (success) {
      AppLogger.exchangeDebug('\n교체 후:');
      AppLogger.exchangeDebug('월|3|1-8|이숙기|과학');
      AppLogger.exchangeDebug('금|5|1-8|문유란|국어');
      AppLogger.exchangeInfo('✅ 교체 성공!');
    } else {
      AppLogger.warning('❌ 교체 실패');
    }
  }
  
  /// TimeSlot 모델의 교체 함수 사용 예시
  static void runTimeSlotExchangeExample() {
    AppLogger.exchangeInfo('\n=== TimeSlot 교체 예시 ===');
    
    // 두 개의 TimeSlot 생성
    TimeSlot slot1 = TimeSlot(
      teacher: '문유란',
      subject: '국어',
      className: '1-8',
      dayOfWeek: DayUtils.getDayNumber('월'),
      period: 3,
      isExchangeable: true,
    );
    
    TimeSlot slot2 = TimeSlot(
      teacher: '이숙기',
      subject: '과학',
      className: '1-8',
      dayOfWeek: DayUtils.getDayNumber('금'),
      period: 5,
      isExchangeable: true,
    );
    
    AppLogger.exchangeDebug('교체 전:');
    AppLogger.exchangeDebug('Slot1: ${slot1.debugInfo}');
    AppLogger.exchangeDebug('Slot2: ${slot2.debugInfo}');
    
    // TimeSlot의 exchangeWith 메서드 사용
    bool success = slot1.exchangeWith(slot2);
    
    if (success) {
      AppLogger.exchangeDebug('\n교체 후:');
      AppLogger.exchangeDebug('Slot1: ${slot1.debugInfo}');
      AppLogger.exchangeDebug('Slot2: ${slot2.debugInfo}');
      AppLogger.exchangeInfo('✅ 교체 성공!');
    } else {
      AppLogger.warning('❌ 교체 실패');
    }
  }
  
  /// 교체 불가능한 경우 예시
  static void runExchangeFailureExample() {
    AppLogger.exchangeInfo('\n=== 교체 불가능한 경우 예시 ===');
    
    List<TimeSlot> timeSlots = [
      // 교체 가능한 수업
      TimeSlot(
        teacher: '문유란',
        subject: '국어',
        className: '1-8',
        dayOfWeek: DayUtils.getDayNumber('월'),
        period: 3,
        isExchangeable: true,
      ),
      // 교체 불가능한 수업 (다른 학급)
      TimeSlot(
        teacher: '이숙기',
        subject: '과학',
        className: '2-1', // 다른 학급
        dayOfWeek: DayUtils.getDayNumber('금'),
        period: 5,
        isExchangeable: true,
      ),
    ];
    
    ExchangeService exchangeService = ExchangeService();
    bool success = exchangeService.performOneToOneExchange(
      timeSlots,
      '문유란', '월', 3,
      '이숙기', '금', 5,
    );
    
    if (!success) {
      AppLogger.warning('❌ 교체 실패 - 다른 학급의 수업은 교체할 수 없습니다');
    }
  }
  
  /// 모든 예시 실행
  static void runAllExamples() {
    runOneToOneExchangeExample();
    runTimeSlotExchangeExample();
    runExchangeFailureExample();
  }
}

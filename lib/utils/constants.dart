/// 앱에서 사용하는 상수들
class AppConstants {
  // 앱 정보
  static const String appName = 'Class Exchange Manager';
  static const String appVersion = '1.0.0';
  
  // 시간표 설정
  static const int defaultDays = 5;      // 기본 요일 수 (월~금)
  static const int defaultPeriods = 7;   // 기본 교시 수
  
  // 요일 이름
  static const List<String> dayNames = [
    '월', '화', '수', '목', '금'
  ];
  
  // 교시 이름
  static const List<String> periodNames = [
    '1교시', '2교시', '3교시', '4교시', '5교시', '6교시', '7교시'
  ];
  
  // 색상 테마
  static const int primaryColor = 0xFF2196F3;  // 파란색
  static const int accentColor = 0xFF03DAC6;   // 청록색
  
  // 교체 상태
  static const String statusPending = 'pending';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  
  // 교체 타입
  static const String exchangeTypeDirect = 'direct';
  static const String exchangeTypeCircular = 'circular';
}


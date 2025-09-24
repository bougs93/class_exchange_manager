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
  
  // 그리드 레이아웃 설정
  static const double teacherColumnWidth = 60.0;    // 교사명 컬럼 폭
  static const double periodColumnWidth = 40.0;     // 교시 컬럼 폭
  static const double headerRowHeight = 25.0;       // 헤더 행 높이
  static const double dataRowHeight = 25.0;          // 데이터 행 높이
  
  // 그리드 색상
  static const int teacherHeaderColor = 0xFFF5F5F5;  // 교사명 헤더 배경색
  static const int periodHeaderColor = 0xFFFAFAFA;   // 교시 헤더 배경색
  static const int stackedHeaderColor = 0xFFE3F2FD;  // 스택된 헤더 배경색
  static const int dataCellColor = 0xFFFFFFFF;       // 데이터 셀 배경색
  
  // 그리드 텍스트 스타일
  static const double headerFontSize = 12.0;        // 헤더 폰트 크기
  static const double dataFontSize = 10.0;           // 데이터 폰트 크기
  static const double dataLineHeight = 1.1;          // 데이터 텍스트 줄 간격
}


/// 요일 관련 유틸리티 클래스
/// 
/// 요일 번호와 요일명 간의 변환 및 정렬 기능을 제공합니다.
/// 중복된 요일 변환 로직을 통합하여 관리합니다.
class DayUtils {
  /// 요일명 목록 (정렬 순서)
  static const List<String> dayNames = ['월', '화', '수', '목', '금'];
  
  /// 요일명을 숫자로 변환
  /// 
  /// 매개변수:
  /// - [day]: 요일명 ('월', '화', '수', '목', '금')
  /// 
  /// 반환값:
  /// - int: 요일 번호 (1=월, 2=화, 3=수, 4=목, 5=금)
  /// - 기본값: 1 (월요일)
  static int getDayNumber(String day) {
    const dayMap = {
      '월': 1,
      '화': 2,
      '수': 3,
      '목': 4,
      '금': 5,
    };
    return dayMap[day] ?? 1;
  }
  
  /// 요일 번호를 요일명으로 변환
  /// 
  /// 매개변수:
  /// - [dayOfWeek]: 요일 번호 (1=월, 2=화, 3=수, 4=목, 5=금, 6=토, 7=일)
  /// 
  /// 반환값:
  /// - String: 요일명 ('월', '화', '수', '목', '금', '토', '일')
  /// - 기본값: '월' (월요일)
  static String getDayName(int dayOfWeek) {
    const allDayNames = ['월', '화', '수', '목', '금', '토', '일'];
    if (dayOfWeek >= 1 && dayOfWeek <= 7) {
      return allDayNames[dayOfWeek - 1];
    }
    return '월'; // 기본값
  }
  
  /// 요일 정렬을 위한 비교 함수
  /// 
  /// 매개변수:
  /// - [a]: 첫 번째 요일명
  /// - [b]: 두 번째 요일명
  /// 
  /// 반환값:
  /// - int: 정렬 순서 (-1: a가 앞, 0: 같음, 1: b가 앞)
  static int compareDays(String a, String b) {
    int indexA = dayNames.indexOf(a);
    int indexB = dayNames.indexOf(b);
    
    if (indexA == -1) indexA = 999;
    if (indexB == -1) indexB = 999;
    
    return indexA.compareTo(indexB);
  }
  
  /// 요일명이 유효한지 확인
  /// 
  /// 매개변수:
  /// - [day]: 확인할 요일명
  /// 
  /// 반환값:
  /// - bool: 유효한 요일명이면 true, 아니면 false
  static bool isValidDay(String day) {
    return dayNames.contains(day);
  }
  
  /// 요일 번호가 유효한지 확인
  /// 
  /// 매개변수:
  /// - [dayOfWeek]: 확인할 요일 번호
  /// 
  /// 반환값:
  /// - bool: 유효한 요일 번호이면 true, 아니면 false
  static bool isValidDayNumber(int dayOfWeek) {
    return dayOfWeek >= 1 && dayOfWeek <= 5;
  }
}

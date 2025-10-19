/// 학급명 파싱 유틸리티
///
/// 다양한 형식의 학급명에서 학년과 반 정보를 추출합니다.
/// - "103" -> 학년: "1", 반: "3"
/// - "1-3" -> 학년: "1", 반: "3"
/// - "1학년 3반" -> 학년: "1", 반: "3"
class ClassNameParser {
  /// 학급명에서 학년 추출
  ///
  /// **지원 형식**:
  /// - 3자리 숫자: "103" -> "1"
  /// - 하이픈 형식: "1-3" -> "1"
  /// - 한글 형식: "1학년 3반" -> "1"
  static String extractGrade(String className) {
    try {
      className = className.trim();

      // 1. 3자리 숫자 형태 처리 (예: "103" -> "1", "203" -> "2")
      if (className.length == 3 && RegExp(r'^\d{3}$').hasMatch(className)) {
        return className[0]; // 첫 번째 자리: 학년
      }

      // 2. 하이픈 형태 처리 (예: "1-1" -> "1")
      final gradeMatch = RegExp(r'(\d+)[-학년]').firstMatch(className);
      if (gradeMatch != null) {
        return gradeMatch.group(1) ?? '';
      }

      // 3. 학년 포함 형태 처리 (예: "1학년 3반" -> "1", "2학년 10반" -> "2")
      final gradeYearMatch = RegExp(r'(\d+)학년').firstMatch(className);
      if (gradeYearMatch != null) {
        return gradeYearMatch.group(1) ?? '';
      }

      return '';
    } catch (e) {
      return '';
    }
  }

  /// 학급명에서 반 번호만 추출
  ///
  /// **지원 형식**:
  /// - 3자리 숫자: "103" -> "3", "110" -> "10"
  /// - 하이픈 형식: "1-3" -> "3", "2-10" -> "10"
  /// - 한글 형식: "1학년 3반" -> "3", "2학년 10반" -> "10"
  static String extractClassNumber(String className) {
    try {
      className = className.trim();

      // 1. 3자리 숫자 형태 처리 (예: "103" -> "3", "110" -> "10")
      if (className.length == 3 && RegExp(r'^\d{3}$').hasMatch(className)) {
        String classNum = className.substring(1); // 나머지: 반
        // 반 번호가 한 자리인 경우 앞의 0 제거
        if (classNum.startsWith('0') && classNum.length > 1) {
          classNum = classNum.substring(1);
        }
        return classNum;
      }

      // 2. 하이픈 형태 처리 (예: "1-3" -> "3", "2-10" -> "10")
      if (className.contains('-')) {
        final parts = className.split('-');
        if (parts.length >= 2) {
          return parts[1].trim();
        }
      }

      // 3. 학년 포함 형태 처리 (예: "1학년 3반" -> "3", "2학년 10반" -> "10")
      final classMatch = RegExp(r'학년\s*(\d+)반').firstMatch(className);
      if (classMatch != null) {
        return classMatch.group(1) ?? '';
      }

      return '';
    } catch (e) {
      return '';
    }
  }

  /// 학년과 반을 모두 추출 (Map 형태로 반환)
  static Map<String, String> parse(String className) {
    return {
      'grade': extractGrade(className),
      'class': extractClassNumber(className),
    };
  }
}

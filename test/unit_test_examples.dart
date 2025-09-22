import 'package:flutter_test/flutter_test.dart';

// 테스트할 간단한 클래스들
class Calculator {
  /// 두 숫자를 더하는 함수
  int add(int a, int b) {
    return a + b;
  }
  
  /// 두 숫자를 빼는 함수
  int subtract(int a, int b) {
    return a - b;
  }
  
  /// 두 숫자를 곱하는 함수
  int multiply(int a, int b) {
    return a * b;
  }
  
  /// 두 숫자를 나누는 함수 (0으로 나누기 방지)
  double divide(int a, int b) {
    if (b == 0) {
      throw ArgumentError('0으로 나눌 수 없습니다');
    }
    return a / b;
  }
}

class StringUtils {
  /// 문자열이 비어있는지 확인
  static bool isEmpty(String? str) {
    return str == null || str.isEmpty;
  }
  
  /// 문자열을 대문자로 변환
  static String toUpperCase(String str) {
    return str.toUpperCase();
  }
  
  /// 문자열의 길이 반환
  static int getLength(String str) {
    return str.length;
  }
  
  /// 문자열이 특정 패턴과 일치하는지 확인
  static bool matches(String str, String pattern) {
    return RegExp(pattern).hasMatch(str);
  }
}

void main() {
  group('Calculator 클래스 테스트', () {
    late Calculator calculator;
    
    setUp(() {
      // 각 테스트 전에 Calculator 인스턴스 생성
      calculator = Calculator();
    });
    
    group('덧셈 테스트', () {
      test('양수 더하기', () {
        // Given: 두 양수
        int a = 5;
        int b = 3;
        
        // When: 더하기 실행
        int result = calculator.add(a, b);
        
        // Then: 결과 확인
        expect(result, equals(8));
      });
      
      test('음수 더하기', () {
        expect(calculator.add(-5, -3), equals(-8));
      });
      
      test('양수와 음수 더하기', () {
        expect(calculator.add(5, -3), equals(2));
      });
      
      test('0 더하기', () {
        expect(calculator.add(0, 5), equals(5));
        expect(calculator.add(5, 0), equals(5));
      });
    });
    
    group('뺄셈 테스트', () {
      test('양수 빼기', () {
        expect(calculator.subtract(10, 3), equals(7));
      });
      
      test('음수 빼기', () {
        expect(calculator.subtract(-5, -3), equals(-2));
      });
      
      test('0 빼기', () {
        expect(calculator.subtract(5, 0), equals(5));
        expect(calculator.subtract(0, 5), equals(-5));
      });
    });
    
    group('곱셈 테스트', () {
      test('양수 곱하기', () {
        expect(calculator.multiply(4, 3), equals(12));
      });
      
      test('음수 곱하기', () {
        expect(calculator.multiply(-4, 3), equals(-12));
        expect(calculator.multiply(-4, -3), equals(12));
      });
      
      test('0 곱하기', () {
        expect(calculator.multiply(5, 0), equals(0));
        expect(calculator.multiply(0, 5), equals(0));
      });
    });
    
    group('나눗셈 테스트', () {
      test('정상적인 나눗셈', () {
        expect(calculator.divide(10, 2), equals(5.0));
        expect(calculator.divide(7, 3), closeTo(2.333, 0.001));
      });
      
      test('0으로 나누기 예외 처리', () {
        // 예외가 발생하는지 확인
        expect(() => calculator.divide(5, 0), throwsA(isA<ArgumentError>()));
      });
    });
  });
  
  group('StringUtils 클래스 테스트', () {
    group('isEmpty 테스트', () {
      test('null 문자열', () {
        expect(StringUtils.isEmpty(null), isTrue);
      });
      
      test('빈 문자열', () {
        expect(StringUtils.isEmpty(''), isTrue);
      });
      
      test('공백 문자열', () {
        expect(StringUtils.isEmpty('   '), isFalse); // 공백은 빈 문자열이 아님
      });
      
      test('일반 문자열', () {
        expect(StringUtils.isEmpty('hello'), isFalse);
      });
    });
    
    group('toUpperCase 테스트', () {
      test('소문자 변환', () {
        expect(StringUtils.toUpperCase('hello'), equals('HELLO'));
      });
      
      test('대소문자 혼합', () {
        expect(StringUtils.toUpperCase('Hello World'), equals('HELLO WORLD'));
      });
      
      test('이미 대문자', () {
        expect(StringUtils.toUpperCase('HELLO'), equals('HELLO'));
      });
    });
    
    group('getLength 테스트', () {
      test('일반 문자열 길이', () {
        expect(StringUtils.getLength('hello'), equals(5));
      });
      
      test('빈 문자열 길이', () {
        expect(StringUtils.getLength(''), equals(0));
      });
      
      test('한글 문자열 길이', () {
        expect(StringUtils.getLength('안녕하세요'), equals(5));
      });
    });
    
    group('matches 테스트', () {
      test('이메일 패턴 매칭', () {
        expect(StringUtils.matches('test@example.com', r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'), isTrue);
        expect(StringUtils.matches('invalid-email', r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'), isFalse);
      });
      
      test('전화번호 패턴 매칭', () {
        expect(StringUtils.matches('010-1234-5678', r'^\d{3}-\d{4}-\d{4}$'), isTrue);
        expect(StringUtils.matches('01012345678', r'^\d{3}-\d{4}-\d{4}$'), isFalse);
      });
    });
  });
}



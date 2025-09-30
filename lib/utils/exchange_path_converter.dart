import '../models/exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../utils/exchange_algorithm.dart';

/// ExchangeOption을 ExchangePath로 변환하는 유틸리티 클래스
class ExchangePathConverter {
  /// ExchangeOption 리스트를 OneToOneExchangePath 리스트로 변환
  static List<OneToOneExchangePath> convertToOneToOnePaths({
    required String selectedTeacher,
    required String selectedDay,
    required int selectedPeriod,
    required String selectedClassName,
    required List<ExchangeOption> options,
  }) {
    List<OneToOneExchangePath> paths = [];
    
    for (ExchangeOption option in options) {
      // 교체 가능한 옵션만 변환
      if (option.isExchangeable) {
        OneToOneExchangePath path = OneToOneExchangePath.fromExchangeOption(
          selectedTeacher,
          selectedDay,
          selectedPeriod,
          selectedClassName,
          option,
        );
        paths.add(path);
      }
    }
    
    // 우선순위별로 정렬 (낮은 숫자가 높은 우선순위)
    paths.sort((a, b) => a.priority.compareTo(b.priority));
    
    return paths;
  }
  
  /// ExchangePath 리스트를 타입별로 분리
  static ({
    List<OneToOneExchangePath> oneToOnePaths,
    List<CircularExchangePath> circularPaths,
    List<ChainExchangePath> chainPaths,
  }) separatePathsByType(List<ExchangePath> paths) {
    List<OneToOneExchangePath> oneToOnePaths = [];
    List<CircularExchangePath> circularPaths = [];
    List<ChainExchangePath> chainPaths = [];

    for (ExchangePath path in paths) {
      switch (path.type) {
        case ExchangePathType.oneToOne:
          if (path is OneToOneExchangePath) {
            oneToOnePaths.add(path);
          }
          break;
        case ExchangePathType.circular:
          if (path is CircularExchangePath) {
            circularPaths.add(path);
          }
          break;
        case ExchangePathType.chain:
          if (path is ChainExchangePath) {
            chainPaths.add(path);
          }
          break;
      }
    }

    return (
      oneToOnePaths: oneToOnePaths,
      circularPaths: circularPaths,
      chainPaths: chainPaths,
    );
  }
  
  /// 선택된 셀 정보에서 학급명을 추출하는 헬퍼 메서드
  static String extractClassNameFromTimeSlots({
    required List<dynamic> timeSlots, // TimeSlot 리스트
    required String teacherName,
    required String day,
    required int period,
  }) {
    // DayUtils를 사용하여 요일 문자열을 숫자로 변환
    int dayOfWeek = _getDayNumber(day);
    
    // 해당 조건에 맞는 TimeSlot 찾기
    for (var slot in timeSlots) {
      if (slot.teacher == teacherName &&
          slot.dayOfWeek == dayOfWeek &&
          slot.period == period) {
        return slot.className ?? '';
      }
    }
    
    return ''; // 찾지 못한 경우 빈 문자열 반환
  }
  
  /// 요일 문자열을 숫자로 변환하는 헬퍼 메서드
  static int _getDayNumber(String day) {
    switch (day) {
      case '월': return 1;
      case '화': return 2;
      case '수': return 3;
      case '목': return 4;
      case '금': return 5;
      case '토': return 6;
      case '일': return 7;
      default: return 0;
    }
  }
}

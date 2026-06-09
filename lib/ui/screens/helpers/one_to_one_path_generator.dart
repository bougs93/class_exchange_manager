import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/time_slot.dart';
import '../../../utils/exchange_algorithm.dart';
import '../../../utils/exchange_path_converter.dart';

/// 1:1 교체 경로 생성 헬퍼
///
/// 순환교체([CircularPathFinder]), 2중교체([DualPathFinder])와 동일한 패턴으로,
/// 1:1 교체 경로 생성 로직을 ExchangeScreen State에서 분리한 것입니다.
/// 순수 변환 로직만 담당하며, Provider/UI 상태 적용은 호출 측(State)에서 처리합니다.
class OneToOnePathGenerator {
  /// 선택된 셀과 교체 옵션으로부터 1:1 교체 경로 목록을 생성합니다.
  ///
  /// - [options]: ExchangeAlgorithm이 산출한 교체 옵션 목록
  ///
  /// Returns: 우선순위로 정렬되고 순차 ID(`onetoone_path_N`)가 부여된 경로 목록
  static List<OneToOneExchangePath> generate({
    required String selectedTeacher,
    required String selectedDay,
    required int selectedPeriod,
    required List<TimeSlot> timeSlots,
    required List<ExchangeOption> options,
  }) {
    // 선택된 셀의 학급명 추출
    final String selectedClassName =
        ExchangePathConverter.extractClassNameFromTimeSlots(
          timeSlots: timeSlots,
          teacherName: selectedTeacher,
          day: selectedDay,
          period: selectedPeriod,
        );

    // ExchangeOption을 OneToOneExchangePath로 변환
    final List<OneToOneExchangePath> paths =
        ExchangePathConverter.convertToOneToOnePaths(
          selectedTeacher: selectedTeacher,
          selectedDay: selectedDay,
          selectedPeriod: selectedPeriod,
          selectedClassName: selectedClassName,
          options: options,
          timeSlots: timeSlots,
        );

    // 순차적인 ID 부여
    for (int i = 0; i < paths.length; i++) {
      paths[i].setCustomId('onetoone_path_${i + 1}');
    }

    return paths;
  }
}

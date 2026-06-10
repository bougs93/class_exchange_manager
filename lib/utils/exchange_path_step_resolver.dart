import '../ui/widgets/timetable_grid/timetable_grid_constants.dart';

/// 셀 왼쪽 상단 모서리에 표시할 단계 번호를 결정한다.
///
/// 1:1 교체와 2중 교체의 셀 모서리 숫자 표시 규칙을 한곳에 모은다.
/// 표시할 숫자가 없으면 null을 반환한다.
///
/// 규칙:
/// - 2중 교체 경로: 기존 단계 번호([dualPathStep], 1 또는 2)를 그대로 사용
/// - 1:1 교체 **양방향**: 출발·도착 양쪽 셀 모두 "1" (2중 교체와 동일한 표현)
/// - 1:1 교체 **단방향**: 비선택 셀만 "1" (선택 셀은 표시하지 않음)
int? resolvePathStepNumber({
  required ArrowDirection oneToOneArrowDirection,
  required bool isInOneToOnePath,
  required bool isInDualPath,
  required bool isSelected,
  required int? dualPathStep,
}) {
  // 2중 교체 경로: 기존 단계 번호 사용 (1 또는 2)
  if (isInDualPath && dualPathStep != null) {
    return dualPathStep;
  }

  // 1:1 교체 양방향: 양쪽 셀 모두 "1"
  if (isInOneToOnePath &&
      oneToOneArrowDirection == ArrowDirection.bidirectional) {
    return 1;
  }

  // 1:1 교체 단방향: 비선택 셀만 "1"
  if (isInOneToOnePath && !isSelected) {
    return 1;
  }

  return null;
}

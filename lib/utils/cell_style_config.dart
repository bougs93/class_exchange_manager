/// 셀 스타일 설정을 위한 데이터 클래스
class CellStyleConfig {
  final bool isTeacherColumn;
  final bool isSelected;
  final bool isExchangeable;
  final bool isLastColumnOfDay;
  final bool isFirstColumnOfDay;
  final bool isHeader;
  final bool isInCircularPath;
  final int? circularPathStep;
  final bool isInSelectedPath;
  final bool isInChainPath;
  final int? chainPathStep;
  final bool isTargetCell;
  final bool isNonExchangeable;

  const CellStyleConfig({
    required this.isTeacherColumn,
    required this.isSelected,
    required this.isExchangeable,
    required this.isLastColumnOfDay,
    this.isFirstColumnOfDay = false,
    this.isHeader = false,
    this.isInCircularPath = false,
    this.circularPathStep,
    this.isInSelectedPath = false,
    this.isInChainPath = false,
    this.chainPathStep,
    this.isTargetCell = false,
    this.isNonExchangeable = false,
  });
}

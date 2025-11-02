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
  final bool isInSupplementPath;
  final bool isTargetCell;
  final bool isNonExchangeable;
  final bool isExchangedSourceCell; // 교체된 소스 셀인지 여부
  final bool isExchangedDestinationCell; // 교체된 목적지 셀인지 여부
  final bool isTeacherNameSelected; // 교사 이름 선택 상태 (새로 추가)
  final bool isHighlightedTeacher; // 하이라이트된 교사 행인지 여부
  final String? headerPosition; // 헤더 위치 정보 (예: "수1", "월3")

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
    this.isInSupplementPath = false,
    this.isTargetCell = false,
    this.isNonExchangeable = false,
    this.isExchangedSourceCell = false, // 교체된 소스 셀 기본값은 false
    this.isExchangedDestinationCell = false, // 교체된 목적지 셀 기본값은 false
    this.isTeacherNameSelected = false, // 교사 이름 선택 상태 기본값은 false
    this.isHighlightedTeacher = false, // 하이라이트된 교사 행 기본값은 false
    this.headerPosition, // 헤더 위치 정보
  });
}

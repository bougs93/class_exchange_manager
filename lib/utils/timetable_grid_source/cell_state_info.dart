/// 셀 상태 정보를 담는 클래스
///
/// `lib/utils/timetable_data_source.dart`에서 분리됨 — 순수 데이터 클래스라
/// 위젯 빌드·알림(notify) 로직과 분리해도 안전하다.
class CellStateInfo {
  final bool isSelected;
  final bool isTargetCell;
  final bool isExchangeableTeacher;
  final bool isLastColumnOfDay;
  final bool isFirstColumnOfDay;
  final bool isInCircularPath;
  final int? circularPathStep;
  final bool isInSelectedPath;
  final bool isInDualPath;
  final int? pathStepNumber; // 셀 모서리에 표시할 단계 번호 (1:1·2중 공통)
  final bool isNonExchangeable;
  final bool isExchangedSourceCell; // 교체된 소스 셀인지 여부
  final bool isExchangedDestinationCell; // 교체된 목적지 셀인지 여부
  final bool isTeacherNameSelected; // 교사 이름 선택 상태 (새로 추가)
  final bool isHighlightedTeacher; // 하이라이트된 교사 행인지 여부 (새로 추가)
  final String? overlayDate; // 날짜표시 OFF일 때 교체된 칸에 붙이는 날짜 꼬리표 (S1.5, 예: "10.06")

  CellStateInfo({
    required this.isSelected,
    required this.isTargetCell,
    required this.isExchangeableTeacher,
    required this.isLastColumnOfDay,
    required this.isFirstColumnOfDay,
    required this.isInCircularPath,
    this.circularPathStep,
    required this.isInSelectedPath,
    required this.isInDualPath,
    this.pathStepNumber,
    required this.isNonExchangeable,
    required this.isExchangedSourceCell,
    required this.isExchangedDestinationCell,
    required this.isTeacherNameSelected, // 새로 추가
    required this.isHighlightedTeacher, // 새로 추가
    this.overlayDate,
  });

  Object get visualSignature => (
    isSelected,
    isTargetCell,
    isExchangeableTeacher,
    isLastColumnOfDay,
    isFirstColumnOfDay,
    isInCircularPath,
    circularPathStep,
    isInSelectedPath,
    isInDualPath,
    pathStepNumber,
    isNonExchangeable,
    isExchangedSourceCell,
    isExchangedDestinationCell,
    isTeacherNameSelected,
    isHighlightedTeacher,
    overlayDate,
  );

  factory CellStateInfo.empty() {
    return CellStateInfo(
      isSelected: false,
      isTargetCell: false,
      isExchangeableTeacher: false,
      isLastColumnOfDay: false,
      isFirstColumnOfDay: false,
      isInCircularPath: false,
      circularPathStep: null,
      isInSelectedPath: false,
      isInDualPath: false,
      pathStepNumber: null,
      isNonExchangeable: false,
      isExchangedSourceCell: false,
      isExchangedDestinationCell: false,
      isTeacherNameSelected: false, // 새로 추가
      isHighlightedTeacher: false, // 새로 추가
    );
  }
}

/// 개인 시간표 화면 상수
///
/// 개인 시간표 화면에서 사용하는 상수들을 정의합니다.
class PersonalScheduleConstants {
  /// 교사명 확인 중복 호출 방지 시간 (밀리초)
  ///
  /// 이 시간 이내에 재호출이 발생하면 무시됩니다.
  /// 화면 전환 시 불필요한 중복 확인을 방지하기 위함입니다.
  static const int teacherNameCheckThrottleMs = 300;

  /// 교사 선택 다이얼로그 너비
  static const double teacherSelectionDialogWidth = 400;

  /// 교사 선택 다이얼로그 높이
  static const double teacherSelectionDialogHeight = 600;
}

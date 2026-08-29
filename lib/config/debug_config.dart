/// 디버그 설정
///
/// 개발 중에만 활성화해야 하는 디버그 기능을 관리합니다.
/// 프로덕션에서는 모든 플래그를 false로 설정해야 합니다.
class DebugConfig {
  /// 개인 시간표 셀 테마 디버그 로그 활성화
  ///
  /// true: 각 셀의 테마 적용 과정을 상세히 로깅 (성능 저하 가능)
  /// false: 셀 테마 로그 비활성화 (프로덕션 권장)
  static const bool enableCellThemeDebugLogs = false;

  /// 교체 정보 추출 디버그 로그 활성화
  ///
  /// true: 교체 정보 추출 과정을 상세히 로깅
  /// false: 교체 정보 추출 로그 비활성화 (프로덕션 권장)
  static const bool enableExchangeInfoDebugLogs = false;

  /// 셀 매칭 디버그 로그 활성화
  ///
  /// true: 셀 매칭 실패/성공 정보를 로깅
  /// false: 셀 매칭 로그 비활성화 (프로덕션 권장)
  static const bool enableCellMatchingDebugLogs = false;

  /// Provider가 바뀔 때마다 이름을 출력합니다.
  /// 시간표 화면이 멈출 때 true로 바꾸고, 콘솔에서 반복되는 Provider를 찾습니다.
  ///
  /// 원인을 찾은 뒤에는 반드시 false로 되돌리세요 (로그가 매우 많습니다).
  static const bool enableProviderUpdateLogs = false;

  /// 시간표 화면 build 횟수를 출력합니다.
  /// 1초에 수십 번이면 무한 리빌드, 1~2번이면 다른 원인(로드 대기 등)입니다.
  static const bool enableTimetableRebuildLogs = false;
}

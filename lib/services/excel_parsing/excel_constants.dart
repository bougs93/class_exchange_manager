/// 엑셀 파싱 상수 정의
class ExcelServiceConstants {
  // 파일 크기 제한
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  // 검색 범위 제한
  static const int maxColumnsToCheck = 50; // 요일 헤더 검색 최대 열 수
  static const int maxPeriodsToCheck = 10; // 교시 검색 최대 범위
  static const int maxHeaderSearchRows = 10; // 헤더 검색 최대 행 수
  static const int maxRowsToLog = 20; // 로그 출력 최대 행 수

  // 셀 순서 검증 샘플링 설정
  static const int maxSamplesForOrderDetection = 20; // 순서 검증 최대 샘플 개수
  static const int minSamplesForOrderDetection = 5; // 순서 검증 최소 샘플 개수

  // 교사 행 개수 검증 샘플링 설정
  static const int maxSamplesForTeacherRowDetection = 10; // 교사 행 개수 검증 최대 샘플 개수
  static const int minSamplesForTeacherRowDetection = 3; // 교사 행 개수 검증 최소 샘플 개수

  // 교사 정보 추출 시 추가 검색 설정
  static const int additionalSearchRowsAfterEmptyCell = 20; // 빈 셀 이후 추가 검색 행 수
}

/// 셀 순서 패턴을 나타내는 enum
///
/// 셀 내용이 두 줄로 구성될 때의 순서를 나타냅니다.
enum CellOrderPattern {
  /// 정상 순서: 학급번호 → 과목 (예: "103\n국어")
  normal,

  /// 바뀐 순서: 과목 → 학급번호 (예: "국어\n103")
  reversed,

  /// 확인 불가: 패턴을 확인할 수 없는 경우
  unknown,
}

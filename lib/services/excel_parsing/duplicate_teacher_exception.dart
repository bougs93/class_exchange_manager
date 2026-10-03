/// 교사 이름 중복 예외 클래스
///
/// 엑셀 파일에서 동일한 교사 이름이 중복되어 발견될 때 발생하는 예외입니다.
class DuplicateTeacherException implements Exception {
  /// 중복된 교사 이름
  final String teacherName;

  /// 첫 번째로 발견된 행 번호 (1-based)
  final int firstRow;

  /// 중복이 발견된 행 번호 (1-based)
  final int duplicateRow;

  DuplicateTeacherException({
    required this.teacherName,
    required this.firstRow,
    required this.duplicateRow,
  });

  @override
  String toString() {
    return '교사 이름 중복 오류: "$teacherName"이(가) $firstRow행과 $duplicateRow행에서 중복되었습니다.';
  }

  /// 사용자에게 표시할 메시지
  String get userMessage {
    return '엑셀 파일에서 교사 이름 "$teacherName"이(가) 중복되었습니다.\n'
        '첫 번째: $firstRow행\n'
        '중복: $duplicateRow행\n\n'
        '엑셀 파일을 확인하고 중복을 제거한 후 다시 시도해주세요.';
  }
}

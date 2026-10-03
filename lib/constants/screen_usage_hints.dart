/// 화면별 상단 사용 안내 문구
///
/// 빈 문자열이면 안내 영역은 표시되지 않습니다.
class ScreenUsageHints {
  ScreenUsageHints._();

  /// 계획서 출력 > 결보강 일정
  static const String contentInput =
      '파란 칸(결강일·교체일·보강 과목)을 눌러 실제 일정을 수정하고, 출력할 교체 건만 체크하세요.';

  /// 계획서 출력 > 결보강 출력
  static const String substitutionOutput =
      '결보강 일정에서 체크한 교체 건만 출력됩니다. 입력란을 확인한 뒤 PDF 미리보기, 인쇄를 누르세요.';

  /// 계획서 출력 > 결보강 백업
  static const String planBackup =
      '왼쪽에서 결강 교사를 고른 뒤 계획서를 선택하고 내보내기를 누르세요. '
      '다른 PC 백업은 가져오기로 복원합니다(계획서 미선택이어도 가능).';

  /// 안내 > 교사안내
  static const String teacherNotice =
      '안내 형식을 선택한 후 복사 버튼을 눌러 문구를 복사하고, 메신저·문서에 붙여 넣어 사용하세요.';

  /// 안내 > 학급안내
  static const String classNotice =
      '안내 형식을 선택한 후 복사 버튼을 눌러 문구를 복사하고, 학급 안내 문서에 붙여 넣어 사용하세요.';
}

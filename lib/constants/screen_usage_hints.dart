/// 문서 출력 탭별 사용 안내 문구
///
/// 빈 문자열이면 안내 영역은 표시되지 않습니다.
class DocumentUsageHints {
  DocumentUsageHints._();

  /// 내용 입력
  static const String substitutionPlan =
      '표에서 선택 항목을 클릭해 필수 정보를 입력하세요. 입력이 끝나면 결보강 출력에서 PDF를 저장할 수 있습니다.';

  /// 결보강 출력
  static const String fileExport =
      '입력란을 확인한 후 PDF 출력·인쇄 버튼을 눌러 결보강 계획서를 저장하거나 인쇄하세요.';

  /// 교사안내
  static const String teacherNotice =
      '안내 형식을 선택한 후 복사 버튼을 눌러 문구를 복사하고, 메신저·문서에 붙여 넣어 사용하세요.';

  /// 학급안내
  static const String classNotice =
      '안내 형식을 선택한 후 복사 버튼을 눌러 문구를 복사하고, 학급 안내 문서에 붙여 넣어 사용하세요.';
}

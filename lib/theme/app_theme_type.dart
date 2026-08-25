/// 앱 디자인 테마 유형
///
/// 사용자가 설정 화면에서 선택할 수 있는 전체 디자인 세트입니다.
/// - [modern]: 플랫 모노 테마 — 틸 그린 포인트의 사이드바 대시보드 디자인
/// - [classic]: 기존의 파란색 계열 디자인 (기본값)
/// - [material3]: 머티리얼 3 기반의 새로운 디자인
enum AppThemeType {
  /// 플랫 모노 테마 (틸 그린 포인트 대시보드 디자인)
  ///
  /// 과거 명칭이 EduLink였으며, 저장 파일 호환성을 위해 [fromJson]에서
  /// 레거시 이름 'edulink'를 이 값으로 변환합니다.
  modern,

  /// 클래식 테마 (기존 파란색 계열 디자인)
  classic,

  /// 머티리얼 3 테마 (새로운 머티리얼 디자인)
  material3;

  /// 설정 화면 표시 순서 (플랫 모노가 첫 번째)
  static List<AppThemeType> get displayOrder => const [
    modern,
    classic,
    material3,
  ];

  /// 저장용 JSON 문자열
  String toJson() => name;

  /// JSON 문자열 → AppThemeType (알 수 없는 값이면 [fallback] 반환)
  ///
  /// 레거시 이름 'edulink'는 [modern]으로 해석합니다.
  static AppThemeType fromJson(String? value, AppThemeType fallback) {
    if (value == 'edulink') {
      return modern;
    }
    for (final type in AppThemeType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return fallback;
  }

  /// 설정 화면에 표시할 이름
  String get displayName => switch (this) {
    AppThemeType.modern => '플랫 모노',
    AppThemeType.classic => '클래식',
    AppThemeType.material3 => '머티리얼 3',
  };

  /// 설정 화면에 표시할 설명
  String get description => switch (this) {
    AppThemeType.modern => '틸 그린 포인트의 대시보드 디자인',
    AppThemeType.classic => '기존의 파란색 계열 디자인',
    AppThemeType.material3 => '부드러운 곡선의 머티리얼 디자인',
  };
}

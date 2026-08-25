import 'package:flutter/material.dart';

import 'app_theme_type.dart';

/// 앱 전역 디자인 토큰 (ThemeExtension)
///
/// 두 디자인 세트(클래식/머티리얼 3)가 각각의 값을 가지는 의미론적 색상·모양 토큰입니다.
/// 위젯에서 `context.tokens`로 접근하며, 선택된 테마에 따라 값이 자동 교체됩니다.
///
/// 주의: 시간표 셀의 기능 색상(초록=교체가능, 노랑=순환, 빨강=불가 등)은
/// `SimplifiedTimetableTheme`에서 관리되며 두 테마에서 공유됩니다.
@immutable
class DesignTokens extends ThemeExtension<DesignTokens> {
  /// 브랜드 강조 색상 (버튼, 선택 상태 등)
  final Color primary;

  /// [primary] 위의 전경색
  final Color onPrimary;

  /// Scaffold 배경색
  final Color scaffoldBackground;

  /// 카드·패널 표면색
  final Color surface;

  /// 은은하게 채워진 섹션 배경색 (설정 카드, 입력 영역 등)
  final Color sectionBackground;

  /// 카드·섹션 테두리색
  final Color cardBorder;

  /// 기본 텍스트 색상
  final Color textPrimary;

  /// 보조 텍스트 색상
  final Color textSecondary;

  /// 흐린 안내 텍스트 색상
  final Color textMuted;

  /// AppBar 배경색
  final Color appBarBackground;

  /// AppBar 전경색 (제목·아이콘)
  final Color appBarForeground;

  /// 은은한 강조 AppBar 배경색 (교체 화면 상단바 등)
  final Color appBarSubtleBackground;

  /// 네비게이션 바 배경색
  final Color navBarBackground;

  /// 네비게이션 바 하단 경계선 색상
  final Color navBarBorderColor;

  /// 네비게이션 바 선택 항목 배경색
  final Color navBarSelectedBackground;

  /// 네비게이션 바 선택 항목 색상 (아이콘·텍스트·인디케이터)
  final Color navBarSelectedColor;

  /// 네비게이션 바 미선택 아이콘 색상
  final Color navBarUnselectedIconColor;

  /// 네비게이션 바 미선택 텍스트 색상
  final Color navBarUnselectedTextColor;

  /// 중형 라운딩 반경 (카드, 버튼 등)
  final double radiusMedium;

  /// 네비게이션 바 선택 인디케이터 라운딩 반경
  ///
  /// 0이면 하단 보더 스타일(클래식·머티리얼 3), 0보다 크면
  /// pill(알약) 모양 인디케이터(플랫 모노)를 그립니다.
  final double navBarIndicatorRadius;

  /// 네비게이션 바 선택 항목의 하단 보더 표시 여부
  final bool navBarShowSelectedBorder;

  /// 메뉴 강조색을 테마 단일 색으로 통일할지 여부
  ///
  /// true(플랫 모노)이면 사이드바 메뉴·안내 바 등이 화면별 고유 색 대신
  /// [primary] 계열 단색으로 표현됩니다.
  final bool monochromeMenuAccents;

  const DesignTokens({
    required this.primary,
    required this.onPrimary,
    required this.scaffoldBackground,
    required this.surface,
    required this.sectionBackground,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.appBarSubtleBackground,
    required this.navBarBackground,
    required this.navBarBorderColor,
    required this.navBarSelectedBackground,
    required this.navBarSelectedColor,
    required this.navBarUnselectedIconColor,
    required this.navBarUnselectedTextColor,
    required this.radiusMedium,
    required this.navBarIndicatorRadius,
    required this.navBarShowSelectedBorder,
    required this.monochromeMenuAccents,
  });

  /// 클래식 테마 토큰 — 기존 파란색 계열 디자인 값
  const DesignTokens.classic()
    : primary = const Color(0xFF2196F3), // Colors.blue
      onPrimary = Colors.white,
      scaffoldBackground = Colors.white,
      surface = Colors.white,
      sectionBackground = const Color(0xFFFAFAFA), // grey.shade50
      cardBorder = const Color(0xFFE0E0E0), // grey.shade300
      textPrimary = const Color(0xFF424242), // grey.shade800
      textSecondary = const Color(0xFF616161), // grey.shade700
      textMuted = const Color(0xFF9E9E9E), // grey.shade500
      appBarBackground = const Color(0xFF2196F3),
      appBarForeground = Colors.white,
      appBarSubtleBackground = const Color(0xFFE3F2FD), // blue.shade50
      navBarBackground = Colors.white,
      navBarBorderColor = const Color(0xFFE0E0E0), // grey.shade300
      navBarSelectedBackground = const Color(0xFFE3F2FD), // blue.shade50
      navBarSelectedColor = const Color(0xFF1976D2), // blue.shade700
      navBarUnselectedIconColor = const Color(0xFF757575), // grey.shade600
      navBarUnselectedTextColor = const Color(0xFF616161), // grey.shade700
      radiusMedium = 8.0,
      navBarIndicatorRadius = 0.0, // 하단 보더 스타일
      navBarShowSelectedBorder = true,
      monochromeMenuAccents = false;

  /// 머티리얼 3 테마 토큰 — M3 베이스라인 팔레트(시드: 0xFF6750A4)
  const DesignTokens.material()
    : primary = const Color(0xFF6750A4),
      onPrimary = Colors.white,
      scaffoldBackground = const Color(0xFFFFFBFE), // M3 surface
      surface = const Color(0xFFF7F2FA), // M3 surfaceContainerLow
      sectionBackground = const Color(0xFFF3EDF7), // M3 surfaceContainer
      cardBorder = const Color(0xFFE7E0EC), // M3 outlineVariant
      textPrimary = const Color(0xFF1D1B20), // M3 onSurface
      textSecondary = const Color(0xFF49454F), // M3 onSurfaceVariant
      textMuted = const Color(0xFF79747E), // M3 outline
      appBarBackground = const Color(0xFFFFFBFE),
      appBarForeground = const Color(0xFF1D1B20),
      appBarSubtleBackground = const Color(
        0xFFECE6F0,
      ), // M3 surfaceContainerHighest
      navBarBackground = const Color(0xFFF3EDF7),
      navBarBorderColor = const Color(0xFFF3EDF7), // 경계선 없는 M3 스타일
      navBarSelectedBackground = const Color(0xFFEADDFF), // M3 primaryContainer
      navBarSelectedColor = const Color(0xFF6750A4),
      navBarUnselectedIconColor = const Color(0xFF49454F),
      navBarUnselectedTextColor = const Color(0xFF49454F),
      radiusMedium = 12.0,
      navBarIndicatorRadius = 0.0, // 하단 보더 스타일
      navBarShowSelectedBorder = true,
      monochromeMenuAccents = false;

  /// 플랫 모노 테마 토큰 — 틸 그린 포인트의 사이드바 대시보드 디자인 값
  ///
  /// 흰 배경 위에 틸(청록)을 강조하고, 옅은 틸 배경으로 선택 상태를 표현합니다.
  const DesignTokens.modern()
    : primary = const Color(0xFF00897B), // 틸 600
      onPrimary = Colors.white,
      scaffoldBackground = Colors.white,
      surface = Colors.white,
      sectionBackground = const Color(0xFFF4F7F6), // 옅은 회록색 섹션 배경
      cardBorder = const Color(0xFFE5EBE9), // 옅은 회록색 테두리
      textPrimary = const Color(0xFF212121),
      textSecondary = const Color(0xFF616161),
      textMuted = const Color(0xFF9E9E9E),
      appBarBackground = Colors.white,
      appBarForeground = const Color(0xFF212121),
      appBarSubtleBackground = const Color(0xFFE0F2F1), // 틸 50
      navBarBackground = Colors.white,
      navBarBorderColor = const Color(0xFFE5EBE9),
      navBarSelectedBackground = const Color(0xFFE0F2F1), // 틸 50
      navBarSelectedColor = const Color(0xFF00897B),
      navBarUnselectedIconColor = const Color(0xFF757575),
      navBarUnselectedTextColor = const Color(0xFF616161),
      radiusMedium = 12.0,
      navBarIndicatorRadius = 14.0, // pill(알약) 인디케이터
      navBarShowSelectedBorder = false,
      monochromeMenuAccents = true;

  /// 테마 유형에 대응하는 디자인 토큰
  ///
  /// 테마 미리보기 등 ThemeData 없이 토큰만 필요한 경우 사용합니다.
  static DesignTokens of(AppThemeType type) => switch (type) {
    AppThemeType.classic => const DesignTokens.classic(),
    AppThemeType.material3 => const DesignTokens.material(),
    AppThemeType.modern => const DesignTokens.modern(),
  };

  @override
  DesignTokens copyWith({
    Color? primary,
    Color? onPrimary,
    Color? scaffoldBackground,
    Color? surface,
    Color? sectionBackground,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? appBarBackground,
    Color? appBarForeground,
    Color? appBarSubtleBackground,
    Color? navBarBackground,
    Color? navBarBorderColor,
    Color? navBarSelectedBackground,
    Color? navBarSelectedColor,
    Color? navBarUnselectedIconColor,
    Color? navBarUnselectedTextColor,
    double? radiusMedium,
    double? navBarIndicatorRadius,
    bool? navBarShowSelectedBorder,
    bool? monochromeMenuAccents,
  }) {
    return DesignTokens(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      surface: surface ?? this.surface,
      sectionBackground: sectionBackground ?? this.sectionBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      appBarBackground: appBarBackground ?? this.appBarBackground,
      appBarForeground: appBarForeground ?? this.appBarForeground,
      appBarSubtleBackground:
          appBarSubtleBackground ?? this.appBarSubtleBackground,
      navBarBackground: navBarBackground ?? this.navBarBackground,
      navBarBorderColor: navBarBorderColor ?? this.navBarBorderColor,
      navBarSelectedBackground:
          navBarSelectedBackground ?? this.navBarSelectedBackground,
      navBarSelectedColor: navBarSelectedColor ?? this.navBarSelectedColor,
      navBarUnselectedIconColor:
          navBarUnselectedIconColor ?? this.navBarUnselectedIconColor,
      navBarUnselectedTextColor:
          navBarUnselectedTextColor ?? this.navBarUnselectedTextColor,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      navBarIndicatorRadius:
          navBarIndicatorRadius ?? this.navBarIndicatorRadius,
      navBarShowSelectedBorder:
          navBarShowSelectedBorder ?? this.navBarShowSelectedBorder,
      monochromeMenuAccents:
          monochromeMenuAccents ?? this.monochromeMenuAccents,
    );
  }

  @override
  DesignTokens lerp(ThemeExtension<DesignTokens>? other, double t) {
    if (other is! DesignTokens) {
      return this;
    }
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return DesignTokens(
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      scaffoldBackground: l(scaffoldBackground, other.scaffoldBackground),
      surface: l(surface, other.surface),
      sectionBackground: l(sectionBackground, other.sectionBackground),
      cardBorder: l(cardBorder, other.cardBorder),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      appBarBackground: l(appBarBackground, other.appBarBackground),
      appBarForeground: l(appBarForeground, other.appBarForeground),
      appBarSubtleBackground: l(
        appBarSubtleBackground,
        other.appBarSubtleBackground,
      ),
      navBarBackground: l(navBarBackground, other.navBarBackground),
      navBarBorderColor: l(navBarBorderColor, other.navBarBorderColor),
      navBarSelectedBackground: l(
        navBarSelectedBackground,
        other.navBarSelectedBackground,
      ),
      navBarSelectedColor: l(navBarSelectedColor, other.navBarSelectedColor),
      navBarUnselectedIconColor: l(
        navBarUnselectedIconColor,
        other.navBarUnselectedIconColor,
      ),
      navBarUnselectedTextColor: l(
        navBarUnselectedTextColor,
        other.navBarUnselectedTextColor,
      ),
      radiusMedium: radiusMedium + (other.radiusMedium - radiusMedium) * t,
      navBarIndicatorRadius:
          navBarIndicatorRadius +
          (other.navBarIndicatorRadius - navBarIndicatorRadius) * t,
      navBarShowSelectedBorder:
          t < 0.5 ? navBarShowSelectedBorder : other.navBarShowSelectedBorder,
      monochromeMenuAccents:
          t < 0.5 ? monochromeMenuAccents : other.monochromeMenuAccents,
    );
  }
}

/// [DesignTokens] 접근 헬퍼
extension DesignTokensContext on BuildContext {
  /// 현재 테마의 디자인 토큰
  ///
  /// ThemeExtension이 등록되지 않은 경우(테스트 등) 클래식 토큰으로 대체합니다.
  DesignTokens get tokens =>
      Theme.of(this).extension<DesignTokens>() ?? const DesignTokens.classic();
}

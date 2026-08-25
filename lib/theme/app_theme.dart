import 'package:flutter/material.dart';

import 'app_theme_type.dart';
import 'design_tokens.dart';

/// 앱 테마 빌더
///
/// [AppThemeType]에 대응하는 [ThemeData]를 생성합니다.
/// 각 테마는 [DesignTokens] ThemeExtension을 함께 등록하여
/// 위젯이 `context.tokens`로 디자인 값에 접근할 수 있게 합니다.
class AppTheme {
  AppTheme._();

  /// 테마 유형에 대응하는 ThemeData 반환
  static ThemeData of(AppThemeType type) => switch (type) {
    AppThemeType.classic => classic(),
    AppThemeType.material3 => material3(),
    AppThemeType.modern => modern(),
  };

  /// 클래식 테마 — 기존 디자인 유지
  ///
  /// 기존 `ThemeData(primarySwatch: Colors.blue)`와 동일한 외형을 보장하며,
  /// 디자인 토큰만 추가로 등록합니다.
  static ThemeData classic() {
    return ThemeData(
      primarySwatch: Colors.blue,
      extensions: const [DesignTokens.classic()],
    );
  }

  /// 머티리얼 3 테마 — 새로운 머티리얼 디자인
  static ThemeData material3() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFFFBFE),
      extensions: const [DesignTokens.material()],

      // AppBar: M3 기본 스타일 (surface 톤 배경)
      // titleTextStyle은 M3 기본값(inherit: false)과 inherit을 맞춰
      // 테마 전환 시 AnimatedDefaultTextStyle 보간 예외를 방지한다.
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFBFE),
        foregroundColor: Color(0xFF1D1B20),
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          inherit: false,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1D1B20),
        ),
      ),

      // 카드: 큰 라운딩 + 은은한 테두리
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFFF7F2FA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE7E0EC)),
        ),
        margin: EdgeInsets.zero,
      ),

      // 다이얼로그: M3 라운딩
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),

      // 입력 필드: 라운드 아웃라인
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCAC4D0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCAC4D0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6750A4), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF7F2FA),
      ),

      // 스낵바: M3 floating 스타일
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE7E0EC),
        thickness: 1,
      ),
    );
  }

  /// 플랫 모노 테마 — 틸 그린 포인트의 사이드바 대시보드 디자인
  ///
  /// 흰 배경 위에 틸(청록)을 강조하며, 필(pill) 형태 버튼·라운드 카드·
  /// 옅은 틸 선택 배경을 사용합니다. 모든 주요 컴포넌트 테마를 포함합니다.
  static ThemeData modern() {
    // 기본 팔레트 (이미지 디자인 기준)
    const primary = Color(0xFF00897B); // 틸 600
    const onPrimary = Colors.white;
    const primaryContainer = Color(0xFFE0F2F1); // 틸 50
    const onPrimaryContainer = Color(0xFF00695C); // 틸 700
    const scaffold = Colors.white;
    const onSurface = Color(0xFF212121);
    const onSurfaceVariant = Color(0xFF616161);
    const outline = Color(0xFFD9E2DF); // 입력 경계
    const outlineVariant = Color(0xFFE5EBE9); // 카드·구분선 경계

    final colorScheme = const ColorScheme.light().copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: const Color(0xFF26A69A), // 틸 400
      onSecondary: onPrimary,
      secondaryContainer: primaryContainer,
      onSecondaryContainer: onPrimaryContainer,
      tertiary: const Color(0xFF00796B), // 틸 700
      onTertiary: onPrimary,
      error: const Color(0xFFD32F2F),
      onError: onPrimary,
      errorContainer: const Color(0xFFFFEBEE),
      onErrorContainer: const Color(0xFFB71C1C),
      surface: scaffold,
      onSurface: onSurface,
      surfaceContainerHighest: const Color(0xFFEDF2F0),
      surfaceContainerHigh: const Color(0xFFF1F5F3),
      surfaceContainer: const Color(0xFFF4F7F6),
      surfaceContainerLow: const Color(0xFFF8FAF9),
      surfaceContainerLowest: scaffold,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      inverseSurface: const Color(0xFF2C2C2C),
      onInverseSurface: Colors.white,
      inversePrimary: const Color(0xFF80CBC4), // 틸 200
      surfaceTint: primary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      extensions: const [DesignTokens.modern()],

      // 기본 아이콘·텍스트
      iconTheme: const IconThemeData(color: Color(0xFF424242)),
      primaryIconTheme: const IconThemeData(color: onPrimary),

      // AppBar: 흰 배경 + 진한 텍스트 (대시보드 헤더 스타일)
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          inherit: false,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),

      // 카드: 그림자 없는 흰 배경 + 옅은 테두리 + 라운딩
      cardTheme: CardThemeData(
        elevation: 0,
        color: scaffold,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),

      // 다이얼로그: 라운드 흰 배경
      dialogTheme: DialogThemeData(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          inherit: false,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        contentTextStyle: const TextStyle(
          inherit: false,
          fontSize: 14,
          height: 1.5,
          color: onSurfaceVariant,
        ),
      ),

      // 바텀시트
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scaffold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: outlineVariant,
      ),

      // 입력 필드: 라운드 아웃라인 + 포커스 시 틸
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scaffold,
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),

      // 버튼: 필(pill) 형태 — 이미지의 추가/삭제/전체삭제 버튼 스타일
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          textStyle: const TextStyle(inherit: false, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          textStyle: const TextStyle(inherit: false, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: const BorderSide(color: outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(inherit: false, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(inherit: false, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // 칩: 라운드 + 옅은 테두리, 선택 시 틸
      chipTheme: ChipThemeData(
        backgroundColor: scaffold,
        selectedColor: primaryContainer,
        checkmarkColor: onPrimaryContainer,
        labelStyle: const TextStyle(inherit: false, fontSize: 13, color: onSurface),
        secondaryLabelStyle: const TextStyle(
          inherit: false,
          fontSize: 13,
          color: onPrimaryContainer,
        ),
        side: const BorderSide(color: outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // 탭 바: 틸 인디케이터 + 틸 라벨 (이미지 상단 탭 스타일)
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: onSurfaceVariant,
        labelStyle: TextStyle(inherit: false, fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(
          inherit: false,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: outlineVariant,
      ),

      // FAB: 틸 배경
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // 선택 컨트롤: 틸
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : null,
        ),
        checkColor: WidgetStateProperty.all(onPrimary),
        side: const BorderSide(color: onSurfaceVariant, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? primary
                  : onSurfaceVariant,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onPrimary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : null,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: primaryContainer,
        thumbColor: primary,
        overlayColor: Color(0x3300897B),
      ),

      // 진행 표시
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primaryContainer,
        circularTrackColor: primaryContainer,
      ),

      // 메뉴·툴팁
      popupMenuTheme: PopupMenuThemeData(
        color: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(inherit: false, fontSize: 14, color: onSurface),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(inherit: false, fontSize: 14, color: onSurface),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(inherit: false, fontSize: 12, color: Colors.white),
      ),

      // 리스트: 선택 시 틸
      listTileTheme: const ListTileThemeData(
        iconColor: onSurfaceVariant,
        selectedColor: primary,
        selectedTileColor: primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),

      // 네비게이션 바·레일: 사이드바 스타일 (틸 인디케이터)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? const IconThemeData(color: primary)
                  : const IconThemeData(color: onSurfaceVariant),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
            color:
                states.contains(WidgetState.selected)
                    ? primary
                    : onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scaffold,
        indicatorColor: primaryContainer,
        selectedIconTheme: const IconThemeData(color: primary),
        unselectedIconTheme: const IconThemeData(color: onSurfaceVariant),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onSurfaceVariant,
        ),
      ),

      // 세그먼트 버튼: 선택 시 틸 아웃라인
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected) ? primary : outline,
              width: states.contains(WidgetState.selected) ? 1.5 : 1,
            ),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? primary
                    : onSurfaceVariant,
          ),
        ),
      ),

      // 스크롤바·구분선
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Color(0xFFBDBDBD)),
        radius: Radius.circular(8),
      ),
      dividerTheme: const DividerThemeData(color: outlineVariant, thickness: 1),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/providers/theme_provider.dart';
import 'package:class_exchange_manager/theme/app_theme.dart';
import 'package:class_exchange_manager/theme/app_theme_type.dart';
import 'package:class_exchange_manager/theme/design_tokens.dart';

void main() {
  group('AppThemeType', () {
    test('JSON 직렬화/역직렬화 왕복', () {
      for (final type in AppThemeType.values) {
        expect(
          AppThemeType.fromJson(type.toJson(), AppThemeType.classic),
          type,
        );
      }
    });

    test('알 수 없는 값은 fallback 반환', () {
      expect(
        AppThemeType.fromJson('unknown', AppThemeType.material3),
        AppThemeType.material3,
      );
      expect(
        AppThemeType.fromJson(null, AppThemeType.classic),
        AppThemeType.classic,
      );
    });

    test('레거시 edulink 값은 modern으로 해석된다', () {
      expect(
        AppThemeType.fromJson('edulink', AppThemeType.classic),
        AppThemeType.modern,
      );
    });

    test('displayOrder는 플랫 모노를 첫 번째로 배치한다', () {
      expect(AppThemeType.displayOrder.first, AppThemeType.modern);
      expect(AppThemeType.displayOrder.length, AppThemeType.values.length);
    });
  });

  group('AppTheme', () {
    test('클래식 테마는 클래식 디자인 토큰을 등록한다', () {
      final theme = AppTheme.of(AppThemeType.classic);
      final tokens = theme.extension<DesignTokens>();

      expect(tokens, isA<DesignTokens>());
      expect(tokens!.primary, const Color(0xFF2196F3)); // 기존 파란색 유지
      expect(tokens.appBarBackground, const Color(0xFF2196F3));
    });

    test('머티리얼 3 테마는 머티리얼 디자인 토큰을 등록한다', () {
      final theme = AppTheme.of(AppThemeType.material3);
      final tokens = theme.extension<DesignTokens>();

      expect(theme.useMaterial3, isTrue);
      expect(tokens!.primary, const Color(0xFF6750A4));
      expect(tokens.radiusMedium, 12.0);
    });

    test('플랫 모노 테마는 틸 그린 디자인 토큰을 등록한다', () {
      final theme = AppTheme.of(AppThemeType.modern);
      final tokens = theme.extension<DesignTokens>();

      expect(theme.useMaterial3, isTrue);
      expect(tokens!.primary, const Color(0xFF00897B));
      expect(tokens.appBarBackground, Colors.white);
      expect(tokens.navBarSelectedBackground, const Color(0xFFE0F2F1));
      expect(tokens.radiusMedium, 12.0);
    });

    test('플랫 모노 테마는 pill 인디케이터와 단색 메뉴 강조를 사용한다', () {
      final modern =
          AppTheme.of(AppThemeType.modern).extension<DesignTokens>()!;
      final classic =
          AppTheme.of(AppThemeType.classic).extension<DesignTokens>()!;
      final material =
          AppTheme.of(AppThemeType.material3).extension<DesignTokens>()!;

      // 플랫 모노: pill 인디케이터 + 메뉴 색상 단일화
      expect(modern.navBarIndicatorRadius, greaterThan(0));
      expect(modern.navBarShowSelectedBorder, isFalse);
      expect(modern.monochromeMenuAccents, isTrue);

      // 클래식·머티리얼 3: 기존 하단 보더 스타일 + 메뉴별 색상 유지
      expect(classic.navBarIndicatorRadius, 0.0);
      expect(classic.navBarShowSelectedBorder, isTrue);
      expect(classic.monochromeMenuAccents, isFalse);
      expect(material.navBarIndicatorRadius, 0.0);
      expect(material.navBarShowSelectedBorder, isTrue);
      expect(material.monochromeMenuAccents, isFalse);
    });

    test('플랫 모노 테마는 주요 컴포넌트 테마를 모두 포함한다', () {
      final theme = AppTheme.of(AppThemeType.modern);

      expect(theme.appBarTheme.backgroundColor, Colors.white);
      expect(theme.cardTheme, isA<CardThemeData>());
      expect(theme.dialogTheme, isA<DialogThemeData>());
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.snackBarTheme, isA<SnackBarThemeData>());
      expect(theme.tabBarTheme, isA<TabBarThemeData>());
      expect(theme.elevatedButtonTheme.style, isNotNull);
      expect(theme.outlinedButtonTheme.style, isNotNull);
      expect(theme.textButtonTheme.style, isNotNull);
      expect(theme.filledButtonTheme.style, isNotNull);
      expect(theme.chipTheme, isA<ChipThemeData>());
      expect(
        theme.floatingActionButtonTheme,
        isA<FloatingActionButtonThemeData>(),
      );
      expect(theme.checkboxTheme, isA<CheckboxThemeData>());
      expect(theme.radioTheme, isA<RadioThemeData>());
      expect(theme.switchTheme, isA<SwitchThemeData>());
      expect(theme.sliderTheme, isA<SliderThemeData>());
      expect(theme.progressIndicatorTheme, isA<ProgressIndicatorThemeData>());
      expect(theme.popupMenuTheme, isA<PopupMenuThemeData>());
      expect(theme.tooltipTheme, isA<TooltipThemeData>());
      expect(theme.bottomSheetTheme, isA<BottomSheetThemeData>());
      expect(theme.listTileTheme, isA<ListTileThemeData>());
      expect(theme.navigationBarTheme, isA<NavigationBarThemeData>());
      expect(theme.navigationRailTheme, isA<NavigationRailThemeData>());
      expect(theme.segmentedButtonTheme, isA<SegmentedButtonThemeData>());
      expect(theme.scrollbarTheme, isA<ScrollbarThemeData>());
      expect(theme.dividerTheme, isA<DividerThemeData>());
    });

    test('DesignTokens.of는 테마 유형에 대응하는 토큰을 반환한다', () {
      for (final type in AppThemeType.values) {
        expect(
          DesignTokens.of(type).primary,
          AppTheme.of(type).extension<DesignTokens>()!.primary,
        );
      }
    });

    test('테마 전환 애니메이션을 위해 커스텀 텍스트 스타일은 inherit: false여야 한다', () {
      // M3 기본 텍스트 스타일은 inherit: false이다. 테마 커스텀 스타일이
      // inherit: true이면 ThemeData 전환 시 TextStyle.lerp가 예외를 던져
      // 무한 재빌드 루프(응답없음)가 발생한다. (버그 회귀 방지)
      for (final type in AppThemeType.values) {
        final theme = AppTheme.of(type);

        final appBarTitle = theme.appBarTheme.titleTextStyle;
        if (appBarTitle != null) {
          expect(appBarTitle.inherit, isFalse, reason: '$type appBar.titleTextStyle');
        }

        final elevated = theme.elevatedButtonTheme.style?.textStyle
            ?.resolve({});
        if (elevated != null) {
          expect(elevated.inherit, isFalse, reason: '$type elevatedButton.textStyle');
        }

        final textButton = theme.textButtonTheme.style?.textStyle?.resolve({});
        if (textButton != null) {
          expect(textButton.inherit, isFalse, reason: '$type textButton.textStyle');
        }

        final chip = theme.chipTheme.labelStyle;
        if (chip != null) {
          expect(chip.inherit, isFalse, reason: '$type chip.labelStyle');
        }

        final tabBar = theme.tabBarTheme.labelStyle;
        if (tabBar != null) {
          expect(tabBar.inherit, isFalse, reason: '$type tabBar.labelStyle');
        }
      }
    });

    test('두 테마의 토큰은 서로 다른 값을 가진다', () {
      final classic =
          AppTheme.of(AppThemeType.classic).extension<DesignTokens>()!;
      final material =
          AppTheme.of(AppThemeType.material3).extension<DesignTokens>()!;
      final modern =
          AppTheme.of(AppThemeType.modern).extension<DesignTokens>()!;

      expect(classic.primary, isNot(material.primary));
      expect(classic.scaffoldBackground, isNot(material.scaffoldBackground));
      expect(modern.primary, isNot(classic.primary));
      expect(modern.primary, isNot(material.primary));
    });
  });

  testWidgets('appThemeProvider가 선택된 테마의 ThemeData를 제공한다', (tester) async {
    ThemeData? resolved;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appThemeTypeProvider.overrideWith(
            (ref) => AppThemeNotifier(
              loader: () async => AppThemeType.material3,
              saver: (_) async => true,
              initialValue: AppThemeType.material3,
              skipInitialLoad: true,
            ),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            resolved = ref.watch(appThemeProvider);
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Theme(data: resolved!, child: const SizedBox()),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(resolved!.useMaterial3, isTrue);
    expect(
      resolved!.extension<DesignTokens>()!.primary,
      const Color(0xFF6750A4),
    );
  });
}

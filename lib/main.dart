import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'constants/app_info.dart';
import 'providers/theme_provider.dart';
import 'ui/widgets/expiry_check_wrapper.dart';

/// 앱의 진입점
void main() {
  runApp(const ProviderScope(child: MyApp()));
}

/// 메인 앱 위젯
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 설정에서 선택한 디자인 테마 (클래식 / 머티리얼 3)
    final theme = ref.watch(appThemeProvider);

    return MaterialApp(
      // 앱 제목: AppInfo.programName과 동일하게 유지
      title: AppInfo.programName,
      theme: theme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      home: const ExpiryCheckWrapper(),
    );
  }
}

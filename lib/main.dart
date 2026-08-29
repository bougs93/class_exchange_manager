import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'constants/app_info.dart';
import 'config/debug_config.dart';
import 'providers/theme_provider.dart';
import 'ui/widgets/expiry_check_wrapper.dart';
import 'utils/logger.dart';

/// 앱의 진입점
void main() {
  runApp(
    ProviderScope(
      // 멈춤 추적: DebugConfig.enableProviderUpdateLogs 를 true 로 바꾸면
      // 콘솔에 매 프레임 갱신되는 Provider 이름이 찍힙니다.
      observers: const [ProviderUpdateObserver()],
      child: const MyApp(),
    ),
  );
}

/// Provider 변경을 콘솔에 남깁니다. 플래그가 꺼져 있으면 아무 것도 하지 않습니다.
///
/// 같은 Provider가 1초에 수십 번 찍히면, 그 Provider가 멈춤의 원인입니다.
class ProviderUpdateObserver extends ProviderObserver {
  const ProviderUpdateObserver();

  /// Provider 이름별 누적 갱신 횟수 (앱 전체에서 공유)
  static final Map<String, int> _updateCounts = {};
  static DateTime _lastReport = DateTime.now();

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (!DebugConfig.enableProviderUpdateLogs) return;

    final name = provider.name ?? provider.runtimeType.toString();
    _updateCounts[name] = (_updateCounts[name] ?? 0) + 1;

    // 1초에 한 번, 가장 많이 갱신된 Provider만 요약해 출력합니다.
    final now = DateTime.now();
    if (now.difference(_lastReport) < const Duration(seconds: 1)) return;
    _lastReport = now;

    final sorted =
        _updateCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).map((e) => '${e.key}=${e.value}').join(', ');
    AppLogger.info('[Provider 갱신 순위] $top');
    _updateCounts.clear();
  }
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

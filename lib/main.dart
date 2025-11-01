import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'constants/app_info.dart';
import 'ui/screens/home_screen.dart';

/// 앱의 진입점
void main() {
  // 프로그램 실행 가능 날짜 체크
  _checkExpiryDate();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// 프로그램 실행 가능 날짜 체크
void _checkExpiryDate() {
  if (AppInfo.isExpired()) {
    // 만료된 경우 경고 (현재는 콘솔 출력만, 나중에 다이얼로그로 확장 가능)
    debugPrint('⚠️ 경고: 프로그램 사용 기간이 만료되었습니다.');
    debugPrint('만료일: ${AppInfo.expiryDate}');
  } else {
    final daysUntilExpiry = AppInfo.getDaysUntilExpiry();
    if (daysUntilExpiry != null && daysUntilExpiry <= 30) {
      // 만료일이 30일 이내인 경우 경고
      debugPrint('⚠️ 경고: 프로그램 사용 기간이 $daysUntilExpiry일 남았습니다.');
    }
  }
}

/// 메인 앱 위젯
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Class Exchange Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      
      ),
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      home: const HomeScreen(),
    );
  }
}


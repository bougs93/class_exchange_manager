import 'dart:io'; // exit() 함수를 사용하기 위한 import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemNavigator 사용
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'constants/app_info.dart';
import 'ui/screens/home_screen.dart';

/// 앱의 진입점
void main() {
  // 프로그램 실행 가능 날짜 체크
  // 만료된 경우 여기서 처리하면 UI가 없으므로, 앱 시작 후 첫 화면에서 체크하도록 변경
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
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
      // 만료 체크를 위한 스플래시 화면을 먼저 표시
      home: const ExpiryCheckWrapper(),
    );
  }
}

/// 만료일 체크 래퍼 위젯
/// 
/// 앱 시작 시 만료일을 체크하고, 만료된 경우 경고 메시지를 표시한 후 프로그램을 종료합니다.
/// 만료되지 않은 경우에만 실제 홈 화면을 표시합니다.
class ExpiryCheckWrapper extends StatefulWidget {
  const ExpiryCheckWrapper({super.key});

  @override
  State<ExpiryCheckWrapper> createState() => _ExpiryCheckWrapperState();
}

class _ExpiryCheckWrapperState extends State<ExpiryCheckWrapper> {
  @override
  void initState() {
    super.initState();
    // 위젯 트리가 빌드된 후 만료 체크 및 다이얼로그 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndHandleExpiry();
    });
  }

  /// 만료일 체크 및 처리
  /// 
  /// 만료된 경우 경고 다이얼로그를 표시하고 프로그램을 종료합니다.
  void _checkAndHandleExpiry() {
    // 만료일이 설정되지 않은 경우 체크하지 않음
    if (AppInfo.expiryDate == null) {
      return;
    }

    // 만료 여부 확인
    if (AppInfo.isExpired()) {
      // 만료된 경우 경고 다이얼로그 표시
      _showExpiryDialog();
    } else {
      // 만료되지 않은 경우 30일 이내 경고만 표시 (선택사항)
      final daysUntilExpiry = AppInfo.getDaysUntilExpiry();
      if (daysUntilExpiry != null && daysUntilExpiry <= 30) {
        debugPrint('⚠️ 경고: 프로그램 사용 기간이 $daysUntilExpiry일 남았습니다.');
      }
    }
  }

  /// 만료 경고 다이얼로그 표시
  /// 
  /// 사용자에게 만료 메시지를 표시하고 확인 버튼 클릭 시 프로그램을 종료합니다.
  void _showExpiryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 외부 터치로 닫기 불가능
      builder: (BuildContext dialogContext) {
        return PopScope(
          // 뒤로 가기 버튼으로도 닫기 불가능
          canPop: false,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '프로그램 만료',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '프로그램 사용 기간이 만료되었습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '만료일: ${AppInfo.expiryDate}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppInfo.usageRestriction,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // 확인 버튼만 제공 (종료 외 선택지 없음)
              TextButton(
                onPressed: () {
                  // 다이얼로그 닫기
                  Navigator.of(dialogContext).pop();
                  // 프로그램 종료
                  _exitApp();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 프로그램 종료
  /// 
  /// 플랫폼에 따라 적절한 방법으로 프로그램을 종료합니다.
  void _exitApp() {
    // 플랫폼별 종료 처리
    if (Platform.isAndroid || Platform.isIOS) {
      // 모바일 플랫폼의 경우 SystemNavigator 사용
      SystemNavigator.pop();
    } else {
      // 데스크톱 플랫폼(Windows, Linux, macOS)의 경우 exit() 사용
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 만료 여부와 관계없이 일단 로딩 화면을 표시
    // 만료된 경우 다이얼로그가 표시되고, 만료되지 않은 경우 HomeScreen으로 전환
    if (AppInfo.expiryDate != null && AppInfo.isExpired()) {
      // 만료된 경우 빈 화면 (다이얼로그가 표시됨)
      return Scaffold(
        body: Container(
          color: Colors.white,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    } else {
      // 만료되지 않은 경우 정상적으로 홈 화면 표시
      return const HomeScreen();
    }
  }
}


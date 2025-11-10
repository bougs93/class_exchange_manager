import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_info.dart';
import '../screens/home_screen.dart';

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
  // 주기적 만료일 체크를 위한 타이머
  Timer? _periodicCheckTimer;
  
  @override
  void initState() {
    super.initState();
    // 위젯 트리가 빌드된 후 만료 체크 및 다이얼로그 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndHandleExpiry();
    });
    
    // 주기적 만료일 체크 시작 (5분마다)
    // 프로그램 시작 후 날짜를 정상으로 복구한 경우를 감지하기 위함
    _startPeriodicExpiryCheck();
  }
  
  @override
  void dispose() {
    // 타이머 정리
    _periodicCheckTimer?.cancel();
    super.dispose();
  }
  
  /// 주기적 만료일 체크 시작
  ///
  /// 프로그램 실행 중에도 주기적으로 만료일을 체크하여,
  /// 프로그램 시작 후 날짜를 정상으로 복구한 경우를 감지합니다.
  void _startPeriodicExpiryCheck() {
    // 만료일이 설정되지 않은 경우 체크하지 않음
    if (AppInfo.expiryDate == null) {
      return;
    }
    
    // 5분마다 만료일 체크
    _periodicCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        // 만료일 체크
        // 프로그램 시작 후 날짜를 정상으로 복구한 경우를 감지하기 위함
        if (AppInfo.isExpired()) {
          // 만료된 경우 경고 다이얼로그 표시
          if (mounted) {
            _showExpiryDialog();
          }
        }
      },
    );
  }

  /// 만료일 체크 및 처리
  ///
  /// 만료된 경우 경고 다이얼로그를 표시하고 프로그램을 종료합니다.
  /// 시스템 날짜 조작 공격도 함께 검증합니다.
  Future<void> _checkAndHandleExpiry() async {
    // 1. 시간 역행 검증 (시스템 날짜 조작 방어)
    // 프로그램 시작 전에 날짜를 과거로 변경한 경우 감지
    final isTimeReversed = await AppInfo.isTimeReversed();
    if (isTimeReversed) {
      _showTimeManipulationDialog(
        '시스템 날짜가 조작된 것으로 감지되었습니다.\n'
        '프로그램을 정상적으로 사용하려면 시스템 날짜를 올바르게 설정해주세요.',
      );
      return;
    }

    // 2. 시간 비정상 점프 검증
    // 마지막 실행 시간과 현재 시간의 차이가 비정상적으로 큰 경우 감지
    final isTimeJumped = await AppInfo.isTimeAbnormallyJumped();
    if (isTimeJumped) {
      _showTimeManipulationDialog(
        '시스템 날짜가 비정상적으로 변경된 것으로 감지되었습니다.\n'
        '프로그램을 정상적으로 사용하려면 시스템 날짜를 올바르게 설정해주세요.',
      );
      return;
    }

    // 3. 만료일이 설정되지 않은 경우 체크하지 않음
    if (AppInfo.expiryDate == null) {
      // 만료일 체크가 없어도 마지막 실행 시간은 저장
      await AppInfo.saveLastExecutionTime();
      return;
    }

    // 4. 만료 여부 확인
    if (AppInfo.isExpired()) {
      // 만료된 경우 경고 다이얼로그 표시
      _showExpiryDialog();
    } else {
      // 만료되지 않은 경우 30일 이내 경고만 표시 (선택사항)
      final daysUntilExpiry = AppInfo.getDaysUntilExpiry();
      if (daysUntilExpiry != null && daysUntilExpiry <= 30) {
        debugPrint('⚠️ 경고: 프로그램 사용 기간이 $daysUntilExpiry일 남았습니다.');
      }
      
      // 정상 실행 시 마지막 실행 시간 저장
      await AppInfo.saveLastExecutionTime();
    }
  }

  /// 시간 조작 경고 다이얼로그 표시
  ///
  /// 시스템 날짜 조작이 감지된 경우 경고 메시지를 표시하고 프로그램을 종료합니다.
  void _showTimeManipulationDialog(String message) {
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
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '시스템 날짜 오류',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
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
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '보안상의 이유로 프로그램을 종료합니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
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
                  foregroundColor: Colors.orange,
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

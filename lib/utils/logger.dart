import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 애플리케이션 전용 로깅 유틸리티 클래스
/// 
/// 이 클래스는 프로덕션 환경에서 안전한 로깅을 제공합니다.
/// 디버그 모드에서만 상세한 로그가 출력되며, 릴리즈 모드에서는
/// 중요한 에러 로그만 출력됩니다.
class AppLogger {
  static final Logger _logger = Logger(
    printer: SimplePrinter(), // 간단한 출력을 위한 SimplePrinter 사용
  );

  /// 교체 관리 관련 특화 로그
  /// 
  /// 교체 관리 기능에서 사용하는 특화된 로깅 메서드들입니다.
  static void exchangeDebug(String message) {
    if (kDebugMode) {
      _logger.d('🔄 [교체관리] $message');
    }
  }

  static void exchangeInfo(String message) {
    _logger.i('📋 [교체관리] $message');
  }

  /// 교사 빈시간 검사 관련 로그
  static void teacherEmptySlotsInfo(String message) {
    if (kDebugMode) {
      developer.log('ℹ️ [교사빈시간] $message', name: 'AppLogger');
    }
  }

  /// 일반 로그 메서드들
  static void debug(String message) {
    if (kDebugMode) {
      _logger.d(message);
    }
  }

  static void info(String message) {
    _logger.i(message);
  }

  static void warning(String message) {
    _logger.w(message);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}

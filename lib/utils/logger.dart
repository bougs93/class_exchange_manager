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

  /// 디버그 로그 출력
  /// 
  /// 개발 중 디버깅 목적으로 사용합니다.
  /// 릴리즈 빌드에서는 출력되지 않습니다.
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  /// 정보 로그 출력
  /// 
  /// 일반적인 정보를 기록할 때 사용합니다.
  /// 릴리즈 빌드에서도 출력됩니다.
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// 경고 로그 출력
  /// 
  /// 주의가 필요한 상황을 기록할 때 사용합니다.
  /// 릴리즈 빌드에서도 출력됩니다.
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// 에러 로그 출력
  /// 
  /// 에러가 발생했을 때 사용합니다.
  /// 릴리즈 빌드에서도 출력됩니다.
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// 치명적 에러 로그 출력
  /// 
  /// 애플리케이션이 중단될 수 있는 심각한 에러를 기록할 때 사용합니다.
  /// 릴리즈 빌드에서도 출력됩니다.
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// 교체 관리 관련 특화 로그
  /// 
  /// 교체 관리 기능에서 사용하는 특화된 로깅 메서드들입니다.
  static void exchangeDebug(String message) {
    debug('🔄 [교체관리] $message');
  }

  static void exchangeInfo(String message) {
    info('📋 [교체관리] $message');
  }

  static void exchangeWarning(String message) {
    warning('⚠️ [교체관리] $message');
  }

  static void exchangeError(String message, [dynamic error, StackTrace? stackTrace]) {
    error('❌ [교체관리] $message', error, stackTrace);
  }

  /// 교사 빈시간 검사 관련 로그
  static void teacherEmptySlotsDebug(String message) {
    if (kDebugMode) {
      developer.log('[교사빈시간] $message', name: 'AppLogger');
    }
  }

  static void teacherEmptySlotsInfo(String message) {
    if (kDebugMode) {
      developer.log('[교사빈시간] $message', name: 'AppLogger');
    }
  }

  static void teacherEmptySlotsWarning(String message) {
    if (kDebugMode) {
      developer.log('[교사빈시간] $message', name: 'AppLogger');
    }
  }

  /// Flutter의 기본 debugPrint를 사용한 안전한 출력
  /// 
  /// Flutter의 debugPrint는 릴리즈 모드에서 자동으로 비활성화됩니다.
  static void safePrint(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'AppLogger');
    }
  }
}

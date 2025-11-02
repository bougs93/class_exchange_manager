import 'package:flutter/material.dart';

/// SnackBar 표시를 위한 헬퍼 클래스
///
/// 프로젝트 전체에서 일관된 스낵바 UI를 제공합니다.
/// context.mounted 검사를 자동으로 수행하여 안전성을 보장합니다.
class SnackBarHelper {
  /// 성공 메시지 표시 (녹색)
  ///
  /// 작업이 성공적으로 완료되었을 때 사용합니다.
  ///
  /// 예시:
  /// ```dart
  /// SnackBarHelper.showSuccess(context, '저장이 완료되었습니다.');
  /// ```
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 에러 메시지 표시 (빨간색)
  ///
  /// 작업 실패 또는 오류가 발생했을 때 사용합니다.
  /// 기본 표시 시간은 3초이며, duration 매개변수로 변경할 수 있습니다.
  ///
  /// 예시:
  /// ```dart
  /// SnackBarHelper.showError(context, '저장에 실패했습니다.');
  /// ```
  static void showError(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 정보 메시지 표시 (파란색 또는 커스텀 색상)
  ///
  /// 일반적인 정보나 안내 메시지를 표시할 때 사용합니다.
  ///
  /// 예시:
  /// ```dart
  /// SnackBarHelper.showInfo(context, '파일을 선택해주세요.');
  /// SnackBarHelper.showInfo(context, '경고 메시지', backgroundColor: Colors.orange);
  /// ```
  static void showInfo(BuildContext context, String message, {Color? backgroundColor}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.blue.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 경고 메시지 표시 (주황색)
  ///
  /// 주의가 필요한 상황을 알릴 때 사용합니다.
  ///
  /// 예시:
  /// ```dart
  /// SnackBarHelper.showWarning(context, '복사할 데이터가 없습니다.');
  /// ```
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// SnackBar 표시를 위한 헬퍼 클래스
///
/// 프로젝트 전체에서 일관된 스낵바 UI를 제공합니다.
/// context.mounted 검사를 자동으로 수행하여 안전성을 보장합니다.
///
/// **이 클래스를 거치지 않고 `ScaffoldMessenger.of(context).showSnackBar(...)`를
/// 직접 호출하지 마세요.** 스낵바를 띄운 위젯이 표시 중에 다시 그려지며
/// unmount되는 경우(리스트 자동 새로고침 등) Flutter의 내부 자동 닫힘
/// 타이머가 시작되지 않아 스낵바가 화면에 영구히 남는 문제가 있었습니다
/// (2026-09-29). 이 클래스의 `_show()`가 그 문제를 해결하는 유일한
/// 지점이므로, 새 스낵바는 항상 아래 메서드(showSuccess/showError/
/// showInfo/showWarning/showWithAction) 중 하나로 표시하세요.
class SnackBarHelper {
  /// 모든 공개 메서드가 거치는 공통 표시 로직
  ///
  /// 직전 스낵바를 즉시 제거한 뒤 새로 표시하여 큐에 쌓여 오래 남는 것을
  /// 방지하고, `duration` 경과 후 강제로 닫아 화면에 계속 남는 문제를 막습니다.
  /// (Flutter의 내부 자동 닫힘 타이머는 현재 라우트가 활성 상태가 아니면
  /// 시작되지 않을 수 있어, 이 안전장치를 별도로 둡니다.)
  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action:
            actionLabel != null && onActionPressed != null
                ? SnackBarAction(
                  label: actionLabel,
                  textColor: Colors.white,
                  onPressed: onActionPressed,
                )
                : null,
      ),
    );

    // 스낵바를 띄운 위젯(예: 목록 아이템)은 스낵바가 떠 있는 동안 다시
    // 그려지며 unmount될 수 있다 — 여기서는 local context가 아니라
    // controller(= 앱 최상단 ScaffoldMessenger에 속함)를 닫는 것이므로
    // context.mounted 여부와 무관하게 항상 시도해야 한다.
    Future.delayed(duration, () {
      // 이미 자체적으로 닫혔을 수 있으므로(큐가 비어 예외 발생 가능) 안전하게 무시합니다.
      try {
        controller.close();
      } catch (_) {}
    });
  }

  /// 성공 메시지 표시 (녹색)
  ///
  /// 작업이 성공적으로 완료되었을 때 사용합니다.
  ///
  /// 예시:
  /// ```dart
  /// SnackBarHelper.showSuccess(context, '저장이 완료되었습니다.');
  /// ```
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message,
      backgroundColor: Colors.green.shade600,
      duration: duration,
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
  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _show(
      context,
      message,
      backgroundColor: Colors.red.shade600,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// 정보 메시지 표시 (브랜드 강조색 또는 커스텀 색상)
  ///
  /// 일반적인 정보나 안내 메시지를 표시할 때 사용합니다.
  ///
  /// 예시:
  /// ```dart
  /// SnackBarHelper.showInfo(context, '파일을 선택해주세요.');
  /// SnackBarHelper.showInfo(context, '경고 메시지', backgroundColor: Colors.orange);
  /// ```
  static void showInfo(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;
    _show(
      context,
      message,
      backgroundColor: backgroundColor ?? context.tokens.primary,
      duration: duration,
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
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message,
      backgroundColor: Colors.orange.shade600,
      duration: duration,
    );
  }

  /// 액션 버튼(예: 되돌리기)이 있는 메시지 표시
  ///
  /// 예시:
  /// ```dart
  /// SnackBarHelper.showWithAction(
  ///   context,
  ///   '교체가 완료되었습니다.',
  ///   backgroundColor: Colors.blue,
  ///   actionLabel: '되돌리기',
  ///   onActionPressed: undoLastExchange,
  /// );
  /// ```
  static void showWithAction(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    _show(
      context,
      message,
      backgroundColor: backgroundColor ?? Colors.blue,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }
}

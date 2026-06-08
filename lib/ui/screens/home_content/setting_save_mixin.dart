import 'package:flutter/material.dart';
import '../../../utils/logger.dart';

/// 설정 저장 공통 로직 Mixin
///
/// 저장 → 결과에 따른 SnackBar 표시 → 진행 상태(setSavingState) 토글의
/// 반복 패턴을 한곳에 모은다. State를 가진 위젯이면 어디서나 혼합해 사용한다.
mixin SettingSaveMixin<T extends StatefulWidget> on State<T> {
  /// SnackBar 표시 헬퍼
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 공통 설정 저장 헬퍼
  ///
  /// [saver] 실제 저장 동작(성공 여부 반환), [successMessage] 성공 메시지,
  /// [onSuccess] 저장 성공 후 콜백, [setSavingState] 진행 상태 토글.
  Future<void> saveSetting({
    required Future<bool> Function() saver,
    required String successMessage,
    String? errorMessage,
    VoidCallback? onSuccess,
    void Function(bool)? setSavingState,
  }) async {
    if (setSavingState != null) {
      setState(() => setSavingState(true));
    }

    try {
      final success = await saver();

      if (mounted) {
        if (success) {
          onSuccess?.call();
          showSnackBar(successMessage);
        } else {
          showSnackBar(errorMessage ?? '저장에 실패했습니다.', isError: true);
        }
      }
    } catch (e) {
      AppLogger.error('설정 저장 중 오류: $e', e);
      if (mounted) {
        showSnackBar('오류가 발생했습니다: $e', isError: true);
      }
    } finally {
      if (mounted && setSavingState != null) {
        setState(() => setSavingState(false));
      }
    }
  }
}

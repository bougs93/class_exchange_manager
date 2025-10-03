import 'package:flutter/material.dart';

/// UI 빌드 관련 헬퍼 메서드들
mixin ExchangeUIBuilder {
  /// 에러 메시지 섹션 빌드
  Widget buildErrorMessageSection(String? errorMessage, VoidCallback onClearError) {
    if (errorMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClearError,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// 사이드바 토글 버튼 빌드
  Widget? buildSidebarToggleButton({
    required bool isVisible,
    required VoidCallback onToggle,
    required int pathCount,
    required Color color,
    bool isLoading = false,
    double loadingProgress = 0.0,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: onToggle,
        icon: Icon(
          isVisible ? Icons.chevron_right : Icons.chevron_left,
          size: 16,
        ),
        label: Text(
          isLoading
            ? '${(loadingProgress * 100).round()}%'
            : '$pathCount개'
        ),
        style: TextButton.styleFrom(foregroundColor: color),
      ),
    );
  }

  /// SnackBar 표시 헬퍼
  void showSnackBarMessage(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../providers/exchange_screen_provider.dart';

/// 교체 화면 AppBar 위젯
class ExchangeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ExchangeScreenState state;
  final VoidCallback onToggleSidebar;

  const ExchangeAppBar({
    super.key,
    required this.state,
    required this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('교체 관리'),
      backgroundColor: Colors.blue.shade50,
      elevation: 0,
      actions: [
        // 순환교체 사이드바 토글 버튼
        if (state.isCircularExchangeModeEnabled &&
            (state.circularPaths.isNotEmpty || state.isCircularPathsLoading))
          _buildSidebarToggleButton(
            isLoading: state.isCircularPathsLoading,
            loadingProgress: state.loadingProgress,
            pathCount: state.circularPaths.length,
            color: Colors.purple.shade600,
          ),

        // 1:1 교체 사이드바 토글 버튼
        if (state.isExchangeModeEnabled && state.oneToOnePaths.isNotEmpty)
          _buildSidebarToggleButton(
            isLoading: false,
            pathCount: state.oneToOnePaths.length,
            color: Colors.blue.shade600,
          ),
      ],
    );
  }

  /// 사이드바 토글 버튼 생성
  Widget _buildSidebarToggleButton({
    required bool isLoading,
    double loadingProgress = 0.0,
    required int pathCount,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: onToggleSidebar,
        icon: Icon(
          state.isSidebarVisible ? Icons.chevron_right : Icons.chevron_left,
          size: 16,
        ),
        label: Text(
          isLoading
            ? '${(loadingProgress * 100).round()}%'
            : '$pathCount개'
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

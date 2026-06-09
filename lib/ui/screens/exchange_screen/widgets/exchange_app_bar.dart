import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../../providers/state_reset_provider.dart';
import '../../../../providers/cell_selection_provider.dart';
import '../../../../models/exchange_mode.dart';
import '../../../../models/circular_exchange_path.dart';
import '../../../../models/one_to_one_exchange_path.dart';
import '../../../../utils/exchange_path_utils.dart';
import '../../../../utils/logger.dart';

/// 교체 화면 AppBar 위젯
class ExchangeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final ExchangeScreenState state;
  final VoidCallback onToggleSidebar;
  final VoidCallback onUpdateHeaderTheme;

  const ExchangeAppBar({
    super.key,
    required this.state,
    required this.onToggleSidebar,
    required this.onUpdateHeaderTheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: const Text('교체'),
      backgroundColor: Colors.blue.shade50,
      elevation: 0,
      actions: [
        // 🧪 테스트 버튼 (개발용)
        _buildTestButton(context, ref),

        // 순환교체 사이드바 토글 버튼
        if (_shouldShowCircularButton())
          _buildSidebarToggleButton(
            isLoading: state.isPathsLoading,
            loadingProgress: state.loadingProgress,
            pathCount: ExchangePathUtils.countPathsOfType<CircularExchangePath>(
              state.availablePaths,
            ),
            color: Colors.purple.shade600,
          ),

        // 1:1 교체 사이드바 토글 버튼
        if (_shouldShowOneToOneButton())
          _buildSidebarToggleButton(
            isLoading: false,
            pathCount: ExchangePathUtils.countPathsOfType<OneToOneExchangePath>(
              state.availablePaths,
            ),
            color: Colors.blue.shade600,
          ),
      ],
    );
  }

  /// 순환교체 버튼 표시 여부
  bool _shouldShowCircularButton() {
    return state.currentMode == ExchangeMode.circularExchange &&
        (ExchangePathUtils.hasPathsOfType<CircularExchangePath>(
              state.availablePaths,
            ) ||
            state.isPathsLoading);
  }

  /// 1:1 교체 버튼 표시 여부
  bool _shouldShowOneToOneButton() {
    return state.currentMode.isExchangeMode &&
        ExchangePathUtils.hasPathsOfType<OneToOneExchangePath>(
          state.availablePaths,
        );
  }

  /// 🧪 테스트 버튼 생성 (개발용)
  Widget _buildTestButton(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.science, color: Colors.orange),
        tooltip: '초기화 테스트',
        onSelected: (String value) => _handleTestAction(context, ref, value),
        itemBuilder:
            (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'level1',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text('Level 1 초기화'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'level2',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text('Level 2 초기화'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'level3',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text('Level 3 초기화'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Text('현재 상태 정보'),
                  ],
                ),
              ),
            ],
      ),
    );
  }

  /// 🧪 테스트 액션 처리
  void _handleTestAction(BuildContext context, WidgetRef ref, String action) {
    final stateResetNotifier = ref.read(stateResetProvider.notifier);

    switch (action) {
      case 'level1':
        if (kDebugMode) {
          AppLogger.exchangeDebug('🧪 [Level 1] 초기화 실행');
        }
        stateResetNotifier.resetPathOnly(reason: '테스트 - Level 1 초기화');
        onUpdateHeaderTheme(); // 헤더 테마 업데이트 필수
        _showTestResult(context, 'Level 1 초기화 완료', Colors.green);
        break;

      case 'level2':
        if (kDebugMode) {
          final beforeState = ref.read(cellSelectionProvider);
          AppLogger.exchangeDebug(
            '🧪 [Level 2] 초기화: ${beforeState.selectedTeacher} '
            '${beforeState.selectedDay}${beforeState.selectedPeriod} → 초기화됨',
          );
        }
        stateResetNotifier.resetExchangeStates(reason: '테스트 - Level 2 초기화');
        _showTestResult(context, 'Level 2 초기화 완료', Colors.orange);
        break;

      case 'level3':
        if (kDebugMode) {
          AppLogger.exchangeDebug('🧪 [Level 3] 전체 상태 초기화 실행');
        }
        stateResetNotifier.resetAllStates(reason: '테스트 - Level 3 초기화');
        _showTestResult(context, 'Level 3 초기화 완료', Colors.red);
        break;

      case 'info':
        _showCurrentStateInfo(context, ref);
        break;
    }
  }

  /// 🧪 현재 상태 정보 표시
  void _showCurrentStateInfo(BuildContext context, WidgetRef ref) {
    final currentState = ref.read(exchangeScreenProvider);
    final cellState = ref.read(cellSelectionProvider);

    final info = '''
현재 상태 정보:

📋 교체 모드: ${currentState.currentMode.displayName}
📊 사용 가능한 경로: ${currentState.availablePaths.length}개
  - 1:1 교체: ${ExchangePathUtils.countPathsOfType<OneToOneExchangePath>(currentState.availablePaths)}개
  - 순환 교체: ${ExchangePathUtils.countPathsOfType<CircularExchangePath>(currentState.availablePaths)}개

🎯 선택된 경로:
  - 1:1: ${currentState.selectedOneToOnePath?.id ?? '없음'}
  - 순환: ${currentState.selectedCircularPath?.id ?? '없음'}
  - 2중교체: ${currentState.selectedDualPath?.id ?? '없음'}

🔍 셀 선택 상태:
  - 선택된 교사: ${cellState.selectedTeacher ?? '없음'}
  - 선택된 요일: ${cellState.selectedDay ?? '없음'}
  - 선택된 교시: ${cellState.selectedPeriod ?? '없음'}
  - 화살표 표시: ${cellState.isArrowVisible ? '예' : '아니오'}

📱 UI 상태:
  - 사이드바 표시: ${currentState.isSidebarVisible ? '예' : '아니오'}
  - 로딩 중: ${currentState.isPathsLoading ? '예' : '아니오'}
''';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text('현재 상태 정보'),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                info,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }

  /// 🧪 테스트 결과 표시
  void _showTestResult(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
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
          isLoading ? '${(loadingProgress * 100).round()}%' : '$pathCount개',
        ),
        style: TextButton.styleFrom(foregroundColor: color),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

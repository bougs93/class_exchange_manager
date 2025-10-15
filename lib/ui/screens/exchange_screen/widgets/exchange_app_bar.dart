import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../../providers/state_reset_provider.dart';
import '../../../../models/exchange_mode.dart';
import '../../../../models/circular_exchange_path.dart';
import '../../../../models/one_to_one_exchange_path.dart';
import '../../../../utils/exchange_path_utils.dart';
import '../../../../utils/logger.dart';

/// 교체 화면 AppBar 위젯
class ExchangeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final ExchangeScreenState state;
  final VoidCallback onToggleSidebar;

  const ExchangeAppBar({
    super.key,
    required this.state,
    required this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: const Text('교체 관리'),
      backgroundColor: Colors.blue.shade50,
      elevation: 0,
      actions: [
        // 테스트 버튼들 - notifyDataSourceListeners() 호출
        PopupMenuButton<String>(
          icon: const Icon(Icons.bug_report, color: Colors.red),
          tooltip: '테스트 메뉴',
          onSelected: (String value) {
            switch (value) {
              case 'notifyDataChanged':
                AppLogger.exchangeDebug('🧪 [테스트] notifyDataChanged() 호출');
                state.dataSource?.notifyDataChanged();
                AppLogger.exchangeDebug('🧪 [테스트] notifyDataChanged() 호출 완료');
                break;
              case 'clearCache':
                AppLogger.exchangeDebug('🧪 [테스트] clearAllCaches() 호출');
                state.dataSource?.clearAllCaches();
                AppLogger.exchangeDebug('🧪 [테스트] clearAllCaches() 호출 완료');
                break;
              case 'refreshUI':
                AppLogger.exchangeDebug('🧪 [테스트] refreshUI() 호출');
                state.dataSource?.refreshUI();
                AppLogger.exchangeDebug('🧪 [테스트] refreshUI() 호출 완료');
                break;
              case 'clearAllSelections':
                AppLogger.exchangeDebug('🧪 [테스트] clearAllSelections() 호출');
                state.dataSource?.clearAllSelections();
                AppLogger.exchangeDebug('🧪 [테스트] clearAllSelections() 호출 완료');
                break;
              case 'resetPathSelectionBatch':
                AppLogger.exchangeDebug('🧪 [테스트] resetPathSelectionBatch() 호출');
                state.dataSource?.resetPathSelectionBatch();
                AppLogger.exchangeDebug('🧪 [테스트] resetPathSelectionBatch() 호출 완료');
                break;
              case 'resetExchangeStatesBatch':
                AppLogger.exchangeDebug('🧪 [테스트] resetExchangeStatesBatch() 호출');
                state.dataSource?.resetExchangeStatesBatch();
                AppLogger.exchangeDebug('🧪 [테스트] resetExchangeStatesBatch() 호출 완료');
                break;
              case 'resetPathOnly':
                AppLogger.exchangeDebug('🧪 [테스트] StateResetProvider.resetPathOnly() 호출');
                ref.read(stateResetProvider.notifier).resetPathOnly(reason: '테스트: resetPathOnly');
                AppLogger.exchangeDebug('🧪 [테스트] StateResetProvider.resetPathOnly() 호출 완료');
                break;
              case 'resetExchangeStates':
                AppLogger.exchangeDebug('🧪 [테스트] StateResetProvider.resetExchangeStates() 호출');
                ref.read(stateResetProvider.notifier).resetExchangeStates(reason: '테스트: resetExchangeStates');
                AppLogger.exchangeDebug('🧪 [테스트] StateResetProvider.resetExchangeStates() 호출 완료');
                break;
              case 'setCurrentMode':
                AppLogger.exchangeDebug('🧪 [테스트] setCurrentMode() 호출');
                ref.read(exchangeScreenProvider.notifier).setCurrentMode(ExchangeMode.circularExchange);
                AppLogger.exchangeDebug('🧪 [테스트] setCurrentMode() 호출 완료');
                break;
              case 'updateSelectedCircularPath':
                AppLogger.exchangeDebug('🧪 [테스트] updateSelectedCircularPath() 호출');
                state.dataSource?.updateSelectedCircularPath(null);
                AppLogger.exchangeDebug('🧪 [테스트] updateSelectedCircularPath() 호출 완료');
                break;
              case 'simulatePathSelection':
                AppLogger.exchangeDebug('🧪 [테스트] 경로 선택 시뮬레이션 시작');
                // ExchangeScreen.onPathSelected() 전체 시퀀스 시뮬레이션
                ref.read(exchangeScreenProvider.notifier).setSelectedCircularPath(null);
                if (state.currentMode != ExchangeMode.circularExchange) {
                  ref.read(exchangeScreenProvider.notifier).setCurrentMode(ExchangeMode.circularExchange);
                }
                state.dataSource?.updateSelectedCircularPath(null);
                AppLogger.exchangeDebug('🧪 [테스트] 경로 선택 시뮬레이션 완료');
                break;
              case 'simulateModeChange':
                AppLogger.exchangeDebug('🧪 [테스트] 모드 변경 시뮬레이션 시작');
                // ExchangeScreen._performModeChangeTasks() 시뮬레이션
                ref.read(stateResetProvider.notifier).resetExchangeStates(reason: '테스트: 모드 변경 시뮬레이션');
                ref.read(exchangeScreenProvider.notifier).setCurrentMode(ExchangeMode.circularExchange);
                AppLogger.exchangeDebug('🧪 [테스트] 모드 변경 시뮬레이션 완료');
                break;
              case 'testSetColumns':
                AppLogger.exchangeDebug('🧪 [테스트] setColumns() 호출');
                // 현재 columns와 동일한 값으로 설정하여 구조적 변경 시뮬레이션
                ref.read(exchangeScreenProvider.notifier).setColumns(state.columns);
                AppLogger.exchangeDebug('🧪 [테스트] setColumns() 호출 완료');
                break;
              case 'simulateRealPathSelection':
                AppLogger.exchangeDebug('🧪 [테스트] 실제 경로 선택 시뮬레이션 시작');
                // 실제 CircularExchangePath 객체 생성하여 테스트
                final circularPaths = state.availablePaths.whereType<CircularExchangePath>().toList();
                if (circularPaths.isNotEmpty) {
                  final testPath = circularPaths.first;
                  AppLogger.exchangeDebug('🧪 [테스트] 테스트 경로: ${testPath.id}');
                  
                  // 실제 경로 선택 시퀀스 시뮬레이션
                  ref.read(exchangeScreenProvider.notifier).setSelectedCircularPath(testPath);
                  
                  if (state.currentMode != ExchangeMode.circularExchange) {
                    ref.read(exchangeScreenProvider.notifier).setCurrentMode(ExchangeMode.circularExchange);
                  }
                  
                  state.dataSource?.updateSelectedCircularPath(testPath);
                  
                  // 타겟 셀 설정 시뮬레이션 (실제 경로가 있을 때만)
                  if (testPath.nodes.length >= 2) {
                    final sourceNode = testPath.nodes[0];
                    final targetNode = testPath.nodes[1];
                    state.dataSource?.updateTargetCell(
                      sourceNode.teacherName, 
                      targetNode.day, 
                      targetNode.period
                    );
                  }
                  
                  AppLogger.exchangeDebug('🧪 [테스트] 실제 경로 선택 시뮬레이션 완료');
                } else {
                  AppLogger.exchangeDebug('🧪 [테스트] 테스트할 순환교체 경로가 없음');
                }
                break;
              case 'toggleSidebar':
                AppLogger.exchangeDebug('🧪 [테스트] 사이드바 토글 호출');
                onToggleSidebar();
                AppLogger.exchangeDebug('🧪 [테스트] 사이드바 토글 완료');
                break;
              case 'showSidebar':
                AppLogger.exchangeDebug('🧪 [테스트] 사이드바 표시');
                ref.read(exchangeScreenProvider.notifier).setSidebarVisible(true);
                AppLogger.exchangeDebug('🧪 [테스트] 사이드바 표시 완료');
                break;
              case 'hideSidebar':
                AppLogger.exchangeDebug('🧪 [테스트] 사이드바 숨김');
                ref.read(exchangeScreenProvider.notifier).setSidebarVisible(false);
                AppLogger.exchangeDebug('🧪 [테스트] 사이드바 숨김 완료');
                break;
              case 'showEmptySidebar':
                AppLogger.exchangeDebug('🧪 [테스트] 빈 사이드바 표시');
                // 순환교체 모드로 변경하여 사이드바 표시 조건 만족
                ref.read(exchangeScreenProvider.notifier).setCurrentMode(ExchangeMode.circularExchange);
                ref.read(exchangeScreenProvider.notifier).setSidebarVisible(true);
                ref.read(exchangeScreenProvider.notifier).setPathsLoading(true);
                AppLogger.exchangeDebug('🧪 [테스트] 빈 사이드바 표시 완료');
                break;
              case 'showSidebarWithPaths':
                AppLogger.exchangeDebug('🧪 [테스트] 경로가 있는 사이드바 표시');
                // 순환교체 모드로 변경하고 더미 경로 추가
                ref.read(exchangeScreenProvider.notifier).setCurrentMode(ExchangeMode.circularExchange);
                ref.read(exchangeScreenProvider.notifier).setSidebarVisible(true);
                ref.read(exchangeScreenProvider.notifier).setPathsLoading(false);
                AppLogger.exchangeDebug('🧪 [테스트] 경로가 있는 사이드바 표시 완료');
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            // 기본 테스트 옵션들
            const PopupMenuItem<String>(
              value: 'notifyDataChanged',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 16),
                  SizedBox(width: 8),
                  Text('notifyDataChanged()'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'clearCache',
              child: Row(
                children: [
                  Icon(Icons.clear_all, size: 16),
                  SizedBox(width: 8),
                  Text('clearAllCaches()'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'refreshUI',
              child: Row(
                children: [
                  Icon(Icons.update, size: 16),
                  SizedBox(width: 8),
                  Text('refreshUI()'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            
            // TimetableDataSource 테스트 옵션들
            const PopupMenuItem<String>(
              value: 'clearAllSelections',
              child: Row(
                children: [
                  Icon(Icons.clear, size: 16),
                  SizedBox(width: 8),
                  Text('clearAllSelections()'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'resetPathSelectionBatch',
              child: Row(
                children: [
                  Icon(Icons.restore, size: 16),
                  SizedBox(width: 8),
                  Text('resetPathSelectionBatch()'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'resetExchangeStatesBatch',
              child: Row(
                children: [
                  Icon(Icons.restore_page, size: 16),
                  SizedBox(width: 8),
                  Text('resetExchangeStatesBatch()'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'updateSelectedCircularPath',
              child: Row(
                children: [
                  Icon(Icons.route, size: 16),
                  SizedBox(width: 8),
                  Text('updateSelectedCircularPath()'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            
            // StateResetProvider 테스트 옵션들
            const PopupMenuItem<String>(
              value: 'resetPathOnly',
              child: Row(
                children: [
                  Icon(Icons.route, size: 16),
                  SizedBox(width: 8),
                  Text('resetPathOnly()'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'resetExchangeStates',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 16),
                  SizedBox(width: 8),
                  Text('resetExchangeStates()'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            
            // ExchangeScreenProvider 테스트 옵션들
            const PopupMenuItem<String>(
              value: 'setCurrentMode',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, size: 16),
                  SizedBox(width: 8),
                  Text('setCurrentMode()'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            
            // 통합 시뮬레이션 테스트 옵션들
            const PopupMenuItem<String>(
              value: 'simulatePathSelection',
              child: Row(
                children: [
                  Icon(Icons.play_arrow, size: 16),
                  SizedBox(width: 8),
                  Text('경로 선택 시뮬레이션'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'simulateModeChange',
              child: Row(
                children: [
                  Icon(Icons.swap_horizontal_circle, size: 16),
                  SizedBox(width: 8),
                  Text('모드 변경 시뮬레이션'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            
            // 헤더 테마 관련 테스트 옵션들
            const PopupMenuItem<String>(
              value: 'testSetColumns',
              child: Row(
                children: [
                  Icon(Icons.view_column, size: 16),
                  SizedBox(width: 8),
                  Text('setColumns()'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'testSetStackedHeaders',
              child: Row(
                children: [
                  Icon(Icons.view_headline, size: 16),
                  SizedBox(width: 8),
                  Text('setStackedHeaders()'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            
            // 실제 경로 선택 시뮬레이션
            const PopupMenuItem<String>(
              value: 'simulateRealPathSelection',
              child: Row(
                children: [
                  Icon(Icons.route, size: 16),
                  SizedBox(width: 8),
                  Text('실제 경로 선택 시뮬레이션'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            
            // 사이드바 관련 테스트 옵션들
            const PopupMenuItem<String>(
              value: 'toggleSidebar',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, size: 16),
                  SizedBox(width: 8),
                  Text('사이드바 토글'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'showSidebar',
              child: Row(
                children: [
                  Icon(Icons.chevron_right, size: 16),
                  SizedBox(width: 8),
                  Text('사이드바 표시'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'hideSidebar',
              child: Row(
                children: [
                  Icon(Icons.chevron_left, size: 16),
                  SizedBox(width: 8),
                  Text('사이드바 숨김'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'showEmptySidebar',
              child: Row(
                children: [
                  Icon(Icons.view_sidebar, size: 16),
                  SizedBox(width: 8),
                  Text('빈 사이드바 표시'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'showSidebarWithPaths',
              child: Row(
                children: [
                  Icon(Icons.view_sidebar_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('경로가 있는 사이드바'),
                ],
              ),
            ),
          ],
        ),

        // 순환교체 사이드바 토글 버튼
        if (_shouldShowCircularButton())
          _buildSidebarToggleButton(
            isLoading: state.isPathsLoading,
            loadingProgress: state.loadingProgress,
            pathCount: ExchangePathUtils.countPathsOfType<CircularExchangePath>(state.availablePaths),
            color: Colors.purple.shade600,
          ),

        // 1:1 교체 사이드바 토글 버튼
        if (_shouldShowOneToOneButton())
          _buildSidebarToggleButton(
            isLoading: false,
            pathCount: ExchangePathUtils.countPathsOfType<OneToOneExchangePath>(state.availablePaths),
            color: Colors.blue.shade600,
          ),
      ],
    );
  }

  /// 순환교체 버튼 표시 여부
  bool _shouldShowCircularButton() {
    return state.currentMode == ExchangeMode.circularExchange &&
        (ExchangePathUtils.hasPathsOfType<CircularExchangePath>(state.availablePaths) || state.isPathsLoading);
  }

  /// 1:1 교체 버튼 표시 여부
  bool _shouldShowOneToOneButton() {
    return state.currentMode.isExchangeMode &&
        ExchangePathUtils.hasPathsOfType<OneToOneExchangePath>(state.availablePaths);
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

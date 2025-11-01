import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/state_reset_provider.dart';
import '../../models/exchange_mode.dart';
import 'exchange_screen/exchange_screen_state_proxy.dart';
import 'exchange_screen/managers/exchange_operation_manager.dart';
import 'help_screen.dart';
import 'info_screen.dart';

/// 홈 콘텐츠 화면
///
/// 메인 홈 화면의 내용을 표시합니다.
/// - 환영 메시지 카드
/// - 메뉴 그리드 (시간표 선택, 교체 관리, 결보강계획서, 개인 시간표, 설정, 도움말, 정보)
class HomeContentScreen extends ConsumerWidget {
  const HomeContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screenState = ref.watch(exchangeScreenProvider);
    final selectedFile = screenState.selectedFile;

    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 환영 메시지 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.school,
                      color: theme.primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '수업 교체 관리자',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedFile != null
                            ? '현재 시간표: ${selectedFile.path.split(Platform.pathSeparator).last}'
                            : '시간표 파일을 선택해주세요',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 메뉴 그리드
            _buildMenuGrid(context, ref, theme),
          ],
        ),
      ),
    );
  }

  /// 메뉴 그리드 생성
  Widget _buildMenuGrid(BuildContext context, WidgetRef ref, ThemeData theme) {
    final menuItems = [
      {
        'title': '시간표 선택',
        'icon': Icons.upload_file,
        'color': theme.primaryColor,
        'onTap': () => _selectExcelFile(context, ref),
      },
      {
        'title': '교체 관리',
        'icon': Icons.swap_horiz,
        'color': theme.primaryColor,
        'onTap': () {
          ref.read(navigationProvider.notifier).state = 1;
        },
      },
      {
        'title': '결보강계획서',
        'icon': Icons.print,
        'color': theme.primaryColor,
        'onTap': () {
          ref.read(navigationProvider.notifier).state = 2;
        },
      },
      {
        'title': '개인 시간표',
        'icon': Icons.person,
        'color': theme.primaryColor,
        'onTap': () {
          ref.read(navigationProvider.notifier).state = 3;
        },
      },
      {
        'title': '설정',
        'icon': Icons.settings,
        'color': Colors.grey.shade600,
        'onTap': () {
          ref.read(navigationProvider.notifier).state = 4;
        },
      },
      {
        'title': '도움말',
        'icon': Icons.help_outline,
        'color': Colors.grey.shade600,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HelpScreen(),
            ),
          );
        },
      },
      {
        'title': '정보',
        'icon': Icons.info_outline,
        'color': Colors.grey.shade600,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InfoScreen(),
            ),
          );
        },
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: menuItems.map((item) {
        return _buildMenuCard(
          context: context,
          theme: theme,
          title: item['title'] as String,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          onTap: item['onTap'] as VoidCallback,
        );
      }).toList(),
    );
  }

  /// 메뉴 카드 생성
  Widget _buildMenuCard({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    const double cardWidth = 120.0;
    const double cardHeight = 124.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: cardWidth,
        maxWidth: cardWidth,
        minHeight: cardHeight,
        maxHeight: cardHeight,
      ),
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 36,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 엑셀 파일 선택 메서드
  Future<void> _selectExcelFile(BuildContext context, WidgetRef ref) async {
    final stateProxy = ExchangeScreenStateProxy(ref);
    final operationManager = ExchangeOperationManager(
      context: context,
      ref: ref,
      stateProxy: stateProxy,
      onCreateSyncfusionGridData: () {},
      onClearAllExchangeStates: () {
        ref.read(stateResetProvider.notifier).resetAllStates(
          reason: '파일 선택 후 전체 상태 초기화',
        );
      },
      onRefreshHeaderTheme: () {},
    );

    final fileSelected = await operationManager.selectExcelFile();

    if (fileSelected) {
      final globalNotifier = ref.read(exchangeScreenProvider.notifier);
      globalNotifier.setCurrentMode(ExchangeMode.view);

      ref.read(stateResetProvider.notifier).resetAllStates(
        reason: '파일 선택 후 전체 상태 초기화',
      );

      // 파일 선택 후 교체 관리 화면으로 이동
      ref.read(navigationProvider.notifier).state = 1;
    }
  }
}

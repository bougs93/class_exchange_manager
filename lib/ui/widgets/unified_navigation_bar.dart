import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/nav_indices.dart';
import '../../providers/navigation_provider.dart';

/// 모든 화면에서 사용하는 통합 네비게이션 바
///
/// 특징:
/// - 자주 사용하는 기능에 빠른 접근
/// - 현재 페이지 위치 명확히 표시
/// - 모든 화면에서 일관된 네비게이션
class UnifiedNavigationBar extends ConsumerWidget {
  const UnifiedNavigationBar({super.key});

  // 네비게이션 항목 정의 (상수로 캐싱)
  static const _navItems = [
    {
      'index': NavIndices.home,
      'icon': Icons.home,
      'label': '홈',
      'tooltip': '홈',
    },
    {
      'index': NavIndices.exchange,
      'icon': Icons.swap_horiz,
      'label': '교체',
      'tooltip': '교체',
    },
    {
      'index': NavIndices.document,
      'icon': Icons.print,
      'label': '출력',
      'tooltip': '출력',
    },
    {
      'index': NavIndices.personalSchedule,
      'icon': Icons.person,
      'label': '시간표',
      'tooltip': '시간표',
    },
    {
      'index': NavIndices.help,
      'icon': Icons.help_outline,
      'label': '도움말',
      'tooltip': '도움말',
    },
    {
      'index': NavIndices.info,
      'icon': Icons.info_outline,
      'label': '정보',
      'tooltip': '정보',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationProvider);

    return Container(
      height: 60, // 높이를 56에서 60으로 증가 (오버플로우 방지)
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children:
            _navItems.map((item) {
              final index = item['index'] as int;
              final icon = item['icon'] as IconData;
              final label = item['label'] as String;
              final tooltip = item['tooltip'] as String;
              final isSelected = selectedIndex == index;

              return Expanded(
                child: _buildNavItem(
                  context: context,
                  ref: ref,
                  index: index,
                  icon: icon,
                  label: label,
                  tooltip: tooltip,
                  isSelected: isSelected,
                ),
              );
            }).toList(),
      ),
    );
  }

  /// 네비게이션 항목 생성
  ///
  /// 선택된 항목은 파란색 배경과 하단 밑줄로 강조됩니다.
  Widget _buildNavItem({
    required BuildContext context,
    required WidgetRef ref,
    required int index,
    required IconData icon,
    required String label,
    required String tooltip,
    required bool isSelected,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(navigationProvider.notifier).state = index;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4), // 패딩을 8에서 4로 감소
            decoration: BoxDecoration(
              // 선택된 항목: 파란색 배경
              color: isSelected ? Colors.blue.shade50 : Colors.transparent,
              // 선택된 항목: 하단 파란색 밑줄
              border:
                  isSelected
                      ? Border(
                        bottom: BorderSide(
                          color: Colors.blue.shade700,
                          width: 3,
                        ),
                      )
                      : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22, // 아이콘 크기를 24에서 22로 약간 감소
                  color:
                      isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                ),
                const SizedBox(height: 3), // 간격을 4에서 3으로 감소
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected
                            ? Colors.blue.shade700
                            : Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

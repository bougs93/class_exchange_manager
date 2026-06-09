import 'package:flutter/material.dart';
import 'document_screen/widgets/class_notice_widget.dart';
import 'document_screen/widgets/teacher_notice_widget.dart';
import '../widgets/unified_navigation_bar.dart';

/// 안내 화면
///
/// 교사안내·학급안내 메시지를 왼쪽 사이드바 메뉴로 제공합니다.
class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  /// 선택된 메뉴 인덱스 (0: 교사안내, 1: 학급안내)
  int _selectedIndex = 0;

  /// 문서 화면과 동일한 사이드바 너비
  static const double _sidebarWidth = 135.0;

  /// 사이드바 메뉴 정의 (아이콘·라벨·강조 색상)
  static const _menuItems = [
    (
      icon: Icons.person,
      label: '교사안내',
      color: Colors.orange,
    ),
    (
      icon: Icons.class_,
      label: '학급안내',
      color: Colors.green,
    ),
  ];

  void _onMenuSelected(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              widthFactor: 1.0,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  /// 왼쪽 사이드바 — 문서 화면과 동일한 레이아웃·스타일
  Widget _buildSidebar() {
    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(_menuItems.length, (index) {
            final item = _menuItems[index];
            final isSelected = _selectedIndex == index;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onMenuSelected(index),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: kUnifiedNavBarHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? item.color.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(color: item.color, width: 1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color:
                              isSelected ? item.color : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? item.color
                                  : Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const TeacherNoticeWidget();
      case 1:
        return const ClassNoticeWidget();
      default:
        return const TeacherNoticeWidget();
    }
  }
}

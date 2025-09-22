import 'package:flutter/material.dart';
import 'exchange_screen.dart';
import 'personal_schedule_screen.dart';
import 'document_screen.dart';
import 'settings_screen.dart';

/// 메인 홈 화면 - Drawer 메뉴가 있는 Scaffold
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // 현재 선택된 메뉴 인덱스

  // 메뉴 항목들 정의
  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': '홈',
      'icon': Icons.home,
      'screen': const HomeContentScreen(),
    },
    {
      'title': '교체 관리',
      'icon': Icons.swap_horiz,
      'screen': const ExchangeScreen(),
    },
    {
      'title': '개인 시간표',
      'icon': Icons.person,
      'screen': const PersonalScheduleScreen(),
    },
    {
      'title': '문서 출력',
      'icon': Icons.print,
      'screen': const DocumentScreen(),
    },
    {
      'title': '설정',
      'icon': Icons.settings,
      'screen': const SettingsScreen(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Exchange Manager'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer 헤더
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.school,
                    size: 48,
                    color: Colors.white,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '교사용 시간표\n교체 관리자',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // 메뉴 항목들
            ...List.generate(_menuItems.length, (index) {
              final item = _menuItems[index];
              return ListTile(
                leading: Icon(
                  item['icon'],
                  color: _selectedIndex == index ? Colors.blue : Colors.grey[600],
                ),
                title: Text(
                  item['title'],
                  style: TextStyle(
                    color: _selectedIndex == index ? Colors.blue : Colors.black,
                    fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: _selectedIndex == index,
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  Navigator.pop(context); // Drawer 닫기
                },
              );
            }),
            // 구분선
            const Divider(),
            // 도움말 메뉴
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('도움말'),
              onTap: () {
                Navigator.pop(context);
                // 도움말 화면으로 이동 (나중에 구현)
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('정보'),
              onTap: () {
                Navigator.pop(context);
                // 정보 화면으로 이동 (나중에 구현)
              },
            ),
          ],
        ),
      ),
      body: _menuItems[_selectedIndex]['screen'],
    );
  }
}

// 홈 콘텐츠 화면
class HomeContentScreen extends StatelessWidget {
  const HomeContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home,
            size: 64,
            color: Colors.blue,
          ),
          SizedBox(height: 16),
          Text(
            '홈 화면',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '시간표를 보여주는 메인 화면입니다.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

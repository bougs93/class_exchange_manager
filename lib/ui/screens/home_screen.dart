import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'exchange_screen.dart';
import 'personal_schedule_screen.dart';
import 'document_screen.dart';
import 'settings_screen.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/state_reset_provider.dart';
import '../../models/exchange_mode.dart';
import '../../ui/screens/exchange_screen/exchange_screen_state_proxy.dart';
import '../../ui/screens/exchange_screen/managers/exchange_operation_manager.dart';

/// 메인 홈 화면 - Drawer 메뉴가 있는 Scaffold
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // 엑셀 파일 선택 관련 상태 관리
  ExchangeScreenStateProxy? _stateProxy;
  ExchangeOperationManager? _operationManager;
  
  @override
  void initState() {
    super.initState();
    
    // StateProxy 초기화
    _stateProxy = ExchangeScreenStateProxy(ref);
    
    // Manager 초기화 (엑셀 파일 처리 및 상태 관리)
    _operationManager = ExchangeOperationManager(
      context: context,
      ref: ref,
      stateProxy: _stateProxy!,
        onCreateSyncfusionGridData: () {
          // 파일이 선택되고 파싱이 완료된 후 시간표 그리드 생성
          if (mounted) {
            // 글로벌 Provider에 시간표 데이터 저장하여 다른 화면과 공유
            final globalNotifier = ref.read(exchangeScreenProvider.notifier);
            final timetableData = _stateProxy!.timetableData;
            
            if (timetableData != null) {
              globalNotifier.setTimetableData(timetableData);
            }
            
            setState(() {});
          }
        },
      onClearAllExchangeStates: () {
        // 교체 상태 초기화
        if (mounted) {
          setState(() {});
        }
      },
      onRefreshHeaderTheme: () {
        // 헤더 테마 업데이트
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  // 엑셀 파일 선택 메서드
  Future<void> _selectExcelFile() async {
    if (_operationManager != null) {
      // 파일 선택 시도
      bool fileSelected = await _operationManager!.selectExcelFile();
      
      // 파일 선택이 성공한 경우에만 초기화 수행
      if (fileSelected) {
        // 파일 선택 후 보기 모드로 전환
        final globalNotifier = ref.read(exchangeScreenProvider.notifier);
        globalNotifier.setCurrentMode(ExchangeMode.view);

        // 파일 선택 후 Level 3 초기화
        ref.read(stateResetProvider.notifier).resetAllStates(
          reason: '파일 선택 후 전체 상태 초기화',
        );
        
        if (mounted) {
          setState(() {});
        }
      }
      // 파일 선택이 취소된 경우 아무 동작하지 않음
    }
  }

  // 엑셀 파일 선택 해제 메서드
  void _clearSelectedFile() {
    _operationManager?.clearSelectedFile();
    if (mounted) setState(() {});
  }



  // 메뉴 항목들 정의
  List<Map<String, dynamic>> _menuItems() => [
    {
      'title': '홈',
      'icon': Icons.home,
      'screen': HomeContentScreen(),
    },
    {
      'title': '교체 관리',
      'icon': Icons.swap_horiz,
      'screen': ExchangeScreen(),
    },
    {
      'title': '결보강계획서/안내',
      'icon': Icons.print,
      'screen': DocumentScreen(),
    },
    {
      'title': '개인 시간표',
      'icon': Icons.person,
      'screen': PersonalScheduleScreen(),
    },

    {
      'title': '설정',
      'icon': Icons.settings,
      'screen': SettingsScreen(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationProvider);

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
            
            // 엑셀 파일 선택 메뉴 (간단한 ListTile 형태)
            Consumer(
              builder: (context, ref, child) {
                final screenState = ref.watch(exchangeScreenProvider);
                final selectedFile = screenState.selectedFile;
                
                return ListTile(
                  leading: Icon(
                    Icons.upload_file,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  title: Text(
                    selectedFile == null ? '엑셀 파일 선택' : '다른 파일 선택',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  subtitle: selectedFile != null 
                    ? Text(
                        selectedFile.path.split('\\').last,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      )
                    : const Text('시간표 파일(.xlsx, .xls)'),
                  onTap: screenState.isLoading ? null : _selectExcelFile,
                  enabled: !screenState.isLoading,
                  trailing: screenState.isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        selectedFile == null ? Icons.add : Icons.refresh,
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                );
              },
            ),
            
            // 파일 해제 메뉴 (파일이 선택된 경우에만 표시)
            Consumer(
              builder: (context, ref, child) {
                final screenState = ref.watch(exchangeScreenProvider);
                final selectedFile = screenState.selectedFile;
                
                // 파일이 선택되지 않은 경우 아무것도 표시하지 않음
                if (selectedFile == null) return const SizedBox.shrink();
                
                return ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  title: const Text(
                    '파일 선택 해제',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),

                  onTap: screenState.isLoading ? null : _clearSelectedFile,
                  enabled: !screenState.isLoading,
                  trailing: screenState.isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.clear,
                        color: Colors.red,
                        size: 16,
                      ),
                );
              },
            ),
            
            const Divider(height: 1),
            
            // 메뉴 항목들
            ...List.generate(_menuItems().length, (index) {
              final item = _menuItems()[index];
              return ListTile(
                leading: Icon(
                  item['icon'] as IconData,
                  color: selectedIndex == index ? Colors.blue : Colors.grey[600],
                ),
                title: Text(
                  item['title'] as String,
                  style: TextStyle(
                    color: selectedIndex == index ? Colors.blue : Colors.black,
                    fontWeight: selectedIndex == index ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: selectedIndex == index,
                onTap: () {
                  ref.read(navigationProvider.notifier).state = index;
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
      body: IndexedStack(
        index: selectedIndex,
        children: _menuItems().map((item) => item['screen'] as Widget).toList(),
      ),
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
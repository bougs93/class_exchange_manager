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
import '../../services/timetable_storage_service.dart';
import '../../services/exchange_history_service.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../../utils/logger.dart';
import '../../ui/widgets/timetable_grid/exchange_executor.dart';
import 'dart:io';

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
            // 🔥 중요: Provider에서 직접 읽어서 사용 (최신 상태 보장)
            final globalNotifier = ref.read(exchangeScreenProvider.notifier);
            final timetableData = ref.read(exchangeScreenProvider).timetableData;
            
            // Provider에 데이터가 없으면 StateProxy에서 다시 확인
            if (timetableData == null || timetableData.timeSlots.isEmpty) {
              final proxyData = _stateProxy!.timetableData;
              if (proxyData != null && proxyData.timeSlots.isNotEmpty) {
                AppLogger.info('🔄 [HomeScreen] onCreateSyncfusionGridData: Provider는 비어있지만 Proxy에 데이터 있음. 다시 설정합니다.');
                globalNotifier.setTimetableData(proxyData);
              }
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
    
    // 프로그램 시작 시 저장된 데이터 자동 로드
    _loadSavedData();
  }
  
  /// 저장된 데이터 자동 로드
  /// 
  /// 프로그램 시작 시 다음 데이터를 자동으로 로드합니다:
  /// - 시간표 데이터
  /// - 교체 리스트
  /// - 시간표 테마 설정
  /// (PDF 출력 설정은 FileExportWidget에서 로드)
  Future<void> _loadSavedData() async {
    try {
      AppLogger.info('프로그램 시작: 저장된 데이터 로드 중...');
      
      // 1. 시간표 테마 설정 로드
      await SimplifiedTimetableTheme.loadThemeSettings();
      
      // 2. 교체 리스트 로드
      final exchangeHistoryService = ExchangeHistoryService();
      await exchangeHistoryService.loadFromLocalStorage();
      
      // 3. 시간표 데이터 로드
      final timetableStorage = TimetableStorageService();
      final timetableData = await timetableStorage.loadTimetableData();
      
      if (timetableData != null) {
        // 시간표 데이터가 있으면 자동으로 로드
        if (mounted) {
          // 🔥 중요: 데이터 검증 로그 추가
          AppLogger.info('🔄 [HomeScreen] timetableData 로드 완료: ${timetableData.teachers.length}명 교사, ${timetableData.timeSlots.length}개 TimeSlot');
          
          final globalNotifier = ref.read(exchangeScreenProvider.notifier);
          globalNotifier.setTimetableData(timetableData);
          
          // 🔥 중요: Provider 설정 후 즉시 확인
          final verifyState = ref.read(exchangeScreenProvider);
          AppLogger.info('🔄 [HomeScreen] Provider 설정 확인: teachers=${verifyState.timetableData?.teachers.length ?? 0}명, timeSlots=${verifyState.timetableData?.timeSlots.length ?? 0}개');
          
          // 저장된 파일 경로 가져오기
          final savedFilePath = await timetableStorage.getSavedFilePath();
          if (savedFilePath != null) {
            final file = File(savedFilePath);
            if (await file.exists()) {
              // 파일이 존재하면 선택 상태로 설정
              _stateProxy?.setSelectedFile(file);
            }
          }
          
          // 🔥 중요: onCreateSyncfusionGridData 콜백에서 직접 timetableData를 사용하도록 수정 필요
          // 하지만 현재 구조상 콜백이 timetableData를 받지 않으므로, 
          // Provider가 업데이트되었는지 확인 후 호출
          // 시간표 그리드 데이터 생성
          if (_operationManager != null) {
            // Provider 업데이트 후 약간의 지연을 주어 상태 반영 보장
            await Future.delayed(const Duration(milliseconds: 50));
            
            final verifyState2 = ref.read(exchangeScreenProvider);
            if (verifyState2.timetableData != null && verifyState2.timetableData!.timeSlots.isNotEmpty) {
              final onCreateSyncfusionGridData = _operationManager!.onCreateSyncfusionGridData;
              onCreateSyncfusionGridData();
            } else {
              AppLogger.error('⚠️ [HomeScreen] Provider에 timetableData가 설정되지 않았습니다!');
            }
          }
          
          // 3-1. 교체된 셀 테마 복원 (시간표 데이터 로드 및 그리드 생성 후)
          // ExchangeExecutor의 정적 메서드를 사용하여 교체된 셀 테마 복원
          if (exchangeHistoryService.getExchangeList().isNotEmpty) {
            ExchangeExecutor.restoreExchangedCells(ref);
            AppLogger.info('교체된 셀 테마 복원 완료');
            
            // 교체된 셀 테마 복원 후 UI 업데이트
            final dataSource = ref.read(exchangeScreenProvider).dataSource;
            if (dataSource != null) {
              dataSource.notifyDataChanged();
            }
          }
          
          setState(() {});
        }
        
        AppLogger.info('시간표 데이터 자동 로드 완료');
      } else {
        AppLogger.info('저장된 시간표 데이터가 없습니다.');
      }
      
      AppLogger.info('저장된 데이터 로드 완료');
    } catch (e) {
      AppLogger.error('저장된 데이터 로드 중 오류: $e', e);
    }
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



  // 메뉴 항목들 정의 (홈 제외: 교체 관리, 결보강계획서/안내, 개인 시간표, 설정)
  List<Map<String, dynamic>> _menuItems() => [
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
            
            // 홈 메뉴 (최상단에 배치)
            ListTile(
              leading: Icon(
                Icons.home,
                color: selectedIndex == 0 ? Colors.blue : Colors.grey[600],
              ),
              title: Text(
                '홈',
                style: TextStyle(
                  color: selectedIndex == 0 ? Colors.blue : Colors.black,
                  fontWeight: selectedIndex == 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: selectedIndex == 0,
              onTap: () {
                ref.read(navigationProvider.notifier).state = 0;
                Navigator.pop(context); // Drawer 닫기
              },
            ),
            
            const Divider(height: 1),
            
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
            
            // 나머지 메뉴 항목들 (홈 제외: 교체 관리, 결보강계획서/안내, 개인 시간표, 설정)
            ...List.generate(_menuItems().length, (index) {
              final item = _menuItems()[index];
              final menuIndex = index + 1; // 홈이 인덱스 0이므로 +1
              return ListTile(
                leading: Icon(
                  item['icon'] as IconData,
                  color: selectedIndex == menuIndex ? Colors.blue : Colors.grey[600],
                ),
                title: Text(
                  item['title'] as String,
                  style: TextStyle(
                    color: selectedIndex == menuIndex ? Colors.blue : Colors.black,
                    fontWeight: selectedIndex == menuIndex ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: selectedIndex == menuIndex,
                onTap: () {
                  ref.read(navigationProvider.notifier).state = menuIndex;
                  Navigator.pop(context); // Drawer 닫기
                },
              );
            }),
            
            // 구분선
            const Divider(height: 1),
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
        children: [
          // 홈 화면 (인덱스 0)
          HomeContentScreen(),
          // 나머지 메뉴 화면들 (인덱스 1부터)
          ..._menuItems().map((item) => item['screen'] as Widget),
        ],
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
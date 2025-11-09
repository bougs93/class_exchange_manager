import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'exchange_screen.dart';
import 'personal_schedule_screen.dart';
import 'document_screen.dart';
import 'settings_screen.dart';
import 'info_screen.dart';
import 'help_screen.dart';
import 'home_content_screen.dart';
import '../../providers/navigation_provider.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/unified_navigation_bar.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/state_reset_provider.dart';
import '../../providers/services_provider.dart';
import '../../providers/substitution_plan_provider.dart';
import '../../models/exchange_mode.dart';
import '../../ui/screens/exchange_screen/exchange_screen_state_proxy.dart';
import '../../ui/screens/exchange_screen/managers/exchange_operation_manager.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../../utils/logger.dart';
import '../../ui/widgets/timetable_grid/exchange_executor.dart';
import '../../services/app_settings_storage_service.dart';
import '../../services/pdf_export_settings_storage_service.dart';
import '../../services/non_exchangeable_data_storage_service.dart';
import '../../services/excel_service.dart';
import '../../models/time_slot.dart';
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
        if (mounted) setState(() {});
      },
      onClearAllExchangeStates: () {
        if (mounted) setState(() {});
      },
      onRefreshHeaderTheme: () {
        if (mounted) setState(() {});
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
  /// - 결보강 계획서 날짜 정보 (absenceDate, substitutionDate, 보강 과목)
  /// (PDF 출력 설정은 FileExportWidget에서 로드)
  Future<void> _loadSavedData() async {
    try {
      AppLogger.info('프로그램 시작: 저장된 데이터 로드 중...');

      // 1. 시간표 테마 설정 로드
      await SimplifiedTimetableTheme.loadThemeSettings();

      // 2. 교체 리스트 로드 (Provider 사용)
      final exchangeHistoryService = ref.read(exchangeHistoryServiceProvider);
      await exchangeHistoryService.loadFromLocalStorage();

      // 3. 시간표 데이터 로드 (Provider 사용)
      final timetableStorage = ref.read(timetableStorageServiceProvider);
      final timetableData = await timetableStorage.loadTimetableData();

      if (timetableData == null || !mounted) {
        AppLogger.info('저장된 시간표 데이터가 없습니다.');
        return;
      }

      // 교체불가 셀 데이터 로드 및 적용
      await _applyNonExchangeableCells(timetableData);

      // Provider에 데이터 설정
      ref.read(exchangeScreenProvider.notifier).setTimetableData(timetableData);

      // 저장된 파일 경로 가져오기 및 설정
      final savedFilePath = await timetableStorage.getSavedFilePath();
      if (savedFilePath != null) {
        final file = File(savedFilePath);
        if (await file.exists()) {
          _stateProxy?.setSelectedFile(file);
        }
      }

      // 시간표 그리드 데이터 생성
      _operationManager?.onCreateSyncfusionGridData();

      // 교체된 셀 테마 복원
      if (exchangeHistoryService.getExchangeList().isNotEmpty) {
        ExchangeExecutor.restoreExchangedCells(ref);
        final dataSource = ref.read(exchangeScreenProvider).dataSource;
        dataSource?.notifyDataChanged();
      }

      // 4. 결보강 계획서 날짜 정보 로드
      try {
        final substitutionPlanNotifier = ref.read(substitutionPlanProvider.notifier);
        await substitutionPlanNotifier.loadFromStorage();
      } catch (e) {
        AppLogger.error('결보강 계획서 날짜 정보 로드 중 오류: $e', e);
      }

      // 5. 앱 설정 로드 (언어 설정)
      try {
        final appSettings = AppSettingsStorageService();
        await appSettings.getLanguageCode(); // 설정 캐시를 위해 미리 로드
        AppLogger.info('앱 설정 로드 완료');
      } catch (e) {
        AppLogger.error('앱 설정 로드 중 오류: $e', e);
      }

      // 6. 기본 교사명과 학교명 로드 (설정 화면 표시용)
      try {
        final pdfSettings = PdfExportSettingsStorageService();
        await pdfSettings.loadDefaultTeacherAndSchoolName(); // 설정 캐시를 위해 미리 로드
        AppLogger.info('기본 교사명과 학교명 로드 완료');
      } catch (e) {
        AppLogger.error('기본 교사명과 학교명 로드 중 오류: $e', e);
      }

      setState(() {});
      AppLogger.info('저장된 데이터 로드 완료');
    } catch (e) {
      AppLogger.error('저장된 데이터 로드 중 오류: $e', e);
    }
  }

  /// 교체불가 셀 데이터 로드 및 적용
  ///
  /// 프로그램 시작 시 저장된 교체불가 셀 데이터를 로드하여
  /// TimeSlot의 isExchangeable을 false로 설정합니다.
  Future<void> _applyNonExchangeableCells(TimetableData timetableData) async {
    try {
      final storageService = NonExchangeableDataStorageService();
      final cells = await storageService.loadNonExchangeableCells();

      if (cells.isEmpty) {
        return;
      }

      // 로드된 교체불가 셀 데이터를 TimeSlot에 적용
      for (var cell in cells) {
        // 해당 TimeSlot 찾기
        try {
          final timeSlot = timetableData.timeSlots.firstWhere(
            (slot) =>
              slot.teacher == cell.teacher &&
              slot.dayOfWeek == cell.dayOfWeek &&
              slot.period == cell.period,
          );

          // TimeSlot의 isExchangeable 설정
          timeSlot.isExchangeable = false;
          timeSlot.exchangeReason = '교체불가';
        } catch (e) {
          // 해당 TimeSlot이 없으면 빈 셀인 경우이므로 새로 생성
          final newTimeSlot = TimeSlot(
            teacher: cell.teacher,
            dayOfWeek: cell.dayOfWeek,
            period: cell.period,
            subject: null,
            className: null,
            isExchangeable: false,
            exchangeReason: '교체불가',
          );
          timetableData.timeSlots.add(newTimeSlot);
        }
      }

      AppLogger.info('교체불가 셀 ${cells.length}개 적용 완료');
    } catch (e) {
      AppLogger.error('교체불가 셀 데이터 적용 중 오류: $e', e);
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

  // 엑셀 파일 선택 해제 메서드 (확인 다이얼로그 포함)
  Future<void> _clearSelectedFile() async {
    // 확인 다이얼로그 표시
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('파일 선택 해제'),
              ),
            ],
          ),
          content: const Text(
            '선택된 시간표 파일을 해제하시겠습니까?\n해제하면 현재 로드된 시간표 정보가 삭제됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('해제'),
            ),
          ],
        );
      },
    );

    // 확인 버튼을 눌렀을 때만 파일 해제
    if (confirm == true && mounted) {
      _operationManager?.clearSelectedFile();
      if (mounted) setState(() {});
    }
  }



  // 메뉴 항목들 정의 (홈 제외: 교체 관리, 결보강계획서, 개인 시간표, 설정)
  List<Map<String, dynamic>> _menuItems() => [
    {
      'title': '교체 관리',
      'icon': Icons.swap_horiz,
      'screen': ExchangeScreen(),
    },
    {
      'title': '결보강계획서',
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
      // 공통 AppBar 사용 (메뉴 아이콘 포함)
      appBar: CommonAppBar(
        title: 'Class Exchange Manager',
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
                    '수업교체 관리자\nClass Exchange Manager',
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
            
            // 나머지 메뉴 항목들 (홈 제외: 교체 관리, 결보강계획서, 개인 시간표, 설정)
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('정보'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InfoScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 통합 네비게이션 바 (모든 화면에서 표시)
          const UnifiedNavigationBar(),
          
          // 본문 내용
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: [
                // 홈 화면 (인덱스 0)
                HomeContentScreen(),
                // 나머지 메뉴 화면들 (인덱스 1부터)
                ..._menuItems().map((item) => item['screen'] as Widget),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
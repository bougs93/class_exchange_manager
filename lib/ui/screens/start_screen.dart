import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'exchange_screen.dart';
import 'personal_schedule_screen.dart';
import 'plan_output_screen.dart';
import 'start_content_screen.dart';
import 'guide_screen.dart';
import 'notice_screen.dart';
import '../../providers/navigation_provider.dart';
import '../widgets/unified_navigation_bar.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/services_provider.dart';
import '../../providers/substitution_plan_provider.dart';
import '../../ui/screens/exchange_screen/exchange_screen_state_proxy.dart';
import '../../ui/screens/exchange_screen/managers/exchange_operation_manager.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../../utils/logger.dart';
import '../../ui/widgets/timetable_grid/exchange_executor.dart';
import '../../services/app_settings_storage_service.dart';
import '../../services/non_exchangeable_data_storage_service.dart';
import '../../services/excel_service.dart';
import '../../models/time_slot.dart';
import 'dart:io';

/// 메인 셸 — 상단 네비게이션과 각 탭 화면(IndexedStack)
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
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
  /// (PDF 출력 설정은 SubstitutionOutputWidget에서 로드)
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

      // 저장된 파일 경로·파일명 설정
      // - 로컬 xlsm이 있으면 selectedFile 설정
      // - Setup 설치 PC 등 JSON 캐시만 있으면 metadata.fileName으로 표시
      final savedFilePath = await timetableStorage.getSavedFilePath();
      final savedFileName = await timetableStorage.getSavedFileName();
      if (savedFilePath != null) {
        final file = File(savedFilePath);
        if (await file.exists()) {
          _stateProxy?.setSelectedFile(file);
        } else if (savedFileName != null && savedFileName.isNotEmpty) {
          _stateProxy?.setTimetableFileName(savedFileName);
        }
      } else if (savedFileName != null && savedFileName.isNotEmpty) {
        _stateProxy?.setTimetableFileName(savedFileName);
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
        final appSettings = AppSettingsStorageService();
        await appSettings.loadTeacherAndSchoolName(); // 설정 캐시를 위해 미리 로드
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




  /// 상단 네비게이션 탭 1~5 (0은 StartContentScreen)
  List<Widget> _tabScreens() => const [
    ExchangeScreen(),
    PlanOutputScreen(),
    NoticeScreen(),
    PersonalScheduleScreen(),
    GuideScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationProvider);

    return Scaffold(
      // 앱바 및 Drawer 제거됨
      body: Column(
        children: [
          // 통합 네비게이션 바 (모든 화면에서 표시)
          const UnifiedNavigationBar(),
          
          // 본문 내용
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: [
                const StartContentScreen(),
                ..._tabScreens(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
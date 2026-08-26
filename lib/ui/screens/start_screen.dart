import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'exchange_screen.dart';
import 'personal_schedule_screen.dart';
import 'plan_output_screen.dart';
import 'start_content_screen.dart';
import 'guide_screen.dart';
import 'notice_screen.dart';
import '../../providers/navigation_provider.dart';
import '../../constants/nav_indices.dart';
import '../widgets/unified_navigation_bar.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/services_provider.dart';
import '../../providers/state_reset_provider.dart';
import '../../providers/substitution_plan_provider.dart';
import '../../providers/timetable_registry_provider.dart';
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

  /// 한 번이라도 연 탭만 실제 위젯을 유지 (시작 시 전체 탭 생성으로 UI가 멈추는 것 방지)
  final Set<int> _activatedTabIndices = {NavIndices.start};

  /// 탭별 위젯 캐시 (재생성 시 상태 유실 방지)
  final List<Widget?> _cachedTabWidgets = List<Widget?>.filled(
    NavIndices.screenCount,
    null,
  );

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

    // 첫 프레임(준비 화면)을 그린 뒤 저장 데이터 로드 — 시작 멈춤 완화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSavedData();
    });
  }

  /// 저장된 데이터 자동 로드
  ///
  /// 프로그램 시작 시 다음 데이터를 자동으로 로드합니다:
  /// - 시간표 데이터
  /// - 교체 리스트
  /// - 시간표 테마 설정
  /// - 결보강 계획서 날짜 정보 (absenceDate, substitutionDate, 보강 과목)
  /// (PDF 출력 설정은 SubstitutionOutputWidget에서 로드)
  ///
  /// 재진입 가드: 로드 중 빠른 시간표 연속 전환으로 두 로드가 겹치면
  /// 상태가 섞이므로, 실행 토큰으로 이전 로드를 중단시킵니다.
  int _loadRunId = 0;

  Future<void> _loadSavedData() async {
    final runId = ++_loadRunId;
    bool isStale() => !mounted || runId != _loadRunId;

    try {
      AppLogger.info('프로그램 시작: 저장된 데이터 로드 중...');

      // 0. 시간표 레지스트리 초기화 (활성 시간표 스코프 적용)
      //    이후 교체 목록·결보강 로드는 활성 시간표 스코프 파일에서 수행됩니다.
      await ref.read(timetableRegistryProvider.notifier).ensureInitialized();
      if (isStale()) return;

      // 1. 시간표 테마 설정 로드
      await SimplifiedTimetableTheme.loadThemeSettings();
      if (isStale()) return;

      // 2. 교체 리스트 로드 (Provider 사용 — 활성 시간표 스코프)
      final activeEntry = ref.read(activeTimetableEntryProvider);
      final activeTimetableId = activeEntry?.id;

      if (activeEntry != null) {
        final exchangeHistoryService = ref.read(exchangeHistoryServiceProvider);
        await exchangeHistoryService.loadFromLocalStorage();
        if (isStale()) return;

        // 3. 시간표 데이터 로드 (Provider 사용 — 활성 시간표 스코프)
        final timetableStorage = ref.read(timetableStorageServiceProvider);
        final timetableData = await timetableStorage.loadTimetableData(
          timetableId: activeTimetableId,
        );
        if (isStale()) return;

        if (timetableData != null && mounted) {
          // 교체불가 셀 데이터 로드 및 적용
          await _applyNonExchangeableCells(timetableData);
          if (isStale()) return;

          // Provider에 데이터 설정
          ref
              .read(exchangeScreenProvider.notifier)
              .setTimetableData(timetableData);

          // 저장된 파일 경로·파일명 설정
          // - 로컬 xlsm이 있으면 selectedFile 설정
          // - Setup 설치 PC 등 JSON 캐시만 있으면 metadata.fileName으로 표시
          final savedFilePath = await timetableStorage.getSavedFilePath(
            timetableId: activeTimetableId,
          );
          final savedFileName = await timetableStorage.getSavedFileName(
            timetableId: activeTimetableId,
          );
          if (isStale()) return;

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
        } else {
          AppLogger.info('저장된 시간표 데이터가 없습니다.');
        }
      } else {
        // 활성 시간표가 없으면(전체 삭제 등) 어떤 파일도 로드하지 않고 빈 상태 유지
        AppLogger.info('등록된 시간표가 없습니다. 시간표 데이터 로드를 건너뜁니다.');
        ref.read(exchangeScreenProvider.notifier).setTimetableData(null);
      }

      // 4. 결보강 계획서 날짜 정보 로드
      //    (스코프가 없으면 저장소가 건너뛰므로 항상 호출)
      try {
        final substitutionPlanNotifier = ref.read(
          substitutionPlanProvider.notifier,
        );
        await substitutionPlanNotifier.loadFromStorage();
      } catch (e) {
        AppLogger.error('결보강 계획서 날짜 정보 로드 중 오류: $e', e);
      }
      if (isStale()) return;

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

  /// 탭 인덱스에 해당하는 화면 위젯 (최초 1회만 생성해 캐시)
  Widget _buildTabWidget(int index) {
    final cached = _cachedTabWidgets[index];
    if (cached != null) return cached;

    // 초보 개발자용: switch로 탭 번호와 화면을 1:1로 연결합니다.
    final Widget widget;
    switch (index) {
      case NavIndices.start:
        widget = const StartContentScreen();
        break;
      case NavIndices.exchange:
        widget = const ExchangeScreen();
        break;
      case NavIndices.planOutput:
        widget = const PlanOutputScreen();
        break;
      case NavIndices.notice:
        widget = const NoticeScreen();
        break;
      case NavIndices.personalSchedule:
        widget = const PersonalScheduleScreen();
        break;
      case NavIndices.guide:
        widget = const GuideScreen();
        break;
      default:
        widget = const SizedBox.shrink();
    }
    _cachedTabWidgets[index] = widget;
    return widget;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationProvider);

    // 활성 시간표 전환 시 저장 데이터(시간표 본문·교체 목록·그리드) 재로드
    ref.listen<int>(timetableSwitchVersionProvider, (previous, next) {
      if (previous != null && previous != next) {
        AppLogger.info('활성 시간표 전환 감지: 저장 데이터 재로드');
        // 이전 시간표의 UI 상태(선택 경로·화살표 등)를 먼저 리셋
        ref
            .read(stateResetProvider.notifier)
            .resetAllStates(reason: '활성 시간표 전환');
        _loadSavedData();
      }
    });

    // 현재 탭을 활성화 목록에 추가 (처음 연 탭부터 위젯 생성)
    _activatedTabIndices.add(selectedIndex);

    return Scaffold(
      // 앱바 및 Drawer 제거됨
      body: Column(
        children: [
          // 통합 네비게이션 바 (모든 화면에서 표시)
          const UnifiedNavigationBar(),

          // 본문: 방문한 탭만 실제 화면, 나머지는 빈 자리 유지
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: List.generate(NavIndices.screenCount, (index) {
                if (_activatedTabIndices.contains(index)) {
                  return _buildTabWidget(index);
                }
                // 아직 안 연 탭은 만들지 않음 → 준비 화면 첫 진입이 가벼워짐
                return const SizedBox.shrink();
              }),
            ),
          ),
        ],
      ),
    );
  }
}

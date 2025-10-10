import 'package:flutter/foundation.dart';
import '../../../../models/exchange_path.dart';
import '../../../../models/one_to_one_exchange_path.dart';
import '../../../../models/circular_exchange_path.dart';
import '../../../../models/chain_exchange_path.dart';
import '../../../../services/excel_service.dart';
import '../../../../services/exchange_service.dart';
import '../../../../services/circular_exchange_service.dart';
import '../../../../services/chain_exchange_service.dart';
import '../../../../utils/exchange_path_converter.dart';
import '../../../../utils/logger.dart';
import '../exchange_screen_state_proxy.dart';

/// 교체 경로 생성 및 관리를 담당하는 Manager
///
/// ExchangePathHandler, PathSelectionHandlerMixin, StateResetHandler Mixin을 대체합니다.
class ExchangePathManager {
  final ExchangeScreenStateProxy stateProxy;
  final ExchangeService exchangeService;
  final CircularExchangeService circularExchangeService;
  final ChainExchangeService chainExchangeService;
  final VoidCallback onUpdateFilteredPaths;
  final void Function(double) onUpdateProgressSmoothly;

  ExchangePathManager({
    required this.stateProxy,
    required this.exchangeService,
    required this.circularExchangeService,
    required this.chainExchangeService,
    required this.onUpdateFilteredPaths,
    required this.onUpdateProgressSmoothly,
  });

  // ===== 경로 생성 =====

  /// 1:1 교체 경로 생성
  void generateOneToOnePaths(List<dynamic> options, TimetableData? timetableData) {
    if (!exchangeService.hasSelectedCell() || timetableData == null) {
      // 기존 경로들에서 1:1교체 경로 제거
      List<ExchangePath> otherPaths = stateProxy.availablePaths
          .where((path) => path is! OneToOneExchangePath)
          .toList();
      stateProxy.setAvailablePaths(otherPaths);
      
      stateProxy.setSelectedOneToOnePath(null);
      stateProxy.setSidebarVisible(false);
      return;
    }

    // 선택된 셀의 학급명 추출
    String selectedClassName = ExchangePathConverter.extractClassNameFromTimeSlots(
      timeSlots: timetableData.timeSlots,
      teacherName: exchangeService.selectedTeacher!,
      day: exchangeService.selectedDay!,
      period: exchangeService.selectedPeriod!,
    );

    // ExchangeOption을 OneToOneExchangePath로 변환
    List<OneToOneExchangePath> paths = ExchangePathConverter.convertToOneToOnePaths(
      selectedTeacher: exchangeService.selectedTeacher!,
      selectedDay: exchangeService.selectedDay!,
      selectedPeriod: exchangeService.selectedPeriod!,
      selectedClassName: selectedClassName,
      options: options.cast(),
      timeSlots: timetableData.timeSlots, // 시간표 데이터 추가
    );

    // 순차적인 ID 부여
    for (int i = 0; i < paths.length; i++) {
      paths[i].setCustomId('onetoone_path_${i + 1}');
    }

    // 기존 경로들에서 1:1교체 경로 제거 후 새로운 경로들 추가
    List<ExchangePath> otherPaths = stateProxy.availablePaths
        .where((path) => path is! OneToOneExchangePath)
        .toList();
    List<ExchangePath> newPaths = [...otherPaths, ...paths];
    stateProxy.setAvailablePaths(newPaths);
    
    stateProxy.setSelectedOneToOnePath(null);
    onUpdateFilteredPaths();
    stateProxy.setSidebarVisible(paths.isNotEmpty);
  }

  /// 순환교체 경로 탐색 (진행률 포함)
  Future<void> findCircularPathsWithProgress(TimetableData? timetableData) async {
    try {
      AppLogger.exchangeDebug('순환교체 경로 탐색 시작');

      // 1단계: 초기화 (10%)
      onUpdateProgressSmoothly(0.1);
      await Future.delayed(const Duration(milliseconds: 100));

      // 2단계: 교사 정보 수집 (20%)
      onUpdateProgressSmoothly(0.2);
      await Future.delayed(const Duration(milliseconds: 100));

      // 3단계: 시간표 분석 (40%)
      onUpdateProgressSmoothly(0.4);
      await Future.delayed(const Duration(milliseconds: 150));

      // 4단계: DFS 경로 탐색 시작 (80%)
      onUpdateProgressSmoothly(0.8);

      AppLogger.exchangeDebug('경로 탐색 실행 시작 - 선택된 셀: ${circularExchangeService.selectedTeacher}, ${circularExchangeService.selectedDay}, ${circularExchangeService.selectedPeriod}');

      if (timetableData == null) {
        AppLogger.error('시간표 데이터가 없습니다.');
        // 기존 경로들에서 순환교체 경로 제거
        List<ExchangePath> otherPaths = stateProxy.availablePaths
            .where((path) => path is! CircularExchangePath)
            .toList();
        stateProxy.setAvailablePaths(otherPaths);
        onUpdateProgressSmoothly(1.0);
        return;
      }

      // 실제 경로 탐색
      List<CircularExchangePath> paths = circularExchangeService.findCircularExchangePaths(
        timetableData.timeSlots,
        timetableData.teachers,
      );

      AppLogger.exchangeDebug('경로 탐색 완료: ${paths.length}개 발견');

      // 5단계: 완료 (100%)
      onUpdateProgressSmoothly(1.0);
      await Future.delayed(const Duration(milliseconds: 200));

      // 기존 경로들에서 순환교체 경로 제거 후 새로운 경로들 추가
      List<ExchangePath> otherPaths = stateProxy.availablePaths
          .where((path) => path is! CircularExchangePath)
          .toList();
      List<ExchangePath> newPaths = [...otherPaths, ...paths];
      stateProxy.setAvailablePaths(newPaths);
      
      onUpdateFilteredPaths();
      stateProxy.setSidebarVisible(paths.isNotEmpty);

      AppLogger.exchangeInfo('순환교체 경로 탐색 완료 - ${paths.length}개 경로 발견');
    } catch (e) {
      AppLogger.error('순환교체 경로 탐색 중 오류: $e');
      // 기존 경로들에서 순환교체 경로 제거
      List<ExchangePath> otherPaths = stateProxy.availablePaths
          .where((path) => path is! CircularExchangePath)
          .toList();
      stateProxy.setAvailablePaths(otherPaths);
      onUpdateProgressSmoothly(1.0);
    }
  }

  /// 연쇄교체 경로 탐색
  Future<void> findChainPathsWithProgress(TimetableData? timetableData) async {
    if (timetableData == null || !chainExchangeService.hasSelectedCell()) {
      AppLogger.warning('연쇄교체: 시간표 데이터 없음 또는 셀 미선택');
      return;
    }

    AppLogger.exchangeInfo('연쇄교체: 경로 탐색 시작');

    try {
      List<ChainExchangePath> paths = chainExchangeService.findChainExchangePaths(
        timetableData.timeSlots,
        timetableData.teachers,
      );

      // 기존 경로들에서 연쇄교체 경로 제거 후 새로운 경로들 추가
      List<ExchangePath> otherPaths = stateProxy.availablePaths
          .where((path) => path is! ChainExchangePath)
          .toList();
      List<ExchangePath> newPaths = [...otherPaths, ...paths];
      stateProxy.setAvailablePaths(newPaths);
      
      onUpdateFilteredPaths();
      stateProxy.setSidebarVisible(paths.isNotEmpty);

      if (paths.isEmpty) {
        AppLogger.exchangeInfo('연쇄교체: 경로 없음');
      } else {
        AppLogger.exchangeInfo('연쇄교체: ${paths.length}개 경로 발견');
      }
    } catch (e) {
      AppLogger.error('연쇄교체 경로 탐색 오류: $e');
      // 기존 경로들에서 연쇄교체 경로 제거
      List<ExchangePath> otherPaths = stateProxy.availablePaths
          .where((path) => path is! ChainExchangePath)
          .toList();
      stateProxy.setAvailablePaths(otherPaths);
    }
  }

}

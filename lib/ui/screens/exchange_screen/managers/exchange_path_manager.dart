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
import '../../../../utils/exchange_path_utils.dart';
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
      _clearPaths<OneToOneExchangePath>();
      return;
    }

    // 선택된 셀의 학급명 추출 및 경로 변환
    final selectedClassName = ExchangePathConverter.extractClassNameFromTimeSlots(
      timeSlots: timetableData.timeSlots,
      teacherName: exchangeService.selectedTeacher!,
      day: exchangeService.selectedDay!,
      period: exchangeService.selectedPeriod!,
    );

    final paths = ExchangePathConverter.convertToOneToOnePaths(
      selectedTeacher: exchangeService.selectedTeacher!,
      selectedDay: exchangeService.selectedDay!,
      selectedPeriod: exchangeService.selectedPeriod!,
      selectedClassName: selectedClassName,
      options: options.cast(),
      timeSlots: timetableData.timeSlots,
    );

    // 순차적인 ID 부여
    for (int i = 0; i < paths.length; i++) {
      paths[i].setCustomId('onetoone_path_${i + 1}');
    }

    _updatePaths(paths);
  }

  /// 순환교체 경로 탐색 (진행률 포함)
  Future<void> findCircularPathsWithProgress(TimetableData? timetableData) async {
    try {
      AppLogger.exchangeDebug('순환교체 경로 탐색 시작');

      // 진행률 단계별 업데이트
      await _updateProgressWithSteps([0.1, 0.2, 0.4, 0.8], [100, 100, 150, 0]);

      if (timetableData == null) {
        AppLogger.error('시간표 데이터가 없습니다.');
        _clearPaths<CircularExchangePath>();
        onUpdateProgressSmoothly(1.0);
        return;
      }

      // 실제 경로 탐색
      final paths = circularExchangeService.findCircularExchangePaths(
        timetableData.timeSlots,
        timetableData.teachers,
      );

      AppLogger.exchangeDebug('경로 탐색 완료: ${paths.length}개 발견');

      // 완료
      onUpdateProgressSmoothly(1.0);
      await Future.delayed(const Duration(milliseconds: 200));

      _updatePaths(paths);
      AppLogger.exchangeInfo('순환교체 경로 탐색 완료 - ${paths.length}개 경로 발견');
    } catch (e) {
      AppLogger.error('순환교체 경로 탐색 중 오류: $e');
      _clearPaths<CircularExchangePath>();
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
      final paths = chainExchangeService.findChainExchangePaths(
        timetableData.timeSlots,
        timetableData.teachers,
      );

      _updatePaths(paths);
      AppLogger.exchangeInfo('연쇄교체: ${paths.isEmpty ? "경로 없음" : "${paths.length}개 경로 발견"}');
    } catch (e) {
      AppLogger.error('연쇄교체 경로 탐색 오류: $e');
      _clearPaths<ChainExchangePath>();
    }
  }

  // ===== 헬퍼 메서드 =====

  /// 경로 업데이트 (공통)
  void _updatePaths<T extends ExchangePath>(List<T> paths) {
    final newPaths = ExchangePathUtils.replacePaths(stateProxy.availablePaths, paths);
    stateProxy.setAvailablePaths(newPaths);
    stateProxy.setSelectedOneToOnePath(null);
    onUpdateFilteredPaths();
    stateProxy.setSidebarVisible(paths.isNotEmpty);
  }

  /// 경로 제거 (공통)
  void _clearPaths<T extends ExchangePath>() {
    final otherPaths = ExchangePathUtils.removePaths<T>(stateProxy.availablePaths);
    stateProxy.setAvailablePaths(otherPaths);
    stateProxy.setSelectedOneToOnePath(null);
    stateProxy.setSidebarVisible(false);
  }

  /// 진행률 단계별 업데이트
  Future<void> _updateProgressWithSteps(List<double> steps, List<int> delays) async {
    for (int i = 0; i < steps.length; i++) {
      onUpdateProgressSmoothly(steps[i]);
      if (delays[i] > 0) {
        await Future.delayed(Duration(milliseconds: delays[i]));
      }
    }
  }
}

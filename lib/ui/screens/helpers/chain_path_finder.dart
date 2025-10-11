import 'package:flutter/foundation.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/time_slot.dart';
import '../../../models/teacher.dart';
import '../../../models/exchange_path.dart';
import '../../../services/chain_exchange_service.dart';
import '../../../utils/logger.dart';

/// 연쇄교체 경로 탐색 관련 헬퍼 함수들
class ChainPathFinder {
  /// 진행률과 함께 연쇄교체 경로 탐색
  static Future<ChainPathResult> findChainPathsWithProgress({
    required ChainExchangeService chainExchangeService,
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
  }) async {
    if (!chainExchangeService.hasSelectedCell()) {
      AppLogger.warning('연쇄교체: 시간표 데이터 없음 또는 셀 미선택');
      return ChainPathResult(
        paths: [],
        filteredPaths: [],
        shouldShowSidebar: false,
        message: null,
        error: '셀이 선택되지 않았습니다',
      );
    }

    AppLogger.exchangeInfo('연쇄교체: 경로 탐색 시작');

    try {
      // 백그라운드에서 연쇄교체 경로 탐색
      List<ChainExchangePath> paths = await compute(
        _findChainPathsInBackground,
        {
          'timeSlots': timeSlots,
          'teachers': teachers,
          'teacher': chainExchangeService.selectedTeacher!,
          'day': chainExchangeService.selectedDay!,
          'period': chainExchangeService.selectedPeriod!,
          'className': chainExchangeService.selectedClass!,
        },
      );

      // 경로에 따른 사이드바 표시 설정
      bool shouldShowSidebar;
      String message;

      if (paths.isEmpty) {
        shouldShowSidebar = false;
        message = '연쇄교체 가능한 경로가 없습니다.';
        AppLogger.exchangeDebug('연쇄교체 경로가 없어서 사이드바를 숨김니다.');
        AppLogger.exchangeInfo('연쇄교체: 경로 없음');
      } else {
        shouldShowSidebar = true;
        message = '연쇄교체 경로 ${paths.length}개를 찾았습니다.';
        AppLogger.exchangeDebug('연쇄교체 경로 ${paths.length}개를 찾았습니다. 사이드바를 표시합니다.');
        AppLogger.exchangeInfo('연쇄교체: ${paths.length}개 경로 발견');
      }

      return ChainPathResult(
        paths: paths,
        filteredPaths: paths.cast<ExchangePath>(),
        shouldShowSidebar: shouldShowSidebar,
        message: message,
        error: null,
      );

    } catch (e) {
      AppLogger.error('연쇄교체 경로 탐색 오류: $e');
      return ChainPathResult(
        paths: [],
        filteredPaths: [],
        shouldShowSidebar: false,
        message: '연쇄교체 경로 탐색 중 오류가 발생했습니다: $e',
        error: e.toString(),
      );
    }
  }
}

/// 백그라운드에서 실행할 함수
List<ChainExchangePath> _findChainPathsInBackground(Map<String, dynamic> data) {
  List<TimeSlot> timeSlots = data['timeSlots'];
  List<Teacher> teachers = data['teachers'];
  String teacher = data['teacher'];
  String day = data['day'];
  int period = data['period'];

  ChainExchangeService service = ChainExchangeService();

  // startChainExchange를 직접 호출하지 않고,
  // timeSlots를 전달하여 내부에서 className을 찾도록 함
  // 임시 DataGridCellTapDetails를 생성할 수 없으므로
  // findChainExchangePaths에서 timeSlots를 통해 className을 찾음
  service.selectCell(teacher, day, period);

  return service.findChainExchangePaths(timeSlots, teachers);
}

/// 연쇄교체 경로 탐색 결과
class ChainPathResult {
  final List<ChainExchangePath> paths;
  final List<ExchangePath> filteredPaths;
  final bool shouldShowSidebar;
  final String? message;
  final String? error;

  ChainPathResult({
    required this.paths,
    required this.filteredPaths,
    required this.shouldShowSidebar,
    required this.message,
    required this.error,
  });
}

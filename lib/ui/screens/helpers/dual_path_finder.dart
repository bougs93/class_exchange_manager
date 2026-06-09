import 'package:flutter/foundation.dart';
import '../../../models/dual_exchange_path.dart';
import '../../../models/time_slot.dart';
import '../../../models/teacher.dart';
import '../../../models/exchange_path.dart';
import '../../../services/dual_exchange_service.dart';
import '../../../utils/logger.dart';

/// 2중교체 경로 탐색 관련 헬퍼 함수들
class DualPathFinder {
  /// 진행률과 함께 2중교체 경로 탐색
  static Future<DualPathResult> findDualPathsWithProgress({
    required DualExchangeService dualExchangeService,
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
  }) async {
    if (!dualExchangeService.hasSelectedCell()) {
      AppLogger.warning('2중교체: 시간표 데이터 없음 또는 셀 미선택');
      return DualPathResult(
        paths: [],
        filteredPaths: [],
        shouldShowSidebar: false,
        message: null,
        error: '셀이 선택되지 않았습니다',
      );
    }

    AppLogger.exchangeInfo('2중교체: 경로 탐색 시작');

    try {
      // 백그라운드에서 2중교체 경로 탐색
      List<DualExchangePath> paths = await compute(
        _findDualPathsInBackground,
        {
          'timeSlots': timeSlots,
          'teachers': teachers,
          'teacher': dualExchangeService.selectedTeacher!,
          'day': dualExchangeService.selectedDay!,
          'period': dualExchangeService.selectedPeriod!,
          'className': dualExchangeService.selectedClass ?? '',
        },
      );

      // 경로에 따른 사이드바 표시 설정
      bool shouldShowSidebar;
      String? message;

      if (paths.isEmpty) {
        shouldShowSidebar = false;
        message = null; // 스낵바 메시지 제거
        AppLogger.exchangeDebug('2중교체 경로가 없어서 사이드바를 숨김니다.');
        AppLogger.exchangeInfo('2중교체: 경로 없음');
      } else {
        shouldShowSidebar = true;
        message = null; // 스낵바 메시지 제거
        AppLogger.exchangeDebug('2중교체 경로 ${paths.length}개를 찾았습니다. 사이드바를 표시합니다.');
        AppLogger.exchangeInfo('2중교체: ${paths.length}개 경로 발견');
      }

      return DualPathResult(
        paths: paths,
        filteredPaths: paths.cast<ExchangePath>(),
        shouldShowSidebar: shouldShowSidebar,
        message: message,
        error: null,
      );

    } catch (e) {
      AppLogger.error('2중교체 경로 탐색 오류: $e');
      return DualPathResult(
        paths: [],
        filteredPaths: [],
        shouldShowSidebar: false,
        message: null, // 스낵바 메시지 제거
        error: e.toString(),
      );
    }
  }
}

/// 백그라운드에서 실행할 함수
List<DualExchangePath> _findDualPathsInBackground(Map<String, dynamic> data) {
  List<TimeSlot> timeSlots = data['timeSlots'];
  List<Teacher> teachers = data['teachers'];
  String teacher = data['teacher'];
  String day = data['day'];
  int period = data['period'];

  DualExchangeService service = DualExchangeService();

  // startDualExchange를 직접 호출하지 않고,
  // timeSlots를 전달하여 내부에서 className을 찾도록 함
  // 임시 DataGridCellTapDetails를 생성할 수 없으므로
  // findDualExchangePaths에서 timeSlots를 통해 className을 찾음
  service.selectCell(teacher, day, period);

  return service.findDualExchangePaths(timeSlots, teachers);
}

/// 2중교체 경로 탐색 결과
class DualPathResult {
  final List<DualExchangePath> paths;
  final List<ExchangePath> filteredPaths;
  final bool shouldShowSidebar;
  final String? message;
  final String? error;

  DualPathResult({
    required this.paths,
    required this.filteredPaths,
    required this.shouldShowSidebar,
    required this.message,
    required this.error,
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/time_slot.dart';
import '../../../models/teacher.dart';
import '../../../services/circular_exchange_service.dart';
import '../../../utils/logger.dart';
import '../../../services/excel_service.dart';

/// 순환교체 경로 탐색 관련 헬퍼 함수들
class CircularPathFinder {
  /// 진행률과 함께 순환교체 경로 탐색
  static Future<CircularPathResult> findCircularPathsWithProgress({
    required CircularExchangeService circularExchangeService,
    required TimetableData? timetableData,
    required Function(double) updateProgress,
    required Function(List<CircularExchangePath>) updateAvailableSteps,
    required Function() resetFilters,
    required dynamic dataSource,
    required BuildContext? context,
  }) async {
    try {
      AppLogger.exchangeDebug('순환교체 경로 탐색 시작');

      // 1단계: 초기화 (10%)
      updateProgress(0.1);
      await Future.delayed(const Duration(milliseconds: 100));

      // 2단계: 교사 정보 수집 (20%)
      updateProgress(0.2);
      await Future.delayed(const Duration(milliseconds: 100));

      // 3단계: 시간표 분석 (40%)
      updateProgress(0.4);
      await Future.delayed(const Duration(milliseconds: 150));

      // 4단계: DFS 경로 탐색 시작 (80%)
      updateProgress(0.8);

      AppLogger.exchangeDebug('경로 탐색 실행 시작 - 선택된 셀: ${circularExchangeService.selectedTeacher}, ${circularExchangeService.selectedDay}, ${circularExchangeService.selectedPeriod}');

      // 백그라운드에서 경로 탐색 실행 (compute 사용)
      Map<String, dynamic> data = {
        'timeSlots': timetableData!.timeSlots,
        'teachers': timetableData.teachers,
        'selectedTeacher': circularExchangeService.selectedTeacher,
        'selectedDay': circularExchangeService.selectedDay,
        'selectedPeriod': circularExchangeService.selectedPeriod,
      };

      List<CircularExchangePath> paths = await compute(_findCircularExchangePathsInBackground, data);

      AppLogger.exchangeDebug('경로 탐색 완료 - 발견된 경로 수: ${paths.length}');

      // 5단계: 결과 처리 (90%)
      updateProgress(0.9);
      await Future.delayed(const Duration(milliseconds: 100));

      // 6단계: 완료 (100%)
      updateProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 150));

      // 순환교체 경로에 순차적인 ID 부여
      for (int i = 0; i < paths.length; i++) {
        paths[i].setCustomId('circular_path_${i + 1}');
      }

      // 사용 가능한 단계들 업데이트
      updateAvailableSteps(paths);

      // 필터 초기화 (새로운 경로 탐색 완료 후)
      resetFilters();

      // 데이터 소스에서도 선택된 경로 초기화
      dataSource?.updateSelectedCircularPath(null);

      // 디버그 콘솔에 출력
      AppLogger.exchangeDebug('순환교체 경로 ${paths.length}개 발견');
      circularExchangeService.logCircularExchangeInfo(paths, timetableData.timeSlots);

      // 경로에 따른 사이드바 표시 설정
      bool shouldShowSidebar = paths.isNotEmpty;
      if (paths.isEmpty) {
        AppLogger.exchangeDebug('순환교체 경로가 없어서 사이드바를 숨김니다.');
      } else {
        AppLogger.exchangeDebug('순환교체 경로 ${paths.length}개를 찾았습니다. 사이드바를 표시합니다.');
      }

      return CircularPathResult(
        paths: paths,
        shouldShowSidebar: shouldShowSidebar,
        error: null,
      );

    } catch (e, stackTrace) {
      // 오류 처리
      AppLogger.exchangeDebug('순환교체 경로 탐색 중 오류 발생: $e');
      AppLogger.exchangeDebug('스택 트레이스: $stackTrace');

      // 사용자에게 오류 알림
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('순환교체 경로 탐색 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return CircularPathResult(
        paths: [],
        shouldShowSidebar: false,
        error: e.toString(),
      );
    }
  }
}

/// 백그라운드에서 순환교체 경로 탐색을 실행하는 함수
/// compute 함수에서 사용하기 위해 클래스 외부에 정의
List<CircularExchangePath> _findCircularExchangePathsInBackground(Map<String, dynamic> data) {
  // 백그라운드에서 새로운 CircularExchangeService 인스턴스 생성
  CircularExchangeService service = CircularExchangeService();

  // 선택된 셀 정보 설정
  service.selectCell(
    data['selectedTeacher'] as String,
    data['selectedDay'] as String,
    data['selectedPeriod'] as int,
  );

  // 경로 탐색 실행
  return service.findCircularExchangePaths(
    data['timeSlots'] as List<TimeSlot>,
    data['teachers'] as List<Teacher>,
  );
}

/// 순환교체 경로 탐색 결과
class CircularPathResult {
  final List<CircularExchangePath> paths;
  final bool shouldShowSidebar;
  final String? error;

  CircularPathResult({
    required this.paths,
    required this.shouldShowSidebar,
    required this.error,
  });
}

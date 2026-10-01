import '../../../services/search/search_runner.dart';
import 'package:flutter/material.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/time_slot.dart';
import '../../../services/circular_exchange_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../services/excel_service.dart';

/// 순환교체 경로 탐색 관련 헬퍼 함수들
class CircularPathFinder {
  /// 진행률과 함께 순환교체 경로 탐색
  /// [validationTimeSlots]는 교체 판정에 쓸 시간표다 — 원본이 아니라
  /// **현재 주의 합성 결과**를 넘겨야 같은 주의 선행 교체가 반영된다(§10.8 4d).
  static Future<CircularPathResult> findCircularPathsWithProgress({
    required CircularExchangeService circularExchangeService,
    required ExchangeSearchRunner runner,
    required bool Function() isCurrent,
    required TimetableData? timetableData,
    required List<TimeSlot> validationTimeSlots,
    required Function(double) updateProgress,
    required Function(List<CircularExchangePath>) updateAvailableSteps,
    required Function() resetFilters,
    required dynamic dataSource,
    required BuildContext? context,
  }) async {
    try {
      AppLogger.exchangeDebug('순환교체 경로 탐색 시작');

      // 진행률 단계만 알리고 인위적인 대기는 두지 않는다.
      // 예전에는 단계마다 Future.delayed로 총 600ms를 쉬어, 실제 탐색이
      // 순식간에 끝나도 셀 선택 반응이 그만큼 늦어 보였다.
      updateProgress(0.4);

      // DFS 경로 탐색 시작 (80%)
      updateProgress(0.8);

      AppLogger.exchangeDebug(
        '경로 탐색 실행 시작 - 선택된 셀: ${circularExchangeService.selectedTeacher}, ${circularExchangeService.selectedDay}, ${circularExchangeService.selectedPeriod}',
      );

      // 웹은 Worker, 네이티브는 compute에서 같은 탐색 엔진을 실행한다.
      // null 체크 강화
      final selectedTeacher = circularExchangeService.selectedTeacher;
      final selectedDay = circularExchangeService.selectedDay;
      final selectedPeriod = circularExchangeService.selectedPeriod;

      if (selectedTeacher == null ||
          selectedDay == null ||
          selectedPeriod == null) {
        AppLogger.exchangeDebug(
          '순환교체: 백그라운드 탐색 취소 - 셀 정보 누락 (teacher=$selectedTeacher, day=$selectedDay, period=$selectedPeriod)',
        );
        return CircularPathResult(
          paths: [],
          shouldShowSidebar: false,
          error: '선택된 셀 정보가 없습니다.',
        );
      }

      final result = await runner.run({
        'kind': 'circular',
        'timeSlots': validationTimeSlots.map((slot) => slot.toJson()).toList(),
        'teacher': selectedTeacher,
        'day': selectedDay,
        'period': selectedPeriod,
      });
      if (!isCurrent()) throw const SearchCancelled();
      final paths = result.map(CircularExchangePath.fromJson).toList();

      AppLogger.exchangeDebug('경로 탐색 완료 - 발견된 경로 수: ${paths.length}');

      // 완료 (100%)
      updateProgress(1.0);

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
      circularExchangeService.logCircularExchangeInfo(
        paths,
        timetableData!.timeSlots,
      );

      // 경로에 따른 사이드바 표시 설정
      bool shouldShowSidebar = paths.isNotEmpty;
      if (paths.isEmpty) {
        AppLogger.exchangeDebug('순환교체 경로가 없어서 사이드바를 숨김니다.');
      } else {
        AppLogger.exchangeDebug(
          '순환교체 경로 ${paths.length}개를 찾았습니다. 사이드바를 표시합니다.',
        );
      }

      return CircularPathResult(
        paths: paths,
        shouldShowSidebar: shouldShowSidebar,
        error: null,
      );
    } on SearchCancelled {
      return CircularPathResult(
        paths: [],
        shouldShowSidebar: false,
        error: 'cancelled',
      );
    } catch (e, stackTrace) {
      // 오류 처리
      AppLogger.exchangeDebug('순환교체 경로 탐색 중 오류 발생: $e');
      AppLogger.exchangeDebug('스택 트레이스: $stackTrace');

      // 사용자에게 오류 알림
      if (isCurrent() && context != null && context.mounted) {
        SnackBarHelper.showError(context, '순환교체 경로 탐색 중 오류가 발생했습니다: $e');
      }

      return CircularPathResult(
        paths: [],
        shouldShowSidebar: false,
        error: e.toString(),
      );
    }
  }
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

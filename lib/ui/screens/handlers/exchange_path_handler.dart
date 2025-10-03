import 'package:flutter/material.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../services/excel_service.dart';
import '../../../services/exchange_service.dart';
import '../../../services/circular_exchange_service.dart';
import '../../../services/chain_exchange_service.dart';
import '../../../utils/exchange_path_converter.dart';
import '../../../utils/logger.dart';

/// 교체 경로 생성 및 관리 관련 핸들러
mixin ExchangePathHandler<T extends StatefulWidget> on State<T> {
  // 하위 클래스에서 구현해야 하는 속성들
  ExchangeService get exchangeService;
  CircularExchangeService get circularExchangeService;
  ChainExchangeService get chainExchangeService;
  TimetableData? get timetableData;

  List<OneToOneExchangePath> get oneToOnePaths;
  set oneToOnePaths(List<OneToOneExchangePath> value);
  OneToOneExchangePath? get selectedOneToOnePath;
  set selectedOneToOnePath(OneToOneExchangePath? value);

  List<CircularExchangePath> get circularPaths;
  set circularPaths(List<CircularExchangePath> value);

  List<ChainExchangePath> get chainPaths;
  set chainPaths(List<ChainExchangePath> value);

  bool get isSidebarVisible;
  set isSidebarVisible(bool value);

  void Function() get updateFilteredPaths;
  void Function(double) get updateProgressSmoothly;

  /// 1:1 교체 경로 생성
  void generateOneToOnePaths(List<dynamic> options) {
    if (!exchangeService.hasSelectedCell() || timetableData == null) {
      oneToOnePaths = [];
      selectedOneToOnePath = null;
      isSidebarVisible = false;
      return;
    }

    // 선택된 셀의 학급명 추출
    String selectedClassName = ExchangePathConverter.extractClassNameFromTimeSlots(
      timeSlots: timetableData!.timeSlots,
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
    );

    // 순차적인 ID 부여
    for (int i = 0; i < paths.length; i++) {
      paths[i].setCustomId('onetoone_path_${i + 1}');
    }

    oneToOnePaths = paths;
    selectedOneToOnePath = null;
    updateFilteredPaths();
    isSidebarVisible = paths.isNotEmpty;
  }

  /// 순환교체 경로 탐색 (진행률 포함)
  Future<void> findCircularPathsWithProgress() async {
    try {
      AppLogger.exchangeDebug('순환교체 경로 탐색 시작');

      // 1단계: 초기화 (10%)
      updateProgressSmoothly(0.1);
      await Future.delayed(const Duration(milliseconds: 100));

      // 2단계: 교사 정보 수집 (20%)
      updateProgressSmoothly(0.2);
      await Future.delayed(const Duration(milliseconds: 100));

      // 3단계: 시간표 분석 (40%)
      updateProgressSmoothly(0.4);
      await Future.delayed(const Duration(milliseconds: 150));

      // 4단계: DFS 경로 탐색 시작 (80%)
      updateProgressSmoothly(0.8);

      AppLogger.exchangeDebug('경로 탐색 실행 시작 - 선택된 셀: ${circularExchangeService.selectedTeacher}, ${circularExchangeService.selectedDay}, ${circularExchangeService.selectedPeriod}');

      if (timetableData == null) {
        AppLogger.error('시간표 데이터가 없습니다.');
        circularPaths = [];
        updateProgressSmoothly(1.0);
        return;
      }

      // 실제 경로 탐색
      List<CircularExchangePath> paths = circularExchangeService.findCircularExchangePaths(
        timetableData!.timeSlots,
        timetableData!.teachers,
      );

      AppLogger.exchangeDebug('경로 탐색 완료: ${paths.length}개 발견');

      // 5단계: 완료 (100%)
      updateProgressSmoothly(1.0);
      await Future.delayed(const Duration(milliseconds: 200));

      circularPaths = paths;
      updateFilteredPaths();
      isSidebarVisible = paths.isNotEmpty;

      AppLogger.exchangeInfo('순환교체 경로 탐색 완료 - ${paths.length}개 경로 발견');
    } catch (e) {
      AppLogger.error('순환교체 경로 탐색 중 오류: $e');
      circularPaths = [];
      updateProgressSmoothly(1.0);
    }
  }

  /// 연쇄교체 경로 탐색
  Future<void> findChainPathsWithProgress() async {
    if (timetableData == null || !chainExchangeService.hasSelectedCell()) {
      AppLogger.warning('연쇄교체: 시간표 데이터 없음 또는 셀 미선택');
      return;
    }

    AppLogger.exchangeInfo('연쇄교체: 경로 탐색 시작');

    try {
      List<ChainExchangePath> paths = chainExchangeService.findChainExchangePaths(
        timetableData!.timeSlots,
        timetableData!.teachers,
      );

      chainPaths = paths;
      updateFilteredPaths();
      isSidebarVisible = paths.isNotEmpty;

      if (paths.isEmpty) {
        AppLogger.exchangeInfo('연쇄교체: 경로 없음');
      } else {
        AppLogger.exchangeInfo('연쇄교체: ${paths.length}개 경로 발견');
      }
    } catch (e) {
      AppLogger.error('연쇄교체 경로 탐색 오류: $e');
      chainPaths = [];
    }
  }
}

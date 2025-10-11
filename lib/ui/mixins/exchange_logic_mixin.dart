import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/exchange_service.dart';
import '../../services/circular_exchange_service.dart';
import '../../services/chain_exchange_service.dart';
import '../../services/excel_service.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/exchange_algorithm.dart';
import '../../utils/logger.dart';
import '../../utils/day_utils.dart';

/// 교체 로직을 담당하는 Mixin
/// 1:1 교체, 순환교체, 연쇄교체 관련 비즈니스 로직을 분리
mixin ExchangeLogicMixin<T extends StatefulWidget> on State<T> {
  // 추상 속성들 - 구현 클래스에서 제공해야 함
  ExchangeService get exchangeService;
  CircularExchangeService get circularExchangeService;
  ChainExchangeService get chainExchangeService;
  TimetableData? get timetableData;
  TimetableDataSource? get dataSource;
  bool get isExchangeModeEnabled;
  bool get isCircularExchangeModeEnabled;
  bool get isChainExchangeModeEnabled;
  CircularExchangePath? get selectedCircularPath;
  ChainExchangePath? get selectedChainPath;
  
  // 추상 메서드들 - 구현 클래스에서 구현해야 함
  void updateDataSource();
  void updateHeaderTheme();
  void showSnackBar(String message, {Color? backgroundColor});

  /// 1:1 교체 처리 시작
  void startOneToOneExchange(DataGridCellTapDetails details) {
    // 데이터 소스가 없는 경우 처리하지 않음
    if (dataSource == null) {
      return;
    }

    // ExchangeService를 사용하여 교체 처리
    ExchangeResult result = exchangeService.startOneToOneExchange(details, dataSource!);

    if (result.isNoAction) {
      return; // 아무 동작하지 않음
    }

    // 교체 대상 선택 후 교체 가능한 시간 탐색 및 표시
    processCellSelection();
  }
  
  /// 순환교체 처리 시작
  void startCircularExchange(DataGridCellTapDetails details) {
    // 데이터 소스가 없는 경우 처리하지 않음
    if (dataSource == null) {
      AppLogger.exchangeDebug('순환교체: 데이터 소스가 없습니다.');
      return;
    }

    AppLogger.exchangeDebug('순환교체: 셀 선택 시작 - 컬럼: ${details.column.columnName}, 행: ${details.rowColumnIndex.rowIndex}');

    // CircularExchangeService를 사용하여 순환교체 처리
    CircularExchangeResult result = circularExchangeService.startCircularExchange(details, dataSource!);

    if (result.isNoAction) {
      AppLogger.exchangeDebug('순환교체: 아무 동작하지 않음 (교사명 열 또는 잘못된 컬럼)');
      return; // 아무 동작하지 않음
    }

    // 새로운 셀 선택 시 기존 선택된 순환교체 경로와 관련 상태 초기화
    if (result.isSelected) {
      AppLogger.exchangeDebug('순환교체: 새로운 셀 선택됨 - 교사: ${result.teacherName}, 요일: ${result.day}, 교시: ${result.period}');

      // 이전 순환교체 경로 관련 상태 완전 초기화
      dataSource?.updateSelectedCircularPath(null);

      // 구현 클래스에서 순환교체 관련 상태 초기화
      clearPreviousCircularExchangeState();

    } else if (result.isDeselected) {
      AppLogger.exchangeDebug('순환교체: 셀 선택 해제됨');
    }

    // 교체 대상 선택 후 교체 가능한 시간 탐색 및 표시
    processCircularCellSelection();
  }

  /// 연쇄교체 처리 시작
  void startChainExchange(DataGridCellTapDetails details) {
    // 데이터 소스가 없는 경우 처리하지 않음
    if (dataSource == null || timetableData == null) {
      AppLogger.exchangeDebug('연쇄교체: 데이터 소스가 없습니다.');
      return;
    }

    AppLogger.exchangeDebug('연쇄교체: 셀 선택 시작 - 컬럼: ${details.column.columnName}, 행: ${details.rowColumnIndex.rowIndex}');

    // ChainExchangeService를 사용하여 연쇄교체 처리
    ChainExchangeResult result = chainExchangeService.startChainExchange(
      details,
      dataSource!,
      timetableData!.timeSlots,
    );

    if (result.isNoAction) {
      AppLogger.exchangeDebug('연쇄교체: 아무 동작하지 않음 (교사명 열 또는 잘못된 컬럼)');
      return; // 아무 동작하지 않음
    }

    // 새로운 셀 선택 시 기존 선택된 연쇄교체 경로와 관련 상태 초기화
    if (result.isSelected) {
      AppLogger.exchangeDebug('연쇄교체: 새로운 셀 선택됨 - 교사: ${result.teacherName}, 요일: ${result.day}, 교시: ${result.period}');

      // 이전 연쇄교체 경로 관련 상태 완전 초기화
      clearPreviousChainExchangeState();

    } else if (result.isDeselected) {
      AppLogger.exchangeDebug('연쇄교체: 셀 선택 해제됨');
    }

    // 교체 대상 선택 후 교체 가능한 시간 탐색 및 표시
    processChainCellSelection();
  }
  
  /// 셀 선택 후 처리 로직 (1:1 교체)
  void processCellSelection() {
    // 데이터 소스에 선택 상태 업데이트
    dataSource?.updateSelection(
      exchangeService.selectedTeacher, 
      exchangeService.selectedDay, 
      exchangeService.selectedPeriod
    );
    
    // 교체 가능한 시간 탐색 및 표시
    updateExchangeableTimes();
    
    // 테마 기반 헤더 업데이트
    updateHeaderTheme();
  }
  
  /// 순환교체 셀 선택 후 처리 로직
  Future<void> processCircularCellSelection() async {
    AppLogger.exchangeDebug('순환교체: 셀 선택 후 처리 시작');

    // 데이터 소스에 선택 상태 업데이트
    dataSource?.updateSelection(
      circularExchangeService.selectedTeacher,
      circularExchangeService.selectedDay,
      circularExchangeService.selectedPeriod
    );

    // 테마 기반 헤더 업데이트
    updateHeaderTheme();

    // 선택된 셀이 빈 셀인지 확인
    if (timetableData != null && isSelectedCellEmpty()) {
      AppLogger.exchangeDebug('순환교체: 빈 셀이 선택됨 - 경로 탐색 건너뜀');
      // 빈 셀인 경우 처리 (구현 클래스에서 처리)
      onEmptyCellSelected();
      return;
    }

    // 순환 교체 경로 찾기 시작 (구현 클래스에서 처리)
    if (timetableData != null) {
      await findCircularPathsWithProgress();
    }
  }

  /// 연쇄교체 셀 선택 후 처리 로직
  Future<void> processChainCellSelection() async {
    AppLogger.exchangeDebug('연쇄교체: 셀 선택 후 처리 시작');

    // 데이터 소스에 선택 상태 업데이트 (1:1/순환 교체와 동일한 방법)
    dataSource?.updateSelection(
      chainExchangeService.selectedTeacher,
      chainExchangeService.selectedDay,
      chainExchangeService.selectedPeriod
    );

    // 테마 기반 헤더 업데이트
    updateHeaderTheme();

    // 선택된 셀이 빈 셀인지 확인
    if (timetableData != null && isSelectedChainCellEmpty()) {
      AppLogger.exchangeDebug('연쇄교체: 빈 셀이 선택됨 - 경로 탐색 건너뜀');
      // 빈 셀인 경우 처리 (구현 클래스에서 처리)
      onEmptyChainCellSelected();
      return;
    }

    // 연쇄 교체 경로 찾기 시작 (구현 클래스에서 처리)
    if (timetableData != null) {
      await findChainPathsWithProgress();
    }
  }
  
  /// 교체 가능한 시간 업데이트
  void updateExchangeableTimes() {
    if (timetableData == null || !exchangeService.hasSelectedCell()) {
      setState(() {
        // 빈 목록으로 설정
      });
      dataSource?.updateExchangeOptions([]);
      return;
    }
    
    // ExchangeService를 사용하여 교체 가능한 시간 탐색
    List<ExchangeOption> options = exchangeService.updateExchangeableTimes(
      timetableData!.timeSlots,
      timetableData!.teachers,
    );
    
    // 1:1교체 경로 생성 (구현 클래스에서 처리)
    generateOneToOnePaths(options);
    
    setState(() {
      // UI 상태 업데이트
    });
    
    // 데이터 소스에 교체 옵션 업데이트
    dataSource?.updateExchangeOptions(options);
    
    // 교체 가능한 교사 정보를 별도로 업데이트
    List<Map<String, dynamic>> exchangeableTeachers = exchangeService.getCurrentExchangeableTeachers(
      timetableData!.timeSlots,
      timetableData!.teachers,
    );
    dataSource?.updateExchangeableTeachers(exchangeableTeachers);
    
    // 디버그 로그 출력
    exchangeService.logExchangeableInfo(exchangeableTeachers);
  }
  
  /// 경로 선택 처리 (토글 기능 제거)
  void selectPath(CircularExchangePath path) {
    AppLogger.exchangeDebug('경로 선택 시도: ${path.id}');
    
    // 토글 기능 제거 - 항상 새로운 경로 선택
    onPathSelected(path);
    
    // 선택된 경로 정보를 콘솔에 출력
    AppLogger.exchangeInfo('선택된 순환교체 경로: ${path.nodes.length}단계');
    for (int i = 0; i < path.nodes.length; i++) {
      final node = path.nodes[i];
      AppLogger.exchangeDebug('  ${i + 1}단계: ${node.day}${node.period} | ${node.teacherName}');
    }
  }
  
  /// 실제 교체 가능한 수업 개수 반환
  int getActualExchangeableCount() {
    // 1:1 교체 모드가 비활성화되어 있거나 선택된 셀이 없으면 0 반환
    if (!isExchangeModeEnabled || !exchangeService.hasSelectedCell() || timetableData == null) {
      return 0;
    }
    
    // 실제 교체 가능한 교사 정보를 가져와서 수업 개수 계산
    List<Map<String, dynamic>> exchangeableTeachers = exchangeService.getCurrentExchangeableTeachers(
      timetableData!.timeSlots,
      timetableData!.teachers,
    );
    
    // 각 교체 가능한 교사 정보가 하나의 수업을 의미하므로 전체 길이가 수업 개수
    return exchangeableTeachers.length;
  }

  /// 선택된 셀이 빈 셀인지 확인 (순환교체)
  bool isSelectedCellEmpty() {
    if (circularExchangeService.selectedTeacher == null ||
        circularExchangeService.selectedDay == null ||
        circularExchangeService.selectedPeriod == null ||
        timetableData == null) {
      return true;
    }

    // 선택된 교사, 요일, 교시에 해당하는 시간표 슬롯 찾기
    String teacherName = circularExchangeService.selectedTeacher!;
    String selectedDay = circularExchangeService.selectedDay!;
    int selectedPeriod = circularExchangeService.selectedPeriod!;

    // 요일을 숫자로 변환
    int dayOfWeek = DayUtils.getDayNumber(selectedDay);

    // 해당 시간에 수업이 있는지 확인
    bool hasClass = timetableData!.timeSlots.any((slot) =>
      slot.teacher == teacherName &&
      slot.dayOfWeek == dayOfWeek &&
      slot.period == selectedPeriod &&
      slot.isNotEmpty
    );

    AppLogger.exchangeDebug('순환교체 빈 셀 확인: 교사=$teacherName, 요일=$selectedDay($dayOfWeek), 교시=$selectedPeriod, 수업있음=$hasClass');

    return !hasClass; // 수업이 없으면 빈 셀
  }

  /// 선택된 셀이 빈 셀인지 확인 (연쇄교체)
  bool isSelectedChainCellEmpty() {
    if (chainExchangeService.selectedTeacher == null ||
        chainExchangeService.selectedDay == null ||
        chainExchangeService.selectedPeriod == null ||
        timetableData == null) {
      return true;
    }

    // 선택된 교사, 요일, 교시에 해당하는 시간표 슬롯 찾기
    String teacherName = chainExchangeService.selectedTeacher!;
    String selectedDay = chainExchangeService.selectedDay!;
    int selectedPeriod = chainExchangeService.selectedPeriod!;

    // 요일을 숫자로 변환
    int dayOfWeek = DayUtils.getDayNumber(selectedDay);

    // 해당 시간에 수업이 있는지 확인
    bool hasClass = timetableData!.timeSlots.any((slot) =>
      slot.teacher == teacherName &&
      slot.dayOfWeek == dayOfWeek &&
      slot.period == selectedPeriod &&
      slot.isNotEmpty
    );

    AppLogger.exchangeDebug('연쇄교체 빈 셀 확인: 교사=$teacherName, 요일=$selectedDay($dayOfWeek), 교시=$selectedPeriod, 수업있음=$hasClass');

    return !hasClass; // 수업이 없으면 빈 셀
  }
  
  // 추상 메서드들 - 구현 클래스에서 구현해야 함
  void onEmptyCellSelected();
  void onEmptyChainCellSelected();
  Future<void> findCircularPathsWithProgress();
  Future<void> findChainPathsWithProgress();
  void generateOneToOnePaths(List<dynamic> options); // ExchangeOption 리스트
  void onPathSelected(CircularExchangePath path);
  void onPathDeselected();
  void clearPreviousCircularExchangeState();
  void clearPreviousChainExchangeState();
}

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/exchange_service.dart';
import '../../services/circular_exchange_service.dart';
import '../../services/chain_exchange_service.dart';
import '../../services/excel_service.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/time_slot.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/exchange_algorithm.dart';
import '../../utils/day_utils.dart';
import '../../utils/logger.dart';

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
    // 데이터 소스에 선택 상태만 업데이트 (재렌더링 방지)
    dataSource?.updateSelection(
      exchangeService.selectedTeacher, 
      exchangeService.selectedDay, 
      exchangeService.selectedPeriod
    );
    
    // 빈 셀인 경우 경로 탐색하지 않음
    if (_isSelectedCellEmpty()) {
      AppLogger.exchangeDebug('1:1교체: 빈 셀 선택 - 경로 탐색 건너뜀');
      onEmptyCellSelected();
      return;
    }

    // 교체 가능한 시간 탐색 및 표시 (비동기 방식)
    updateExchangeableTimesWithProgress().then((_) {
      // 경로 탐색 완료 후 테마 기반 헤더 업데이트
      updateHeaderTheme();
    });
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

    // 빈 셀인 경우 경로 탐색하지 않음
    if (_isSelectedCellEmpty()) {
      AppLogger.exchangeDebug('순환교체: 빈 셀 선택 - 경로 탐색 건너뜀');
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

    // 빈 셀인 경우 경로 탐색하지 않음
    if (_isSelectedCellEmpty()) {
      AppLogger.exchangeDebug('연쇄교체: 빈 셀 선택 - 경로 탐색 건너뜀');
      onEmptyChainCellSelected();
      return;
    }

    // 연쇄 교체 경로 찾기 시작 (구현 클래스에서 처리)
    if (timetableData != null) {
      await findChainPathsWithProgress();
    }
  }
  
  /// 셀이 비어있지 않은지 확인 (과목이나 학급이 있는지 검사)
  /// 
  /// [teacherName] 교사 이름
  /// [day] 요일 (월, 화, 수, 목, 금)
  /// [period] 교시 (1-7)
  /// 
  /// Returns: `bool` - 수업이 있으면 true, 없으면 false
  bool _isCellNotEmpty(String teacherName, String day, int period) {
    if (timetableData == null) {
      AppLogger.exchangeDebug('🔄 [교체관리] 셀 확인: timetableData가 null입니다 - $teacherName $day$period교시');
      return false;
    }
    
    try {
      final dayNumber = DayUtils.getDayNumber(day);
      
      // 🔥 수업있음 판단 과정 상세 로그 (TimeSlot.isEmpty/isNotEmpty getter 사용 - 중복 계산 제거)
      AppLogger.exchangeDebug('📊 [교체관리] 수업있음 판단 시작: $teacherName $day$period교시');
      
      final timeSlot = timetableData!.timeSlots.firstWhere(
        (slot) => slot.teacher == teacherName && 
                  slot.dayOfWeek == dayNumber && 
                  slot.period == period,
        orElse: () => TimeSlot(), // 빈 TimeSlot 반환
      );
      
      final slotFound = timeSlot.teacher == teacherName && 
                       timeSlot.dayOfWeek == dayNumber && 
                       timeSlot.period == period;
      
      AppLogger.exchangeDebug('  - TimeSlot 찾기: ${slotFound ? "성공" : "실패 (빈 TimeSlot 반환)"}');
      
      // TimeSlot의 isEmpty/isNotEmpty getter 직접 사용 (중복 계산 제거)
      final subject = timeSlot.subject;
      final className = timeSlot.className;
      final isEmpty = timeSlot.isEmpty; // TimeSlot.isEmpty getter 사용
      final isNotEmpty = timeSlot.isNotEmpty; // TimeSlot.isNotEmpty getter 사용
      
      AppLogger.exchangeDebug('  - subject 값: ${subject ?? "null"}');
      AppLogger.exchangeDebug('  - className 값: ${className ?? "null"}');
      AppLogger.exchangeDebug('  - isEmpty 판단: $isEmpty (TimeSlot.isEmpty 사용)');
      AppLogger.exchangeDebug('  - isNotEmpty 판단: $isNotEmpty (TimeSlot.isNotEmpty 사용)');
      AppLogger.exchangeDebug('  ✅ 최종 판단: 수업있음=$isNotEmpty');
      
      bool hasClass = timeSlot.isNotEmpty;
      AppLogger.exchangeDebug('🔄 [교체관리] 셀 확인: $teacherName $day$period교시, 수업있음=$hasClass (최종 결과)');
      
      return hasClass;
    } catch (e) {
      AppLogger.exchangeDebug('🔄 [교체관리] 셀 확인 중 오류: $e');
      AppLogger.error('셀 확인 중 예외 발생: $e', e);
      return false;
    }
  }

  /// 선택된 셀이 빈 셀인지 확인 (모든 교체 모드용)
  bool _isSelectedCellEmpty() {
    // 현재 교체 모드에 따라 적절한 서비스 선택
    String? teacher;
    String? day;
    int? period;
    
    if (isChainExchangeModeEnabled) {
      teacher = chainExchangeService.selectedTeacher;
      day = chainExchangeService.selectedDay;
      period = chainExchangeService.selectedPeriod;
    } else if (isCircularExchangeModeEnabled) {
      teacher = circularExchangeService.selectedTeacher;
      day = circularExchangeService.selectedDay;
      period = circularExchangeService.selectedPeriod;
    } else {
      teacher = exchangeService.selectedTeacher;
      day = exchangeService.selectedDay;
      period = exchangeService.selectedPeriod;
    }
    
    if (teacher == null || day == null || period == null || timetableData == null) {
      return true;
    }

    return !_isCellNotEmpty(teacher, day, period);
  }

  /// 교체 가능한 시간 업데이트 (비동기 방식)
  ///
  /// **중요**: 헤더 테마 업데이트는 이 메서드 완료 후 호출자가 수행해야 함
  /// - 경로 탐색 완료 → Provider 업데이트 → `.then()` → 헤더 테마 업데이트
  ///
  /// **실행 순서**:
  /// 1. 로딩 상태 시작
  /// 2. 경로 탐색
  /// 3. generateOneToOnePaths() → Provider 경로 추가 + 사이드바 표시
  /// 4. DataSource 업데이트
  /// 5. 완료 (`.then()`에서 헤더 테마 업데이트)
  Future<void> updateExchangeableTimesWithProgress() async {
    if (timetableData == null || !exchangeService.hasSelectedCell()) {
      setState(() {
        // 빈 목록으로 설정
      });
      dataSource?.updateExchangeOptions([]);
      return;
    }

    AppLogger.exchangeDebug('1:1 교체: 비동기 경로 탐색 시작');

    // ✅ 로딩 상태 시작 (1:1 교체용)
    setState(() {
      // UI 로딩 상태 표시
    });
    
    // 로딩 상태 설정은 구현 클래스에서 처리
    onStartLoading();

    try {
      // 비동기로 교체 가능한 시간 탐색
      await Future.delayed(Duration.zero); // UI 업데이트를 위한 프레임 양보

      List<ExchangeOption> options = exchangeService.updateExchangeableTimes(
        timetableData!.timeSlots,
        timetableData!.teachers,
      );

      AppLogger.exchangeDebug('1:1 교체: 경로 탐색 완료 - ${options.length}개 경로 발견');

      // 1:1교체 경로 생성 (구현 클래스에서 처리)
      // ⚠️ 이 시점에서 Provider에 경로가 추가되고 UI 리스너가 트리거됨
      // ⚠️ 사이드바도 이 시점에서 표시됨 (generateOneToOnePaths 내부)
      AppLogger.exchangeDebug('1:1 교체: generateOneToOnePaths 호출 직전');
      generateOneToOnePaths(options);
      AppLogger.exchangeDebug('1:1 교체: generateOneToOnePaths 호출 완료');

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

      AppLogger.exchangeDebug('1:1 교체: Provider 및 DataSource 업데이트 완료');

      // ✅ 로딩 완료 상태 설정 (1:1 교체용)
      onFinishLoading();

      // ✅ 모든 데이터 업데이트 완료
      // 헤더 테마 업데이트는 호출자(.then())에서 수행
    } catch (e, stackTrace) {
      AppLogger.exchangeDebug('1:1 교체 경로 탐색 중 오류: $e');
      AppLogger.exchangeDebug('스택 트레이스: $stackTrace');
      
      // ✅ 오류 발생 시에도 로딩 상태 해제
      onErrorLoading();
    }
  }

  /// 교체 가능한 시간 업데이트 (하위 호환성을 위한 동기 래퍼)
  @Deprecated('Use updateExchangeableTimesWithProgress() instead')
  void updateExchangeableTimes() {
    updateExchangeableTimesWithProgress();
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

  
  // 추상 메서드들 - 구현 클래스에서 구현해야 함
  void onEmptyCellSelected();
  void onEmptyChainCellSelected();
  Future<void> findCircularPathsWithProgress();
  
  // 로딩 상태 관리 콜백들 - 구현 클래스에서 구현해야 함
  void onStartLoading();
  void onFinishLoading();
  void onErrorLoading();
  Future<void> findChainPathsWithProgress();
  void generateOneToOnePaths(List<dynamic> options); // ExchangeOption 리스트
  void onPathSelected(CircularExchangePath path);
  void onPathDeselected();
  void clearPreviousCircularExchangeState();
  void clearPreviousChainExchangeState();
}

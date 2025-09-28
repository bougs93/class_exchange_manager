import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../services/exchange_service.dart';
import '../../services/circular_exchange_service.dart';
import '../../services/excel_service.dart';
import '../../models/circular_exchange_path.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/exchange_algorithm.dart';
import '../../utils/logger.dart';
import '../../utils/day_utils.dart';

/// 교체 로직을 담당하는 Mixin
/// 1:1 교체와 순환교체 관련 비즈니스 로직을 분리
mixin ExchangeLogicMixin<T extends StatefulWidget> on State<T> {
  // 추상 속성들 - 구현 클래스에서 제공해야 함
  ExchangeService get exchangeService;
  CircularExchangeService get circularExchangeService;
  TimetableData? get timetableData;
  TimetableDataSource? get dataSource;
  bool get isExchangeModeEnabled;
  bool get isCircularExchangeModeEnabled;
  CircularExchangePath? get selectedCircularPath;
  
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
    
    setState(() {
      // UI 상태 업데이트는 ExchangeService에서 처리됨
    });
    
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
    
    setState(() {
      // UI 상태 업데이트
    });
    
    // 새로운 셀 선택 시 기존 선택된 순환교체 경로 초기화
    if (result.isSelected) {
      AppLogger.exchangeDebug('순환교체: 새로운 셀 선택됨 - 교사: ${result.teacherName}, 요일: ${result.day}, 교시: ${result.period}');
      dataSource?.updateSelectedCircularPath(null);
    } else if (result.isDeselected) {
      AppLogger.exchangeDebug('순환교체: 셀 선택 해제됨');
    }
    
    // 교체 대상 선택 후 교체 가능한 시간 탐색 및 표시
    processCircularCellSelection();
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
  
  /// 경로 선택 처리 (토글 기능 포함)
  void selectPath(CircularExchangePath path) {
    // 이미 선택된 경로를 다시 클릭하면 선택 해제 (토글 기능)
    bool isSamePathSelected = selectedCircularPath != null && 
                             selectedCircularPath!.nodes.length == path.nodes.length &&
                             selectedCircularPath!.nodes.asMap().entries.every((entry) {
                               int idx = entry.key;
                               var selectedNode = entry.value;
                               var pathNode = path.nodes[idx];
                               return selectedNode.teacherName == pathNode.teacherName &&
                                      selectedNode.day == pathNode.day &&
                                      selectedNode.period == pathNode.period &&
                                      selectedNode.className == pathNode.className;
                             });
    
    if (isSamePathSelected) {
      // 선택 해제
      onPathDeselected();
      
      AppLogger.exchangeInfo('순환교체 경로 선택이 해제되었습니다.');
      
      // 사용자에게 선택 해제 알림
      showSnackBar(
        '순환교체 경로 선택이 해제되었습니다.',
        backgroundColor: Colors.grey.shade600,
      );
      
      return;
    }
    
    // 새로운 경로 선택
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

  /// 선택된 셀이 빈 셀인지 확인
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
    
    AppLogger.exchangeDebug('빈 셀 확인: 교사=$teacherName, 요일=$selectedDay($dayOfWeek), 교시=$selectedPeriod, 수업있음=$hasClass');
    
    return !hasClass; // 수업이 없으면 빈 셀
  }
  
  // 추상 메서드들 - 구현 클래스에서 구현해야 함
  void onEmptyCellSelected();
  Future<void> findCircularPathsWithProgress();
  void onPathSelected(CircularExchangePath path);
  void onPathDeselected();
}

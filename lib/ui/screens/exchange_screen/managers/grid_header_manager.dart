import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../models/exchange_mode.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../../providers/selected_week_provider.dart';
import '../../../../providers/services_provider.dart';
import '../../../../services/exchange_service.dart';
import '../../../../services/circular_exchange_service.dart';
import '../../../../services/dual_exchange_service.dart';
import '../../../../utils/fixed_header_style_manager.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/syncfusion_timetable_helper.dart';
import '../../../../utils/timetable_data_source.dart';
import '../exchange_screen_state_proxy.dart';

/// Syncfusion DataGrid 컬럼/헤더 생성 및 테마 업데이트를 담당하는 Manager
///
/// 기존 ExchangeScreen State에 인라인으로 존재하던 그리드/헤더 생성 로직을
/// 분리한 것입니다. 동작은 동일하며, 호출 타이밍(ValueKey, addPostFrameCallback)은
/// 위젯 측에 그대로 유지됩니다.
class GridHeaderManager {
  final WidgetRef ref;
  final ExchangeScreenStateProxy stateProxy;

  GridHeaderManager({required this.ref, required this.stateProxy});

  // ===== 의존성 접근자 (Provider/Proxy에서 파생) =====
  ExchangeService get _exchangeService => ref.read(exchangeServiceProvider);
  CircularExchangeService get _circularExchangeService =>
      ref.read(circularExchangeServiceProvider);
  DualExchangeService get _dualExchangeService =>
      ref.read(dualExchangeServiceProvider);

  TimetableDataSource? get _dataSource =>
      ref.read(exchangeScreenProvider).dataSource;

  bool get _isExchangeModeEnabled =>
      stateProxy.currentMode == ExchangeMode.oneToOneExchange;
  bool get _isCircularExchangeModeEnabled =>
      stateProxy.currentMode == ExchangeMode.circularExchange;
  bool get _isDualExchangeModeEnabled =>
      stateProxy.currentMode == ExchangeMode.dualExchange;

  /// Syncfusion DataGrid 컬럼 및 헤더 생성
  void createSyncfusionGridData() {
    // 글로벌 Provider에서 시간표 데이터 확인 (StartScreen에서 설정한 데이터)
    final globalTimetableData = ref.read(exchangeScreenProvider).timetableData;

    if (globalTimetableData == null) {
      return;
    }

    // ExchangeService를 사용하여 교체 가능한 교사 정보 수집 (현재 선택된 교사가 있는 경우에만)
    List<Map<String, dynamic>> exchangeableTeachers = [];
    if (_exchangeService.hasSelectedCell()) {
      // 현재 교체 가능한 교사 정보를 가져옴
      exchangeableTeachers = _exchangeService.getCurrentExchangeableTeachers(
        globalTimetableData.timeSlots,
        globalTimetableData.teachers,
      );
    }

    // 선택된 요일과 교시 결정 (1:1 교체, 순환교체, 2중교체 모드, 또는 모든 모드에서 교체 리스트 셀 선택에 따라)
    String? selectedDay;
    int? selectedPeriod;

    if (_isExchangeModeEnabled && _exchangeService.hasSelectedCell()) {
      // 1:1 교체 모드
      selectedDay = _exchangeService.selectedDay;
      selectedPeriod = _exchangeService.selectedPeriod;
    } else if (_isCircularExchangeModeEnabled &&
        _circularExchangeService.hasSelectedCell()) {
      // 순환교체 모드
      selectedDay = _circularExchangeService.selectedDay;
      selectedPeriod = _circularExchangeService.selectedPeriod;
    } else if (_isDualExchangeModeEnabled &&
        _dualExchangeService.hasSelectedCell()) {
      // 2중교체 모드
      selectedDay = _dualExchangeService.selectedDay;
      selectedPeriod = _dualExchangeService.selectedPeriod;
    } else {
      // 모든 모드에서 교체 리스트 셀 선택 시 헤더 색상 변경 (보기 모드뿐만 아니라 다른 모드에서도)
      // TimetableDataSource에서 선택된 경로 확인 (TimetableGridSection에서 설정한 경로)
      final dataSourceCircularPath = _dataSource?.getSelectedCircularPath();
      final dataSourceOneToOnePath = _dataSource?.getSelectedOneToOnePath();
      final dataSourceDualPath = _dataSource?.getSelectedDualPath();

      if (dataSourceCircularPath != null &&
          dataSourceCircularPath.nodes.isNotEmpty) {
        selectedDay = dataSourceCircularPath.nodes.first.day;
        selectedPeriod = dataSourceCircularPath.nodes.first.period;
      } else if (dataSourceOneToOnePath != null &&
          dataSourceOneToOnePath.nodes.isNotEmpty) {
        selectedDay = dataSourceOneToOnePath.nodes.first.day;
        selectedPeriod = dataSourceOneToOnePath.nodes.first.period;
      } else if (dataSourceDualPath != null &&
          dataSourceDualPath.nodes.isNotEmpty) {
        selectedDay = dataSourceDualPath.nodes.first.day;
        selectedPeriod = dataSourceDualPath.nodes.first.period;
      }
    }

    // SyncfusionTimetableHelper를 사용하여 데이터 생성 (테마 기반)
    final result = SyncfusionTimetableHelper.convertToSyncfusionData(
      globalTimetableData.timeSlots,
      globalTimetableData.teachers,
      selectedDay: selectedDay, // 선택된 요일 전달
      selectedPeriod: selectedPeriod, // 선택된 교시 전달
      targetDay: _dataSource?.targetDay, // 타겟 셀 요일 (보기 모드용)
      targetPeriod: _dataSource?.targetPeriod, // 타겟 셀 교시 (보기 모드용)
      exchangeableTeachers: exchangeableTeachers, // 교체 가능한 교사 정보 전달
      selectedCircularPath: stateProxy.selectedCircularPath, // 선택된 순환교체 경로 전달
      selectedOneToOnePath: stateProxy.selectedOneToOnePath, // 선택된 1:1 교체 경로 전달
      selectedDualPath: stateProxy.selectedDualPath, // 선택된 2중교체 경로 전달
      selectedSupplementPath: stateProxy.selectedSupplementPath, // 선택된 보강 경로 전달
      weekMonday: ref.read(selectedWeekProvider), // 요일 헤더 날짜 표시(§10.5)
    );

    // Provider를 통해 그리드 데이터 업데이트 (변경이 필요한 경우에만 호출하여 성능 최적화)
    final notifier = ref.read(exchangeScreenProvider.notifier);
    final currentState = ref.read(exchangeScreenProvider);

    // 🔥 중요: 컬럼이 비어있거나 길이가 0인 경우 강제 업데이트 (초기 상태 보정)
    final bool needsForceUpdate =
        currentState.columns.isEmpty && result.columns.isNotEmpty;

    // 현재 상태와 비교하여 실제로 변경이 필요한 경우에만 업데이트
    if (needsForceUpdate ||
        _shouldUpdateColumns(currentState.columns, result.columns)) {
      notifier.setColumns(result.columns);
    }

    if (needsForceUpdate ||
        _shouldUpdateStackedHeaders(
          currentState.stackedHeaders,
          result.stackedHeaders,
        )) {
      notifier.setStackedHeaders(result.stackedHeaders);
    }

    // 엑셀 파일 로드 시마다 무조건 새로운 데이터소스 생성
    final dataSource = TimetableDataSource(
      timeSlots: globalTimetableData.timeSlots,
      teachers: globalTimetableData.teachers,
      ref: ref, // WidgetRef 추가
    );

    // 교체불가 편집 모드 상태를 TimetableDataSource에 전달
    dataSource.setNonExchangeableEditMode(
      ref.read(exchangeScreenProvider).currentMode ==
          ExchangeMode.nonExchangeableEdit,
    );

    // Provider에 데이터 소스 설정
    notifier.setDataSource(dataSource);
  }

  /// 테마 기반 헤더 업데이트 (선택된 교시 헤더를 연한 파란색으로 표시)
  ///
  /// [forceUpdate]: true인 경우 줌 팩터 변경 등으로 인해 헤더를 강제로 재생성합니다.
  void updateHeaderTheme({bool forceUpdate = false}) {
    final screenState = ref.read(exchangeScreenProvider);

    // 🔥 중요: timetableData가 없으면 헤더 업데이트 중단
    // 모드 전환 중 timetableData가 로드되지 않은 경우를 방지
    if (screenState.timetableData == null) {
      return;
    }

    // 🔥 중요: 기존 컬럼이 있고 timetableData가 있으면, 구조적 변경 없이 스타일만 업데이트
    // 모드 전환 시 컬럼을 재생성하지 않고 기존 컬럼 유지
    // 단, forceUpdate가 true인 경우 (줌 팩터 변경 등) 헤더를 재생성해야 함
    if (!forceUpdate &&
        screenState.columns.isNotEmpty &&
        screenState.timetableData != null) {
      // 기존 컬럼이 있으면 DataSource만 업데이트 (스타일 변경만 반영)
      screenState.dataSource?.notifyDataChanged();
      return;
    }

    // 선택된 요일과 교시 결정 (단순화된 로직)
    final selectionInfo = _getSelectedPeriodInfo();
    final String? selectedDay = selectionInfo.day;
    final int? selectedPeriod = selectionInfo.period;

    // FixedHeaderStyleManager의 셀 선택 전용 업데이트 사용 (성능 최적화)
    FixedHeaderStyleManager.updateHeaderForCellSelection(
      selectedDay: selectedDay,
      selectedPeriod: selectedPeriod,
    );

    // 교시 헤더 색상 변경을 위한 캐시 강제 초기화
    FixedHeaderStyleManager.clearCacheForPeriodHeaderColorChange();

    // ExchangeService를 사용하여 교체 가능한 교사 정보 수집
    final timetableData = screenState.timetableData!;
    List<Map<String, dynamic>> exchangeableTeachers = _exchangeService
        .getCurrentExchangeableTeachers(
          timetableData.timeSlots,
          timetableData.teachers,
        );

    // 선택된 교시 정보를 전달하여 헤더만 업데이트
    final result = SyncfusionTimetableHelper.convertToSyncfusionData(
      timetableData.timeSlots,
      timetableData.teachers,
      selectedDay: selectedDay, // 테마에서 사용할 선택 정보
      selectedPeriod: selectedPeriod,
      targetDay: _dataSource?.targetDay, // 타겟 셀 요일 (보기 모드용)
      targetPeriod: _dataSource?.targetPeriod, // 타겟 셀 교시 (보기 모드용)
      exchangeableTeachers: exchangeableTeachers, // 교체 가능한 교사 정보 전달
      // 보기 모드에서도 경로 정보 전달 (헤더 스타일 적용을 위해)
      selectedCircularPath: stateProxy.selectedCircularPath, // 순환교체 경로
      selectedOneToOnePath: stateProxy.selectedOneToOnePath, // 1:1 교체 경로
      selectedDualPath: stateProxy.selectedDualPath, // 2중교체 경로
      selectedSupplementPath: stateProxy.selectedSupplementPath, // 보강 경로
    );

    // Provider를 통한 헤더 업데이트 (최적화됨 - 구조적 변경이 있는 경우에만 업데이트)
    final notifier = ref.read(exchangeScreenProvider.notifier);
    final currentState = ref.read(exchangeScreenProvider);

    // 🔥 중요: 컬럼이 비어있거나 길이가 0인 경우 강제 업데이트 (초기 상태 보정)
    final bool needsForceUpdate =
        currentState.columns.isEmpty && result.columns.isNotEmpty;

    // 구조적 변경(컬럼 수, 헤더 수)이 있는 경우에만 업데이트하여 ValueKey 변경 방지
    bool needsStructuralUpdate =
        needsForceUpdate ||
        _shouldUpdateColumns(currentState.columns, result.columns) ||
        _shouldUpdateStackedHeaders(
          currentState.stackedHeaders,
          result.stackedHeaders,
        );

    // forceUpdate가 true인 경우 무조건 헤더 재생성 (줌 팩터 변경 등)
    if (forceUpdate || needsStructuralUpdate) {
      // 구조적 변경이 필요한 경우에만 columns/stackedHeaders 업데이트
      if (forceUpdate ||
          needsForceUpdate ||
          _shouldUpdateColumns(currentState.columns, result.columns)) {
        notifier.setColumns(result.columns);
      }

      if (forceUpdate ||
          needsForceUpdate ||
          _shouldUpdateStackedHeaders(
            currentState.stackedHeaders,
            result.stackedHeaders,
          )) {
        notifier.setStackedHeaders(result.stackedHeaders);
      }
    }

    // TimetableDataSource의 최적화된 UI 업데이트 (배치 업데이트 지원)
    screenState.dataSource?.notifyDataChanged();
  }

  /// 선택된 교시 정보를 안전하게 가져오는 메서드
  ({String? day, int? period}) _getSelectedPeriodInfo() {
    final screenState = ref.read(exchangeScreenProvider);

    // 1:1 교체 모드
    if (_isExchangeModeEnabled && _exchangeService.hasSelectedCell()) {
      return (
        day: _exchangeService.selectedDay,
        period: _exchangeService.selectedPeriod,
      );
    }

    // 순환교체 모드
    if (_isCircularExchangeModeEnabled &&
        _circularExchangeService.hasSelectedCell()) {
      return (
        day: _circularExchangeService.selectedDay,
        period: _circularExchangeService.selectedPeriod,
      );
    }

    // 2중교체 모드
    if (_isDualExchangeModeEnabled && _dualExchangeService.hasSelectedCell()) {
      return (
        day: _dualExchangeService.selectedDay,
        period: _dualExchangeService.selectedPeriod,
      );
    }

    // 경로 선택 시 (모든 모드에서 교체 리스트 셀 선택)
    try {
      final dataSourceCircularPath =
          screenState.dataSource?.getSelectedCircularPath();
      if (dataSourceCircularPath != null &&
          dataSourceCircularPath.nodes.isNotEmpty) {
        return (
          day: dataSourceCircularPath.nodes.first.day,
          period: dataSourceCircularPath.nodes.first.period,
        );
      }

      final dataSourceOneToOnePath =
          screenState.dataSource?.getSelectedOneToOnePath();
      if (dataSourceOneToOnePath != null &&
          dataSourceOneToOnePath.nodes.isNotEmpty) {
        return (
          day: dataSourceOneToOnePath.nodes.first.day,
          period: dataSourceOneToOnePath.nodes.first.period,
        );
      }

      final dataSourceDualPath = screenState.dataSource?.getSelectedDualPath();
      if (dataSourceDualPath != null && dataSourceDualPath.nodes.isNotEmpty) {
        return (
          day: dataSourceDualPath.nodes.first.day,
          period: dataSourceDualPath.nodes.first.period,
        );
      }

      final dataSourceSupplementPath =
          screenState.dataSource?.getSelectedSupplementPath();
      if (dataSourceSupplementPath != null &&
          dataSourceSupplementPath.nodes.isNotEmpty) {
        return (
          day: dataSourceSupplementPath.nodes.first.day,
          period: dataSourceSupplementPath.nodes.first.period,
        );
      }
    } catch (e) {
      // 경로 정보 접근 중 오류 발생 시 안전하게 처리
      AppLogger.error('경로 정보 접근 중 오류: $e');
    }

    // 선택된 교시가 없는 경우
    return (day: null, period: null);
  }

  /// 컬럼 업데이트가 필요한지 확인 (최적화됨 - 구조적 변경만 감지)
  bool _shouldUpdateColumns(
    List<GridColumn> currentColumns,
    List<GridColumn> newColumns,
  ) {
    // 🔥 중요: 빈 리스트인 경우 무조건 업데이트 (초기 상태 또는 리셋된 상태)
    if (currentColumns.isEmpty && newColumns.isNotEmpty) {
      return true;
    }

    // 길이가 다르면 구조적 변경
    if (currentColumns.length != newColumns.length) {
      return true;
    }

    // 컬럼명이나 기본 구조가 변경된 경우만 업데이트 (스타일 변경은 제외)
    for (int i = 0; i < currentColumns.length; i++) {
      if (currentColumns[i].columnName != newColumns[i].columnName) {
        return true; // 컬럼명 변경은 구조적 변경
      }
      // width 변경은 스타일 변경이므로 제외하여 불필요한 ValueKey 변경 방지
    }
    return false;
  }

  /// 스택 헤더 업데이트가 필요한지 확인 (최적화됨 - 구조적 변경만 감지)
  bool _shouldUpdateStackedHeaders(
    List<StackedHeaderRow> currentHeaders,
    List<StackedHeaderRow> newHeaders,
  ) {
    // 🔥 중요: 빈 리스트인 경우 무조건 업데이트 (초기 상태 또는 리셋된 상태)
    if (currentHeaders.isEmpty && newHeaders.isNotEmpty) {
      return true;
    }

    // 길이가 다르면 구조적 변경
    if (currentHeaders.length != newHeaders.length) {
      return true;
    }

    // 헤더 구조가 변경된 경우만 업데이트 (스타일 변경은 제외)
    for (int i = 0; i < currentHeaders.length; i++) {
      if (currentHeaders[i].cells.length != newHeaders[i].cells.length) {
        return true;
      }

      for (int j = 0; j < currentHeaders[i].cells.length; j++) {
        if (currentHeaders[i].cells[j].columnNames.length !=
            newHeaders[i].cells[j].columnNames.length) {
          return true;
        }

        // 컬럼명 구조가 변경된 경우만 업데이트
        for (
          int k = 0;
          k < currentHeaders[i].cells[j].columnNames.length;
          k++
        ) {
          if (currentHeaders[i].cells[j].columnNames[k] !=
              newHeaders[i].cells[j].columnNames[k]) {
            return true;
          }
        }
      }
    }
    return false;
  }
}

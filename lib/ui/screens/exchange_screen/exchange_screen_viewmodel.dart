import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../services/excel_service.dart';
import '../../../services/exchange_service.dart';
import '../../../services/circular_exchange_service.dart';
import '../../../services/chain_exchange_service.dart';
import '../../../providers/exchange_screen_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../models/time_slot.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../utils/logger.dart';
import '../../../utils/timetable_data_source.dart';
import 'helpers/grid_helper.dart';
import 'helpers/cell_tap_helper.dart';

/// 요일과 교시 정보를 담는 클래스 (Flutter Material의 DayPeriod와 충돌 방지)
class DayPeriodInfo {
  final String day;
  final int period;

  DayPeriodInfo({required this.day, required this.period});
}

/// ExchangeScreen의 ViewModel
/// 비즈니스 로직을 UI에서 분리
class ExchangeScreenViewModel {
  final Ref ref;
  final ExchangeService exchangeService;
  final CircularExchangeService circularExchangeService;
  final ChainExchangeService chainExchangeService;

  ExchangeScreenViewModel({
    required this.ref,
    required this.exchangeService,
    required this.circularExchangeService,
    required this.chainExchangeService,
  });

  /// Provider notifier 접근
  ExchangeScreenNotifier get _notifier =>
      ref.read(exchangeScreenProvider.notifier);

  /// 현재 상태 접근
  ExchangeScreenState get _state => ref.read(exchangeScreenProvider);

  // ==================== 교체불가 편집 모드 ====================

  /// 교체불가 편집 모드 토글
  void toggleNonExchangeableEditMode({
    required bool isExchangeModeEnabled,
    required bool isCircularExchangeModeEnabled,
    required bool isChainExchangeModeEnabled,
    required VoidCallback toggleExchangeMode,
    required VoidCallback toggleCircularExchangeMode,
    required VoidCallback toggleChainExchangeMode,
    required TimetableDataSource? dataSource,
  }) {
    final currentMode = _state.isNonExchangeableEditMode;

    // 다른 교체 모드가 활성화되어 있다면 비활성화
    if (!currentMode) {
      if (isExchangeModeEnabled) toggleExchangeMode();
      if (isCircularExchangeModeEnabled) toggleCircularExchangeMode();
      if (isChainExchangeModeEnabled) toggleChainExchangeMode();
    }

    // 상태 변경
    _notifier.setNonExchangeableEditMode(!currentMode);

    // DataSource에 편집 모드 상태 전달
    dataSource?.setNonExchangeableEditMode(!currentMode);

    AppLogger.exchangeDebug(
        '교체불가 편집 모드 토글: ${!currentMode ? "활성화" : "비활성화"}');
  }

  /// 셀을 교체불가로 설정 또는 해제 (토글 방식)
  void setCellAsNonExchangeable(
    DataGridCellTapDetails details,
    TimetableData? timetableData,
    TimetableDataSource? dataSource,
  ) {
    if (timetableData == null || dataSource == null) return;

    final teacherName = getTeacherNameFromCell(details, dataSource);
    final dayPeriodInfo = extractDayPeriodFromColumnName(details);

    if (teacherName == null || dayPeriodInfo == null) return;

    // DataSource의 메서드를 사용하여 일관성 유지
    // (NonExchangeableManager를 통해 처리되며, 캐시 무효화 및 UI 업데이트 포함)
    dataSource.setCellAsNonExchangeable(
        teacherName, dayPeriodInfo.day, dayPeriodInfo.period);
  }

  /// 교사명 클릭 시 해당 교사의 모든 시간을 교체가능/교체불가능으로 토글
  void toggleTeacherAllTimes(
    String teacherName,
    TimetableData? timetableData,
    TimetableDataSource? dataSource,
  ) {
    if (dataSource == null) return;

    // DataSource의 메서드를 사용하여 일관성 유지
    // (NonExchangeableManager를 통해 처리되며, 캐시 무효화 및 UI 업데이트 포함)
    dataSource.toggleTeacherAllTimes(teacherName);
  }

  // ==================== 헬퍼 메서드 ====================

  /// 셀에서 교사명 추출
  String? getTeacherNameFromCell(
    DataGridCellTapDetails details,
    TimetableDataSource? dataSource,
  ) {
    if (dataSource == null) return null;

    const int headerRowCount = 2;
    int actualRowIndex = details.rowColumnIndex.rowIndex - headerRowCount;

    if (actualRowIndex >= 0 && actualRowIndex < dataSource.rows.length) {
      DataGridRow row = dataSource.rows[actualRowIndex];
      for (DataGridCell rowCell in row.getCells()) {
        if (rowCell.columnName == 'teacher') {
          return rowCell.value.toString();
        }
      }
    }
    return null;
  }

  /// 컬럼명에서 요일과 교시 정보 추출
  DayPeriodInfo? extractDayPeriodFromColumnName(DataGridCellTapDetails details) {
    if (details.column.columnName == 'teacher') {
      return null;
    }

    List<String> parts = details.column.columnName.split('_');
    if (parts.length != 2) {
      AppLogger.exchangeDebug('컬럼명 형식이 올바르지 않음: ${details.column.columnName}');
      return null;
    }

    String day = parts[0];
    int period = int.tryParse(parts[1]) ?? 0;

    return DayPeriodInfo(day: day, period: period);
  }

  /// 교사명, 요일, 교시로 TimeSlot 찾기
  TimeSlot? findTimeSlot(
    String teacherName,
    String day,
    int period,
    TimetableData timetableData,
  ) {
    try {
      return timetableData.timeSlots.firstWhere(
        (slot) =>
            slot.teacher == teacherName &&
            slot.dayOfWeek != null &&
            _getDayName(slot.dayOfWeek!) == day &&
            slot.period == period,
      );
    } catch (e) {
      return null;
    }
  }

  /// 요일 숫자를 문자열로 변환
  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return '월';
      case 2:
        return '화';
      case 3:
        return '수';
      case 4:
        return '목';
      case 5:
        return '금';
      default:
        return '';
    }
  }

  // ==================== Grid Helper 위임 ====================

  /// Syncfusion DataGrid 컬럼 및 헤더 생성 (Helper 사용)
  GridData createSyncfusionGridData({
    required TimetableData timetableData,
    List<Map<String, dynamic>>? exchangeableTeachers,
    CircularExchangePath? selectedCircularPath,
    OneToOneExchangePath? selectedOneToOnePath,
    ChainExchangePath? selectedChainPath,
  }) {
    return GridHelper.createSyncfusionGridData(
      timetableData: timetableData,
      exchangeableTeachers: exchangeableTeachers,
      selectedCircularPath: selectedCircularPath,
      selectedOneToOnePath: selectedOneToOnePath,
      selectedChainPath: selectedChainPath,
    );
  }

  // ==================== Cell Tap Helper 위임 ====================

  /// 셀 탭 처리 가능 여부 확인
  bool shouldHandleCellTap({
    required bool isExchangeModeEnabled,
    required bool isCircularExchangeModeEnabled,
    required bool isChainExchangeModeEnabled,
    required bool isNonExchangeableEditMode,
  }) {
    return CellTapHelper.shouldHandleCellTap(
      isExchangeModeEnabled: isExchangeModeEnabled,
      isCircularExchangeModeEnabled: isCircularExchangeModeEnabled,
      isChainExchangeModeEnabled: isChainExchangeModeEnabled,
      isNonExchangeableEditMode: isNonExchangeableEditMode,
    );
  }

  /// 교체 가능한 교사 수 계산
  int getActualExchangeableCount(
    List<Map<String, dynamic>>? exchangeableTeachers,
  ) {
    return CellTapHelper.getActualExchangeableCount(exchangeableTeachers);
  }
}

/// ViewModel Provider
final exchangeScreenViewModelProvider = Provider<ExchangeScreenViewModel>((ref) {
  return ExchangeScreenViewModel(
    ref: ref,
    exchangeService: ref.read(exchangeServiceProvider),
    circularExchangeService: ref.read(circularExchangeServiceProvider),
    chainExchangeService: ref.read(chainExchangeServiceProvider),
  );
});

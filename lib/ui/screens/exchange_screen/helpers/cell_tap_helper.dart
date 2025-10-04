import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../services/excel_service.dart';
import '../../../../utils/timetable_data_source.dart';

/// 셀 탭 이벤트 처리 헬퍼
class CellTapHelper {
  /// 셀 탭 이벤트가 교체 모드에서 처리 가능한지 확인
  static bool shouldHandleCellTap({
    required bool isExchangeModeEnabled,
    required bool isCircularExchangeModeEnabled,
    required bool isChainExchangeModeEnabled,
    required bool isNonExchangeableEditMode,
  }) {
    return isExchangeModeEnabled ||
        isCircularExchangeModeEnabled ||
        isChainExchangeModeEnabled ||
        isNonExchangeableEditMode;
  }

  /// 교체 모드별로 적절한 핸들러 호출
  static void handleCellTap({
    required DataGridCellTapDetails details,
    required bool isExchangeModeEnabled,
    required bool isCircularExchangeModeEnabled,
    required bool isChainExchangeModeEnabled,
    required bool isNonExchangeableEditMode,
    required TimetableData? timetableData,
    required TimetableDataSource? dataSource,
    required VoidCallback Function(DataGridCellTapDetails) onOneToOneModeTap,
    required VoidCallback Function(DataGridCellTapDetails) onCircularModeTap,
    required VoidCallback Function(DataGridCellTapDetails) onChainModeTap,
    required VoidCallback Function(DataGridCellTapDetails) onNonExchangeableEditTap,
  }) {
    if (timetableData == null) return;

    // 교사명 열 클릭 처리 (교체불가 편집 모드에서만)
    if (details.column.columnName == 'teacher' && isNonExchangeableEditMode) {
      onNonExchangeableEditTap(details);
      return;
    }

    // 각 모드별 처리
    if (isNonExchangeableEditMode) {
      onNonExchangeableEditTap(details);
    } else if (isExchangeModeEnabled) {
      onOneToOneModeTap(details);
    } else if (isCircularExchangeModeEnabled) {
      onCircularModeTap(details);
    } else if (isChainExchangeModeEnabled) {
      onChainModeTap(details);
    }
  }

  /// 교체 가능한 교사 수 계산
  static int getActualExchangeableCount(
    List<Map<String, dynamic>>? exchangeableTeachers,
  ) {
    if (exchangeableTeachers == null || exchangeableTeachers.isEmpty) {
      return 0;
    }

    // 중복 제거: 같은 교사의 다른 시간은 하나로 카운트
    Set<String> uniqueTeachers = {};
    for (var teacher in exchangeableTeachers) {
      uniqueTeachers.add(teacher['teacherName'] as String);
    }

    return uniqueTeachers.length;
  }
}

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:flutter/material.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../utils/logger.dart';

/// SubstitutionPlanData Extension - 컬럼 값 접근
extension SubstitutionPlanDataAccessor on SubstitutionPlanData {
  /// 컬럼명으로 데이터 값 가져오기
  String getValueByColumnName(String columnName) {
    return switch (columnName) {
      'absenceDate' => absenceDate,
      'absenceDay' => absenceDay,
      'period' => period,
      'grade' => grade,
      'className' => className,
      'subject' => subject,
      'teacher' => teacher,
      'supplementSubject' => supplementSubject,
      'supplementTeacher' => supplementTeacher,
      'substitutionDate' => substitutionDate,
      'substitutionDay' => substitutionDay,
      'substitutionPeriod' => substitutionPeriod,
      'substitutionSubject' => substitutionSubject,
      'substitutionTeacher' => substitutionTeacher,
      'remarks' => remarks,
      'groupId' => groupId ?? '',
      _ => '',
    };
  }
}

/// 그리드 설정 클래스
class SubstitutionPlanGridConfig {
  /// 여백 및 스타일 상수
  static const EdgeInsets headerPadding = EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0);
  static const EdgeInsets cellPadding = EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0);
  static const double smallSpacing = 2.0;
  static const double mediumSpacing = 2.0;
  static const double headerFontSize = 12.0;
  static const double cellFontSize = 12.0;

  /// 컬럼 정의
  static List<GridColumn> getColumns() {
    return [
      GridColumn(columnName: 'absenceDate', label: _buildHeaderLabel('결강일'), width: 70),
      GridColumn(columnName: 'absenceDay', label: _buildHeaderLabel('요일'), width: 45),
      GridColumn(columnName: 'period', label: _buildHeaderLabel('교시'), width: 45),
      GridColumn(columnName: 'grade', label: _buildHeaderLabel('학년'), width: 45),
      GridColumn(columnName: 'className', label: _buildHeaderLabel('반'), width: 55),
      GridColumn(columnName: 'subject', label: _buildHeaderLabel('과목'), width: 70),
      GridColumn(columnName: 'teacher', label: _buildHeaderLabel('교사'), width: 70),
      GridColumn(columnName: 'supplementSubject', label: _buildHeaderLabel('과목'), width: 70),
      GridColumn(columnName: 'supplementTeacher', label: _buildHeaderLabel('성명'), width: 90),
      GridColumn(columnName: 'substitutionDate', label: _buildHeaderLabel('교체일'), width: 70),
      GridColumn(columnName: 'substitutionDay', label: _buildHeaderLabel('요일'), width: 45),
      GridColumn(columnName: 'substitutionPeriod', label: _buildHeaderLabel('교시'), width: 45),
      GridColumn(columnName: 'substitutionSubject', label: _buildHeaderLabel('과목'), width: 70),
      GridColumn(columnName: 'substitutionTeacher', label: _buildHeaderLabel('교사'), width: 90),
      GridColumn(columnName: 'remarks', label: _buildHeaderLabel('비고'), width: 100),
    ];
  }

  /// 스택 헤더 정의
  static List<StackedHeaderRow> getStackedHeaders() {
    return [
      StackedHeaderRow(
        cells: [
          _buildStackedHeaderCell(['absenceDate', 'absenceDay', 'period', 'grade', 'className', 'subject', 'teacher'], '결강'),
          _buildStackedHeaderCell(['supplementSubject', 'supplementTeacher'], '보강/수업변경'),
          _buildStackedHeaderCell(['substitutionDate', 'substitutionDay', 'substitutionPeriod', 'substitutionSubject', 'substitutionTeacher'], '수업 교체'),
          _buildStackedHeaderCell(['remarks'], '비고'),
        ],
      ),
    ];
  }

  /// 헤더 레이블 위젯 생성
  static Widget _buildHeaderLabel(String text) {
    return Container(
      padding: headerPadding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: cellFontSize,
          height: 1.0,
        ),
      ),
    );
  }

  /// 스택 헤더 셀 위젯 생성
  static StackedHeaderCell _buildStackedHeaderCell(List<String> columnNames, String text) {
    return StackedHeaderCell(
      columnNames: columnNames,
      child: Container(
        padding: headerPadding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: headerFontSize,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// 셀 렌더러 Factory 클래스
class CellRendererFactory {
  /// 셀 렌더링 (타입에 따라 적절한 렌더러 선택)
  static Widget build(
    DataGridCell cell,
    DataGridRow row, {
    Function(String, String)? onDateCellTap,
    Function(String)? onSupplementSubjectTap,
  }) {
    return switch (cell.columnName) {
      'absenceDate' || 'substitutionDate' => DateCellRenderer.build(cell, row, onDateCellTap),
      'supplementSubject' => SupplementSubjectCellRenderer.build(cell, row, onSupplementSubjectTap),
      _ => NormalCellRenderer.build(cell),
    };
  }
}

/// 날짜 셀 렌더러
class DateCellRenderer {
  static Widget build(DataGridCell cell, DataGridRow row, Function(String, String)? onDateCellTap) {
    // 교체일(substitutionDate) 컬럼인 경우 교사 이름 확인
    bool isSelectable = false;
    String displayText = '';

    if (cell.columnName == 'substitutionDate') {
      // 교체일 컬럼의 경우: 교체 교사가 있으면 항상 선택 가능
      final substitutionTeacherCell = row.getCells().firstWhere(
        (c) => c.columnName == 'substitutionTeacher',
        orElse: () => const DataGridCell<String>(columnName: 'substitutionTeacher', value: ''),
      );
      final substitutionTeacher = (substitutionTeacherCell.value?.toString() ?? '').trim();
      isSelectable = substitutionTeacher.isNotEmpty;
      displayText = cell.value?.toString() ?? '';
    } else {
      // 다른 날짜 컬럼(결강일 등)의 경우: 항상 선택 가능
      isSelectable = true;
      displayText = cell.value?.toString() ?? '';
    }

    return GestureDetector(
      onTap: () {
        AppLogger.exchangeDebug('셀 클릭 - 컬럼: ${cell.columnName}, 값: ${cell.value}, 선택가능: $isSelectable');

        if (!isSelectable) {
          AppLogger.exchangeDebug('교체일 선택 불가: 교체 교사가 없거나 이미 날짜가 설정됨');
          return;
        }

        if (onDateCellTap != null) {
          // exchangeId를 row의 첫 번째 셀에서 추출
          final exchangeIdCell = row.getCells().firstWhere(
            (c) => c.columnName == '_exchangeId',
            orElse: () => const DataGridCell<String>(columnName: '_exchangeId', value: ''),
          );
          final exchangeId = exchangeIdCell.value?.toString() ?? '';

          AppLogger.exchangeDebug('exchangeId: $exchangeId, 콜백 호출');

          if (exchangeId.isNotEmpty) {
            onDateCellTap(exchangeId, cell.columnName);
          } else {
            AppLogger.warning('exchangeId가 비어있습니다');
          }
        } else {
          AppLogger.warning('onDateCellTap이 null입니다');
        }
      },
      child: Container(
        alignment: Alignment.center,
        padding: SubstitutionPlanGridConfig.cellPadding,
        decoration: BoxDecoration(
          color: isSelectable && (displayText.isEmpty || displayText == '선택') ? Colors.blue.shade50 : Colors.transparent,
          border: isSelectable && (displayText.isEmpty || displayText == '선택') ? Border.all(color: Colors.blue.shade200) : null,
          borderRadius: isSelectable && (displayText.isEmpty || displayText == '선택') ? BorderRadius.circular(4) : null,
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: SubstitutionPlanGridConfig.cellFontSize,
            height: 1.0,
            color: isSelectable && (displayText.isEmpty || displayText == '선택') ? Colors.blue.shade700 : Colors.black87,
            fontWeight: isSelectable && (displayText.isEmpty || displayText == '선택') ? FontWeight.w500 : FontWeight.normal,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// 보강 과목 셀 렌더러
class SupplementSubjectCellRenderer {
  static Widget build(DataGridCell cell, DataGridRow row, Function(String)? onSupplementSubjectTap) {
    final value = (cell.value?.toString() ?? '').trim();
    final isEmpty = value.isEmpty;

    // exchangeId 추출
    final exchangeIdCell = row.getCells().firstWhere(
      (c) => c.columnName == '_exchangeId',
      orElse: () => const DataGridCell<String>(columnName: '_exchangeId', value: ''),
    );
    final exchangeId = exchangeIdCell.value?.toString() ?? '';

    // 보강 교사명(성명) 셀 찾기
    final supplementTeacherCell = row.getCells().firstWhere(
      (c) => c.columnName == 'supplementTeacher',
      orElse: () => const DataGridCell<String>(columnName: 'supplementTeacher', value: ''),
    );
    final supplementTeacher = (supplementTeacherCell.value?.toString() ?? '').trim();
    final hasTeacher = supplementTeacher.isNotEmpty;

    // 보강 교사명이 있으면 항상 활성화 (과목이 있어도 재선택 가능)
    final isSelectable = hasTeacher;

    return GestureDetector(
      onTap: () async {
        if (exchangeId.isEmpty || !isSelectable) return;
        if (onSupplementSubjectTap != null) {
          onSupplementSubjectTap(exchangeId);
        }
      },
      child: Container(
        alignment: Alignment.center,
        padding: SubstitutionPlanGridConfig.cellPadding,
        decoration: BoxDecoration(
          color: isSelectable && isEmpty ? Colors.blue.shade50 : Colors.transparent,
          border: isSelectable && isEmpty ? Border.all(color: Colors.blue.shade200) : null,
          borderRadius: isSelectable && isEmpty ? BorderRadius.circular(4) : null,
        ),
        child: Text(
          isEmpty ? (hasTeacher ? '과목선택' : '') : value,
          style: TextStyle(
            fontSize: SubstitutionPlanGridConfig.cellFontSize,
            height: 1.0,
            color: isSelectable && isEmpty ? Colors.blue.shade700 : Colors.black87,
            fontWeight: isSelectable && isEmpty ? FontWeight.w500 : FontWeight.normal,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// 일반 셀 렌더러
class NormalCellRenderer {
  static Widget build(DataGridCell cell) {
    return Container(
      alignment: Alignment.center,
      padding: SubstitutionPlanGridConfig.cellPadding,
      child: Text(
        cell.value?.toString() ?? '',
        style: const TextStyle(
          fontSize: SubstitutionPlanGridConfig.cellFontSize,
          height: 1.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 디버그 유틸리티 클래스 (production 빌드에서 제거 가능)
class SubstitutionPlanDebugger {
  /// planData 테이블을 디버그 콘솔에 표 형태로 출력
  static void printTable(List<SubstitutionPlanData> planData) {
    if (!kDebugMode) return; // production에서 완전히 제거

    if (planData.isEmpty) {
      AppLogger.exchangeDebug('=== PlanData 테이블 (빈 데이터) ===');
      return;
    }

    // 컬럼 헤더 정의 (한글명과 영문명 매핑)
    final Map<String, String> columnHeaders = {
      'exchangeId': '교체ID',
      'absenceDate': '결강일',
      'absenceDay': '결강요일',
      'period': '교시',
      'grade': '학년',
      'className': '반',
      'subject': '과목',
      'teacher': '교사',
      'supplementSubject': '보강과목',
      'supplementTeacher': '보강교사',
      'substitutionDate': '교체일',
      'substitutionDay': '교체요일',
      'substitutionPeriod': '교체교시',
      'substitutionSubject': '교체과목',
      'substitutionTeacher': '교체교사',
      'remarks': '비고',
      'groupId': '그룹ID',
    };

    // 출력할 컬럼 순서 정의 (exchangeId는 제외)
    final List<String> displayColumns = [
      'absenceDate', 'absenceDay', 'period', 'grade', 'className', 'subject', 'teacher',
      'supplementSubject', 'supplementTeacher', 'substitutionDate', 'substitutionDay',
      'substitutionPeriod', 'substitutionSubject', 'substitutionTeacher', 'remarks', 'groupId'
    ];

    // 각 컬럼의 최대 너비 계산
    final Map<String, int> columnWidths = {};
    for (String column in displayColumns) {
      int maxWidth = columnHeaders[column]!.length;
      for (SubstitutionPlanData data in planData) {
        String value = data.getValueByColumnName(column);
        maxWidth = maxWidth > value.length ? maxWidth : value.length;
      }
      columnWidths[column] = maxWidth;
    }

    // 테이블 출력 시작
    AppLogger.exchangeDebug('=== PlanData 테이블 (총 ${planData.length}개 항목) ===');

    // 헤더 출력
    String headerLine = '';
    for (String column in displayColumns) {
      String header = columnHeaders[column]!;
      headerLine += header.padRight(columnWidths[column]! + 2);
    }
    AppLogger.exchangeDebug(headerLine);

    // 구분선 출력
    String separatorLine = '';
    for (String column in displayColumns) {
      separatorLine += '-'.padRight(columnWidths[column]! + 2, '-');
    }
    AppLogger.exchangeDebug(separatorLine);

    // 데이터 행 출력
    for (int i = 0; i < planData.length; i++) {
      SubstitutionPlanData data = planData[i];
      String dataLine = '';
      for (String column in displayColumns) {
        String value = data.getValueByColumnName(column);
        dataLine += value.padRight(columnWidths[column]! + 2);
      }
      AppLogger.exchangeDebug('${(i + 1).toString().padLeft(3)}: $dataLine');
    }

    AppLogger.exchangeDebug('=== 테이블 출력 완료 ===');
  }
}

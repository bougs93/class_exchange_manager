import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:flutter/material.dart';
import '../../../../models/print_profile.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../theme/design_tokens.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/data_grid_extensions.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../widgets/selectable_cell_builder.dart';

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
class ContentInputGridConfig {
  /// 여백 및 스타일 상수
  static const EdgeInsets headerPadding = EdgeInsets.zero;
  static const EdgeInsets cellPadding = EdgeInsets.zero;
  static const double mediumSpacing = 5.0;
  static const double smallSpacing = 2.0;
  static const double headerFontSize = 12.0;
  static const double cellFontSize = 12.0;

  /// SfDataGrid headerRowHeight 와 동일 (비고 2행 합침 높이 계산용)
  static const double headerRowHeight = 35.0;

  /// 헤더 1·2행 공통 테두리 (스택 헤더·컬럼 헤더 동일)
  ///
  /// 배경색은 디자인 토큰([DesignTokens.sectionBackground])으로 제공됩니다.
  static Color _headerBorderColor(DesignTokens tokens) => tokens.cardBorder;

  /// 컬럼 정의
  static List<GridColumn> getColumns(DesignTokens tokens) {
    return [
      GridColumn(
        columnName: 'select',
        label: _buildHeaderLabel('선택', tokens),
        width: 40,
      ),
      GridColumn(
        columnName: 'profile',
        label: _buildHeaderLabel('계획서', tokens),
        width: 95,
      ),
      GridColumn(
        columnName: 'absenceDate',
        label: _buildHeaderLabel('결강일', tokens),
        width: 60,
      ),
      GridColumn(
        columnName: 'absenceDay',
        label: _buildHeaderLabel('요일', tokens),
        width: 35,
      ),
      GridColumn(
        columnName: 'period',
        label: _buildHeaderLabel('교시', tokens),
        width: 35,
      ),
      GridColumn(
        columnName: 'grade',
        label: _buildHeaderLabel('학년', tokens),
        width: 35,
      ),
      GridColumn(
        columnName: 'className',
        label: _buildHeaderLabel('반', tokens),
        width: 35,
      ),
      GridColumn(
        columnName: 'subject',
        label: _buildHeaderLabel('과목', tokens),
        width: 60,
      ),
      GridColumn(
        columnName: 'teacher',
        label: _buildHeaderLabel('교사', tokens),
        width: 60,
      ),
      GridColumn(
        columnName: 'supplementSubject',
        label: _buildHeaderLabel('과목', tokens),
        width: 60,
      ),
      GridColumn(
        columnName: 'supplementTeacher',
        label: _buildHeaderLabel('성명', tokens),
        width: 70,
      ),
      GridColumn(
        columnName: 'substitutionDate',
        label: _buildHeaderLabel('교체일', tokens),
        width: 60,
      ),
      GridColumn(
        columnName: 'substitutionDay',
        label: _buildHeaderLabel('요일', tokens),
        width: 35,
      ),
      GridColumn(
        columnName: 'substitutionPeriod',
        label: _buildHeaderLabel('교시', tokens),
        width: 35,
      ),
      GridColumn(
        columnName: 'substitutionSubject',
        label: _buildHeaderLabel('과목', tokens),
        width: 60,
      ),
      GridColumn(
        columnName: 'substitutionTeacher',
        label: _buildHeaderLabel('교사', tokens),
        width: 70,
      ),
      GridColumn(
        columnName: 'remarks',
        // 스택 헤더(1행)에만 '비고' 표시 — 2행은 빈 셀로 rowspan 효과
        label: _buildEmptySubHeaderLabel(tokens),
        width: 100,
      ),
    ];
  }

  /// 스택 헤더 정의
  static List<StackedHeaderRow> getStackedHeaders(DesignTokens tokens) {
    return [
      StackedHeaderRow(
        cells: [
          _buildMergedColumnStackedHeaderCell('select', '선택', tokens),
          _buildMergedColumnStackedHeaderCell('profile', '계획서', tokens),
          _buildStackedHeaderCell(
            [
              'absenceDate',
              'absenceDay',
              'period',
              'grade',
              'className',
              'subject',
              'teacher',
            ],
            '결강',
            tokens,
          ),
          _buildStackedHeaderCell(
            ['supplementSubject', 'supplementTeacher'],
            '보강/수업변경',
            tokens,
          ),
          _buildStackedHeaderCell(
            [
              'substitutionDate',
              'substitutionDay',
              'substitutionPeriod',
              'substitutionSubject',
              'substitutionTeacher',
            ],
            '수업 교체',
            tokens,
          ),
          _buildMergedColumnStackedHeaderCell('remarks', '비고', tokens),
        ],
      ),
    ];
  }

  /// 단일 열 스택 헤더 (1행에 텍스트, 2행은 빈 배경 — 가로선 없이 합쳐 보임)
  static StackedHeaderCell _buildMergedColumnStackedHeaderCell(
    String columnName,
    String text,
    DesignTokens tokens,
  ) {
    return StackedHeaderCell(
      columnNames: [columnName],
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.sectionBackground,
          border: Border(
            left: BorderSide(color: _headerBorderColor(tokens)),
            top: BorderSide(color: _headerBorderColor(tokens)),
            right: BorderSide(color: _headerBorderColor(tokens)),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: headerFontSize,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 헤더 레이블 위젯 생성
  static Widget _buildHeaderLabel(String text, DesignTokens tokens) {
    return Container(
      padding: headerPadding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border.all(color: _headerBorderColor(tokens)),
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

  /// 비고 2행 — 배경만 채움 (1행과 같은 색, 위쪽 테두리 없음)
  static Widget _buildEmptySubHeaderLabel(DesignTokens tokens) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border(
          left: BorderSide(color: _headerBorderColor(tokens)),
          right: BorderSide(color: _headerBorderColor(tokens)),
          bottom: BorderSide(color: _headerBorderColor(tokens)),
        ),
      ),
      child: const SizedBox.expand(),
    );
  }

  /// 스택 헤더 셀 위젯 생성
  static StackedHeaderCell _buildStackedHeaderCell(
    List<String> columnNames,
    String text,
    DesignTokens tokens,
  ) {
    return StackedHeaderCell(
      columnNames: columnNames,
      child: Container(
        padding: headerPadding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.sectionBackground,
          border: Border.all(color: _headerBorderColor(tokens)),
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
    bool Function(String groupId)? isSelected,
    ValueChanged<String>? onToggleSelect,
    List<PrintProfile> Function(String teacher)? profileOptions,
    String? Function(String groupId)? selectedProfileId,
    Function(String groupId, String? profileId)? onProfileChanged,
  }) {
    return switch (cell.columnName) {
      'select' => SelectCellRenderer.build(
        row,
        isSelected: isSelected,
        onToggle: onToggleSelect,
      ),
      'profile' => ProfileCellRenderer.build(
        row,
        optionsFor: profileOptions,
        selectedIdFor: selectedProfileId,
        onChanged: onProfileChanged,
      ),
      'absenceDate' ||
      'substitutionDate' => DateCellRenderer.build(cell, row, onDateCellTap),
      'supplementSubject' => SupplementSubjectCellRenderer.build(
        cell,
        row,
        onSupplementSubjectTap,
      ),
      _ => NormalCellRenderer.build(cell),
    };
  }
}

/// 선택(체크박스) 셀 렌더러 — 상태는 그룹(교체 건) 단위로 공유
class SelectCellRenderer {
  static Widget build(
    DataGridRow row, {
    required bool Function(String groupId)? isSelected,
    required ValueChanged<String>? onToggle,
  }) {
    final groupId = row.extractCellValue('_groupId');
    return Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: Checkbox(
          value: isSelected != null && groupId.isNotEmpty && isSelected(groupId),
          onChanged: (groupId.isEmpty || onToggle == null)
              ? null
              : (_) => onToggle(groupId),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// 계획서(인쇄 프로파일) 지정 셀 렌더러 — 해당 행 교사의 계획서만 표시
class ProfileCellRenderer {
  static Widget build(
    DataGridRow row, {
    required List<PrintProfile> Function(String teacher)? optionsFor,
    required String? Function(String groupId)? selectedIdFor,
    required Function(String groupId, String? profileId)? onChanged,
  }) {
    final groupId = row.extractCellValue('_groupId');
    final teacher = row.extractCellValue('teacher');
    final options = optionsFor != null ? optionsFor(teacher) : <PrintProfile>[];
    final selectedId = selectedIdFor != null ? selectedIdFor(groupId) : null;
    final hasSelection = options.any((p) => p.id == selectedId);

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: DropdownButton<String>(
        value: hasSelection ? selectedId : null,
        isDense: true,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: const Text(
          '미지정',
          style: TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
        items: options
            .map(
              (p) => DropdownMenuItem<String>(
                value: p.id,
                child: Text(
                  p.name,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged:
            groupId.isEmpty || onChanged == null
                ? null
                : (value) => onChanged(groupId, value),
      ),
    );
  }
}

/// 날짜 셀 렌더러
class DateCellRenderer {
  static Widget build(
    DataGridCell cell,
    DataGridRow row,
    Function(String, String)? onDateCellTap,
  ) {
    // 날짜 값을 월.일 형식으로 변환하여 표시
    final rawDate = cell.value?.toString() ?? '';
    final displayText = DateFormatUtils.toMonthDay(rawDate);
    bool isSelectable = false;

    if (cell.columnName == 'substitutionDate') {
      // 교체일 컬럼의 경우: 교체 교사가 있으면 항상 선택 가능
      final substitutionTeacher = row.extractCellValue('substitutionTeacher');
      isSelectable = substitutionTeacher.isNotEmpty;
    } else {
      // 다른 날짜 컬럼(결강일 등)의 경우: 항상 선택 가능
      isSelectable = true;
    }

    final isEmpty = displayText.isEmpty || displayText == '선택';

    return SelectableCellBuilder.build(
      isSelectable: isSelectable,
      isEmpty: isEmpty,
      displayText: displayText,
      onTap: () {
        AppLogger.exchangeDebug(
          '셀 클릭 - 컬럼: ${cell.columnName}, 값: ${cell.value}, 선택가능: $isSelectable',
        );

        if (!isSelectable) {
          AppLogger.exchangeDebug('교체일 선택 불가: 교체 교사가 없거나 이미 날짜가 설정됨');
          return;
        }

        if (onDateCellTap != null) {
          // exchangeId를 Extension 메서드로 추출
          final exchangeId = row.extractCellValue('_exchangeId');

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
    );
  }
}

/// 보강 과목 셀 렌더러
class SupplementSubjectCellRenderer {
  static Widget build(
    DataGridCell cell,
    DataGridRow row,
    Function(String)? onSupplementSubjectTap,
  ) {
    final value = (cell.value?.toString() ?? '').trim();
    final isEmpty = value.isEmpty;

    // exchangeId와 보강 교사명 추출 (Extension 메서드 사용)
    final exchangeId = row.extractCellValue('_exchangeId');
    final supplementTeacher = row.extractCellValue('supplementTeacher');
    final hasTeacher = supplementTeacher.isNotEmpty;

    // 보강 교사명이 있으면 항상 활성화 (과목이 있어도 재선택 가능)
    final isSelectable = hasTeacher;

    // 표시 텍스트 결정
    final displayText = isEmpty ? (hasTeacher ? '과목선택' : '') : value;

    return SelectableCellBuilder.build(
      isSelectable: isSelectable,
      isEmpty: isEmpty,
      displayText: displayText,
      onTap: () async {
        if (exchangeId.isEmpty || !isSelectable) return;
        if (onSupplementSubjectTap != null) {
          onSupplementSubjectTap(exchangeId);
        }
      },
    );
  }
}

/// 일반 셀 렌더러
class NormalCellRenderer {
  static Widget build(DataGridCell cell) {
    return Container(
      alignment: Alignment.center,
      padding: ContentInputGridConfig.cellPadding,
      child: Text(
        cell.value?.toString() ?? '',
        style: const TextStyle(
          fontSize: ContentInputGridConfig.cellFontSize,
          height: 1.0,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// 디버그 유틸리티 클래스 (production 빌드에서 제거 가능)
class ContentInputGridDebugger {
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
      'absenceDate',
      'absenceDay',
      'period',
      'grade',
      'className',
      'subject',
      'teacher',
      'supplementSubject',
      'supplementTeacher',
      'substitutionDate',
      'substitutionDay',
      'substitutionPeriod',
      'substitutionSubject',
      'substitutionTeacher',
      'remarks',
      'groupId',
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

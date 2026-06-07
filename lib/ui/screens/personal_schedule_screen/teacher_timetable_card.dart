import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../models/time_slot.dart';
import '../../../utils/personal_exchange_info_extractor.dart';
import '../../../utils/personal_timetable_helper.dart';
import '../../../ui/widgets/timetable_grid/grid_scaling_helper.dart';
import '../../../ui/widgets/timetable_grid/timetable_grid_constants.dart';
import 'personal_timetable_datasource.dart';
import 'teacher_card_grid_constants.dart';

/// 저장된 교사 1명의 주간 시간표를 카드 형태로 표시합니다.
///
/// - 카드 헤더: 교사명 (+ 담당 과목)
/// - 카드 본문: 교시 × 요일 미니 [SfDataGrid]
class TeacherTimetableCard extends StatefulWidget {
  final String teacherName;
  final String? subject;
  final String? roleLabel;
  final String? dateStatusMessage;
  final List<TimeSlot> timeSlots;
  final List<DateTime> weekDates;
  final double zoomFactor;
  final List<ExchangeCellInfo> exchangeInfoList;
  final bool isExchangeViewEnabled;

  /// 설정에 저장된 '내 교사' 여부 — 강조 테두리 표시
  final bool isHighlighted;

  const TeacherTimetableCard({
    super.key,
    required this.teacherName,
    this.subject,
    this.roleLabel,
    this.dateStatusMessage,
    required this.timeSlots,
    required this.weekDates,
    required this.zoomFactor,
    required this.exchangeInfoList,
    required this.isExchangeViewEnabled,
    this.isHighlighted = true,
  });

  @override
  State<TeacherTimetableCard> createState() => _TeacherTimetableCardState();
}

class _TeacherTimetableCardState extends State<TeacherTimetableCard> {
  PersonalTimetableDataSource? _dataSource;
  int _lastRowCount = 0;

  @override
  Widget build(BuildContext context) {
    final result = PersonalTimetableHelper.convertToPersonalTimetableData(
      widget.timeSlots,
      widget.teacherName,
      widget.weekDates,
      zoomFactor: widget.zoomFactor,
    );

    _ensureDataSource(result.rows);

    final scaledColumns =
        GridScalingHelper.scaleColumns(result.columns, widget.zoomFactor);
    final scaledStackedHeaders = GridScalingHelper.scaleStackedHeaders(
      result.stackedHeaders,
      widget.zoomFactor,
    );

    final headerHeight =
        GridScalingHelper.scaleHeaderHeight(widget.zoomFactor) *
        TeacherCardGridConstants.personalTimetableSizeMultiplier;
    final rowHeight =
        GridScalingHelper.scaleRowHeight(widget.zoomFactor) *
        TeacherCardGridConstants.personalTimetableSizeMultiplier;

    // 스택 헤더(날짜) + 컬럼 헤더(요일) + 데이터 행
    final gridHeight =
        headerHeight * (scaledStackedHeaders.length + 1) +
        rowHeight * result.rows.length;

    final gridWidth = scaledColumns.fold<double>(
      0,
      (sum, column) => sum + column.width,
    );

    final cardWidth = gridWidth.clamp(
      200.0,
      TeacherCardGridConstants.maxCardWidth,
    );

    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          TeacherCardGridConstants.cardBorderRadius,
        ),
        side: widget.isHighlighted
            ? BorderSide(color: highlightColor, width: 1.5)
            : BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: cardWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCardHeader(context, highlightColor),
            SizedBox(
              height: gridHeight,
              child: Theme(
                data: theme.copyWith(
                  textTheme: theme.textTheme.copyWith(
                    bodyMedium: TextStyle(
                      fontSize:
                          GridLayoutConstants.baseFontSize * widget.zoomFactor,
                    ),
                    bodySmall: TextStyle(
                      fontSize:
                          GridLayoutConstants.baseFontSize * widget.zoomFactor,
                    ),
                    titleMedium: TextStyle(
                      fontSize:
                          GridLayoutConstants.baseFontSize * widget.zoomFactor,
                    ),
                    labelMedium: TextStyle(
                      fontSize:
                          GridLayoutConstants.baseFontSize * widget.zoomFactor,
                    ),
                    labelLarge: TextStyle(
                      fontSize:
                          GridLayoutConstants.baseFontSize * widget.zoomFactor,
                    ),
                    labelSmall: TextStyle(
                      fontSize:
                          GridLayoutConstants.baseFontSize * widget.zoomFactor,
                    ),
                  ),
                ),
                child: SfDataGrid(
                  source: _dataSource!,
                  columns: scaledColumns,
                  stackedHeaderRows: scaledStackedHeaders,
                  gridLinesVisibility: GridLinesVisibility.both,
                  headerGridLinesVisibility: GridLinesVisibility.both,
                  allowSorting: false,
                  allowTriStateSorting: false,
                  columnWidthMode: ColumnWidthMode.none,
                  headerRowHeight: headerHeight,
                  rowHeight: rowHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// DataSource를 생성하거나 행 수 변경 시 재생성, 그 외에는 갱신만 합니다.
  void _ensureDataSource(List<DataGridRow> rows) {
    if (_dataSource == null || _lastRowCount != rows.length) {
      _dataSource = PersonalTimetableDataSource(
        rows: rows,
        exchangeInfoList: widget.exchangeInfoList,
        isExchangeViewEnabled: widget.isExchangeViewEnabled,
      );
      _lastRowCount = rows.length;
      return;
    }

    _dataSource!.updateRows(
      rows,
      exchangeInfoList: widget.exchangeInfoList,
      isExchangeViewEnabled: widget.isExchangeViewEnabled,
    );
  }

  /// 카드 상단 — 교사명·담당 과목
  Widget _buildCardHeader(BuildContext context, Color highlightColor) {
    final subject = widget.subject?.trim();
    final hasSubject = subject != null && subject.isNotEmpty;
    final roleLabel = widget.roleLabel?.trim();
    final hasRoleLabel = roleLabel != null && roleLabel.isNotEmpty;
    final dateStatusMessage = widget.dateStatusMessage?.trim();
    final hasDateStatusMessage =
        dateStatusMessage != null && dateStatusMessage.isNotEmpty;

    return Container(
      height: TeacherCardGridConstants.cardHeaderHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: TeacherCardGridConstants.cardInnerPadding,
      ),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? highlightColor.withValues(alpha: 0.08)
            : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person,
            size: 16,
            color: widget.isHighlighted ? highlightColor : Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.teacherName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isHighlighted
                          ? highlightColor
                          : Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasDateStatusMessage) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      dateStatusMessage,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasSubject) ...[
            const SizedBox(width: 4),
            Text(
              subject,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (hasRoleLabel) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

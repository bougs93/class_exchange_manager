import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../models/time_slot.dart';
import '../../../utils/personal_exchange_info_extractor.dart';
import '../../../utils/personal_timetable_helper.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/widget_image_clipboard_helper.dart';
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
  /// 카드 전체(헤더+표)를 이미지로 캡처할 때 사용합니다.
  final GlobalKey _captureKey = GlobalKey();

  PersonalTimetableDataSource? _dataSource;
  int _lastRowCount = 0;
  bool _isCopyingImage = false;

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
    final borderRadius = BorderRadius.circular(
      TeacherCardGridConstants.cardBorderRadius,
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: widget.isHighlighted
          ? BorderSide(color: highlightColor, width: 1.5)
          : BorderSide(color: Colors.grey.shade300),
    );

    // 그림자는 RepaintBoundary 밖 — 이미지 복사 시 검정 테두리(그림자) 제외
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RepaintBoundary(
            key: _captureKey,
            // 둥근 모서리 바깥 영역을 흰색으로 채워 캡처 시 투명(검정) 픽셀 방지
            child: ColoredBox(
              color: Colors.white,
              child: Material(
                color: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                shape: cardShape,
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 복사 버튼은 캡처 영역 밖(Stack)에 배치
                      _buildCardHeader(context, highlightColor),
                SizedBox(
                  height: gridHeight,
                  child: Theme(
                    data: theme.copyWith(
                      textTheme: theme.textTheme.copyWith(
                        bodyMedium: TextStyle(
                          fontSize:
                              GridLayoutConstants.baseFontSize *
                              widget.zoomFactor,
                        ),
                        bodySmall: TextStyle(
                          fontSize:
                              GridLayoutConstants.baseFontSize *
                              widget.zoomFactor,
                        ),
                        titleMedium: TextStyle(
                          fontSize:
                              GridLayoutConstants.baseFontSize *
                              widget.zoomFactor,
                        ),
                        labelMedium: TextStyle(
                          fontSize:
                              GridLayoutConstants.baseFontSize *
                              widget.zoomFactor,
                        ),
                        labelLarge: TextStyle(
                          fontSize:
                              GridLayoutConstants.baseFontSize *
                              widget.zoomFactor,
                        ),
                        labelSmall: TextStyle(
                          fontSize:
                              GridLayoutConstants.baseFontSize *
                              widget.zoomFactor,
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
              ),
            ),
          ),
          // 이미지 복사 버튼 — 화면에만 표시, 캡처 이미지에는 포함하지 않음
          Positioned(
            top:
                (TeacherCardGridConstants.cardHeaderHeight -
                    TeacherCardGridConstants.copyButtonReserveWidth) /
                2,
            right: TeacherCardGridConstants.cardInnerPadding,
            child: _buildCopyImageButton(highlightColor),
          ),
        ],
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
          // 교사명 + 교체·보강·날짜 미지정 — 왼쪽 우선 배치
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
                if (hasRoleLabel) ...[
                  const SizedBox(width: 6),
                  _buildRoleBadge(roleLabel),
                ],
                if (hasDateStatusMessage) ...[
                  const SizedBox(width: 6),
                  _buildDateStatusBadge(dateStatusMessage),
                ],
              ],
            ),
          ),
          if (hasSubject) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                subject,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
          // 오른쪽 이미지 복사 버튼과 겹치지 않도록 여백 확보
          const SizedBox(width: TeacherCardGridConstants.copyButtonReserveWidth),
        ],
      ),
    );
  }

  /// 교체·보강 역할 뱃지 (교사명 바로 옆)
  Widget _buildRoleBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.orange.shade800,
        ),
      ),
    );
  }

  /// 날짜 미지정 안내 뱃지
  Widget _buildDateStatusBadge(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.red.shade700,
        ),
      ),
    );
  }

  /// 시간표 카드를 이미지로 클립보드에 복사하는 버튼
  Widget _buildCopyImageButton(Color highlightColor) {
    return Tooltip(
      message: '이미지로 복사',
      child: InkWell(
        onTap: _isCopyingImage ? null : _copyCardAsImage,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _isCopyingImage
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: highlightColor,
                  ),
                )
              : Icon(
                  Icons.image_outlined,
                  size: 16,
                  color: highlightColor,
                ),
        ),
      ),
    );
  }

  /// 카드(헤더+시간표)를 PNG로 캡처해 클립보드에 저장합니다.
  Future<void> _copyCardAsImage() async {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(2.0, 3.0);
    setState(() => _isCopyingImage = true);

    try {
      // 그리드 페인트가 끝난 뒤 캡처합니다.
      await WidgetsBinding.instance.endOfFrame;
      final copied = await WidgetImageClipboardHelper.copyWidgetToClipboard(
        _captureKey,
        pixelRatio: pixelRatio,
      );

      if (!mounted) return;

      if (copied) {
        SnackBarHelper.showSuccess(
          context,
          '${widget.teacherName} 시간표가 클립보드에 복사되었습니다.',
        );
      } else {
        SnackBarHelper.showError(context, '이미지 캡처에 실패했습니다.');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, '이미지 복사 중 오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCopyingImage = false);
      }
    }
  }
}

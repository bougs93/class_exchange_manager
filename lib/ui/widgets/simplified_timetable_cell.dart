import 'package:flutter/material.dart';
import '../../constants/cell_status_tooltips.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../../utils/cell_style_config.dart';
import 'cell_status_border_overlay.dart';
import 'plain_timetable_cell_painter.dart';
import 'exchanged_cell_status_overlay.dart';

/// 단순화된 시간표 셀 위젯
///
/// 성능 주의: 화면에 동시에 뜨는 셀이 수백 개이므로 `ConsumerWidget`으로
/// 두면 셀마다 Provider 구독이 생겨 웹에서 눈에 띄게 느려진다.
/// 상태 심볼 표시 여부는 `TimetableDataSource`가 한 번만 읽어 넘겨준다.
class SimplifiedTimetableCell extends StatelessWidget {
  final String content;
  final bool isTeacherColumn;
  final bool isSelected;
  final bool isExchangeable;
  final bool isLastColumnOfDay;
  final bool isFirstColumnOfDay;
  final bool isHeader;
  final bool isInCircularPath; // 순환교체 경로에 포함된 셀인지 여부
  final int? circularPathStep; // 순환교체 경로에서의 단계 (1, 2, 3...)
  final bool isInSelectedPath; // 선택된 경로에 포함된 셀인지 여부 (1:1 교체 모드)
  final bool isInDualPath; // 2중교체 경로에 포함된 셀인지 여부
  final int? pathStepNumber; // 셀 모서리에 표시할 단계 번호 (1:1·2중 공통)
  final bool isTargetCell; // 타겟 셀인지 여부 (교체 대상의 같은 행 셀)
  final bool isNonExchangeable; // 교체불가 셀인지 여부
  final bool isExchangedSourceCell; // 교체된 소스 셀인지 여부
  final bool isExchangedDestinationCell; // 교체된 목적지 셀인지 여부
  final String? overlayDate; // "?" 툴팁용. 날짜 글자 자체는 그리드 위 층에 그린다.
  final bool isTeacherNameSelected; // 교사 이름 선택 상태 (새로 추가)
  final bool isHighlightedTeacher; // 하이라이트된 교사 행인지 여부 (새로 추가)
  final bool showStatusSymbols; // X·O 상태 오버레이 표시 여부 (데이터소스가 주입)
  final VoidCallback? onTap;

  const SimplifiedTimetableCell({
    super.key,
    required this.content,
    required this.isTeacherColumn,
    required this.isSelected,
    required this.isExchangeable,
    this.isLastColumnOfDay = false,
    this.isFirstColumnOfDay = false,
    this.isHeader = false,
    this.isInCircularPath = false,
    this.circularPathStep,
    this.isInSelectedPath = false,
    this.isInDualPath = false,
    this.pathStepNumber,
    this.isTargetCell = false,
    this.isNonExchangeable = false,
    this.isExchangedSourceCell = false, // 교체된 소스 셀 기본값은 false
    this.isExchangedDestinationCell = false, // 교체된 목적지 셀 기본값은 false
    this.overlayDate,
    this.isTeacherNameSelected = false, // 교사 이름 선택 상태 기본값은 false
    this.isHighlightedTeacher = false, // 하이라이트된 교사 행 기본값은 false
    this.showStatusSymbols = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = SimplifiedTimetableTheme.getCellStyleFromConfig(
      CellStyleConfig(
        isTeacherColumn: isTeacherColumn,
        isSelected: isSelected,
        isExchangeable: isExchangeable,
        isLastColumnOfDay: isLastColumnOfDay,
        isFirstColumnOfDay: isFirstColumnOfDay,
        isHeader: isHeader,
        isInCircularPath: isInCircularPath,
        circularPathStep: circularPathStep,
        isInSelectedPath: isInSelectedPath,
        isInDualPath: isInDualPath,
        pathStepNumber: pathStepNumber,
        isTargetCell: isTargetCell,
        isNonExchangeable: isNonExchangeable,
        isExchangedSourceCell: isExchangedSourceCell,
        isExchangedDestinationCell: isExchangedDestinationCell,
        isTeacherNameSelected: isTeacherNameSelected, // 새로 추가
        isHighlightedTeacher: isHighlightedTeacher, // 새로 추가
      ),
    );

    // 디버깅을 위한 로그 (리빌드로 인한 중복 출력 방지를 위해 제거)
    // Flutter의 위젯 리빌드 메커니즘으로 인해 build() 메서드가 여러 번 호출되어
    // 로그가 반복 출력되는 것을 방지하기 위해 주석 처리
    // if (isSelected) {
    //   AppLogger.exchangeDebug('선택된 셀 렌더링: $content, 교사열=$isTeacherColumn, 선택됨=$isSelected');
    // }

    // 빠진 수업·맡은 수업·교체 불가 수업 셀에만 툴팁을 표시합니다.
    final baseTooltipMessage = CellStatusTooltips.forCellState(
      isTeacherColumn: isTeacherColumn,
      isHeader: isHeader,
      isNonExchangeable: isNonExchangeable,
      isExchangedSourceCell: isExchangedSourceCell,
      isExchangedDestinationCell: isExchangedDestinationCell,
    );

    // "?" 꼬리표(S1.10, 순환·2중 교체의 날짜 미확정 표시)는 무엇인지 툴팁으로 설명한다.
    final tooltipMessage =
        overlayDate == '?' && baseTooltipMessage != null
            ? '$baseTooltipMessage\n순환/2중 교체는 노드별 날짜가 저장되지 않아 결강일 주에 표시합니다.'
            : baseTooltipMessage;

    final bool hasNonExchangeableSymbol =
        showStatusSymbols && isNonExchangeable;
    final bool hasSourceSymbol = showStatusSymbols && isExchangedSourceCell;
    final bool hasDestinationSymbol =
        showStatusSymbols && isExchangedDestinationCell;
    final bool hasOverlay =
        style.statusBorder != null ||
        style.overlayWidget != null ||
        hasNonExchangeableSymbol ||
        hasSourceSymbol ||
        hasDestinationSymbol;

    // 성능: 한 화면에 셀이 1000개 넘게 뜨므로 셀 하나의 렌더 오브젝트 수가
    // 그대로 스크롤 비용이 된다.
    //
    // 오버레이도 툴팁도 없는 "평범한" 셀(대부분)은 위젯을 쌓는 대신
    // 캔버스에 직접 그려 렌더 오브젝트를 4개 → 1개로 줄인다.
    // 그리는 내용은 아래 위젯 트리와 동일하다(PlainTimetableCellPainter 주석 참고).
    if (!hasOverlay && tooltipMessage == null && onTap == null) {
      return CustomPaint(
        size: Size.infinite,
        painter: PlainTimetableCellPainter(
          content: content,
          backgroundColor: style.backgroundColor,
          textStyle: style.textStyle,
          border: style.border,
        ),
      );
    }

    // 나머지(오버레이·툴팁이 있는 특수 셀)는 기존 위젯 트리를 그대로 쓴다.
    // - onTap은 보통 쓰이지 않는다(탭은 SfDataGrid.onCellTap이 처리) → 있을 때만 감싼다
    // - Container 대신 DecoratedBox (ConstrainedBox·Align 래퍼 제거)
    // 모든 오버레이는 Positioned.fill 계열이라 레이아웃 결과는 동일하다.

    // 기본 셀 내용 — FittedBox로 좁은 셀에서도 글자 잘림 방지
    Widget content0 = Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          content,
          style: style.textStyle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.clip,
        ),
      ),
    );

    if (hasOverlay) {
      content0 = Stack(
        children: [
          content0,
          // 상태 강조 테두리 (레이아웃 밖 오버레이)
          if (style.statusBorder != null)
            CellStatusBorderOverlay(border: style.statusBorder!),
          // 빠진 수업(X)·맡은 수업(O)·교체 불가(X) 반투명 오버레이
          if (hasNonExchangeableSymbol)
            const ExchangedCellStatusOverlay(
              type: CellStatusSymbolType.nonExchangeable,
            ),
          if (hasSourceSymbol)
            const ExchangedCellStatusOverlay(
              type: CellStatusSymbolType.missedClass,
            ),
          if (hasDestinationSymbol)
            const ExchangedCellStatusOverlay(
              type: CellStatusSymbolType.takenClass,
            ),
          // 테마에서 제공하는 오버레이 위젯 (교체 가능한 셀에 숫자 1 표시)
          if (style.overlayWidget != null) style.overlayWidget!,
          // 날짜 꼬리표는 셀 안이 아니라 그리드 위 층에 그린다.
          // 여기 값은 "?" 툴팁에만 쓴다.
        ],
      );
    }

    Widget cellBody = DecoratedBox(
      decoration: BoxDecoration(
        color: style.backgroundColor,
        border: style.border,
      ),
      child: content0,
    );

    if (onTap != null) {
      cellBody = GestureDetector(onTap: onTap, child: cellBody);
    }

    if (tooltipMessage == null) {
      return cellBody;
    }

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 300),
      child: cellBody,
    );
  }
}

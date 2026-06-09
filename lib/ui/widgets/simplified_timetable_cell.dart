import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/cell_status_tooltips.dart';
import '../../providers/cell_status_symbol_visibility_provider.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../../utils/cell_style_config.dart';
import 'cell_status_border_overlay.dart';
import 'exchanged_cell_status_overlay.dart';

/// 단순화된 시간표 셀 위젯
class SimplifiedTimetableCell extends ConsumerWidget {
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
  final int? dualPathStep; // 2중교체 경로에서의 단계 (1, 2)
  final bool isTargetCell; // 타겟 셀인지 여부 (교체 대상의 같은 행 셀)
  final bool isNonExchangeable; // 교체불가 셀인지 여부
  final bool isExchangedSourceCell; // 교체된 소스 셀인지 여부
  final bool isExchangedDestinationCell; // 교체된 목적지 셀인지 여부
  final bool isTeacherNameSelected; // 교사 이름 선택 상태 (새로 추가)
  final bool isHighlightedTeacher; // 하이라이트된 교사 행인지 여부 (새로 추가)
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
    this.dualPathStep,
    this.isTargetCell = false,
    this.isNonExchangeable = false,
    this.isExchangedSourceCell = false, // 교체된 소스 셀 기본값은 false
    this.isExchangedDestinationCell = false, // 교체된 목적지 셀 기본값은 false
    this.isTeacherNameSelected = false, // 교사 이름 선택 상태 기본값은 false
    this.isHighlightedTeacher = false, // 하이라이트된 교사 행 기본값은 false
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showStatusSymbols = ref.watch(cellStatusSymbolVisibilityProvider);

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
        dualPathStep: dualPathStep,
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

    // 셀 전체 영역에서 마우스 호버가 감지되도록 크기를 채웁니다.
    final cellBody = GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.backgroundColor,
          border: style.border,
        ),
        child: Stack(
          children: [
            // 기본 셀 내용 — FittedBox로 좁은 셀에서도 글자 잘림 방지
            Center(
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
            ),
            // 상태 강조 테두리 (레이아웃 밖 오버레이)
            if (style.statusBorder != null)
              CellStatusBorderOverlay(border: style.statusBorder!),
            // 빠진 수업(X)·맡은 수업(O)·교체 불가(X) 반투명 오버레이
            if (showStatusSymbols && isNonExchangeable)
              const ExchangedCellStatusOverlay(
                type: CellStatusSymbolType.nonExchangeable,
              ),
            if (showStatusSymbols && isExchangedSourceCell)
              const ExchangedCellStatusOverlay(
                type: CellStatusSymbolType.missedClass,
              ),
            if (showStatusSymbols && isExchangedDestinationCell)
              const ExchangedCellStatusOverlay(
                type: CellStatusSymbolType.takenClass,
              ),
            // 테마에서 제공하는 오버레이 위젯 (교체 가능한 셀에 숫자 1 표시)
            if (style.overlayWidget != null) style.overlayWidget!,
          ],
        ),
      ),
    );

    // 빠진 수업·맡은 수업·교체 불가 수업 셀에만 툴팁을 표시합니다.
    final tooltipMessage = CellStatusTooltips.forCellState(
      isTeacherColumn: isTeacherColumn,
      isHeader: isHeader,
      isNonExchangeable: isNonExchangeable,
      isExchangedSourceCell: isExchangedSourceCell,
      isExchangedDestinationCell: isExchangedDestinationCell,
    );

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

import 'package:flutter/material.dart';
import '../../utils/simplified_timetable_theme.dart';

/// 단순화된 시간표 셀 위젯
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
  final bool isInChainPath; // 연쇄교체 경로에 포함된 셀인지 여부
  final int? chainPathStep; // 연쇄교체 경로에서의 단계 (1, 2)
  final bool isTargetCell; // 타겟 셀인지 여부 (교체 대상의 같은 행 셀)
  final bool isNonExchangeable; // 교체불가 셀인지 여부
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
    this.isInChainPath = false,
    this.chainPathStep,
    this.isTargetCell = false,
    this.isNonExchangeable = false,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final style = SimplifiedTimetableTheme.getCellStyle(
      isTeacherColumn: isTeacherColumn,
      isSelected: isSelected,
      isExchangeable: isExchangeable,
      isLastColumnOfDay: isLastColumnOfDay,
      isFirstColumnOfDay: isFirstColumnOfDay,
      isHeader: isHeader,
      isInCircularPath: isInCircularPath,
      circularPathStep: circularPathStep,
      isInSelectedPath: isInSelectedPath,
      isInChainPath: isInChainPath,
      chainPathStep: chainPathStep,
      isTargetCell: isTargetCell, // 타겟 셀 정보 전달
      isNonExchangeable: isNonExchangeable, // 교체불가 셀 정보 전달
    );
    
    // 디버깅을 위한 로그 (리빌드로 인한 중복 출력 방지를 위해 제거)
    // Flutter의 위젯 리빌드 메커니즘으로 인해 build() 메서드가 여러 번 호출되어
    // 로그가 반복 출력되는 것을 방지하기 위해 주석 처리
    // if (isSelected) {
    //   AppLogger.exchangeDebug('선택된 셀 렌더링: $content, 교사열=$isTeacherColumn, 선택됨=$isSelected');
    // }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.backgroundColor,
          border: style.border,
        ),
        child: Stack(
          children: [
            // 기본 셀 내용
            Center(
              child: Text(
                content,
                style: style.textStyle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 테마에서 제공하는 오버레이 위젯 (교체 가능한 셀에 숫자 1 표시)
            if (style.overlayWidget != null) style.overlayWidget!,
          ],
        ),
      ),
    );
  }
}

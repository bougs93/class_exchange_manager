import 'package:flutter/material.dart';
import '../../utils/simplified_timetable_theme.dart';
import '../../utils/logger.dart';

/// 단순화된 시간표 셀 위젯
class SimplifiedTimetableCell extends StatelessWidget {
  final String content;
  final bool isTeacherColumn;
  final bool isSelected;
  final bool isExchangeable;
  final bool isLastColumnOfDay;
  final bool isHeader;
  final bool isInCircularPath; // 순환교체 경로에 포함된 셀인지 여부
  final VoidCallback? onTap;
  
  const SimplifiedTimetableCell({
    super.key,
    required this.content,
    required this.isTeacherColumn,
    required this.isSelected,
    required this.isExchangeable,
    this.isLastColumnOfDay = false,
    this.isHeader = false,
    this.isInCircularPath = false,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final style = SimplifiedTimetableTheme.getCellStyle(
      isTeacherColumn: isTeacherColumn,
      isSelected: isSelected,
      isExchangeable: isExchangeable,
      isLastColumnOfDay: isLastColumnOfDay,
      isHeader: isHeader,
      isInCircularPath: isInCircularPath,
    );
    
    // 디버깅을 위한 로그
    if (isSelected) {
      AppLogger.exchangeDebug('선택된 셀 렌더링: $content, 교사열=$isTeacherColumn, 선택됨=$isSelected');
    }
    
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

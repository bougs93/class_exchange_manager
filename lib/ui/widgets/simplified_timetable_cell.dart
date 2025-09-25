import 'package:flutter/material.dart';
import '../../utils/simplified_timetable_theme.dart';

/// 단순화된 시간표 셀 위젯
class SimplifiedTimetableCell extends StatelessWidget {
  final String content;
  final bool isTeacherColumn;
  final bool isSelected;
  final bool isExchangeable;
  final bool isLastColumnOfDay;
  final bool isHeader;
  final VoidCallback? onTap;
  
  const SimplifiedTimetableCell({
    super.key,
    required this.content,
    required this.isTeacherColumn,
    required this.isSelected,
    required this.isExchangeable,
    this.isLastColumnOfDay = false,
    this.isHeader = false,
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
    );
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.backgroundColor,
          border: style.border,
        ),
        child: Text(
          content,
          style: style.textStyle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

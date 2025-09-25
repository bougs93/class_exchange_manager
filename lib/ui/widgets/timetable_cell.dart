import 'package:flutter/material.dart';
import '../../utils/timetable_theme.dart';

/// 시간표 셀을 표시하는 재사용 가능한 위젯
class TimetableCell extends StatelessWidget {
  final String content;
  final CellState state;
  final bool isTeacherColumn;
  final bool isLastColumnOfDay;
  final VoidCallback? onTap;
  
  const TimetableCell({
    super.key,
    required this.content,
    required this.state,
    required this.isTeacherColumn,
    this.isLastColumnOfDay = false,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TimetableTheme.getCellColor(
            state: state,
            isTeacherColumn: isTeacherColumn,
          ),
          border: TimetableTheme.getBorder(
            isTeacherColumn: isTeacherColumn,
            isLastColumnOfDay: isLastColumnOfDay,
            state: state,
          ),
        ),
        child: Text(
          content,
          style: TimetableTheme.getTextStyle(
            state: state,
            isHeader: false,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
  
}

/// 시간표 헤더 셀을 표시하는 위젯
class TimetableHeaderCell extends StatelessWidget {
  final String content;
  final CellState state;
  final bool isLastColumnOfDay;
  
  const TimetableHeaderCell({
    super.key,
    required this.content,
    required this.state,
    this.isLastColumnOfDay = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final headerStyle = TimetableTheme.getHeaderStyle(
      state: state,
      isLastColumnOfDay: isLastColumnOfDay,
    );
    
    return Container(
      padding: EdgeInsets.zero,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: headerStyle.backgroundColor,
        border: headerStyle.border,
      ),
      child: Text(
        content,
        style: headerStyle.textStyle,
        textAlign: TextAlign.center,
      ),
    );
  }
}

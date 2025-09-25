import 'package:flutter/material.dart';
import '../../utils/simplified_timetable_theme.dart';

/// 시간표 셀을 표시하는 재사용 가능한 위젯
class TimetableCell extends StatelessWidget {
  final String content;
  final bool isSelected;
  final bool isExchangeable;
  final bool isTeacherColumn;
  final bool isLastColumnOfDay;
  final VoidCallback? onTap;
  
  const TimetableCell({
    super.key,
    required this.content,
    required this.isSelected,
    required this.isExchangeable,
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
          color: _getCellColor(isTeacherColumn),
          border: _getBorder(isTeacherColumn, isLastColumnOfDay),
        ),
        child: Text(
          content,
          style: _getTextStyle(false),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
  
  /// 셀 배경색 결정
  Color _getCellColor(bool isTeacherColumn) {
    return SimplifiedTimetableTheme.getCellStyle(
      isTeacherColumn: isTeacherColumn,
      isSelected: isSelected,
      isExchangeable: isExchangeable,
      isLastColumnOfDay: false,
    ).backgroundColor;
  }
  
  /// 셀 테두리 결정
  Border _getBorder(bool isTeacherColumn, bool isLastColumnOfDay) {
    return SimplifiedTimetableTheme.getCellStyle(
      isTeacherColumn: isTeacherColumn,
      isSelected: isSelected,
      isExchangeable: isExchangeable,
      isLastColumnOfDay: isLastColumnOfDay,
    ).border;
  }
  
  /// 텍스트 스타일 결정
  TextStyle _getTextStyle(bool isHeader) {
    return SimplifiedTimetableTheme.getCellStyle(
      isTeacherColumn: false,
      isSelected: isSelected,
      isExchangeable: isExchangeable,
      isLastColumnOfDay: false,
      isHeader: isHeader,
    ).textStyle;
  }
}

/// 시간표 헤더 셀을 표시하는 위젯
class TimetableHeaderCell extends StatelessWidget {
  final String content;
  final bool isSelected;
  final bool isExchangeable;
  final bool isLastColumnOfDay;
  
  const TimetableHeaderCell({
    super.key,
    required this.content,
    required this.isSelected,
    required this.isExchangeable,
    this.isLastColumnOfDay = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _getCellColor(false),
        border: _getBorder(false, isLastColumnOfDay),
      ),
      child: Text(
        content,
        style: _getTextStyle(true),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  /// 셀 배경색 결정
  Color _getCellColor(bool isTeacherColumn) {
    return SimplifiedTimetableTheme.getCellStyle(
      isTeacherColumn: isTeacherColumn,
      isSelected: isSelected,
      isExchangeable: isExchangeable,
      isLastColumnOfDay: false,
    ).backgroundColor;
  }
  
  /// 셀 테두리 결정
  Border _getBorder(bool isTeacherColumn, bool isLastColumnOfDay) {
    return SimplifiedTimetableTheme.getCellStyle(
      isTeacherColumn: isTeacherColumn,
      isSelected: isSelected,
      isExchangeable: isExchangeable,
      isLastColumnOfDay: isLastColumnOfDay,
    ).border;
  }
  
  /// 텍스트 스타일 결정
  TextStyle _getTextStyle(bool isHeader) {
    return SimplifiedTimetableTheme.getCellStyle(
      isTeacherColumn: false,
      isSelected: isSelected,
      isExchangeable: isExchangeable,
      isLastColumnOfDay: false,
      isHeader: isHeader,
    ).textStyle;
  }
}

import 'package:flutter/material.dart';
import 'constants.dart';
import 'simplified_timetable_theme.dart';

/// 시간표 관련 모든 스타일을 통합 관리하는 클래스
class TimetableTheme {
  // 색상 정의 (SimplifiedTimetableTheme 참조)
  static const Color selectedColor = Colors.blue;
  static const Color exchangeableColor = Colors.green;
  static const Color defaultColor = SimplifiedTimetableTheme.defaultColor;
  static const Color teacherHeaderColor = SimplifiedTimetableTheme.teacherHeaderColor;
  static const Color periodHeaderColor = Color(0xFFFAFAFA);
  
  // 색상 변형 정의 (SimplifiedTimetableTheme 참조)
  static const Color selectedColorLight = SimplifiedTimetableTheme.selectedColorLight;
  static const Color exchangeableColorLight = SimplifiedTimetableTheme.exchangeableColorLight;
  static const Color selectedColorDark = SimplifiedTimetableTheme.selectedColorDark;
  static const Color exchangeableColorDark = Color(0xFF388E3C); // green.shade700
  static const Color exchangeableColorMedium = Color(0xFF66BB6A); // green.shade400
  
  /// 셀 상태별 배경색 결정 (단순화)
  static Color getCellColor({
    required CellState state,
    required bool isTeacherColumn,
  }) {
    switch (state) {
      case CellState.selected:
        return selectedColorLight;
      case CellState.exchangeable:
        return exchangeableColorLight;
      case CellState.normal:
        return isTeacherColumn ? teacherHeaderColor : defaultColor;
    }
  }
  
  /// 텍스트 스타일 결정 (단순화)
  static TextStyle getTextStyle({
    required CellState state,
    required bool isHeader,
  }) {
    return TextStyle(
      fontSize: isHeader ? AppConstants.headerFontSize : AppConstants.dataFontSize,
      fontWeight: state == CellState.selected ? FontWeight.bold : FontWeight.normal,
      color: state == CellState.selected ? selectedColorDark : Colors.black,
      height: AppConstants.dataLineHeight,
    );
  }
  
  /// 테두리 스타일 결정 (단순화)
  static Border getBorder({
    required bool isTeacherColumn,
    required bool isLastColumnOfDay,
    CellState state = CellState.normal,
  }) {
    // 일반 셀의 경우 기존 테두리 스타일 적용
    return Border(
      right: BorderSide(
        color: Colors.grey,
        width: isTeacherColumn ? 3 : (isLastColumnOfDay ? 3 : 0.5),
      ),
      bottom: const BorderSide(color: Colors.grey, width: 0.5),
    );
  }
  
  /// 헤더 스타일 결정 (단순화)
  static HeaderStyle getHeaderStyle({
    required CellState state,
    required bool isLastColumnOfDay,
  }) {
    return HeaderStyle(
      backgroundColor: state == CellState.selected 
          ? selectedColorLight
          : state == CellState.exchangeable
              ? exchangeableColorLight
              : periodHeaderColor,
      textStyle: getTextStyle(state: state, isHeader: true),
      border: getBorder(
        isTeacherColumn: false,
        isLastColumnOfDay: isLastColumnOfDay,
        state: state,
      ),
    );
  }
}

/// 셀 상태를 나타내는 enum (단순화)
enum CellState {
  normal,      // 일반 상태
  selected,    // 선택된 상태
  exchangeable // 교체 가능한 상태
}

/// 헤더 스타일 데이터 클래스
class HeaderStyle {
  final Color backgroundColor;
  final TextStyle textStyle;
  final Border border;
  
  HeaderStyle({
    required this.backgroundColor,
    required this.textStyle,
    required this.border,
  });
}

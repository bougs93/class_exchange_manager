import 'package:flutter/material.dart';
import 'constants.dart';

/// 선택된 교시 관련 모든 스타일을 관리하는 통합 클래스
class SelectedPeriodTheme {
  /// 배경색만 필요한 경우
  static Color getBackgroundColor({
    required bool isTeacherColumn,
    required bool isSelected,
    required bool isExchangeableTeacher,
  }) {
    if (isTeacherColumn) {
      return isSelected 
          ? Colors.blue.shade100  // 선택된 교사명 열
          : const Color(AppConstants.teacherHeaderColor);
    } else {
      if (isSelected) {
        return Colors.blue.shade100; // 선택된 교시 셀
      } else if (isExchangeableTeacher) {
        return Colors.green.shade200; // 교체 가능한 교사 셀
      } else {
        return const Color(AppConstants.dataCellColor); // 기본 색상
      }
    }
  }
  
  /// 텍스트 스타일만 필요한 경우
  static TextStyle getTextStyle({
    required bool isSelected,
    bool isHeader = false,
  }) {
    return TextStyle(
      fontSize: isHeader ? AppConstants.headerFontSize : AppConstants.dataFontSize,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      color: isSelected ? Colors.blue.shade700 : Colors.black,
    );
  }
  
  /// 테두리만 필요한 경우
  static Border getBorder({
    required bool isTeacherColumn,
    required bool isSelected,
    bool isLastDay = false,
    bool isLastPeriod = false,
  }) {
    if (isTeacherColumn) {
      return const Border(
        right: BorderSide(color: Colors.grey, width: 3),
        bottom: BorderSide(color: Colors.grey, width: 1),
      );
    } else {
      return Border(
        right: BorderSide(
          color: Colors.grey, 
          width: (isLastDay && isLastPeriod) ? 1 : (isLastPeriod ? 3 : 1),
        ),
        bottom: const BorderSide(color: Colors.grey, width: 1),
      );
    }
  }
  
  /// 모든 스타일이 필요한 경우 (고급 사용법)
  static CellStyles getAllStyles({
    required bool isTeacherColumn,
    required bool isSelected,
    required bool isExchangeableTeacher,
    bool isLastDay = false,
    bool isLastPeriod = false,
    bool isHeader = false,
  }) {
    return CellStyles(
      backgroundColor: getBackgroundColor(
        isTeacherColumn: isTeacherColumn,
        isSelected: isSelected,
        isExchangeableTeacher: isExchangeableTeacher,
      ),
      textStyle: getTextStyle(
        isSelected: isSelected,
        isHeader: isHeader,
      ),
      border: getBorder(
        isTeacherColumn: isTeacherColumn,
        isSelected: isSelected,
        isLastDay: isLastDay,
        isLastPeriod: isLastPeriod,
      ),
    );
  }
  
  /// 헤더 전용 스타일 (기존 TimetableGridHeaderTheme 호환)
  static HeaderStyles getHeaderStyles({
    required bool isSelected,
    required bool isLastDay,
    required bool isLastPeriod,
  }) {
    return HeaderStyles(
      backgroundColor: isSelected 
          ? Colors.blue.shade100
          : const Color(AppConstants.periodHeaderColor),
      textStyle: TextStyle(
        fontSize: AppConstants.headerFontSize,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.blue.shade700 : Colors.black,
      ),
      border: Border(
        right: BorderSide(
          color: Colors.grey, 
          width: (isLastDay && isLastPeriod) ? 1 : (isLastPeriod ? 3 : 1),
        ),
        bottom: const BorderSide(color: Colors.grey, width: 1),
      ),
    );
  }
}

/// 셀 스타일 데이터 클래스
class CellStyles {
  final Color backgroundColor;
  final TextStyle textStyle;
  final Border border;
  
  CellStyles({
    required this.backgroundColor,
    required this.textStyle,
    required this.border,
  });
}

/// 헤더 스타일 데이터 클래스
class HeaderStyles {
  final Color backgroundColor;
  final TextStyle textStyle;
  final Border border;
  
  HeaderStyles({
    required this.backgroundColor,
    required this.textStyle,
    required this.border,
  });
}

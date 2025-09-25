import 'package:flutter/material.dart';
import 'constants.dart';
import 'logger.dart';

/// 단순화된 시간표 테마 클래스
/// 기존의 TimetableTheme와 SelectedPeriodTheme를 통합
class SimplifiedTimetableTheme {
  // 색상 정의
  static const Color _defaultColor = Colors.white;
  static const Color _teacherHeaderColor = Color(0xFFF5F5F5);
  
  // 색상 변형
  static const Color _selectedColorLight = Color(0xFFE3F2FD);
  static const Color _exchangeableColorLight = Color(0xFFC8E6C9);
  static const Color _selectedColorDark = Color(0xFF1976D2);
  
  /// 통합된 셀 스타일 생성
  static CellStyle getCellStyle({
    required bool isTeacherColumn,
    required bool isSelected,
    required bool isExchangeable,
    required bool isLastColumnOfDay,
    bool isHeader = false,
  }) {
    return CellStyle(
      backgroundColor: _getBackgroundColor(
        isTeacherColumn: isTeacherColumn,
        isSelected: isSelected,
        isExchangeable: isExchangeable,
      ),
      textStyle: _getTextStyle(
        isSelected: isSelected,
        isHeader: isHeader,
      ),
      border: _getBorder(
        isTeacherColumn: isTeacherColumn,
        isSelected: isSelected,
        isLastColumnOfDay: isLastColumnOfDay,
      ),
    );
  }
  
  /// 배경색 결정
  static Color _getBackgroundColor({
    required bool isTeacherColumn,
    required bool isSelected,
    required bool isExchangeable,
  }) {
    if (isSelected) {
      return _selectedColorLight;
    } else if (isExchangeable) {
      return _exchangeableColorLight;
    } else {
      return isTeacherColumn ? _teacherHeaderColor : _defaultColor;
    }
  }
  
  /// 텍스트 스타일 결정
  static TextStyle _getTextStyle({
    required bool isSelected,
    required bool isHeader,
  }) {
    return TextStyle(
      fontSize: isHeader ? AppConstants.headerFontSize : AppConstants.dataFontSize,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: isSelected ? _selectedColorDark : Colors.black,
      height: AppConstants.dataLineHeight,
    );
  }
  
  /// 테두리 스타일 결정
  static Border _getBorder({
    required bool isTeacherColumn,
    required bool isSelected,
    required bool isLastColumnOfDay,
  }) {
    // 선택된 셀의 경우 빨간색 테두리
    if (isSelected) {
      AppLogger.debug('빨간색 테두리 적용: 교사열=$isTeacherColumn, 선택됨=$isSelected');
      return Border.all(color: Colors.red, width: 3.0); // 더 두껍게 설정
    }
    
    // 일반 셀의 경우 기존 테두리 스타일
    return Border(
      right: BorderSide(
        color: Colors.grey,
        width: isTeacherColumn ? 3 : (isLastColumnOfDay ? 3 : 0.5),
      ),
      bottom: const BorderSide(color: Colors.grey, width: 0.5),
    );
  }
}

/// 통합된 셀 스타일 데이터 클래스
class CellStyle {
  final Color backgroundColor;
  final TextStyle textStyle;
  final Border border;
  
  CellStyle({
    required this.backgroundColor,
    required this.textStyle,
    required this.border,
  });
}

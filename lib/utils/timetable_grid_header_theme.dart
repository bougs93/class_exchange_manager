import 'package:flutter/material.dart';
import 'constants.dart';

/// 시간표 그리드 헤더 스타일 테마 클래스
class TimetableGridHeaderTheme {
  /// 선택된 교시 헤더 스타일
  static TextStyle getSelectedHeaderStyle() {
    return TextStyle(
      fontSize: AppConstants.headerFontSize,
      fontWeight: FontWeight.bold,        // 굵은 글씨
      color: Colors.blue.shade700,         // 파란색 텍스트
    );
  }
  
  /// 일반 교시 헤더 스타일
  static TextStyle getNormalHeaderStyle() {
    return TextStyle(
      fontSize: AppConstants.headerFontSize,
      fontWeight: FontWeight.w500,         // 보통 글씨
      color: Colors.black,                 // 검은색 텍스트
    );
  }
  
  /// 선택된 교시 헤더 배경색
  static Color getSelectedHeaderBackground() {
    return Colors.blue.shade100;           // 연한 파란색 배경
  }
  
  /// 일반 교시 헤더 배경색
  static Color getNormalHeaderBackground() {
    return const Color(0xFFFAFAFA); // 교시 헤더 배경색
  }
  
  /// 특정 교시가 선택되었는지 확인
  static bool isPeriodSelected(String day, int period, String? selectedDay, int? selectedPeriod) {
    return selectedDay == day && selectedPeriod == period;
  }
  
  /// 선택된 교시 헤더의 테두리 스타일
  static Border getSelectedHeaderBorder(bool isLastDay, bool isLastPeriod) {
    return Border(
      right: BorderSide(
        color: Colors.grey, 
        width: (isLastDay && isLastPeriod) ? 1 : (isLastPeriod ? 3 : 1),
      ),
      bottom: const BorderSide(color: Colors.grey, width: 1),
    );
  }
  
  /// 일반 교시 헤더의 테두리 스타일
  static Border getNormalHeaderBorder(bool isLastDay, bool isLastPeriod) {
    return Border(
      right: BorderSide(
        color: Colors.grey, 
        width: (isLastDay && isLastPeriod) ? 1 : (isLastPeriod ? 3 : 1),
      ),
      bottom: const BorderSide(color: Colors.grey, width: 1),
    );
  }
}

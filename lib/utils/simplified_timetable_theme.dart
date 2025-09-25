import 'package:flutter/material.dart';
import 'constants.dart';

/// 단순화된 시간표 테마 클래스
/// 기존의 TimetableTheme와 SelectedPeriodTheme를 통합
class SimplifiedTimetableTheme {
  // 색상 정의 (public으로 변경하여 다른 테마에서 참조 가능)
  static const Color defaultColor = Colors.white;
  static const Color teacherHeaderColor = Color(0xFFF5F5F5);
  
  // 색상 변형 (public으로 변경하여 다른 테마에서 참조 가능)
  static const Color selectedColorLight = Color(0xFFE3F2FD);
  static const Color exchangeableColorLight = Color(0xFFC8E6C9);
  static const Color selectedColorDark = Color(0xFF1976D2);
  
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
      overlayWidget: _getOverlayWidget(
        isExchangeable: isExchangeable,
        isTeacherColumn: isTeacherColumn,
        isHeader: isHeader,
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
      return selectedColorLight;
    } else if (isExchangeable) {
      return exchangeableColorLight;
    } else {
      return isTeacherColumn ? teacherHeaderColor : defaultColor;
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
      color: isSelected ? selectedColorDark : Colors.black,
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
      return Border.all(
        color: Color(AppConstants.selectedCellColor), 
        width: AppConstants.selectedCellBorderWidth
      );
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
  
  /// 특정 교시가 선택되었는지 확인
  static bool isPeriodSelected(String day, int period, String? selectedDay, int? selectedPeriod) {
    return selectedDay == day && selectedPeriod == period;
  }
  
  /// 교체 가능한 셀에 표시할 오버레이 위젯 생성 (내부용)
  static Widget? _getOverlayWidget({
    required bool isExchangeable,
    required bool isTeacherColumn,
    required bool isHeader,
  }) {
    // 교체 가능한 셀이고, 교사명 열이 아니고, 헤더가 아닌 경우에만 표시
    if (!isExchangeable || isTeacherColumn || isHeader) {
      return null;
    }
    
    // 기본값으로 1:1 교체용 오버레이 생성
    return createExchangeableOverlay(
      color: Colors.red.shade600,
      number: '1',
    );
  }
  
  /// 교체 가능한 셀에 표시할 오버레이 위젯 생성 (공용 함수)
  /// 다른 서비스에서도 사용할 수 있도록 public으로 제공
  static Widget createExchangeableOverlay({
    required Color color,
    required String number,
    double size = 10.0,
    double fontSize = 8.0,
  }) {
    return Positioned(
      top: 0,
      left: 0,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0), // 왼쪽 상단 모서리는 직각
            topRight: Radius.circular(2),
            bottomLeft: Radius.circular(0), // 왼쪽 하단 모서리는 직각
            bottomRight: Radius.circular(2),
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// 통합된 셀 스타일 데이터 클래스
class CellStyle {
  final Color backgroundColor;
  final TextStyle textStyle;
  final Border border;
  final Widget? overlayWidget; // 교체 가능한 셀에 표시할 오버레이 위젯
  
  CellStyle({
    required this.backgroundColor,
    required this.textStyle,
    required this.border,
    this.overlayWidget,
  });
}

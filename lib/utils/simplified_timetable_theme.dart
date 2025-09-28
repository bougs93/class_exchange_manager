import 'package:flutter/material.dart';
import 'constants.dart';

/// 단순화된 시간표 테마 클래스
/// 기존의 TimetableTheme와 SelectedPeriodTheme를 통합
class SimplifiedTimetableTheme {
  // 색상 정의 (public으로 변경하여 다른 테마에서 참조 가능)
  static const Color defaultColor = Colors.white;
  static const Color teacherHeaderColor = Color(0xFFF5F5F5);
  
  // 색상 변형 (public으로 변경하여 다른 테마에서 참조 가능)
  static const Color selectedColorLight = Color.fromARGB(255, 255, 174, 0); // 진한 오렌지색
  static const Color exchangeableColorLight = Color(0xFFE0E0E0);
  static const Color selectedColorDark = Color(0xFF1976D2);
    // 텍스트 색상 상수
  static const Color selectedTextColor = Colors.black; // 선택된 셀의 텍스트 색상 (흰색)
  
  // 순환교체 경로 색상
  static const Color circularPathColorLight = Color.fromARGB(255, 203, 142, 214); // 연한 보라색
  static const Color circularPathColorDark = Color(0xFF7B1FA2); // 진한 보라색
  
  // 선택된 경로 색상 (1:1 교체 모드에서 경로 선택시)
  static const Color selectedPathColorLight = Color.fromARGB(255, 117, 190, 119); // 진한 녹색 (더 명확한 구분)
  static const Color selectedPathColorDark = Color(0xFF2E7D32); // 더 진한 녹색
  
  // 오버레이 색상 상수
  static const Color overlayColorSelected = Color(0xFFD32F2F); // 진한 빨간색
  static const Color overlayColorExchangeable = Color.fromARGB(255, 250, 160, 169); // 연한 빨간색 (Colors.red.shade200의 실제 색상값)
  
  // 선택된 셀 테두리 색상 상수
  static const Color selectedCellBorderColor = Color(0xFFFF0000); // 선택된 셀 테두리 색상 (빨간색)
  static const double selectedCellBorderWidth = 1.0; // 선택된 셀 테두리 두께
  static const bool showSelectedCellBorder = false; // 선택된 셀 테두리 표시 여부
  
  /// 통합된 셀 스타일 생성
  static CellStyle getCellStyle({
    required bool isTeacherColumn,
    required bool isSelected,
    required bool isExchangeable,
    required bool isLastColumnOfDay,
    bool isHeader = false,
    bool isInCircularPath = false, // 순환교체 경로에 포함된 셀인지 여부
    int? circularPathStep, // 순환교체 경로에서의 단계 (1, 2, 3...)
    bool isInSelectedPath = false, // 선택된 경로에 포함된 셀인지 여부 (1:1 교체 모드)
  }) {
    return CellStyle(
      backgroundColor: _getBackgroundColor(
        isTeacherColumn: isTeacherColumn,
        isSelected: isSelected,
        isExchangeable: isExchangeable,
        isInCircularPath: isInCircularPath,
        isInSelectedPath: isInSelectedPath,
      ),
      textStyle: _getTextStyle(
        isSelected: isSelected,
        isHeader: isHeader,
        isInCircularPath: isInCircularPath,
      ),
      border: _getBorder(
        isTeacherColumn: isTeacherColumn,
        isSelected: isSelected,
        isLastColumnOfDay: isLastColumnOfDay,
        isInCircularPath: isInCircularPath,
      ),
      overlayWidget: _getOverlayWidget(
        isExchangeable: isExchangeable,
        isTeacherColumn: isTeacherColumn,
        isHeader: isHeader,
        isInCircularPath: isInCircularPath,
        circularPathStep: circularPathStep,
        isInSelectedPath: isInSelectedPath,
        isSelected: isSelected,
      ),
    );
  }
  
  /// 배경색 결정
  static Color _getBackgroundColor({
    required bool isTeacherColumn,
    required bool isSelected,
    required bool isExchangeable,
    required bool isInCircularPath,
    required bool isInSelectedPath,
  }) {
    if (isSelected) {
      return selectedColorLight;
    } else if (isInCircularPath) {
      return circularPathColorLight;
    } else if (isInSelectedPath) {
      return selectedPathColorLight; // 선택된 경로에 포함된 셀은 연한 녹색
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
    required bool isInCircularPath,
  }) {
    Color textColor = Colors.black;
    FontWeight fontWeight = FontWeight.normal;
    
    if (isSelected) {
      textColor = selectedTextColor; // 선택된 셀의 텍스트 색상 상수 사용
      fontWeight = FontWeight.bold;
    } else if (isInCircularPath) {
      textColor = circularPathColorDark;
      fontWeight = FontWeight.w600;
    }
    
    return TextStyle(
      fontSize: isHeader ? AppConstants.headerFontSize : AppConstants.dataFontSize,
      fontWeight: fontWeight,
      color: textColor,
      height: AppConstants.dataLineHeight,
    );
  }
  
  /// 테두리 스타일 결정
  static Border _getBorder({
    required bool isTeacherColumn,
    required bool isSelected,
    required bool isLastColumnOfDay,
    required bool isInCircularPath,
  }) {
    // 선택된 셀의 경우 빨간색 테두리 (표시 여부 설정에 따라)
    if (isSelected && showSelectedCellBorder) {
      return Border.all(
        color: selectedCellBorderColor, 
        width: selectedCellBorderWidth
      );
    }
    
    // 순환교체 경로에 포함된 셀의 경우 일반 테두리 (보라색 테두리 제거)
    if (isInCircularPath) {
      return Border(
        right: BorderSide(
          color: Colors.grey,
          width: isTeacherColumn ? 3 : (isLastColumnOfDay ? 3 : 0.5),
        ),
        bottom: const BorderSide(color: Colors.grey, width: 0.5),
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
    required bool isInCircularPath,
    int? circularPathStep, // 순환교체 경로에서의 단계 (1, 2, 3...)
    required bool isInSelectedPath, // 선택된 경로에 포함된 셀인지 여부
    required bool isSelected, // 셀이 선택된 상태인지 여부
  }) {
    // 교사명 열이거나 헤더인 경우 표시하지 않음
    if (isTeacherColumn || isHeader) {
      return null;
    }
    
    // 순환교체 경로에 포함된 셀인 경우 단계별 숫자 오버레이
    if (isInCircularPath && circularPathStep != null) {
      return createExchangeableOverlay(
        color: overlayColorSelected, // 순환교체는 진한 빨간색
        number: circularPathStep.toString(), // 단계별 숫자 (1, 2, 3...)
      );
    }
    
    // 선택된 경로에 포함된 셀이면서 선택되지 않은 셀인 경우 진한 빨간색 오버레이
    if (isInSelectedPath && !isSelected) {
      return createExchangeableOverlay(
        color: overlayColorSelected, // 진한 빨간색
        number: '1',
      );
    }
    
    // 1:1 교체 가능한 셀이면서 선택되지 않은 셀인 경우 오버레이 표시
    if (isExchangeable && !isSelected) {
      return createExchangeableOverlay(
        color: overlayColorExchangeable, // 연한 빨간색
        number: '1',
      );
    }
    
    // 그 외의 경우 오버레이 표시하지 않음
    return null;
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

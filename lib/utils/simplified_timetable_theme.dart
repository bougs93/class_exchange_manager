import 'package:flutter/material.dart';
import 'cell_style_config.dart';
import 'constants.dart';

/// 단순화된 시간표 테마 클래스
/// 기존의 TimetableTheme와 SelectedPeriodTheme를 통합
class SimplifiedTimetableTheme {
  
  /// 동적 폰트 사이즈 배율 (확대/축소용)
  static double _fontScaleFactor = 1.0;
  
  /// 폰트 사이즈 배율 설정 (줌 인/아웃 시 호출)
  static void setFontScaleFactor(double factor) {
    _fontScaleFactor = factor;
  }
  
  /// 현재 폰트 사이즈 배율 반환
  static double get fontScaleFactor => _fontScaleFactor;
  // 색상 정의 (public으로 변경하여 다른 테마에서 참조 가능)
  static const Color defaultColor = Colors.white;
  static const Color teacherHeaderColor = Color(0xFFF5F5F5);
  
  // 경계선 관련 상수
  static const Color normalBorderColor = Colors.grey;
  static const Color dayBorderColor = Color(0xFF424242); // 요일별 첫 번째 교시 경계선 색상 (Colors.grey.shade800과 동일)
  static const Color dayHeaderBorderColor = Color(0xFF424242); // 요일 헤더 왼쪽 경계선 색상
  static const double normalBorderWidth = 0.2;
  static const double dayBorderWidth = 2.0; // 요일별 첫 번째 교시 경계선 두께
  static const double dayHeaderBorderWidth = 2.0; // 요일 헤더 왼쪽 경계선 두께
  
  // 선택된 셀 색상 (마우스 클릭, 교체할 셀 선택시)
  static const Color selectedColorLight = Color(0xFFFFEB3B); // 노란색 (기존 테마 유지)
  static const Color exchangeableColorLight = Color(0xFFE0E0E0);
  static const Color selectedColorDark = Color(0xFF1976D2);
  // 선택된 셀 테두리 색상 상수
  static const Color selectedCellBorderColor = Color(0xFFFF0000); // 선택된 셀 테두리 색상 (빨간색)
  static const double selectedCellBorderWidth = 2; // 선택된 셀 테두리 두께
  static BorderStyle selectedCellBorderStyle = BorderStyle.solid; // 선택된 셀 테두리 스타일 (solid, dashed)
  static const bool showSelectedCellBorder = true; // 선택된 셀 테두리 표시 여부

// 타겟 셀 테두리 색상 상수 (이동할 같은 교사의 셀 테두리)
  static const Color targetCellBorderColor = Color(0xFFFF0000); // 타겟 셀 테두리 색상 (빨간색)
  static const double targetCellBorderWidth = 2.5; // 타겟 셀 테두리 두께
  static BorderStyle targetCellBorderStyle = BorderStyle.solid; // 타겟 셀 테두리 스타일 (solid만 지원, 점선은 CustomPainter 사용)
  static const bool showTargetCellBorder = true; // 타겟 셀 테두리 표시 여부

// 교체완료 셀 테두리 색상 상수 (교체가 완료된 셀의 테두리)
  static const Color exchangedCellBorderColor = Color(0xFF2196F3); // 교체완료 셀 테두리 색상 (파란색)
  static const double exchangedCellBorderWidth = 2.5; // 교체완료 셀 테두리 두께 (더 두껍게)
  static BorderStyle exchangedCellBorderStyle = BorderStyle.solid; // 교체완료 셀 테두리 스타일
  static const bool showExchangedCellBorder = true; // 교체완료 셀 테두리 표시 여부
  
  // 타겟 셀 배경색 상수 (교체 대상의 같은 행 셀 배경색)
  static const Color targetCellBackgroundColor = Color.fromARGB(255, 255, 255, 255); // 타겟 셀 배경색 (연한 녹색)
  static const bool showTargetCellBackground = true; // 타겟 셀 배경색 표시 여부

  // 텍스트 색상 상수
  static const Color selectedTextColor = Colors.black; // 선택된 셀의 텍스트 색상 (흰색)
  
  // 순환교체 경로 색상
  static const Color circularPathColorLight = Color.fromARGB(255, 203, 142, 214); // 연한 보라색
  static const Color circularPathColorDark = Color(0xFF7B1FA2); // 진한 보라색
  
  // 선택된 경로 색상 (1:1 교체 모드에서 경로 선택시)
  static const Color selectedPathColorLight = Color.fromARGB(255, 117, 190, 119); // 진한 녹색 (더 명확한 구분)
  static const Color selectedPathColorDark = Color(0xFF2E7D32); // 더 진한 녹색
  
  // 연쇄교체 경로 색상
  static const Color chainPathColorLight = Color(0xFFFF8A65); // 연한 주황색
  static const Color chainPathColorDark = Color(0xFFFF5722); // 주황색
  
  // 오버레이 색상 상수
  static const Color overlayColorSelected = Color(0xFFD32F2F); // 진한 빨간색
  static const Color overlayColorExchangeable = Color.fromARGB(255, 250, 160, 169); // 연한 빨간색 (Colors.red.shade200의 실제 색상값)
  
  // 교체불가 셀 색상
  static const Color nonExchangeableColor = Color(0xFFFFCDD2); // 연한 빨간색 배경
  
    
  /// 통합된 셀 스타일 생성 (개선된 버전 - CellStyleConfig 사용)
  static CellStyle getCellStyleFromConfig(CellStyleConfig config) {
    return CellStyle(
      backgroundColor: _getBackgroundColor(
        isTeacherColumn: config.isTeacherColumn,
        isSelected: config.isSelected,
        isExchangeable: config.isExchangeable,
        isInCircularPath: config.isInCircularPath,
        isInSelectedPath: config.isInSelectedPath,
        isInChainPath: config.isInChainPath,
        isTargetCell: config.isTargetCell,
        isNonExchangeable: config.isNonExchangeable,
      ),
      textStyle: _getTextStyle(
        isSelected: config.isSelected,
        isHeader: config.isHeader,
        isInCircularPath: config.isInCircularPath,
      ),
      border: _getBorder(
        isTeacherColumn: config.isTeacherColumn,
        isSelected: config.isSelected,
        isLastColumnOfDay: config.isLastColumnOfDay,
        isFirstColumnOfDay: config.isFirstColumnOfDay,
        isInCircularPath: config.isInCircularPath,
        isHeader: config.isHeader,
        isTargetCell: config.isTargetCell,
        isExchanged: config.isExchanged,
      ),
      overlayWidget: _getOverlayWidget(
        isExchangeable: config.isExchangeable,
        isTeacherColumn: config.isTeacherColumn,
        isHeader: config.isHeader,
        isInCircularPath: config.isInCircularPath,
        circularPathStep: config.circularPathStep,
        isInSelectedPath: config.isInSelectedPath,
        isSelected: config.isSelected,
        isInChainPath: config.isInChainPath,
        chainPathStep: config.chainPathStep,
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
    required bool isInChainPath,
    required bool isTargetCell, // 타겟 셀인지 여부 추가
    required bool isNonExchangeable, // 교체불가 셀인지 여부
  }) {
    // 교체불가 셀인 경우 빨간색 배경 (최우선순위)
    if (isNonExchangeable) {
      return nonExchangeableColor;
    }
    
    // 타겟 셀 배경색이 표시 여부가 true인 경우
    if (isTargetCell && showTargetCellBackground) {
      return targetCellBackgroundColor;
    }
    
    // 다른 상태들 (타겟 셀이 아닌 경우에만 적용)
    if (isSelected) {
      return selectedColorLight;
    } else if (isInCircularPath) {
      return circularPathColorLight;
    } else if (isInChainPath) {
      return chainPathColorLight;
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
      fontSize: (isHeader ? AppConstants.headerFontSize : AppConstants.dataFontSize) * _fontScaleFactor,
      fontWeight: fontWeight,
      color: textColor,
      height: AppConstants.dataLineHeight, // 줄간격은 줌 변화에 영향받지 않음
    );
  }
  
  /// 테두리 스타일 결정
  static Border _getBorder({
    required bool isTeacherColumn,
    required bool isSelected,
    required bool isLastColumnOfDay,
    required bool isFirstColumnOfDay,
    required bool isInCircularPath,
    required bool isHeader,
    required bool isTargetCell,
    required bool isExchanged,
  }) {
    // 교체완료 셀의 경우 파란색 테두리 (표시 여부 설정에 따라)
    // 헤더 셀과 일반 셀 모두에 적용 (최우선순위)
    if (isExchanged && showExchangedCellBorder) {
      return Border.all(
        color: exchangedCellBorderColor, 
        width: exchangedCellBorderWidth,
        style: exchangedCellBorderStyle, // 점선 또는 실선 스타일 적용
      );
    }
    
    // 타겟 셀의 경우 빨간색 테두리 (표시 여부 설정에 따라)
    // 헤더 셀과 일반 셀 모두에 적용
    if (isTargetCell && showTargetCellBorder) {
      return Border.all(
        color: targetCellBorderColor, 
        width: targetCellBorderWidth,
        style: targetCellBorderStyle, // 점선 또는 실선 스타일 적용
      );
    }
    
    // 선택된 셀의 경우 빨간색 테두리 (표시 여부 설정에 따라)
    // 헤더 셀과 일반 셀 모두에 적용
    if (isSelected && showSelectedCellBorder) {
      return Border.all(
        color: selectedCellBorderColor, 
        width: selectedCellBorderWidth,
        style: selectedCellBorderStyle, // 점선 또는 실선 스타일 적용
      );
    }
    
    // 순환교체 경로에 포함된 셀의 경우 일반 테두리 (보라색 테두리 제거)
    if (isInCircularPath) {
      return Border(
        left: BorderSide(
          color: isFirstColumnOfDay ? dayBorderColor : normalBorderColor, // 요일별 첫 번째 교시에 더 진한 색상
          width: isFirstColumnOfDay ? dayBorderWidth : normalBorderWidth, // 요일별 첫 번째 교시에 두꺼운 경계선
        ),
        right: const BorderSide(color: normalBorderColor, width: normalBorderWidth), // 모든 교시에 얇은 경계선
        bottom: const BorderSide(color: normalBorderColor, width: normalBorderWidth),
      );
    }
    
    // 일반 셀의 경우 기존 테두리 스타일
    return Border(
      left: BorderSide(
        color: isFirstColumnOfDay ? dayBorderColor : normalBorderColor, // 요일별 첫 번째 교시에 더 진한 색상
        width: isFirstColumnOfDay ? dayBorderWidth : normalBorderWidth, // 요일별 첫 번째 교시에 두꺼운 경계선
      ),
      right: const BorderSide(color: normalBorderColor, width: normalBorderWidth), // 모든 교시에 얇은 경계선
      bottom: const BorderSide(color: normalBorderColor, width: normalBorderWidth),
    );
  }
  
  /// 특정 교시가 선택되었는지 확인
  static bool isPeriodSelected(String day, int period, String? selectedDay, int? selectedPeriod) {
    return selectedDay == day && selectedPeriod == period;
  }
  
  /// 특정 교시가 타겟 셀인지 확인
  static bool isPeriodTarget(String day, int period, String? targetDay, int? targetPeriod) {
    return targetDay == day && targetPeriod == period;
  }

  /// 점선 테두리를 가진 컨테이너 생성 (CustomPainter 사용)
  static Widget createDashedBorderContainer({
    required Widget child,
    required Color borderColor,
    required double borderWidth,
    double dashWidth = 5.0,
    double dashSpace = 3.0,
  }) {
    return CustomPaint(
      painter: DashedBorderPainter(
        color: borderColor,
        strokeWidth: borderWidth,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
      ),
      child: child,
    );
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
    required bool isInChainPath, // 연쇄교체 경로에 포함된 셀인지 여부
    int? chainPathStep, // 연쇄교체 경로에서의 단계 (1, 2)
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
    
    // 연쇄교체 경로에 포함된 셀인 경우 단계별 숫자 오버레이
    if (isInChainPath && chainPathStep != null) {
      return createExchangeableOverlay(
        color: overlayColorSelected, // 연쇄교체도 진한 빨간색
        number: chainPathStep.toString(), // 단계별 숫자 (1, 2)
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

/// 점선 테두리를 그리는 CustomPainter
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  
  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final dashLength = dashWidth + dashSpace;
    
    // 상단 테두리
    for (double i = 0; i < size.width; i += dashLength) {
      path.moveTo(i, 0);
      path.lineTo((i + dashWidth).clamp(0, size.width), 0);
    }
    
    // 우측 테두리
    for (double i = 0; i < size.height; i += dashLength) {
      path.moveTo(size.width, i);
      path.lineTo(size.width, (i + dashWidth).clamp(0, size.height));
    }
    
    // 하단 테두리
    for (double i = 0; i < size.width; i += dashLength) {
      path.moveTo(i, size.height);
      path.lineTo((i + dashWidth).clamp(0, size.width), size.height);
    }
    
    // 좌측 테두리
    for (double i = 0; i < size.height; i += dashLength) {
      path.moveTo(0, i);
      path.lineTo(0, (i + dashWidth).clamp(0, size.height));
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

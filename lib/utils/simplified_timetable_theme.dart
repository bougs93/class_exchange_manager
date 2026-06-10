import 'package:flutter/material.dart';
import '../ui/widgets/cell_status_border_overlay.dart';
import 'cell_style_config.dart';
import 'constants.dart';
import '../services/timetable_theme_storage_service.dart';
import '../services/app_settings_storage_service.dart';
import '../constants/teacher_row_highlight_colors.dart';
import 'logger.dart';

/// 단순화된 시간표 테마 클래스
/// 기존의 TimetableTheme와 SelectedPeriodTheme를 통합
class SimplifiedTimetableTheme {
  /// 동적 폰트 사이즈 배율 (확대/축소용)
  static double _fontScaleFactor = 1.0;

  /// 교체불가 셀 색상 (저장/로드 가능)
  /// 기본값: 연한 빨간색 (0xFFFFCDD2)
  static Color _nonExchangeableColor = const Color(0xFFFFCDD2);

  /// 하이라이트된 교사 행 색상 (저장/로드 가능)
  /// 기본값: 청록 (0xFFB2DFDB) — 교체 범례 색상과 구분
  static Color _highlightedTeacherColor =
      TeacherRowHighlightColors.defaultColor;

  /// 폰트 사이즈 배율 설정 (줌 인/아웃 시 호출)
  static void setFontScaleFactor(double factor) {
    _fontScaleFactor = factor;
    // 테마 설정 저장
    _saveThemeSettings();
  }

  /// 교체불가 셀 색상 설정
  ///
  /// 매개변수:
  /// - `color`: 설정할 색상
  static void setNonExchangeableColor(Color color) {
    _nonExchangeableColor = color;
    // 테마 설정 저장
    _saveThemeSettings();
  }

  /// 테마 설정 저장 서비스
  static final TimetableThemeStorageService _themeStorage =
      TimetableThemeStorageService();

  /// 테마 설정 저장
  static Future<void> _saveThemeSettings() async {
    try {
      await _themeStorage.saveThemeSettings(
        fontScaleFactor: _fontScaleFactor,
        nonExchangeableColor: _nonExchangeableColor.toARGB32(), // ARGB 값으로 저장
      );
    } catch (e) {
      AppLogger.error('테마 설정 저장 실패: $e', e);
    }
  }

  /// 테마 설정 로드
  ///
  /// 프로그램 시작 시 호출되어 저장된 테마 설정을 로드합니다.
  static Future<void> loadThemeSettings() async {
    try {
      // 폰트 사이즈 배율 로드
      final fontScaleFactor = await _themeStorage.getFontScaleFactor();
      _fontScaleFactor = fontScaleFactor;

      // 교체불가 셀 색상 로드
      final loadedColor = await _themeStorage.getNonExchangeableColor();
      if (loadedColor != null) {
        _nonExchangeableColor = loadedColor;
        AppLogger.info(
          '교체불가 셀 색상 로드 완료: ${_nonExchangeableColor.toARGB32().toRadixString(16)}',
        );
      } else {
        // 저장된 색상이 없으면 기본값 유지
        AppLogger.info('교체불가 셀 색상: 기본값 사용');
      }

      // 하이라이트된 교사 행 색상 로드
      await loadHighlightedTeacherColor();

      AppLogger.info('테마 설정 로드 완료: fontScaleFactor=$fontScaleFactor');
    } catch (e) {
      AppLogger.error('테마 설정 로드 실패: $e', e);
    }
  }

  /// 하이라이트된 교사 행 색상 로드
  ///
  /// 설정에서 저장된 하이라이트 색상을 로드합니다.
  static Future<void> loadHighlightedTeacherColor() async {
    try {
      final appSettings = AppSettingsStorageService();
      final colorValue = await appSettings.getHighlightedTeacherColor();

      if (colorValue != null) {
        _highlightedTeacherColor = TeacherRowHighlightColors.resolveSavedColor(
          colorValue,
        );
        AppLogger.info(
          '하이라이트 교사 행 색상 로드 완료: ${_highlightedTeacherColor.toARGB32().toRadixString(16)}',
        );
      } else {
        // 저장된 색상이 없으면 기본값 유지
        AppLogger.info('하이라이트 교사 행 색상: 기본값 사용');
      }
    } catch (e) {
      AppLogger.error('하이라이트 교사 행 색상 로드 실패: $e', e);
    }
  }

  /// 현재 폰트 사이즈 배율 반환
  static double get fontScaleFactor => _fontScaleFactor;

  /// 현재 교체불가 셀 색상 반환
  static Color get nonExchangeableColor => _nonExchangeableColor;

  /// 현재 하이라이트된 교사 행 색상 반환
  static Color get highlightedTeacherColor => _highlightedTeacherColor;

  /// 하이라이트된 교사 행 색상 설정
  ///
  /// 매개변수:
  /// - `color`: 설정할 색상
  static Future<void> setHighlightedTeacherColor(Color color) async {
    _highlightedTeacherColor = color;
    // 앱 설정에 저장
    final appSettings = AppSettingsStorageService();
    await appSettings.saveHighlightedTeacherColor(color.toARGB32());
  }

  // 색상 정의 (public으로 변경하여 다른 테마에서 참조 가능)
  static const Color defaultColor = Colors.white;
  static const Color teacherHeaderColor = Color(0xFFF5F5F5);

  // 경계선 관련 상수
  static const Color normalBorderColor = Colors.grey;
  static const Color dayBorderColor = Color(
    0xFF424242,
  ); // 요일별 첫 번째 교시 경계선 색상 (Colors.grey.shade800과 동일)
  static const Color dayHeaderBorderColor = Color(
    0xFF424242,
  ); // 요일 헤더 왼쪽 경계선 색상
  static const double normalBorderWidth = 0.2;
  static const double dayBorderWidth = 2.0; // 요일별 첫 번째 교시 경계선 두께
  static const double dayHeaderBorderWidth = 2.0; // 요일 헤더 왼쪽 경계선 두께

  // 선택된 셀 색상 (마우스 클릭, 교체할 셀 선택시)
  static const Color selectedColorLight = Color(0xFFFFEB3B); // 노란색 (기존 테마 유지)
  static const Color exchangeableColorLight = Color(0xFFE0E0E0);
  static const Color selectedColorDark = Color(0xFF1976D2);
  // 교사 이름 선택 색상 (새로 추가)
  static const Color selectedTeacherNameColor = Color(
    0xFFC8E6C9,
  ); // 조금 더 진한 그린색
  // 선택된 셀 테두리 색상 상수
  static const Color selectedCellBorderColor = Color(
    0xFFFF0000,
  ); // 선택된 셀 테두리 색상 (빨간색)
  static const double selectedCellBorderWidth = 2; // 선택된 셀 테두리 두께
  static BorderStyle selectedCellBorderStyle =
      BorderStyle.solid; // 선택된 셀 테두리 스타일 (solid, dashed)
  static const bool showSelectedCellBorder = true; // 선택된 셀 테두리 표시 여부

  // 교체된 셀 선택 시 헤더 색상 비활성화 플래그
  static bool _isExchangedCellSelectedHeaderDisabled = false;

  // 셀 선택시 선택교사가 이동할 목적지 셀 테두리 색상 상수 (선택교사가 이동할 같은 교사의 셀 테두리)
  static const Color selectedTeacherDestinationBorderColor = Color(
    0xFFFF0000,
  ); // 선택된 교사가 이동할 목적지 셀 테두리 색상 (빨간색)
  static const double selectedTeacherDestinationBorderWidth =
      2.5; // 선택된 교사가 이동할 목적지 셀 테두리 두께
  static BorderStyle selectedTeacherDestinationBorderStyle =
      BorderStyle
          .solid; // 선택된 교사가 이동할 목적지 셀 테두리 스타일 (solid만 지원, 점선은 CustomPainter 사용)
  static const bool showSelectedTeacherDestinationBorder =
      true; // 선택된 교사가 이동할 목적지 셀 테두리 표시 여부

  // 교체된 소스 셀 테두리 색상 상수 (교체가 완료된 소스 셀의 테두리) - 원본 수업이 있던 셀
  static const Color exchangedSourceCellBorderColor = Color(
    0xFF2196F3,
  ); // 교체된 소스 셀 테두리 색상 (파란색)
  static const double exchangedSourceCellBorderWidth = 2; // 교체된 소스 셀 테두리 두께
  static BorderStyle exchangedSourceCellBorderStyle =
      BorderStyle.solid; // 교체된 소스 셀 테두리 스타일
  static const bool showExchangedSourceCellBorder = true; // 교체된 소스 셀 테두리 표시 여부
  // 교체된 목적지 셀 배경색 상수 (교체가 완료된 목적지 셀의 배경색) - 교체 후 새 교사가 배정된 셀
  static const Color exchangedDestinationCellBackgroundColor = Color.fromARGB(
    255,
    144,
    199,
    245,
  ); // 교체된 목적지 셀 배경색 (연한 파란색)
  static const bool showExchangedDestinationCellBackground =
      true; // 교체된 목적지 셀 배경색 표시 여부

  // 텍스트 색상 상수
  static const Color selectedTextColor = Colors.black; // 선택된 셀의 텍스트 색상 (흰색)

  // 순환교체 경로 색상
  static const Color circularPathColorLight = Color.fromARGB(
    255,
    203,
    142,
    214,
  ); // 연한 보라색
  static const Color circularPathColorDark = Color(0xFF7B1FA2); // 진한 보라색

  // 선택된 경로 색상 (1:1 교체 모드에서 경로 선택시)
  static const Color selectedPathColorLight = Color.fromARGB(
    255,
    117,
    190,
    119,
  ); // 진한 녹색 (더 명확한 구분)
  static const Color selectedPathColorDark = Color(0xFF2E7D32); // 더 진한 녹색

  // 2중교체 경로 색상
  static const Color dualPathColorLight = Color(0xFFFF8A65); // 연한 주황색
  static const Color dualPathColorDark = Color(0xFFFF5722); // 주황색

  // 오버레이 색상 상수
  static const Color overlayColorSelected = Color(0xFFD32F2F); // 진한 빨간색
  static const Color overlayColorExchangeable = Color.fromARGB(
    255,
    250,
    160,
    169,
  ); // 연한 빨간색 (Colors.red.shade200의 실제 색상값)

  // 교체불가 셀 색상은 getter를 통해 접근: SimplifiedTimetableTheme.nonExchangeableColor
  // 기본값: 연한 빨간색 (0xFFFFCDD2)

  // ==================== 교체된 셀 선택 시 헤더 색상 제어 메서드 ====================

  /// 교체된 셀 선택 시 헤더 색상 비활성화 설정
  static void setExchangedCellSelectedHeaderDisabled(bool isDisabled) {
    _isExchangedCellSelectedHeaderDisabled = isDisabled;
  }

  /// 교체된 셀 선택 시 헤더 색상 비활성화 상태 반환
  static bool get isExchangedCellSelectedHeaderDisabled =>
      _isExchangedCellSelectedHeaderDisabled;

  /// 통합된 셀 스타일 생성 (개선된 버전 - CellStyleConfig 사용)
  static CellStyle getCellStyleFromConfig(CellStyleConfig config) {
    return CellStyle(
      backgroundColor: _getBackgroundColor(
        isTeacherColumn: config.isTeacherColumn,
        isSelected: config.isSelected,
        isExchangeable: config.isExchangeable,
        isInCircularPath: config.isInCircularPath,
        isInSelectedPath: config.isInSelectedPath,
        isInDualPath: config.isInDualPath,
        isTargetCell: config.isTargetCell,
        isNonExchangeable: config.isNonExchangeable,
        isExchangedSourceCell: config.isExchangedSourceCell,
        isExchangedDestinationCell: config.isExchangedDestinationCell,
        isHeader: config.isHeader,
        isTeacherNameSelected: config.isTeacherNameSelected, // 새로 추가
        isHighlightedTeacher: config.isHighlightedTeacher, // 새로 추가
      ),
      textStyle: _getTextStyle(
        isSelected: config.isSelected,
        isHeader: config.isHeader,
        isInCircularPath: config.isInCircularPath,
      ),
      border: _getBorder(isFirstColumnOfDay: config.isFirstColumnOfDay),
      statusBorder: _getStatusBorder(
        isSelected: config.isSelected,
        isHeader: config.isHeader,
        isTargetCell: config.isTargetCell,
        isExchangedSourceCell: config.isExchangedSourceCell,
        isTeacherNameSelected: config.isTeacherNameSelected,
      ),
      overlayWidget: _getOverlayWidget(
        isExchangeable: config.isExchangeable,
        isTeacherColumn: config.isTeacherColumn,
        isHeader: config.isHeader,
        isInCircularPath: config.isInCircularPath,
        circularPathStep: config.circularPathStep,
        isSelected: config.isSelected,
        pathStepNumber: config.pathStepNumber,
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
    required bool isInDualPath,
    required bool isTargetCell, // 타겟 셀인지 여부 추가
    required bool isNonExchangeable, // 교체불가 셀인지 여부
    required bool isExchangedSourceCell, // 교체된 소스 셀인지 여부 추가
    required bool isExchangedDestinationCell, // 교체된 목적지 셀인지 여부 추가
    required bool isHeader, // 헤더인지 여부 추가
    required bool isTeacherNameSelected, // 교사 이름 선택 상태 (새로 추가)
    required bool isHighlightedTeacher, // 하이라이트된 교사 행인지 여부 (새로 추가)
  }) {
    // 교사 이름 선택 상태인 경우 노란색 배경 (최우선순위)
    if (isTeacherNameSelected) {
      return selectedColorLight; // 노란색 배경
    }

    // 교체된 목적지 셀인 경우 연한 파란색 배경
    if (isExchangedDestinationCell && showExchangedDestinationCellBackground) {
      return exchangedDestinationCellBackgroundColor;
    }

    // 교체불가 셀인 경우 빨간색 배경 (저장된 색상 또는 기본값)
    if (isNonExchangeable) {
      return _nonExchangeableColor;
    }

    // 다른 상태들 (타겟 셀이 아닌 경우에만 적용)
    // 교체된 셀 선택 시 헤더의 노란색 배경 비활성화
    if (isSelected && !(isHeader && _isExchangedCellSelectedHeaderDisabled)) {
      return selectedColorLight;
    } else if (isInCircularPath) {
      return circularPathColorLight;
    } else if (isInDualPath) {
      return dualPathColorLight;
    } else if (isInSelectedPath) {
      return selectedPathColorLight; // 선택된 경로에 포함된 셀은 연한 녹색
    } else if (isExchangeable && !isHeader) {
      // 헤더가 아닌 경우에만 교체 가능한 셀 회색 배경 적용
      return exchangeableColorLight;
    } else if (isHighlightedTeacher) {
      // 하이라이트된 교사 행 (낮은 우선순위 - 다른 상태보다 나중에 적용)
      return _highlightedTeacherColor;
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
      fontSize:
          (isHeader ? AppConstants.headerFontSize : AppConstants.dataFontSize) *
          _fontScaleFactor,
      fontWeight: fontWeight,
      color: textColor,
      height: AppConstants.dataLineHeight, // 줄간격은 줌 변화에 영향받지 않음
    );
  }

  /// 그리드 구분용 얇은 테두리 (레이아웃용 — 두꺼운 상태 테두리는 오버레이로 그림)
  static Border _getBorder({required bool isFirstColumnOfDay}) {
    return _getGridBorder(isFirstColumnOfDay: isFirstColumnOfDay);
  }

  /// 상태 강조 테두리 — BoxDecoration 대신 오버레이로 그려 텍스트 영역을 유지
  static CellStatusBorder? _getStatusBorder({
    required bool isSelected,
    required bool isHeader,
    required bool isTargetCell,
    required bool isExchangedSourceCell,
    required bool isTeacherNameSelected,
  }) {
    if (isTeacherNameSelected) {
      return CellStatusBorder(
        color: selectedCellBorderColor,
        width: selectedCellBorderWidth,
      );
    }

    if (isExchangedSourceCell && showExchangedSourceCellBorder) {
      return CellStatusBorder(
        color: exchangedSourceCellBorderColor,
        width: exchangedSourceCellBorderWidth,
      );
    }

    if (isTargetCell && showSelectedTeacherDestinationBorder) {
      return CellStatusBorder(
        color: selectedTeacherDestinationBorderColor,
        width: selectedTeacherDestinationBorderWidth,
      );
    }

    if (isSelected &&
        showSelectedCellBorder &&
        !(isHeader && _isExchangedCellSelectedHeaderDisabled)) {
      return CellStatusBorder(
        color: selectedCellBorderColor,
        width: selectedCellBorderWidth,
      );
    }

    return null;
  }

  static Border _getGridBorder({required bool isFirstColumnOfDay}) {
    return Border(
      left: BorderSide(
        color: isFirstColumnOfDay ? dayBorderColor : normalBorderColor,
        width: isFirstColumnOfDay ? dayBorderWidth : normalBorderWidth,
      ),
      right: const BorderSide(
        color: normalBorderColor,
        width: normalBorderWidth,
      ),
      bottom: const BorderSide(
        color: normalBorderColor,
        width: normalBorderWidth,
      ),
    );
  }

  /// 특정 교시가 선택되었는지 확인
  static bool isPeriodSelected(
    String day,
    int period,
    String? selectedDay,
    int? selectedPeriod,
  ) {
    return selectedDay == day && selectedPeriod == period;
  }

  /// 특정 교시가 타겟 셀인지 확인
  static bool isPeriodTarget(
    String day,
    int period,
    String? targetDay,
    int? targetPeriod,
  ) {
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
    required bool isSelected, // 셀이 선택된 상태인지 여부
    int? pathStepNumber, // 1:1·2중 경로 셀 모서리 단계 번호 (없으면 null)
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

    // 1:1·2중 교체 경로 단계 번호 오버레이 (resolver가 결정한 단일 분기)
    if (pathStepNumber != null) {
      return createExchangeableOverlay(
        color: overlayColorSelected, // 진한 빨간색
        number: pathStepNumber.toString(), // 단계별 숫자 (1, 2)
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
  final CellStatusBorder? statusBorder;
  final Widget? overlayWidget; // 교체 가능한 셀에 표시할 오버레이 위젯

  CellStyle({
    required this.backgroundColor,
    required this.textStyle,
    required this.border,
    this.statusBorder,
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
    final paint =
        Paint()
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

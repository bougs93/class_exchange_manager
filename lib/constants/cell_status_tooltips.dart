/// 교체 화면 시간표 셀 상태별 툴팁 문구
///
/// 빠진 수업·맡은 수업·교체 불가 수업 셀에 마우스를 올렸을 때 표시합니다.
class CellStatusTooltips {
  CellStatusTooltips._();

  static const String missedClassTitle = '빠진 수업';
  static const String takenClassTitle = '맡은 수업';

  static const String nonExchangeableTitle = '교체 불가 수업';

  /// 셀 상태에 맞는 툴팁 문구를 반환합니다. 해당 상태가 없으면 null.
  static String? forCellState({
    required bool isTeacherColumn,
    required bool isHeader,
    required bool isNonExchangeable,
    required bool isExchangedSourceCell,
    required bool isExchangedDestinationCell,
  }) {
    // 교사명·헤더 열에는 상태 툴팁을 표시하지 않습니다.
    if (isTeacherColumn || isHeader) {
      return null;
    }

    // 시각적 우선순위와 동일: 교체 불가 > 빠진 수업 > 맡은 수업
    if (isNonExchangeable) {
      return nonExchangeableTitle;
    }
    if (isExchangedSourceCell) {
      return missedClassTitle;
    }
    if (isExchangedDestinationCell) {
      return takenClassTitle;
    }

    return null;
  }
}

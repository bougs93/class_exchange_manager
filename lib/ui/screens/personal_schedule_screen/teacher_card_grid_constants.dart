/// 교사 시간표 카드 그리드 레이아웃 상수
class TeacherCardGridConstants {
  /// 카드 외곽 여백
  static const double cardOuterPadding = 8.0;

  /// 카드 내부 여백
  static const double cardInnerPadding = 8.0;

  /// 카드 헤더 높이
  static const double cardHeaderHeight = 36.0;

  /// 카드 모서리 둥글기
  static const double cardBorderRadius = 8.0;

  /// 개인 시간표 그리드 세로 크기 배율 (기존 화면과 동일)
  static const double personalTimetableSizeMultiplier = 1.2;

  /// 카드 최대 너비 (넓은 화면에서 과도하게 늘어나지 않도록)
  static const double maxCardWidth = 720.0;

  /// 본문 카드 상단 툴바 — 가로 여백
  static const double toolbarHorizontalPadding = 8.0;

  /// 주차 칩 행 상단 여백
  static const double chipRowPaddingTop = 8.0;

  /// 줌 툴바 하단 여백
  static const double zoomToolbarPaddingBottom = 6.0;

  /// 툴바와 시간표 그리드 사이 간격
  static const double toolbarGridGap = 8.0;

  /// 시간표 AppBar 높이 (기본 56 → 컴팩트)
  static const double scheduleAppBarHeight = 40.0;

  /// AppBar에서 ◀ 날짜범위 ▶ 표시에 필요한 최소 가로 폭
  static const double scheduleAppBarDateRangeMinWidth = 640.0;

  /// 툴바 1줄(줌+교체 | 주차칩) 배치 최소 가로 폭 — 미만이면 2줄
  static const double scheduleToolbarSingleRowMinWidth = 480.0;

  /// 툴바 2줄일 때 그룹 간 세로 간격
  static const double scheduleToolbarWrappedRowGap = 4.0;

  /// 주차 칩 가로·세로 내부 패딩
  static const double weekChipPaddingHorizontal = 2.0;
  static const double weekChipLabelPaddingHorizontal = 4.0;

  /// 주차 칩 간격
  static const double weekChipSpacing = 4.0;
}

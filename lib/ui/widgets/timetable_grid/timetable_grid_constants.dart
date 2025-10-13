/// 화살표 계산 관련 상수
class ArrowConstants {
  // 화살표 머리 각도 (라디안)
  static const double headAngle = 0.5;

  // 텍스트 스타일
  static const double textFontSize = 12.0;
  static const double textBackgroundPadding = 1.0;
  static const double textOutlineWidth = 2.0;
}

/// 그리드 레이아웃 관련 상수
class GridLayoutConstants {
  // 고정 영역 설정
  static const int frozenColumnsCount = 1; // 교사명 열(첫 번째 열) 고정
  static const int headerRowsCount = 2; // 헤더 행 2개 (요일 + 교시)

  // 확대/축소 설정
  static const double defaultZoomFactor = 1.0; // 기본 확대 비율 100%
  static const double minZoom = 0.5; // 최소 확대 비율 50%
  static const double maxZoom = 2.0; // 최대 확대 비율 200%
  static const double zoomStep = 0.1; // 확대/축소 단계

  // 기본 폰트 크기
  static const double baseFontSize = 14.0;
}

/// 화살표의 시작점과 끝점이 어느 경계면에서 나야 하는지 결정하는 열거형
enum ArrowEdge {
  top,    // 상단 경계면 중앙
  bottom, // 하단 경계면 중앙
  left,   // 왼쪽 경계면 중앙
  right,  // 오른쪽 경계면 중앙
}

/// 화살표의 방향을 정의하는 열거형
enum ArrowDirection {
  forward,    // 시작 → 끝 방향 (단방향)
  bidirectional, // 양쪽 방향 (↔)
}

/// 화살표의 우선 방향을 정의하는 열거형
enum ArrowPriority {
  verticalFirst,  // 세로 우선 (먼저 수직 이동, 그 다음 수평 이동)
  horizontalFirst, // 가로 우선 (먼저 수평 이동, 그 다음 수직 이동)
}

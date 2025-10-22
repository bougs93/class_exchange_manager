/// 화살표 상태 관리 유틸리티 클래스 (싱글톤)
///
/// 화살표 초기화 및 상태 관리만을 담당합니다.
/// 실제 화살표 그리기는 ExchangeArrowPainter가 담당합니다.
class ArrowStateManager {
  // 싱글톤 인스턴스
  static final ArrowStateManager _instance = ArrowStateManager._internal();

  // 싱글톤 생성자
  factory ArrowStateManager() => _instance;

  // 내부 생성자
  ArrowStateManager._internal();

  /// 모든 화살표 상태 초기화
  ///
  /// 이 메서드는 화살표 관련 상태를 초기화하는 시그널 역할만 합니다.
  /// 실제 화살표 제거는 CellSelectionProvider.hideArrow()에서 처리됩니다.
  void clearAllArrows() {
    // 화살표 초기화 시그널
    // 실제 구현은 Provider에서 처리
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

/// 스크롤 상태 모델
/// 시간표 그리드의 수평/수직 스크롤 오프셋을 관리
class ScrollState {
  /// 수평 스크롤 오프셋
  final double horizontalOffset;
  
  /// 수직 스크롤 오프셋
  final double verticalOffset;
  
  /// 스크롤 중인지 여부 (마우스 오른쪽 버튼 드래그 또는 두 손가락 터치)
  final bool isScrolling;
  
  const ScrollState({
    this.horizontalOffset = 0.0,
    this.verticalOffset = 0.0,
    this.isScrolling = false,
  });
  
  /// 상태 복사 메서드
  ScrollState copyWith({
    double? horizontalOffset,
    double? verticalOffset,
    bool? isScrolling,
  }) {
    return ScrollState(
      horizontalOffset: horizontalOffset ?? this.horizontalOffset,
      verticalOffset: verticalOffset ?? this.verticalOffset,
      isScrolling: isScrolling ?? this.isScrolling,
    );
  }
  
  @override
  String toString() {
    return 'ScrollState(h: ${horizontalOffset.toStringAsFixed(1)}, v: ${verticalOffset.toStringAsFixed(1)}, scrolling: $isScrolling)';
  }
}

/// 스크롤 상태 관리 Notifier
/// 시간표 그리드의 스크롤 오프셋을 Riverpod로 관리
class ScrollNotifier extends StateNotifier<ScrollState> {
  ScrollNotifier() : super(const ScrollState());
  
  /// 스크롤 오프셋 업데이트
  /// ScrollController의 리스너에서 호출됨
  void updateOffset(double horizontal, double vertical) {
    state = state.copyWith(
      horizontalOffset: horizontal,
      verticalOffset: vertical,
    );
  }
  
  /// 스크롤 중 상태 설정
  /// 마우스 오른쪽 버튼 드래그 또는 두 손가락 터치 시작/종료 시 호출
  void setScrolling(bool isScrolling) {
    state = state.copyWith(isScrolling: isScrolling);
  }
  
  /// 스크롤 상태 리셋
  void reset() {
    state = const ScrollState();
    AppLogger.exchangeDebug('🔄 [스크롤] ScrollProvider 상태 초기화');
  }
}

/// 스크롤 상태 Provider
///
/// 시간표 그리드의 스크롤 오프셋과 상태를 관리합니다.
///
/// **사용 예시:**
/// ```dart
/// // 전체 상태 구독
/// final scrollState = ref.watch(scrollProvider);
///
/// // 특정 필드만 구독 (성능 최적화 - select 사용)
/// final hOffset = ref.watch(scrollProvider.select((s) => s.horizontalOffset));
/// final vOffset = ref.watch(scrollProvider.select((s) => s.verticalOffset));
/// final isScrolling = ref.watch(scrollProvider.select((s) => s.isScrolling));
/// ```
final scrollProvider = StateNotifierProvider<ScrollNotifier, ScrollState>((ref) {
  return ScrollNotifier();
});


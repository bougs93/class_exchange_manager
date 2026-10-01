import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 단일 탭이 지연되지 않는 `InkWell` 대체 위젯
///
/// ## 왜 필요한가
///
/// `InkWell`/`GestureDetector`에 `onTap`과 `onDoubleTap`을 함께 주면,
/// Flutter는 두 번째 탭이 오는지 보려고 `kDoubleTapTimeout`(300ms)만큼
/// 기다린 뒤에야 `onTap`을 실행한다. 사이드바에서 교체 경로를 클릭했을 때
/// 하이라이트와 시간표 반영이 눈에 띄게 늦었던 원인이다.
///
/// Flutter에 오래된 이슈로 올라와 있고(flutter#67255, #113906, #148945)
/// 프레임워크 차원의 해결책은 아직 없다. 공식 대안인
/// `SerialTapGestureRecognizer`를 쓰려면 `RawGestureDetector`로 내려가야 해서
/// `InkWell`의 잉크 효과를 잃는다. 그래서 여기서는 `onTap`만 넘겨 즉시
/// 실행시키고, 연속 탭 판정을 직접 한다 — 겉모습은 그대로 두고 지연만 없앤다.
///
/// ## 동작
///
/// - 첫 탭: 기다리지 않고 바로 [onTap] 실행
/// - [kDoubleTapTimeout] 안에 같은 위젯을 다시 탭: [onDoubleTap] 실행
///
/// 즉 더블탭은 "선택(첫 탭) → 실행(두 번째 탭)" 순서로 일어난다.
/// 기존에도 더블탭 콜백이 선택을 먼저 했으므로 결과는 같고, 첫 탭의 피드백이
/// 즉시 보인다는 점만 달라진다.
class InstantTapInkWell extends StatefulWidget {
  const InstantTapInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final BorderRadius? borderRadius;

  @override
  State<InstantTapInkWell> createState() => _InstantTapInkWellState();
}

class _InstantTapInkWellState extends State<InstantTapInkWell> {
  /// 직전 탭 시각 — 연속 탭 판정용
  DateTime? _lastTapAt;

  void _handleTap() {
    final onDoubleTap = widget.onDoubleTap;
    final now = DateTime.now();

    if (onDoubleTap != null) {
      final last = _lastTapAt;
      if (last != null && now.difference(last) <= kDoubleTapTimeout) {
        _lastTapAt = null; // 세 번째 탭이 또 더블탭이 되지 않도록 초기화
        onDoubleTap();
        return;
      }
    }

    _lastTapAt = now;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    // onTap/onDoubleTap이 모두 없으면 제스처 자체를 달지 않는다.
    if (widget.onTap == null && widget.onDoubleTap == null) {
      return widget.child;
    }

    return InkWell(
      // onDoubleTap은 일부러 넘기지 않는다 — 넘기는 순간 300ms 지연이 생긴다.
      onTap: _handleTap,
      borderRadius: widget.borderRadius,
      child: widget.child,
    );
  }
}

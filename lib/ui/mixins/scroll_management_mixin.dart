import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/scroll_provider.dart';
import '../../utils/logger.dart';

/// 스크롤 관리 공통 믹신
/// 교체 관리 시간표와 결보강 계획서에서 공통으로 사용하는 스크롤 관리 로직
mixin ScrollManagementMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  // 스크롤 컨트롤러들
  late final ScrollController horizontalScrollController;
  late final ScrollController verticalScrollController;

  /// true면 교체 화면 화살표용 전역 scrollProvider에 오프셋을 올립니다.
  /// 시간표 카드 그리드처럼 다른 화면은 false 로 두세요.
  bool get syncScrollToGlobalProvider => true;

  // 드래그 스크롤 시작점과 그때의 스크롤 값
  Offset? _rightClickDragStart;
  double? _rightClickScrollStartH;
  double? _rightClickScrollStartV;

  /// 왼쪽 버튼을 누르기만 한 상태. 조금만 움직이면 칸 선택으로 둔다.
  bool _awaitingLeftSlop = false;

  /// 왼쪽을 끌어 스크롤한 직후, 따라오는 칸 탭을 한 번 무시한다.
  bool _dragScrollBlocksTap = false;

  /// 왼쪽을 이만큼 넘기면 칸 선택이 아니라 스크롤로 본다.
  static const double _leftDragSlop = 8;

  /// 칸 탭 처리 전에 확인한다. 드래그 스크롤 직후면 true.
  bool get dragScrollBlocksTap => _dragScrollBlocksTap;

  /// 웹은 휠(가운데) 버튼, PC는 오른쪽 버튼이 바로 스크롤된다.
  /// 웹의 오른쪽 버튼은 브라우저 메뉴와 겹치므로 쓰지 않는다.
  bool _isImmediatePanButton(int buttons) {
    if (kIsWeb) return buttons == kMiddleMouseButton;
    return buttons == kSecondaryMouseButton;
  }

  void _rememberScrollStart(Offset position) {
    _rightClickDragStart = position;
    _rightClickScrollStartH =
        horizontalScrollController.hasClients
            ? horizontalScrollController.offset
            : 0.0;
    _rightClickScrollStartV =
        verticalScrollController.hasClients
            ? verticalScrollController.offset
            : 0.0;
  }

  void _applyDragDelta(Offset position) {
    final start = _rightClickDragStart;
    final startH = _rightClickScrollStartH;
    final startV = _rightClickScrollStartV;
    if (start == null || startH == null || startV == null) return;

    final delta = position - start;
    if (horizontalScrollController.hasClients) {
      final newH = (startH - delta.dx).clamp(
        0.0,
        horizontalScrollController.position.maxScrollExtent,
      );
      horizontalScrollController.jumpTo(newH);
    }
    if (verticalScrollController.hasClients) {
      final newV = (startV - delta.dy).clamp(
        0.0,
        verticalScrollController.position.maxScrollExtent,
      );
      verticalScrollController.jumpTo(newV);
    }
  }

  void _endDragScroll() {
    final blockedTap = _dragScrollBlocksTap;
    _awaitingLeftSlop = false;
    _rightClickDragStart = null;
    _rightClickScrollStartH = null;
    _rightClickScrollStartV = null;
    _setGlobalScrolling(false);
    if (!blockedTap) return;
    // 칸 탭은 버튼을 뗀 뒤에 오므로, 이번 프레임이 지난 뒤에 푼다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dragScrollBlocksTap = false;
    });
  }

  /// 스크롤 컨트롤러 초기화
  void initializeScrollControllers() {
    horizontalScrollController = ScrollController();
    verticalScrollController = ScrollController();

    // 스크롤 리스너 등록
    horizontalScrollController.addListener(_onScrollChanged);
    verticalScrollController.addListener(_onScrollChanged);

    AppLogger.exchangeDebug('🔄 [스크롤] 스크롤 컨트롤러 초기화 완료');
  }

  /// 스크롤 컨트롤러 해제
  void disposeScrollControllers() {
    // 스크롤 리스너 해제
    horizontalScrollController.removeListener(_onScrollChanged);
    verticalScrollController.removeListener(_onScrollChanged);

    // 컨트롤러 해제
    horizontalScrollController.dispose();
    verticalScrollController.dispose();

    AppLogger.exchangeDebug('🔄 [스크롤] 스크롤 컨트롤러 해제 완료');
  }

  /// 스크롤 변경 시 호출되는 콜백
  void _onScrollChanged() {
    if (!syncScrollToGlobalProvider) return;

    final horizontalOffset =
        horizontalScrollController.hasClients
            ? horizontalScrollController.offset
            : 0.0;
    final verticalOffset =
        verticalScrollController.hasClients
            ? verticalScrollController.offset
            : 0.0;

    // ScrollProvider를 통해 스크롤 상태 업데이트
    ref
        .read(scrollProvider.notifier)
        .updateOffset(horizontalOffset, verticalOffset);
  }

  void _setGlobalScrolling(bool isScrolling) {
    if (!syncScrollToGlobalProvider) return;
    ref.read(scrollProvider.notifier).setScrolling(isScrolling);
  }

  /// 현재 스크롤 오프셋 가져오기
  Map<String, double> getCurrentScrollOffset() {
    return {
      'horizontal':
          horizontalScrollController.hasClients
              ? horizontalScrollController.offset
              : 0.0,
      'vertical':
          verticalScrollController.hasClients
              ? verticalScrollController.offset
              : 0.0,
    };
  }

  /// 스크롤 위치로 이동
  void scrollToPosition({double? horizontal, double? vertical}) {
    if (horizontal != null && horizontalScrollController.hasClients) {
      final clampedH = horizontal.clamp(
        0.0,
        horizontalScrollController.position.maxScrollExtent,
      );
      horizontalScrollController.jumpTo(clampedH);
    }

    if (vertical != null && verticalScrollController.hasClients) {
      final clampedV = vertical.clamp(
        0.0,
        verticalScrollController.position.maxScrollExtent,
      );
      verticalScrollController.jumpTo(clampedV);
    }
  }

  /// 스크롤 상태 리셋
  void resetScrollPosition() {
    scrollToPosition(horizontal: 0.0, vertical: 0.0);
    if (syncScrollToGlobalProvider) {
      ref.read(scrollProvider.notifier).reset();
    }
  }

  /// 드래그 스크롤이 적용된 위젯으로 감싸기.
  ///
  /// 왼쪽은 조금만 움직이면 칸 선택이고, 더 끌면 스크롤이다.
  /// 웹은 휠 버튼, PC는 오른쪽 버튼이 바로 스크롤된다. 모바일은 두 손가락이다.
  Widget wrapWithDragScroll(Widget child) {
    return GestureDetector(
      // 두 손가락 드래그 스크롤 (모바일)
      onScaleStart: (details) {
        if (details.pointerCount == 2) {
          _rightClickDragStart = details.focalPoint;
          _rightClickScrollStartH =
              horizontalScrollController.hasClients
                  ? horizontalScrollController.offset
                  : 0.0;
          _rightClickScrollStartV =
              verticalScrollController.hasClients
                  ? verticalScrollController.offset
                  : 0.0;
          _setGlobalScrolling(true);
        }
      },
      // 포인터가 움직일 때마다 불리는 자리다. 여기에 로그를 넣으면
      // 디버그 빌드에서 이동 한 번에 콘솔 출력이 두 번씩 일어나 스크롤이
      // 끊긴다(웹 console 출력은 특히 비싸다). 로그를 되살리지 말 것.
      onScaleUpdate: (details) {
        if (details.pointerCount == 2 &&
            _rightClickDragStart != null &&
            _rightClickScrollStartH != null &&
            _rightClickScrollStartV != null) {
          final delta = details.focalPoint - _rightClickDragStart!;

          // 수평 스크롤
          if (horizontalScrollController.hasClients) {
            final newH = (_rightClickScrollStartH! - delta.dx).clamp(
              0.0,
              horizontalScrollController.position.maxScrollExtent,
            );
            horizontalScrollController.jumpTo(newH);
          }

          // 수직 스크롤
          if (verticalScrollController.hasClients) {
            final newV = (_rightClickScrollStartV! - delta.dy).clamp(
              0.0,
              verticalScrollController.position.maxScrollExtent,
            );
            verticalScrollController.jumpTo(newV);
          }
        }
      },
      onScaleEnd: (details) {
        _rightClickDragStart = null;
        _rightClickScrollStartH = null;
        _rightClickScrollStartV = null;
        _setGlobalScrolling(false);
      },
      child: Listener(
        onPointerDown: (event) {
          if (_isImmediatePanButton(event.buttons)) {
            _awaitingLeftSlop = false;
            _rememberScrollStart(event.position);
            _setGlobalScrolling(true);
            return;
          }
          if (event.buttons == kPrimaryMouseButton) {
            _awaitingLeftSlop = true;
            _rememberScrollStart(event.position);
          }
        },
        onPointerMove: (event) {
          if (_awaitingLeftSlop &&
              event.buttons == kPrimaryMouseButton &&
              _rightClickDragStart != null) {
            final moved = event.position - _rightClickDragStart!;
            if (moved.distance < _leftDragSlop) return;
            _awaitingLeftSlop = false;
            _dragScrollBlocksTap = true;
            _setGlobalScrolling(true);
          }

          final panning =
              _isImmediatePanButton(event.buttons) ||
              (!_awaitingLeftSlop && event.buttons == kPrimaryMouseButton);
          if (panning) _applyDragDelta(event.position);
        },
        onPointerUp: (event) {
          if (event.buttons == 0) _endDragScroll();
        },
        onPointerCancel: (_) => _endDragScroll(),
        child: child,
      ),
    );
  }
}

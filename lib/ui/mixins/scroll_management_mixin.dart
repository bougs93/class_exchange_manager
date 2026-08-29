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

  // 마우스 오른쪽 버튼 및 두 손가락 드래그 상태
  Offset? _rightClickDragStart;
  double? _rightClickScrollStartH;
  double? _rightClickScrollStartV;

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

  /// 드래그 스크롤이 적용된 위젯으로 감싸기
  /// SfDataGrid를 감싸서 마우스 오른쪽 버튼 및 두 손가락 드래그 스크롤 기능 제공
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
            AppLogger.exchangeDebug(
              '🖱️ [스크롤] 두 손가락 터치 수평 스크롤: ${_rightClickScrollStartH!.toStringAsFixed(1)} → ${newH.toStringAsFixed(1)} (델타: ${delta.dx.toStringAsFixed(1)})',
            );
          }

          // 수직 스크롤
          if (verticalScrollController.hasClients) {
            final newV = (_rightClickScrollStartV! - delta.dy).clamp(
              0.0,
              verticalScrollController.position.maxScrollExtent,
            );
            verticalScrollController.jumpTo(newV);
            AppLogger.exchangeDebug(
              '🖱️ [스크롤] 두 손가락 터치 수직 스크롤: ${_rightClickScrollStartV!.toStringAsFixed(1)} → ${newV.toStringAsFixed(1)} (델타: ${delta.dy.toStringAsFixed(1)})',
            );
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
        // 마우스 오른쪽 버튼 스크롤 (데스크톱)
        onPointerDown: (event) {
          if (event.buttons == kSecondaryMouseButton) {
            _rightClickDragStart = event.position;
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
        onPointerMove: (event) {
          if (event.buttons == kSecondaryMouseButton &&
              _rightClickDragStart != null &&
              _rightClickScrollStartH != null &&
              _rightClickScrollStartV != null) {
            final delta = event.position - _rightClickDragStart!;

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
        onPointerUp: (event) {
          if (event.buttons != kSecondaryMouseButton) {
            _rightClickDragStart = null;
            _rightClickScrollStartH = null;
            _rightClickScrollStartV = null;
            _setGlobalScrolling(false);
          }
        },
        child: child,
      ),
    );
  }
}

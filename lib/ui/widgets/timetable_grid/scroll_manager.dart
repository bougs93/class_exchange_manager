import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../utils/constants.dart';
import 'timetable_grid_constants.dart';

/// 스크롤 관리 클래스
class ScrollManager {
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final VoidCallback onScrollChanged;

  // 드래그 스크롤 관련 변수들
  Offset? _lastPanOffset;
  bool _isDragging = false;

  // 성능 최적화: 스크롤 디바운스 타이머
  Timer? _scrollDebounceTimer;
  DateTime _lastScrollUpdate = DateTime.now();

  ScrollManager({
    required this.verticalScrollController,
    required this.horizontalScrollController,
    required this.onScrollChanged,
  }) {
    verticalScrollController.addListener(_onScrollChangedDebounced);
    horizontalScrollController.addListener(_onScrollChangedDebounced);
  }

  /// 스크롤 변경 시 화살표 재그리기 (성능 최적화된 실시간 업데이트)
  void _onScrollChangedDebounced() {
    DateTime now = DateTime.now();

    // 업데이트 빈도 제한 (60fps = 16ms 간격)
    if (now.difference(_lastScrollUpdate).inMilliseconds < 16) {
      return;
    }

    _lastScrollUpdate = now;
    onScrollChanged();
  }

  /// 마우스 오른쪽 버튼 또는 2손가락 드래그 시작
  void onPanStart(DragStartDetails details) {
    _lastPanOffset = details.localPosition;
    _isDragging = false;
  }

  /// 드래그 업데이트 - 스크롤 실행
  void onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _lastPanOffset == null) return;

    Offset delta = details.localPosition - _lastPanOffset!;

    // 최소 이동 거리 체크 (실수 방지)
    if (delta.distance < 3.0) return;

    // 드래그 방향의 반대로 스크롤
    _scrollByOffset(-delta);

    _lastPanOffset = details.localPosition;
  }

  /// 드래그 종료
  void onPanEnd(DragEndDetails details) {
    _isDragging = false;
    _lastPanOffset = null;
  }

  /// 마우스 버튼 이벤트 처리 (오른쪽 버튼 감지)
  void onMouseDown(PointerDownEvent event) {
    if (event.buttons == kSecondaryButton) {
      _isDragging = true;
      _lastPanOffset = event.localPosition;
    }
  }

  void onMouseUp(PointerUpEvent event) {
    _isDragging = false;
  }

  void onMouseMove(PointerMoveEvent event) {
    if (_isDragging && _lastPanOffset != null) {
      Offset delta = event.localPosition - _lastPanOffset!;

      // 최소 이동 거리 체크
      if (delta.distance < 3.0) return;

      _scrollByOffset(-delta);
      _lastPanOffset = event.localPosition;
    }
  }

  /// 오프셋만큼 스크롤 이동
  void _scrollByOffset(Offset delta) {
    if (horizontalScrollController.hasClients) {
      horizontalScrollController.jumpTo(
        (horizontalScrollController.offset + delta.dx).clamp(
          horizontalScrollController.position.minScrollExtent,
          horizontalScrollController.position.maxScrollExtent,
        ),
      );
    }

    if (verticalScrollController.hasClients) {
      verticalScrollController.jumpTo(
        (verticalScrollController.offset + delta.dy).clamp(
          verticalScrollController.position.minScrollExtent,
          verticalScrollController.position.maxScrollExtent,
        ),
      );
    }
  }

  /// 특정 셀을 화면 중앙으로 스크롤
  void scrollToCell({
    required int teacherIndex,
    required int columnIndex,
    required double zoomFactor,
  }) {
    // 세로 스크롤 계산
    _scrollVertically(teacherIndex, zoomFactor);

    // 가로 스크롤 계산 (첫 번째 열은 고정)
    if (columnIndex > 0) {
      _scrollHorizontally(columnIndex - 1, zoomFactor);
    }
  }

  /// 세로 스크롤 실행
  void _scrollVertically(int teacherIndex, double zoomFactor) {
    if (!verticalScrollController.hasClients) return;

    double targetRowOffset = teacherIndex * AppConstants.dataRowHeight * zoomFactor;

    // 중앙 정렬인 경우 뷰포트 높이의 절반만큼 조정
    if (AppConstants.scrollAlignment == ScrollAlignment.center) {
      double viewportHeight = verticalScrollController.position.viewportDimension;
      double cellHeight = AppConstants.dataRowHeight * zoomFactor;
      targetRowOffset = targetRowOffset - (viewportHeight / 2) + (cellHeight / 2);

      // 스크롤 범위 내로 제한
      targetRowOffset = targetRowOffset.clamp(
        verticalScrollController.position.minScrollExtent,
        verticalScrollController.position.maxScrollExtent,
      );
    }

    verticalScrollController.animateTo(
      targetRowOffset,
      duration: const Duration(milliseconds: ArrowConstants.scrollAnimationMilliseconds),
      curve: Curves.easeInOut,
    );
  }

  /// 가로 스크롤 실행
  void _scrollHorizontally(int scrollableColumnIndex, double zoomFactor) {
    if (!horizontalScrollController.hasClients) return;

    double targetColumnOffset = scrollableColumnIndex * AppConstants.periodColumnWidth * zoomFactor;

    // 중앙 정렬인 경우 뷰포트 너비의 절반만큼 조정
    if (AppConstants.scrollAlignment == ScrollAlignment.center) {
      double viewportWidth = horizontalScrollController.position.viewportDimension;
      double cellWidth = AppConstants.periodColumnWidth * zoomFactor;
      targetColumnOffset = targetColumnOffset - (viewportWidth / 2) + (cellWidth / 2);

      // 스크롤 범위 내로 제한
      targetColumnOffset = targetColumnOffset.clamp(
        horizontalScrollController.position.minScrollExtent,
        horizontalScrollController.position.maxScrollExtent,
      );
    }

    horizontalScrollController.animateTo(
      targetColumnOffset,
      duration: const Duration(milliseconds: ArrowConstants.scrollAnimationMilliseconds),
      curve: Curves.easeInOut,
    );
  }

  /// 리소스 정리
  void dispose() {
    _scrollDebounceTimer?.cancel();
    verticalScrollController.removeListener(_onScrollChangedDebounced);
    horizontalScrollController.removeListener(_onScrollChangedDebounced);
  }
}

import 'package:flutter/material.dart';
import 'timetable_grid_constants.dart';
import '../../../utils/simplified_timetable_theme.dart';

/// 그리드 확대/축소 관리 클래스
class ZoomManager {
  double _zoomFactor = GridLayoutConstants.defaultZoomFactor;
  final VoidCallback onZoomChanged;

  ZoomManager({required this.onZoomChanged});

  /// 현재 확대 비율
  double get zoomFactor => _zoomFactor;

  /// 현재 확대 비율을 퍼센트로 반환
  int get zoomPercentage => (_zoomFactor * 100).round();

  /// 그리드 확대
  void zoomIn() {
    if (_zoomFactor < GridLayoutConstants.maxZoom) {
      _zoomFactor = (_zoomFactor + GridLayoutConstants.zoomStep)
          .clamp(GridLayoutConstants.minZoom, GridLayoutConstants.maxZoom);
      SimplifiedTimetableTheme.setFontScaleFactor(_zoomFactor);
      onZoomChanged();
    }
  }

  /// 그리드 축소
  void zoomOut() {
    if (_zoomFactor > GridLayoutConstants.minZoom) {
      _zoomFactor = (_zoomFactor - GridLayoutConstants.zoomStep)
          .clamp(GridLayoutConstants.minZoom, GridLayoutConstants.maxZoom);
      SimplifiedTimetableTheme.setFontScaleFactor(_zoomFactor);
      onZoomChanged();
    }
  }

  /// 확대/축소 초기화
  void resetZoom() {
    _zoomFactor = GridLayoutConstants.defaultZoomFactor;
    SimplifiedTimetableTheme.setFontScaleFactor(GridLayoutConstants.defaultZoomFactor);
    onZoomChanged();
  }

  /// 초기 폰트 배율 설정
  void initialize() {
    SimplifiedTimetableTheme.setFontScaleFactor(_zoomFactor);
  }

  /// 리소스 정리
  void dispose() {
    // 필요한 경우 리소스 정리
  }
}

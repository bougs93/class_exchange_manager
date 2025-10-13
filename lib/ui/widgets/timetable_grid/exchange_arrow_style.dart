import 'package:flutter/material.dart';
import 'timetable_grid_constants.dart';

/// 교체 모드별 화살표 스타일을 정의하는 클래스
class ExchangeArrowStyle {
  final Color color;           // 화살표 색상
  final double strokeWidth;    // 선 두께
  final Color outlineColor;    // 외곽선 색상
  final double outlineWidth;   // 외곽선 두께
  final double arrowHeadSize;  // 화살표 머리 크기
  final ArrowDirection direction; // 화살표 방향

  const ExchangeArrowStyle({
    required this.color,
    this.strokeWidth = 3.0,
    this.outlineColor = Colors.white,
    this.outlineWidth = 5.0,
    this.arrowHeadSize = 12.0,
    this.direction = ArrowDirection.forward,
  });

  /// 1:1 교체 모드용 스타일 (단방향 - 별도 화살표로 양방향 구현)
  static const ExchangeArrowStyle oneToOne = ExchangeArrowStyle(
    color: Colors.green,
    strokeWidth: 3.0,
    outlineColor: Colors.white,
    outlineWidth: 5.0,
    arrowHeadSize: 12.0,
    direction: ArrowDirection.forward,
  );

  /// 순환 교체 모드용 스타일 (단방향)
  static const ExchangeArrowStyle circular = ExchangeArrowStyle(
    color: Color(0xFFB894B8), // 보라색 (#B894B8)
    strokeWidth: 2.5,
    outlineColor: Colors.white,
    outlineWidth: 4.5,
    arrowHeadSize: 10.0,
    direction: ArrowDirection.forward,
  );

  /// 연쇄 교체 모드용 스타일 (양방향)
  static const ExchangeArrowStyle chain = ExchangeArrowStyle(
    color: Color(0xFFFF8C69), // 주황색 (#FF8C69)
    strokeWidth: 2.0,
    outlineColor: Colors.white,
    outlineWidth: 4.0,
    arrowHeadSize: 8.0,
    direction: ArrowDirection.bidirectional,
  );

  /// 보강 교체 모드용 스타일 (단방향)
  static const ExchangeArrowStyle supplement = ExchangeArrowStyle(
    color: Color(0xFF20B2AA), // 틸 색상 (#20B2AA)
    strokeWidth: 2.5,
    outlineColor: Colors.white,
    outlineWidth: 4.5,
    arrowHeadSize: 10.0,
    direction: ArrowDirection.forward,
  );
}

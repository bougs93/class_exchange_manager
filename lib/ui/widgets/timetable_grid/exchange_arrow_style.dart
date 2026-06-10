import 'package:flutter/material.dart';
import 'timetable_grid_constants.dart';

/// 교체 모드별 화살표 스타일을 정의하는 클래스
class ExchangeArrowStyle {
  final Color color; // 화살표 색상
  final double strokeWidth; // 선 두께
  final Color outlineColor; // 외곽선 색상
  final double outlineWidth; // 외곽선 두께
  final double arrowHeadSize; // 화살표 머리 크기
  final ArrowDirection direction; // 화살표 방향

  const ExchangeArrowStyle({
    required this.color,
    this.strokeWidth = 3.0,
    this.outlineColor = Colors.white,
    this.outlineWidth = 5.0,
    this.arrowHeadSize = 12.0,
    this.direction = ArrowDirection.forward,
  });

  /// 일부 속성만 교체한 새 스타일 생성
  ///
  /// 화살표 머리 크기·방향을 런타임 설정에 맞춰 조정할 때 사용한다.
  ExchangeArrowStyle copyWith({
    Color? color,
    double? strokeWidth,
    Color? outlineColor,
    double? outlineWidth,
    double? arrowHeadSize,
    ArrowDirection? direction,
  }) {
    return ExchangeArrowStyle(
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      arrowHeadSize: arrowHeadSize ?? this.arrowHeadSize,
      direction: direction ?? this.direction,
    );
  }

  /// 1:1 교체 모드용 스타일 (방향은 설정에 따라 런타임에 적용)
  static const ExchangeArrowStyle oneToOne = ExchangeArrowStyle(
    color: Colors.green,
    strokeWidth: 3.0,
    outlineColor: Colors.white,
    outlineWidth: 5.0,
    arrowHeadSize: 12.0,
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

  /// 2중 교체 모드용 스타일 (방향은 설정에 따라 런타임에 적용)
  static const ExchangeArrowStyle dual = ExchangeArrowStyle(
    color: Color(0xFFFF8C69), // 주황색 (#FF8C69)
    strokeWidth: 2.0,
    outlineColor: Colors.white,
    outlineWidth: 4.0,
    arrowHeadSize: 8.0,
  );

  /// 보강 모드용 스타일 (단방향)
  static const ExchangeArrowStyle supplement = ExchangeArrowStyle(
    color: Color(0xFF20B2AA), // 틸 색상 (#20B2AA)
    strokeWidth: 2.5,
    outlineColor: Colors.white,
    outlineWidth: 4.5,
    arrowHeadSize: 10.0,
    direction: ArrowDirection.forward,
  );
}

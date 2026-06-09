import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 셀·범례에 표시하는 교체 상태 기호 종류

enum CellStatusSymbolType {
  /// 빠진 수업 — 맡은 수업 O와 동일한 색·투명도의 X
  missedClass,

  /// 맡은 수업 — 반투명 O
  takenClass,

  /// 교체 불가 수업 — 반투명 빨간 채움 + X
  nonExchangeable,
}

/// 빠진 수업·맡은 수업·교체 불가 수업 셀 위에 표시하는 상태 오버레이

class ExchangedCellStatusOverlay extends StatelessWidget {
  final CellStatusSymbolType type;

  const ExchangedCellStatusOverlay({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(child: ExchangedStatusSymbol(type: type)),
    );
  }
}

/// 범례·셀 공통 — 빠진 수업(X)·맡은 수업(O)·교체 불가(X) 기호를 그립니다.

class ExchangedStatusSymbol extends StatelessWidget {
  final CellStatusSymbolType type;

  const ExchangedStatusSymbol({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: ExchangedStatusPainter(type: type));
  }
}

/// X·O 기호와 반투명 배경을 그리는 Painter

class ExchangedStatusPainter extends CustomPainter {
  /// 맡은 수업 O·빠진 수업 X 공통 색상·투명도
  static const Color _takenClassSymbolColor = Color(0xFF1565C0);
  static const double _takenClassSymbolAlpha = 0.74;

  static const Color _nonExchangeableColor = Color(0xFFC62828);

  final CellStatusSymbolType type;

  const ExchangedStatusPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    switch (type) {
      case CellStatusSymbolType.missedClass:
        _paintClassX(
          canvas,
          size,
          center,
          _takenClassSymbolColor,
          fillAlpha: 0,
          strokeAlpha: _takenClassSymbolAlpha,
        );

      case CellStatusSymbolType.nonExchangeable:
        _paintClassX(
          canvas,
          size,
          center,
          _nonExchangeableColor,
          fillAlpha: 0.14,
          strokeAlpha: 0.58,
        );

      case CellStatusSymbolType.takenClass:
        _paintTakenClassCircle(canvas, size, center);
    }
  }

  /// 빠진 수업·교체 불가 — 반투명 채움 + X

  void _paintClassX(
    Canvas canvas,

    Size size,

    Offset center,

    Color color, {

    double fillAlpha = 0.22,

    double strokeAlpha = 0.8,
  }) {
    final symbolRadius = math.min(size.width, size.height) * 0.28;

    final strokeWidth = math.max(1.5, symbolRadius * 0.22);

    if (fillAlpha > 0) {
      final fillPaint =
          Paint()
            ..color = color.withValues(alpha: fillAlpha)
            ..style = PaintingStyle.fill;
      canvas.drawRect(Offset.zero & size, fillPaint);
    }

    final strokePaint =
        Paint()
          ..color = color.withValues(alpha: strokeAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center.translate(-symbolRadius, -symbolRadius),

      center.translate(symbolRadius, symbolRadius),

      strokePaint,
    );

    canvas.drawLine(
      center.translate(symbolRadius, -symbolRadius),

      center.translate(-symbolRadius, symbolRadius),

      strokePaint,
    );
  }

  /// 맡은 수업 O — 크고 옅은 원으로 중앙 글자가 비치도록 그립니다.

  void _paintTakenClassCircle(Canvas canvas, Size size, Offset center) {
    final symbolRadius = math.min(size.width, size.height) * 0.38;

    final strokeWidth = math.max(1.2, symbolRadius * 0.12);

    final ringPaint =
        Paint()
          ..color = _takenClassSymbolColor.withValues(
            alpha: _takenClassSymbolAlpha,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 1.1
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, symbolRadius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant ExchangedStatusPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}

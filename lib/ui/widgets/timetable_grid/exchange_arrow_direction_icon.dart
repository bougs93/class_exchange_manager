import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'timetable_grid_constants.dart';

/// 설정 화면에서 교체 화살표 표시 방식을 미리보기하는 아이콘
///
/// - [singleLine] true: 가로 단방향 화살표 1개 (→, 연쇄교체)
/// - 양방향: 가로 직선 1개 + 양쪽 화살표 머리 (↔)
/// - 단방향: 가로 직선 2개 + 각각 한쪽 화살표 머리 (→, ←)
class ExchangeArrowDirectionIcon extends StatelessWidget {
  final ArrowDirection direction;
  final Color color;

  /// 연쇄교체 등 단방향 화살표 1개만 표시할 때 true
  final bool singleLine;

  final double width;
  final double height;

  const ExchangeArrowDirectionIcon({
    super.key,
    required this.direction,
    this.color = Colors.green,
    this.singleLine = false,
    this.width = 44,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    final String semanticsLabel;
    if (singleLine) {
      semanticsLabel = '단방향 1개 화살표';
    } else if (direction == ArrowDirection.forward) {
      semanticsLabel = '단방향 2개 화살표';
    } else {
      semanticsLabel = '양방향 1개 화살표';
    }

    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _ExchangeArrowDirectionIconPainter(
            direction: direction,
            color: color,
            singleLine: singleLine,
          ),
        ),
      ),
    );
  }
}

class _ExchangeArrowDirectionIconPainter extends CustomPainter {
  final ArrowDirection direction;
  final Color color;
  final bool singleLine;

  _ExchangeArrowDirectionIconPainter({
    required this.direction,
    required this.color,
    this.singleLine = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padX = size.width * 0.08;
    final left = padX;
    final right = size.width - padX;

    if (singleLine) {
      final y = size.height / 2;
      _drawHorizontalArrow(
        canvas,
        Offset(left, y),
        Offset(right, y),
        bidirectional: false,
      );
      return;
    }

    if (direction == ArrowDirection.bidirectional) {
      // 가로 양방향 화살표 1개 (중앙)
      final y = size.height / 2;
      _drawHorizontalArrow(
        canvas,
        Offset(left, y),
        Offset(right, y),
        bidirectional: true,
      );
    } else {
      // 가로 단방향 화살표 2개 (위: →, 아래: ←)
      final gap = size.height * 0.22;
      final yTop = size.height / 2 - gap;
      final yBottom = size.height / 2 + gap;
      _drawHorizontalArrow(
        canvas,
        Offset(left, yTop),
        Offset(right, yTop),
        bidirectional: false,
      );
      _drawHorizontalArrow(
        canvas,
        Offset(right, yBottom),
        Offset(left, yBottom),
        bidirectional: false,
      );
    }
  }

  /// 가로 직선 화살표 (흰색 외곽선 + 색상 내부선)
  void _drawHorizontalArrow(
    Canvas canvas,
    Offset start,
    Offset end, {
    required bool bidirectional,
  }) {
    const innerWidth = 2.0;
    const outlineWidth = 3.2;

    final outlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = outlineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final innerPaint = Paint()
      ..color = color
      ..strokeWidth = innerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, outlinePaint);
    canvas.drawLine(start, end, innerPaint);

    _drawArrowHead(canvas, start, end, innerWidth, outlineWidth);
    if (bidirectional) {
      _drawArrowHead(canvas, end, start, innerWidth, outlineWidth);
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset from,
    Offset to,
    double innerWidth,
    double outlineWidth,
  ) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const headLength = 5.0;
    const headAngle = math.pi / 6;

    final p1 = Offset(
      to.dx - headLength * math.cos(angle - headAngle),
      to.dy - headLength * math.sin(angle - headAngle),
    );
    final p2 = Offset(
      to.dx - headLength * math.cos(angle + headAngle),
      to.dy - headLength * math.sin(angle + headAngle),
    );

    final outlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = outlineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final innerPaint = Paint()
      ..color = color
      ..strokeWidth = innerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final paint in [outlinePaint, innerPaint]) {
      canvas.drawLine(to, p1, paint);
      canvas.drawLine(to, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExchangeArrowDirectionIconPainter oldDelegate) {
    return oldDelegate.direction != direction ||
        oldDelegate.color != color ||
        oldDelegate.singleLine != singleLine;
  }
}

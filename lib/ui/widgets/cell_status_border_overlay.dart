import 'package:flutter/material.dart';

/// 레이아웃에 영향 없이 셀 위에 그리는 상태 테두리 정보
class CellStatusBorder {
  final Color color;
  final double width;

  const CellStatusBorder({
    required this.color,
    required this.width,
  });
}

/// 상태 테두리를 셀 안쪽에 오버레이로 그립니다 (텍스트 영역 유지).
class CellStatusBorderOverlay extends StatelessWidget {
  final CellStatusBorder border;

  const CellStatusBorderOverlay({
    super.key,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: CellStatusBorderPainter(
            color: border.color,
            strokeWidth: border.width,
          ),
        ),
      ),
    );
  }
}

/// 셀 안쪽 inset 사각형 테두리 Painter
class CellStatusBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CellStatusBorderPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final half = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      half,
      half,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CellStatusBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

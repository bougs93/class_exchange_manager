import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/scroll_provider.dart';
import '../../../providers/zoom_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/overlay_date_chip_layout.dart';
import 'timetable_grid_constants.dart';

/// 날짜 꼬리표 층. 칸 목록은 밖에서 만들고, 줌·스크롤만 여기서 따라간다.
class OverlayDateChipLayer extends ConsumerWidget {
  final List<OverlayDateMark> marks;

  const OverlayDateChipLayer({super.key, required this.marks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (marks.isEmpty) return const SizedBox.shrink();

    final zoomFactor = ref.watch(zoomProvider.select((s) => s.zoomFactor));
    final scrollState = ref.watch(scrollProvider);
    return IgnorePointer(
      child: CustomPaint(
        painter: OverlayDateChipPainter(
          marks: marks,
          zoomFactor: zoomFactor,
          scrollOffset: Offset(
            scrollState.horizontalOffset,
            scrollState.verticalOffset,
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 교체된 칸의 날짜 꼬리표를 그리드 위에 그린다.
///
/// 셀 위젯 안이 아니라 화살표와 같은 층에 그려, 학년-반 글자 배치는 그대로 둔다.
class OverlayDateChipPainter extends CustomPainter {
  final List<OverlayDateMark> marks;
  final double zoomFactor;
  final Offset scrollOffset;

  OverlayDateChipPainter({
    required this.marks,
    required this.zoomFactor,
    required this.scrollOffset,
  });

  static const double _fontSize = 8;
  static const double _horizontalPadding = 2;
  static const double _verticalPadding = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (marks.isEmpty || size.width <= 0 || size.height <= 0) return;

    final rowHeight = AppConstants.dataRowHeight * zoomFactor;
    final frames = OverlayDateChipPlacer.place(
      marks: marks,
      cellOrigin: _cellOrigin,
      columnWidth: _columnWidth,
      rowHeight: rowHeight,
      chipSize: _chipSize,
      gap: zoomFactor,
    );

    canvas.save();
    canvas.clipRect(_scrollableClip(size));
    final background =
        Paint()..color = Colors.black.withValues(alpha: 0.55);
    for (final frame in frames) {
      _paintChip(canvas, frame, background);
    }
    canvas.restore();
  }

  void _paintChip(Canvas canvas, OverlayDateChipFrame frame, Paint background) {
    final radius = Radius.circular(3 * zoomFactor);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame.rect, radius),
      background,
    );

    final painter = _textPainter(frame.mark.label)..layout();
    painter.paint(
      canvas,
      Offset(
        frame.rect.left + (frame.rect.width - painter.width) / 2,
        frame.rect.top + (frame.rect.height - painter.height) / 2,
      ),
    );
  }

  Size _chipSize(OverlayDateMark mark) {
    final painter = _textPainter(mark.label)..layout();
    return Size(
      painter.width + _horizontalPadding * 2 * zoomFactor,
      painter.height + _verticalPadding * 2 * zoomFactor,
    );
  }

  TextPainter _textPainter(String label) {
    return TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: _fontSize * zoomFactor,
          height: 1.1,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
  }

  /// 교사명 열과 헤더 위에는 그리지 않는다. 스크롤해도 헤더·교사명을 덮지 않게.
  Rect _scrollableClip(Size size) {
    final frozenColumnWidth = AppConstants.teacherColumnWidth * zoomFactor;
    final headerHeight =
        AppConstants.headerRowHeight *
        GridLayoutConstants.headerRowsCount *
        zoomFactor;
    return Rect.fromLTWH(
      frozenColumnWidth,
      headerHeight,
      size.width - frozenColumnWidth,
      size.height - headerHeight,
    );
  }

  /// 화살표와 같은 셀 좌상단 좌표 (헤더·스크롤·고정 열 반영)
  Offset _cellOrigin(int columnIndex, int teacherIndex) {
    double x = 0;
    for (var i = 0; i < columnIndex; i++) {
      x += _columnWidth(i);
    }

    var y =
        AppConstants.headerRowHeight *
        GridLayoutConstants.headerRowsCount *
        zoomFactor;
    y += teacherIndex * AppConstants.dataRowHeight * zoomFactor;

    final horizontalOffset = columnIndex == 0 ? 0.0 : scrollOffset.dx;
    x -= horizontalOffset;
    y -= scrollOffset.dy;
    return Offset(x, y);
  }

  double _columnWidth(int columnIndex) {
    final base =
        columnIndex == 0
            ? AppConstants.teacherColumnWidth
            : AppConstants.periodColumnWidth;
    return base * zoomFactor;
  }

  @override
  bool shouldRepaint(covariant OverlayDateChipPainter oldDelegate) {
    if (oldDelegate.zoomFactor != zoomFactor ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.marks.length != marks.length) {
      return true;
    }
    for (var i = 0; i < marks.length; i++) {
      if (oldDelegate.marks[i] != marks[i]) return true;
    }
    return false;
  }
}

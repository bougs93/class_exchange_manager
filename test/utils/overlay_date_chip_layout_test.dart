import 'package:class_exchange_manager/utils/overlay_date_chip_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _chip = Size(20, 10);
const _rowHeight = 25.0;
const _headerHeight = 50.0;

Offset _origin(int column, int teacher) {
  final x = column == 0 ? 0.0 : 40 + (column - 1) * 35.0;
  return Offset(x, _headerHeight + teacher * _rowHeight);
}

double _width(int column) => column == 0 ? 40 : 35;

List<OverlayDateChipFrame> _place(List<OverlayDateMark> marks) {
  return OverlayDateChipPlacer.place(
    marks: marks,
    cellOrigin: _origin,
    columnWidth: _width,
    rowHeight: _rowHeight,
    chipSize: (_) => _chip,
  );
}

void main() {
  test('1행 칩은 칸 아래에 있고 헤더 쪽으로 넘어가지 않는다', () {
    final frame = _place([
      const OverlayDateMark(teacherIndex: 0, columnIndex: 1, label: '9.28'),
    ]).single;

    final cellTop = _origin(1, 0).dy;
    final cellBottom = cellTop + _rowHeight;

    expect(frame.rect.top, greaterThanOrEqualTo(cellTop));
    expect(frame.rect.bottom, cellBottom);
    expect(frame.rect.center.dx, _origin(1, 0).dx + _width(1) / 2);
  });

  test('2행 칩은 칸 위쪽 선 한가운데에 걸린다', () {
    final frame = _place([
      const OverlayDateMark(teacherIndex: 1, columnIndex: 2, label: '9.30'),
    ]).single;

    final cellTop = _origin(2, 1).dy;

    expect(frame.rect.center.dy, cellTop);
    expect(frame.rect.center.dx, _origin(2, 1).dx + _width(2) / 2);
  });

  test('같은 열의 1행과 2행 칩은 겹치지 않는다', () {
    final frames = _place([
      const OverlayDateMark(teacherIndex: 0, columnIndex: 1, label: '9.28'),
      const OverlayDateMark(teacherIndex: 1, columnIndex: 1, label: '9.30'),
    ]);

    expect(frames[0].rect.overlaps(frames[1].rect), isFalse);
    expect(frames[0].rect.bottom, lessThan(frames[1].rect.top));
    expect(frames[0].rect.top, greaterThanOrEqualTo(_origin(1, 0).dy));
    // 2행은 선 위에 그대로 걸린다.
    expect(frames[1].rect.center.dy, _origin(1, 1).dy);
  });
}

import 'dart:ui';

/// 날짜 꼬리표를 그릴 칸
class OverlayDateMark {
  final int teacherIndex;
  final int columnIndex;
  final String label;

  const OverlayDateMark({
    required this.teacherIndex,
    required this.columnIndex,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      other is OverlayDateMark &&
      other.teacherIndex == teacherIndex &&
      other.columnIndex == columnIndex &&
      other.label == label;

  @override
  int get hashCode => Object.hash(teacherIndex, columnIndex, label);
}

/// 배치된 날짜 꼬리표의 화면 좌표
class OverlayDateChipFrame {
  final OverlayDateMark mark;
  final Rect rect;

  const OverlayDateChipFrame({required this.mark, required this.rect});
}

/// 날짜 꼬리표 위치
///
/// 칸 글자 배치는 바꾸지 않고, 칩만 칸 경계에 올린다.
/// - 2행부터: 칸 위쪽 가로선 한가운데. 절반은 앞 칸, 절반은 이 칸 위쪽.
/// - 1행: 교시 헤더와 만나지 않도록 칩 전체를 칸 아래에 둔다.
/// - 같은 열의 1행·2행이 같이 있으면, 2행 칩이 올라오는 만큼 1행 칩을 위로 밀어
///   서로 겹치지 않게 한다. 1행 칩은 칸 위(헤더)로는 넘지 않는다.
class OverlayDateChipPlacer {
  const OverlayDateChipPlacer._();

  static List<OverlayDateChipFrame> place({
    required List<OverlayDateMark> marks,
    required Offset Function(int columnIndex, int teacherIndex) cellOrigin,
    required double Function(int columnIndex) columnWidth,
    required double rowHeight,
    required Size Function(OverlayDateMark mark) chipSize,
    double gap = 1,
  }) {
    final secondRowByColumn = <int, OverlayDateMark>{
      for (final mark in marks)
        if (mark.teacherIndex == 1) mark.columnIndex: mark,
    };

    return [
      for (final mark in marks)
        OverlayDateChipFrame(
          mark: mark,
          rect: _rectFor(
            mark,
            cellOrigin: cellOrigin(mark.columnIndex, mark.teacherIndex),
            columnWidth: columnWidth(mark.columnIndex),
            rowHeight: rowHeight,
            chipSize: chipSize(mark),
            lowerChipHeight:
                mark.teacherIndex == 0
                    ? chipSize(secondRowByColumn[mark.columnIndex] ?? mark)
                        .height
                    : null,
            liftForRowBelow:
                mark.teacherIndex == 0 &&
                secondRowByColumn.containsKey(mark.columnIndex),
            gap: gap,
          ),
        ),
    ];
  }

  static Rect _rectFor(
    OverlayDateMark mark, {
    required Offset cellOrigin,
    required double columnWidth,
    required double rowHeight,
    required Size chipSize,
    required double? lowerChipHeight,
    required bool liftForRowBelow,
    required double gap,
  }) {
    final left = cellOrigin.dx + (columnWidth - chipSize.width) / 2;

    if (mark.teacherIndex == 0) {
      var bottom = cellOrigin.dy + rowHeight;
      if (liftForRowBelow && lowerChipHeight != null) {
        // 2행 칩은 공유 선 위로 자기 높이의 절반만큼 올라온다.
        bottom -= lowerChipHeight / 2 + gap;
      }
      var top = bottom - chipSize.height;
      // 위로 밀어도 교시 헤더(칸 위쪽 선)는 넘지 않는다.
      if (top < cellOrigin.dy) {
        top = cellOrigin.dy;
      }
      return Rect.fromLTWH(left, top, chipSize.width, bottom - top);
    }

    // 위쪽 선 한가운데에 걸친다.
    final top = cellOrigin.dy - chipSize.height / 2;
    return Rect.fromLTWH(left, top, chipSize.width, chipSize.height);
  }
}

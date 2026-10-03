import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/arrow_geometry.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/timetable_grid_constants.dart';

void main() {
  group('ArrowGeometry.offsetAlongEdge', () {
    test('top 모서리는 x 성분만 적용한다', () {
      final result = ArrowGeometry.offsetAlongEdge(
        ArrowEdge.top,
        const Offset(7.0, 7.0),
      );
      expect(result, const Offset(7.0, 0));
    });

    test('right 모서리는 y 성분만 적용한다', () {
      final result = ArrowGeometry.offsetAlongEdge(
        ArrowEdge.right,
        const Offset(7.0, 7.0),
      );
      expect(result, const Offset(0, 7.0));
    });
  });

  group('ArrowGeometry.lineIntersectsRect', () {
    final rect = Rect.fromLTWH(10, 10, 100, 100);

    test('선분이 완전히 사각형 내부에 있으면 true', () {
      final result = ArrowGeometry.lineIntersectsRect(
        const Offset(20, 20),
        const Offset(50, 50),
        rect,
      );
      expect(result, isTrue);
    });

    test('선분이 사각형과 완전히 떨어져 있으면 false', () {
      final result = ArrowGeometry.lineIntersectsRect(
        const Offset(200, 200),
        const Offset(300, 300),
        rect,
      );
      expect(result, isFalse);
    });

    test('수직선이 사각형의 세로 범위를 관통하면 true', () {
      final result = ArrowGeometry.lineIntersectsRect(
        const Offset(50, 0),
        const Offset(50, 200),
        rect,
      );
      expect(result, isTrue);
    });

    test('수평선이 사각형의 가로 범위를 관통하면 true', () {
      final result = ArrowGeometry.lineIntersectsRect(
        const Offset(0, 50),
        const Offset(200, 50),
        rect,
      );
      expect(result, isTrue);
    });

    test('수직선이 사각형의 x 범위 밖에 있으면 false', () {
      final result = ArrowGeometry.lineIntersectsRect(
        const Offset(500, 0),
        const Offset(500, 200),
        rect,
      );
      expect(result, isFalse);
    });
  });

  group('ArrowGeometry.isPointInVisibleArea', () {
    const canvasSize = Size(500, 500);
    const frozenColumnWidth = 40.0;
    const headerHeight = 50.0;

    test('고정 영역과 헤더 아래, 캔버스 내부의 점은 보이는 영역에 있다', () {
      final result = ArrowGeometry.isPointInVisibleArea(
        const Offset(100, 100),
        canvasSize,
        frozenColumnWidth,
        headerHeight,
      );
      expect(result, isTrue);
    });

    test('고정 열 내부(왼쪽)의 점은 보이는 영역이 아니다', () {
      final result = ArrowGeometry.isPointInVisibleArea(
        const Offset(10, 100),
        canvasSize,
        frozenColumnWidth,
        headerHeight,
      );
      expect(result, isFalse);
    });

    test('헤더 영역(위쪽)의 점은 보이는 영역이 아니다', () {
      final result = ArrowGeometry.isPointInVisibleArea(
        const Offset(100, 10),
        canvasSize,
        frozenColumnWidth,
        headerHeight,
      );
      expect(result, isFalse);
    });
  });

  group('ArrowGeometry.getCellCenterPosition', () {
    test('스크롤 오프셋이 0일 때 0번 열, 0번 행의 중앙 좌표를 계산한다', () {
      // columnWidth(0) = teacherColumnWidth(40.0) * zoom(1.0) = 40.0
      // rowHeight = dataRowHeight(25.0) * zoom(1.0) = 25.0
      // origin.y = headerRowHeight(25.0) * headerRowsCount(2) * zoom(1.0) = 50.0
      final result = ArrowGeometry.getCellCenterPosition(
        0,
        0,
        1.0,
        Offset.zero,
      );
      expect(result, const Offset(20.0, 62.5));
    });

    test('줌 배율과 스크롤 오프셋이 적용된 1번 열, 2번 행의 중앙 좌표를 계산한다', () {
      // columnWidth(0) = 40 * 2.0 = 80 (고정 열, x 누적용)
      // columnWidth(1) = periodColumnWidth(35.0) * 2.0 = 70
      // origin.x = 80 - scrollOffset.dx(10) = 70
      // origin.y = (25*2*2.0) + 2*(25*2.0) - scrollOffset.dy(5) = 100 + 100 - 5 = 195
      // center = origin + (70/2, 50/2) = (70+35, 195+25) = (105, 220)
      final result = ArrowGeometry.getCellCenterPosition(
        1,
        2,
        2.0,
        const Offset(10, 5),
      );
      expect(result, const Offset(105.0, 220.0));
    });
  });

  group('ArrowGeometry.getCellEdgeCenterPosition', () {
    test('top 경계면은 셀 상단 가로 중앙을 반환한다', () {
      final result = ArrowGeometry.getCellEdgeCenterPosition(
        0,
        0,
        ArrowEdge.top,
        1.0,
        Offset.zero,
      );
      expect(result, const Offset(20.0, 50.0));
    });

    test('right 경계면은 셀 오른쪽 세로 중앙을 반환한다', () {
      final result = ArrowGeometry.getCellEdgeCenterPosition(
        0,
        0,
        ArrowEdge.right,
        1.0,
        Offset.zero,
      );
      expect(result, const Offset(40.0, 62.5));
    });
  });

  group('ArrowGeometry.determineArrowEdges', () {
    test('verticalFirst: 목표가 아래쪽 + 오른쪽이면 bottom/left', () {
      final result = ArrowGeometry.determineArrowEdges(
        0,
        0,
        1,
        1,
        ArrowPriority.verticalFirst,
      );
      expect(result['start'], ArrowEdge.bottom);
      expect(result['end'], ArrowEdge.left);
    });

    test('horizontalFirst: 목표가 아래쪽 + 오른쪽이면 right/top', () {
      final result = ArrowGeometry.determineArrowEdges(
        0,
        0,
        1,
        1,
        ArrowPriority.horizontalFirst,
      );
      expect(result['start'], ArrowEdge.right);
      expect(result['end'], ArrowEdge.top);
    });
  });
}

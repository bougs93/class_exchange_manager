import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../utils/constants.dart';
import 'timetable_grid_constants.dart';

/// 화살표 좌표/가시성 계산을 담당하는 순수 유틸리티 클래스
///
/// [ExchangeArrowPainter]에서 분리된 순수 기하 연산 모음이다.
/// `Canvas`를 다루지 않고, 숫자/불리언만 입출력하며 부수효과가 없다.
/// (이동 전 동작과 100% 동일하도록 로직/리터럴을 그대로 옮겼다.)
class ArrowGeometry {
  ArrowGeometry._(); // 인스턴스화 방지 (static 메서드 전용)

  /// 셀 모서리의 접선 방향으로만 오프셋을 적용한다.
  ///
  /// 끝점이 셀 경계(모서리) 위에 그대로 남도록, 모서리에 수직인 성분은 버리고
  /// 모서리를 따라 미끄러지는 성분만 사용한다.
  /// - 상/하단(수평) 모서리: x 성분만 적용
  /// - 좌/우(수직) 모서리: y 성분만 적용
  static Offset offsetAlongEdge(ArrowEdge edge, Offset offset) {
    switch (edge) {
      case ArrowEdge.top:
      case ArrowEdge.bottom:
        return Offset(offset.dx, 0);
      case ArrowEdge.left:
      case ArrowEdge.right:
        return Offset(0, offset.dy);
    }
  }

  /// 화살표가 화면 영역 내에 있는지 검사하는 메서드
  /// 고정 영역과 스크롤 영역을 모두 고려
  ///
  /// [sourcePos] 화살표 시작점 좌표
  /// [targetPos] 화살표 끝점 좌표
  /// [canvasSize] 캔버스 크기
  /// [zoomFactor] 확대/축소 배율 (고정 영역 경계 계산용)
  ///
  /// Returns: bool - 화살표가 화면에 보이는지 여부
  static bool isArrowVisible(
    Offset sourcePos,
    Offset targetPos,
    Size canvasSize,
    double zoomFactor,
  ) {
    // 고정 영역 경계 (확대/축소 배율 적용)
    double frozenColumnWidth = AppConstants.teacherColumnWidth * zoomFactor;
    double headerHeight =
        (AppConstants.headerRowHeight * GridLayoutConstants.headerRowsCount) *
        zoomFactor;

    // 화살표의 모든 점들 (시작점, 끝점, 중간점)
    List<Offset> arrowPoints = [
      sourcePos,
      targetPos,
      Offset(sourcePos.dx, targetPos.dy), // 직각 화살표의 중간점
    ];

    // 각 점이 보이는 영역에 있는지 검사
    for (Offset point in arrowPoints) {
      if (isPointInVisibleArea(
        point,
        canvasSize,
        frozenColumnWidth,
        headerHeight,
      )) {
        return true; // 하나라도 보이는 영역에 있으면 화살표를 그림
      }
    }

    // 모든 점이 화면 밖에 있어도 화살표가 화면 영역과 교차하는지 확인
    return isArrowIntersectingVisibleArea(
      sourcePos,
      targetPos,
      canvasSize,
      frozenColumnWidth,
      headerHeight,
    );
  }

  /// 특정 점이 보이는 영역에 있는지 검사하는 메서드
  /// 화면 영역에서만 화살표를 그리도록 함
  ///
  /// [point] 검사할 점의 좌표
  /// [canvasSize] 캔버스 크기
  /// [frozenColumnWidth] 고정 열 너비
  /// [headerHeight] 헤더 높이
  ///
  /// Returns: bool - 점이 화면 영역에 있는지 여부
  static bool isPointInVisibleArea(
    Offset point,
    Size canvasSize,
    double frozenColumnWidth,
    double headerHeight,
  ) {
    // 화면 영역에서만 화살표 그리기 허용
    // 고정 열 오른쪽, 헤더 아래쪽 영역만 허용
    bool inVisibleArea =
        point.dx > frozenColumnWidth &&
        point.dy > headerHeight &&
        point.dx <= canvasSize.width &&
        point.dy <= canvasSize.height;

    return inVisibleArea;
  }

  /// 화살표가 화면 영역과 교차하는지 확인하는 메서드
  /// 직각 화살표의 두 선분이 화면 영역과 교차하는지 검사
  ///
  /// [sourcePos] 화살표 시작점 좌표
  /// [targetPos] 화살표 끝점 좌표
  /// [canvasSize] 캔버스 크기
  /// [frozenColumnWidth] 고정 열 너비
  /// [headerHeight] 헤더 높이
  ///
  /// Returns: bool - 화살표가 화면 영역과 교차하는지 여부
  static bool isArrowIntersectingVisibleArea(
    Offset sourcePos,
    Offset targetPos,
    Size canvasSize,
    double frozenColumnWidth,
    double headerHeight,
  ) {
    // 화면 영역 정의 (스크롤 가능한 영역)
    Rect visibleArea = Rect.fromLTWH(
      frozenColumnWidth,
      headerHeight,
      canvasSize.width - frozenColumnWidth,
      canvasSize.height - headerHeight,
    );

    // 직각 화살표의 중간점 계산 (세로 우선 기준)
    Offset midPoint = Offset(sourcePos.dx, targetPos.dy);

    // 첫 번째 선분: 시작점 → 중간점
    bool firstSegmentIntersects = lineIntersectsRect(
      sourcePos,
      midPoint,
      visibleArea,
    );

    // 두 번째 선분: 중간점 → 끝점
    bool secondSegmentIntersects = lineIntersectsRect(
      midPoint,
      targetPos,
      visibleArea,
    );

    return firstSegmentIntersects || secondSegmentIntersects;
  }

  /// 선분이 사각형과 교차하는지 확인하는 메서드
  ///
  /// [start] 선분 시작점
  /// [end] 선분 끝점
  /// [rect] 사각형 영역
  ///
  /// Returns: bool - 선분이 사각형과 교차하는지 여부
  static bool lineIntersectsRect(Offset start, Offset end, Rect rect) {
    // 선분의 경계 상자
    Rect lineBounds = Rect.fromPoints(start, end);

    // 경계 상자가 사각형과 교차하는지 확인
    if (!rect.overlaps(lineBounds)) {
      return false;
    }

    // 선분의 양 끝점이 사각형 내부에 있는지 확인
    if (rect.contains(start) || rect.contains(end)) {
      return true;
    }

    // 선분이 사각형의 경계와 교차하는지 확인
    // 수직선인 경우
    if (start.dx == end.dx) {
      double x = start.dx;
      if (x >= rect.left && x <= rect.right) {
        double minY = math.min(start.dy, end.dy);
        double maxY = math.max(start.dy, end.dy);
        return !(maxY < rect.top || minY > rect.bottom);
      }
    }

    // 수평선인 경우
    if (start.dy == end.dy) {
      double y = start.dy;
      if (y >= rect.top && y <= rect.bottom) {
        double minX = math.min(start.dx, end.dx);
        double maxX = math.max(start.dx, end.dx);
        return !(maxX < rect.left || minX > rect.right);
      }
    }

    return false;
  }

  /// 컬럼 너비 (줌 배율 적용) — 0번 열은 교사명 고정열, 이후는 교시 열
  static double columnWidth(int columnIndex, double zoomFactor) {
    final base =
        columnIndex == 0
            ? AppConstants.teacherColumnWidth
            : AppConstants.periodColumnWidth;
    return base * zoomFactor;
  }

  /// 데이터 행 높이 (줌 배율 적용)
  static double rowHeight(double zoomFactor) =>
      AppConstants.dataRowHeight * zoomFactor;

  /// 셀 좌상단 좌표 계산 (헤더·스크롤 오프셋·고정 영역 반영)
  ///
  /// 셀 중앙/경계면 좌표 계산의 공통 기준점이다.
  /// 교사명 열(columnIndex == 0)은 고정 영역이므로 수평 스크롤을 적용하지 않는다.
  static Offset getCellOrigin(
    int columnIndex,
    int teacherIndex,
    double zoomFactor,
    Offset scrollOffset,
  ) {
    double x = 0;
    for (int i = 0; i < columnIndex; i++) {
      x += columnWidth(i, zoomFactor);
    }

    double y =
        AppConstants.headerRowHeight *
        GridLayoutConstants.headerRowsCount *
        zoomFactor;
    y += teacherIndex * rowHeight(zoomFactor);

    // 교사명 열은 고정 영역이므로 수평 오프셋 미적용
    final horizontalOffset = columnIndex == 0 ? 0.0 : scrollOffset.dx;
    x -= horizontalOffset;
    y -= scrollOffset.dy;

    return Offset(x, y);
  }

  /// 셀의 정중앙 위치 계산 (보강 화살표 시작점 전용)
  ///
  /// Returns: Offset - 셀 가로·세로 중앙 좌표 (스크롤 오프셋 반영)
  static Offset getCellCenterPosition(
    int columnIndex,
    int teacherIndex,
    double zoomFactor,
    Offset scrollOffset,
  ) {
    final origin = getCellOrigin(
      columnIndex,
      teacherIndex,
      zoomFactor,
      scrollOffset,
    );
    return origin +
        Offset(
          columnWidth(columnIndex, zoomFactor) / 2,
          rowHeight(zoomFactor) / 2,
        );
  }

  /// 셀의 경계면 중앙 위치 계산 (화살표 시작점/끝점용)
  /// 스크롤 오프셋과 고정 영역을 반영하여 실제 화면상의 위치를 계산
  ///
  /// [columnIndex] 셀의 열 인덱스
  /// [teacherIndex] 셀의 교사 인덱스
  /// [edge] 경계면 종류 (상, 하, 좌, 우)
  ///
  /// Returns: Offset - 경계면 중앙의 좌표 (스크롤 오프셋 및 고정 영역 반영)
  static Offset getCellEdgeCenterPosition(
    int columnIndex,
    int teacherIndex,
    ArrowEdge edge,
    double zoomFactor,
    Offset scrollOffset,
  ) {
    final origin = getCellOrigin(
      columnIndex,
      teacherIndex,
      zoomFactor,
      scrollOffset,
    );
    final cw = columnWidth(columnIndex, zoomFactor);
    final rowH = rowHeight(zoomFactor);

    // 좌상단 기준으로 각 경계면 중앙까지의 오프셋
    switch (edge) {
      case ArrowEdge.top: // 상단 가로 중앙
        return origin + Offset(cw / 2, 0);
      case ArrowEdge.bottom: // 하단 가로 중앙
        return origin + Offset(cw / 2, rowH);
      case ArrowEdge.left: // 왼쪽 경계 세로 중앙
        return origin + Offset(0, rowH / 2);
      case ArrowEdge.right: // 오른쪽 경계 세로 중앙
        return origin + Offset(cw, rowH / 2);
    }
  }

  /// 화살표의 시작점과 끝점 경계면을 결정하는 함수
  ///
  /// [sourceColumnIndex] 시작 셀의 열 인덱스
  /// [sourceTeacherIndex] 시작 셀의 교사 인덱스
  /// [targetColumnIndex] 목표 셀의 열 인덱스
  /// [targetTeacherIndex] 목표 셀의 교사 인덱스
  /// [priority] 화살표 우선 방향 (세로 우선 또는 가로 우선)
  ///
  /// Returns: `Map<String, ArrowEdge>` - 'start'와 'end' 키로 시작점과 끝점의 경계면 반환
  static Map<String, ArrowEdge> determineArrowEdges(
    int sourceColumnIndex,
    int sourceTeacherIndex,
    int targetColumnIndex,
    int targetTeacherIndex,
    ArrowPriority priority,
  ) {
    // 상대적 위치 계산
    bool isTargetBelow =
        targetTeacherIndex > sourceTeacherIndex; // 목표가 아래쪽에 있는지
    bool isTargetRight = targetColumnIndex > sourceColumnIndex; // 목표가 오른쪽에 있는지
    bool isTargetAbove = targetTeacherIndex < sourceTeacherIndex; // 목표가 위쪽에 있는지
    bool isTargetLeft = targetColumnIndex < sourceColumnIndex; // 목표가 왼쪽에 있는지

    ArrowEdge startEdge;
    ArrowEdge endEdge;

    if (priority == ArrowPriority.verticalFirst) {
      // 세로 우선: 먼저 세로 이동, 그 다음 가로 이동
      // 시작점: 세로 방향으로 나가도록
      if (isTargetBelow) {
        startEdge = ArrowEdge.bottom; // 목표가 아래쪽: 하단에서 시작
      } else if (isTargetAbove) {
        startEdge = ArrowEdge.top; // 목표가 위쪽: 상단에서 시작
      } else {
        // 같은 행에 있는 경우, 열 위치에 따라 결정
        if (isTargetRight) {
          startEdge = ArrowEdge.right; // 목표가 오른쪽: 오른쪽에서 시작
        } else if (isTargetLeft) {
          startEdge = ArrowEdge.left; // 목표가 왼쪽: 왼쪽에서 시작
        } else {
          startEdge = ArrowEdge.right; // 같은 위치 (기본값)
        }
      }

      // 끝점: 가로 방향으로 들어오도록
      if (isTargetRight) {
        endEdge = ArrowEdge.left; // 목표가 오른쪽: 왼쪽 경계면에서 끝
      } else if (isTargetLeft) {
        endEdge = ArrowEdge.right; // 목표가 왼쪽: 오른쪽 경계면에서 끝
      } else {
        // 같은 열에 있는 경우, 행 위치에 따라 결정
        if (isTargetBelow) {
          endEdge = ArrowEdge.top; // 목표가 아래쪽: 상단에서 끝
        } else if (isTargetAbove) {
          endEdge = ArrowEdge.bottom; // 목표가 위쪽: 하단에서 끝
        } else {
          endEdge = ArrowEdge.left; // 같은 위치 (기본값)
        }
      }
    } else {
      // 가로 우선: 먼저 가로 이동, 그 다음 세로 이동
      // 시작점: 가로 방향으로 나가도록
      if (isTargetRight) {
        startEdge = ArrowEdge.right; // 목표가 오른쪽: 오른쪽에서 시작
      } else if (isTargetLeft) {
        startEdge = ArrowEdge.left; // 목표가 왼쪽: 왼쪽에서 시작
      } else {
        // 같은 열에 있는 경우, 행 위치에 따라 결정
        if (isTargetBelow) {
          startEdge = ArrowEdge.bottom; // 목표가 아래쪽: 하단에서 시작
        } else if (isTargetAbove) {
          startEdge = ArrowEdge.top; // 목표가 위쪽: 상단에서 시작
        } else {
          startEdge = ArrowEdge.right; // 같은 위치 (기본값)
        }
      }

      // 끝점: 세로 방향으로 들어오도록
      if (isTargetBelow) {
        endEdge = ArrowEdge.top; // 목표가 아래쪽: 상단에서 끝
      } else if (isTargetAbove) {
        endEdge = ArrowEdge.bottom; // 목표가 위쪽: 하단에서 끝
      } else {
        // 같은 행에 있는 경우, 열 위치에 따라 결정
        if (isTargetRight) {
          endEdge = ArrowEdge.left; // 목표가 오른쪽: 왼쪽 경계면에서 끝
        } else if (isTargetLeft) {
          endEdge = ArrowEdge.right; // 목표가 왼쪽: 오른쪽 경계면에서 끝
        } else {
          endEdge = ArrowEdge.left; // 같은 위치 (기본값)
        }
      }
    }

    return {'start': startEdge, 'end': endEdge};
  }
}

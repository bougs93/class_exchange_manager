import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// 그리드 스케일링 헬퍼 클래스
///
/// Syncfusion DataGrid의 줌 팩터 기반 스케일링 로직을 통합합니다.
///
/// ## 결과를 캐시하지 말 것 (2026-10-01 확인)
///
/// 매 빌드마다 `GridColumn`을 새로 만드는 것이 낭비처럼 보여서, 원본 리스트
/// 동일성 + 줌 배율을 키로 결과를 캐시해 본 적이 있다. 경로 선택은 조금
/// 빨라졌지만 **스크롤이 눈에 띄게 느려졌다**.
///
/// 같은 `GridColumn` 인스턴스를 계속 넘기면 `SfDataGrid`가 "컬럼이 안 바뀌었다"고
/// 보고 내부 컬럼 갱신을 건너뛴다. 그 결과 폭·가시 컬럼 정보를 스크롤하는 동안
/// 프레임마다 다시 계산하게 되어, 리빌드 한 번의 비용이 스크롤 전체로 번졌다.
/// 게다가 이 클래스는 교체 화면과 개인 시간표 화면이 함께 쓰는 static 유틸이라
/// 단일 캐시를 서로 밀어내기도 한다.
///
/// 리빌드 비용을 줄이고 싶다면 여기서 캐시하지 말고, 컬럼이 바뀌지 않은
/// 리빌드에서 `SfDataGrid` 자체를 다시 만들지 않도록 위젯 구조를 손봐야 한다.
class GridScalingHelper {
  /// 기본 헤더 높이
  static const double baseHeaderHeight = 25.0;

  /// 기본 데이터 행 높이
  static const double baseRowHeight = 25.0;

  /// 줌 팩터에 따라 컬럼들을 스케일링하여 반환
  ///
  /// [columns] 원본 컬럼 목록
  /// [zoomFactor] 현재 줌 팩터 (1.0 = 100%)
  ///
  /// Returns: `List<GridColumn>` - 스케일링된 컬럼 목록
  static List<GridColumn> scaleColumns(
    List<GridColumn> columns,
    double zoomFactor,
  ) {
    return columns.map((column) {
      return GridColumn(
        columnName: column.columnName,
        width: column.width * zoomFactor,
        label: column.label,
      );
    }).toList();
  }

  /// 줌 팩터에 따라 스택 헤더들을 스케일링하여 반환
  ///
  /// [stackedHeaders] 원본 스택 헤더 목록
  /// [zoomFactor] 현재 줌 팩터 (1.0 = 100%)
  ///
  /// Returns: `List<StackedHeaderRow>` - 스케일링된 스택 헤더 목록
  static List<StackedHeaderRow> scaleStackedHeaders(
    List<StackedHeaderRow> stackedHeaders,
    double zoomFactor,
  ) {
    return stackedHeaders.map((headerRow) {
      return StackedHeaderRow(
        cells:
            headerRow.cells.map((cell) {
              return StackedHeaderCell(
                child: cell.child,
                columnNames: cell.columnNames,
              );
            }).toList(),
      );
    }).toList();
  }

  /// 줌 팩터에 따라 헤더 행 높이를 계산하여 반환
  ///
  /// [zoomFactor] 현재 줌 팩터 (1.0 = 100%)
  ///
  /// Returns: double - 스케일링된 헤더 행 높이
  static double scaleHeaderHeight(double zoomFactor) {
    return baseHeaderHeight * zoomFactor;
  }

  /// 줌 팩터에 따라 데이터 행 높이를 계산하여 반환
  ///
  /// [zoomFactor] 현재 줌 팩터 (1.0 = 100%)
  ///
  /// Returns: double - 스케일링된 데이터 행 높이
  static double scaleRowHeight(double zoomFactor) {
    return baseRowHeight * zoomFactor;
  }
}

import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// 그리드 스케일링 헬퍼 클래스
///
/// Syncfusion DataGrid의 줌 팩터 기반 스케일링 로직을 통합합니다.
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
        cells: headerRow.cells.map((cell) {
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

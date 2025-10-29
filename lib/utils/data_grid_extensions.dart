import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// DataGridRow Extension
/// DataGridCell 값 추출을 간소화하는 확장 메서드
extension DataGridRowExtensions on DataGridRow {
  /// 특정 컬럼의 셀 값을 문자열로 추출
  ///
  /// [columnName] 추출할 컬럼명
  /// [defaultValue] 셀이 없거나 값이 null일 때 반환할 기본값
  ///
  /// Returns: 셀 값 (trim 처리됨)
  String extractCellValue(String columnName, [String defaultValue = '']) {
    final cell = getCells().firstWhere(
      (c) => c.columnName == columnName,
      orElse: () => const DataGridCell<String>(columnName: '', value: ''),
    );
    return (cell.value?.toString() ?? defaultValue).trim();
  }

  /// 특정 컬럼의 셀 값을 가져오되 trim 처리하지 않음
  ///
  /// [columnName] 추출할 컬럼명
  /// [defaultValue] 셀이 없거나 값이 null일 때 반환할 기본값
  ///
  /// Returns: 셀 값 (원본)
  String extractCellValueRaw(String columnName, [String defaultValue = '']) {
    final cell = getCells().firstWhere(
      (c) => c.columnName == columnName,
      orElse: () => const DataGridCell<String>(columnName: '', value: ''),
    );
    return cell.value?.toString() ?? defaultValue;
  }
}

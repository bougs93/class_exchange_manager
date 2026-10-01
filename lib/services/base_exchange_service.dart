import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../utils/timetable_data_source.dart';
import 'search/exchange_search_context.dart';

/// UI 셀 좌표를 순수 Dart 탐색 상태에 연결한다.
abstract class BaseExchangeService extends ExchangeSearchContext {
  /// 셀에서 교사명 추출
  ///
  /// Syncfusion DataGrid에서 헤더 구조:
  /// - 일반 헤더: 1개 (컬럼명 표시)
  /// - 스택된 헤더: 1개 (요일별 병합)
  /// 총 2개의 헤더 행이 있으므로 실제 데이터 행 인덱스는 2를 빼야 함
  String getTeacherNameFromCell(
    DataGridCellTapDetails details,
    TimetableDataSource dataSource,
  ) {
    String teacherName = '';

    const int headerRowCount = 2;
    int actualRowIndex = details.rowColumnIndex.rowIndex - headerRowCount;

    if (actualRowIndex >= 0 && actualRowIndex < dataSource.rows.length) {
      DataGridRow row = dataSource.rows[actualRowIndex];
      for (DataGridCell rowCell in row.getCells()) {
        if (rowCell.columnName == 'teacher') {
          teacherName = rowCell.value.toString();
          break;
        }
      }
    }
    return teacherName;
  }
}

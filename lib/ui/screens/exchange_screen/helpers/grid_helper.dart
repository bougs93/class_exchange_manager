import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../services/excel_service.dart';
import '../../../../utils/syncfusion_timetable_helper.dart';
import '../../../../models/circular_exchange_path.dart';
import '../../../../models/one_to_one_exchange_path.dart';
import '../../../../models/chain_exchange_path.dart';

/// Syncfusion DataGrid 관련 헬퍼 클래스
/// 컬럼, 헤더 생성 등 그리드 설정을 담당
class GridHelper {
  /// Syncfusion DataGrid 컬럼 및 헤더 생성
  static GridData createSyncfusionGridData({
    required TimetableData timetableData,
    List<Map<String, dynamic>>? exchangeableTeachers,
    CircularExchangePath? selectedCircularPath,
    OneToOneExchangePath? selectedOneToOnePath,
    ChainExchangePath? selectedChainPath,
  }) {
    // SyncfusionTimetableHelper를 사용하여 데이터 생성
    final result = SyncfusionTimetableHelper.convertToSyncfusionData(
      timetableData.timeSlots,
      timetableData.teachers,
      exchangeableTeachers: exchangeableTeachers,
      selectedCircularPath: selectedCircularPath,
      selectedOneToOnePath: selectedOneToOnePath,
      selectedChainPath: selectedChainPath,
    );

    return GridData(
      columns: result.columns,
      stackedHeaders: result.stackedHeaders,
    );
  }
}

/// 그리드 데이터를 담는 클래스
class GridData {
  final List<GridColumn> columns;
  final List<StackedHeaderRow> stackedHeaders;

  GridData({
    required this.columns,
    required this.stackedHeaders,
  });
}

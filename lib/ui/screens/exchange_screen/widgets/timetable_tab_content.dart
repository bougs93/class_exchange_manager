import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../models/exchange_path.dart';
import '../../../../models/exchange_mode.dart';
import '../../../../services/excel_service.dart';
import '../../../../utils/timetable_data_source.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../widgets/exchange_control_panel.dart';
import '../../../widgets/timetable_grid_section.dart';

/// 시간표 탭 컨텐츠 위젯
class TimetableTabContent extends StatelessWidget {
  final ExchangeScreenState state;
  final TimetableData? timetableData;
  final TimetableDataSource? dataSource;
  final List<GridColumn> columns;
  final List<StackedHeaderRow> stackedHeaders;
  final GlobalKey<State<TimetableGridSection>> timetableGridKey;

  // 콜백 함수들
  final void Function(ExchangeMode) onModeChanged;
  final void Function(DataGridCellTapDetails) onCellTap;
  final int Function() getActualExchangeableCount;
  final ExchangePath? Function() getCurrentSelectedPath;
  final Widget Function(String?, VoidCallback) buildErrorMessageSection;
  final VoidCallback onClearError;
  final VoidCallback? onHeaderThemeUpdate; // 헤더 테마 업데이트 콜백

  const TimetableTabContent({
    super.key,
    required this.state,
    required this.timetableData,
    required this.dataSource,
    required this.columns,
    required this.stackedHeaders,
    required this.timetableGridKey,
    required this.onModeChanged,
    required this.onCellTap,
    required this.getActualExchangeableCount,
    required this.getCurrentSelectedPath,
    required this.buildErrorMessageSection,
    required this.onClearError,
    this.onHeaderThemeUpdate, // 헤더 테마 업데이트 콜백
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 교체 제어 패널
        ExchangeControlPanel(
          selectedFile: state.selectedFile,
          isLoading: state.isLoading,
          currentMode: state.currentMode,
          onModeChanged: onModeChanged,
        ),

        // 시간표 그리드 표시 섹션 (TabBar와 바로 붙이기 위해 간격 제거)
        if (timetableData != null)
          Expanded(
            child: TimetableGridSection(
              key: ValueKey('timetable_grid_${timetableData?.teachers.length ?? 0}_${columns.length}_${stackedHeaders.length}'),
              timetableData: timetableData,
              dataSource: dataSource,
              columns: columns,
              stackedHeaders: stackedHeaders,
              isExchangeModeEnabled: state.currentMode == ExchangeMode.oneToOneExchange,
              isCircularExchangeModeEnabled: state.currentMode == ExchangeMode.circularExchange,
              isChainExchangeModeEnabled: state.currentMode == ExchangeMode.chainExchange,
              exchangeableCount: getActualExchangeableCount(),
              onCellTap: onCellTap,
              selectedExchangePath: getCurrentSelectedPath(),
            ),
          )
        else
          const Expanded(child: SizedBox.shrink()),

        // 오류 메시지 표시
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: buildErrorMessageSection(state.errorMessage, onClearError),
          ),
      ],
    );
  }
}

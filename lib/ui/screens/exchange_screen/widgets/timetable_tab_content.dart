import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../models/exchange_path.dart';
import '../../../../services/excel_service.dart';
import '../../../../utils/timetable_data_source.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../widgets/file_selection_section.dart';
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
  final VoidCallback onSelectExcelFile;
  final VoidCallback onToggleExchangeMode;
  final VoidCallback onToggleCircularExchangeMode;
  final VoidCallback onToggleChainExchangeMode;
  final VoidCallback onToggleNonExchangeableEditMode;
  final VoidCallback onClearSelection;
  final void Function(DataGridCellTapDetails) onCellTap;
  final int Function() getActualExchangeableCount;
  final ExchangePath? Function() getCurrentSelectedPath;
  final Widget Function(String?, VoidCallback) buildErrorMessageSection;
  final VoidCallback onClearError;

  const TimetableTabContent({
    super.key,
    required this.state,
    required this.timetableData,
    required this.dataSource,
    required this.columns,
    required this.stackedHeaders,
    required this.timetableGridKey,
    required this.onSelectExcelFile,
    required this.onToggleExchangeMode,
    required this.onToggleCircularExchangeMode,
    required this.onToggleChainExchangeMode,
    required this.onToggleNonExchangeableEditMode,
    required this.onClearSelection,
    required this.onCellTap,
    required this.getActualExchangeableCount,
    required this.getCurrentSelectedPath,
    required this.buildErrorMessageSection,
    required this.onClearError,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 파일 선택 섹션
          FileSelectionSection(
            selectedFile: state.selectedFile,
            isLoading: state.isLoading,
            isExchangeModeEnabled: state.isExchangeModeEnabled,
            isCircularExchangeModeEnabled: state.isCircularExchangeModeEnabled,
            isChainExchangeModeEnabled: state.isChainExchangeModeEnabled,
            isNonExchangeableEditMode: state.isNonExchangeableEditMode,
            onSelectExcelFile: onSelectExcelFile,
            onToggleExchangeMode: onToggleExchangeMode,
            onToggleCircularExchangeMode: onToggleCircularExchangeMode,
            onToggleChainExchangeMode: onToggleChainExchangeMode,
            onToggleNonExchangeableEditMode: onToggleNonExchangeableEditMode,
            onClearSelection: onClearSelection,
          ),

          const SizedBox(height: 24),

          // 시간표 그리드 표시 섹션
          if (timetableData != null)
            Expanded(
              child: TimetableGridSection(
                key: timetableGridKey,
                timetableData: timetableData,
                dataSource: dataSource,
                columns: columns,
                stackedHeaders: stackedHeaders,
                isExchangeModeEnabled: state.isExchangeModeEnabled,
                isCircularExchangeModeEnabled: state.isCircularExchangeModeEnabled,
                isChainExchangeModeEnabled: state.isChainExchangeModeEnabled,
                exchangeableCount: getActualExchangeableCount(),
                onCellTap: onCellTap,
                selectedExchangePath: getCurrentSelectedPath(),
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),

          // 오류 메시지 표시
          if (state.errorMessage != null)
            buildErrorMessageSection(state.errorMessage, onClearError),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../models/exchange_path.dart';
import '../../../../models/exchange_mode.dart';
import '../../../../services/excel_service.dart';
import '../../../../utils/timetable_data_source.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../widgets/exchange_control_panel.dart';
import '../../../widgets/timetable_grid_section.dart';

/// 시간표 탭 컨텐츠 위젯
class TimetableTabContent extends ConsumerWidget {
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
  final Widget Function(String?, VoidCallback) buildPaddedErrorMessageSection;
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
    required this.buildPaddedErrorMessageSection,
    required this.onClearError,
    this.onHeaderThemeUpdate, // 헤더 테마 업데이트 콜백
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // 시간표 그리드 (모드 선택 + 실행 도구가 그리드 헤더에 통합됨)
        if (timetableData != null)
          Expanded(
            child: TimetableGridSection(
              key: ValueKey(
                'timetable_grid_${timetableData?.teachers.length ?? 0}',
              ),
              timetableData: timetableData,
              dataSource: dataSource,
              columns: columns,
              stackedHeaders: stackedHeaders,
              isExchangeModeEnabled:
                  state.currentMode == ExchangeMode.oneToOneExchange,
              isCircularExchangeModeEnabled:
                  state.currentMode == ExchangeMode.circularExchange,
              isDualExchangeModeEnabled:
                  state.currentMode == ExchangeMode.dualExchange,
              exchangeableCount: getActualExchangeableCount(),
              onCellTap: onCellTap,
              selectedExchangePath: getCurrentSelectedPath(),
              onHeaderThemeUpdate: onHeaderThemeUpdate,
              currentMode: state.currentMode,
              onModeChanged: onModeChanged,
            ),
          )
        else ...[
          // 파일 미로드 시 모드 선택만 표시
          ExchangeControlPanel(
            currentMode: state.currentMode,
            onModeChanged: onModeChanged,
          ),
          const Expanded(child: SizedBox.shrink()),
        ],

        // 오류 메시지 표시 (교체·준비 화면 공통 스타일)
        buildPaddedErrorMessageSection(state.errorMessage, onClearError),
      ],
    );
  }
}

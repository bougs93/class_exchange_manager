import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../models/exchange_history_item.dart';
import '../../providers/cell_selection_provider.dart';
import '../../ui/widgets/timetable_grid/timetable_grid_constants.dart';
import '../exchange_cell_dates.dart';
import '../exchange_path_step_resolver.dart';
import '../exchanged_cell_overlay_dates.dart';
import '../overlay_date_chip_layout.dart';
import '../week_date_calculator.dart';
import 'cell_state_info.dart';

/// `TimetableDataSource`의 셀 상태 계산 헬퍼
///
/// `lib/utils/timetable_data_source.dart`에서 분리됨. setState/notifyListeners를
/// 호출하지 않고 위젯도 만들지 않는, 순수 계산/조회 로직만 모은 것이다.
/// (알림 배칭·위젯 빌드 로직은 원래 파일에 그대로 남아 있다.)
class CellStateHelper {
  CellStateHelper._();

  /// 교사명 추출
  static String extractTeacherName(DataGridRow row) {
    for (DataGridCell rowCell in row.getCells()) {
      if (rowCell.columnName == 'teacher') {
        return rowCell.value.toString();
      }
    }
    return '';
  }

  /// 요일별 마지막 교시 확인
  static bool isLastColumnOfDay(String day, int period) {
    bool isLastPeriod = period == 7;
    bool isLastDay = day == '금';
    return isLastPeriod && !isLastDay;
  }

  /// 교사명 열 상태 정보 생성
  static CellStateInfo createTeacherColumnState({
    required CellSelectionState cellState,
    required String teacherName,
    required bool isHighlightedTeacher,
    required bool Function(String teacherName, String day, int period)
    isInCircularPath,
    required bool Function(String teacherName, String day, int period)
    isInDualPath,
    required bool Function(String teacherName, String day, int period)
    isInSelectedOneToOnePath,
  }) {
    // 교사 이름 컬럼은 해당 교사의 선택 상태를 확인
    bool isTeacherSelected = cellState.selectedTeacher == teacherName;
    bool isTeacherNameSelected = cellState.selectedTeacherName == teacherName;

    // 교사가 교체 가능한지 확인 (교체 가능한 교사 목록에 포함되어 있는지)
    bool isTeacherExchangeable = cellState.exchangeableTeachers.any(
      (teacher) => teacher['teacherName'] == teacherName,
    );

    return CellStateInfo(
      isSelected: isTeacherSelected, // 교사 이름 선택은 isSelected에 포함하지 않음
      isExchangeableTeacher: isTeacherExchangeable,
      isInCircularPath: isInCircularPath(teacherName, '', 0),
      isInDualPath: isInDualPath(teacherName, '', 0),
      isInSelectedPath: isInSelectedOneToOnePath(teacherName, '', 0),
      isNonExchangeable: false,
      isExchangedSourceCell: false, // 교사명 열은 교체된 소스 셀 상태 적용 안함
      isExchangedDestinationCell: false, // 교사명 열은 교체된 목적지 셀 상태 적용 안함
      isTargetCell: false,
      isLastColumnOfDay: false,
      isFirstColumnOfDay: false,
      circularPathStep: null,
      pathStepNumber: null,
      isTeacherNameSelected: isTeacherNameSelected,
      isHighlightedTeacher: isHighlightedTeacher,
    );
  }

  /// 데이터 셀 상태 정보 생성
  static CellStateInfo createDataCellState({
    required CellSelectionState cellState,
    required DataGridCell dataGridCell,
    required String teacherName,
    required bool isHighlightedTeacher,
    required ArrowDirection oneToOneArrowDirection,
    required Map<String, String> overlayLabels,
    required bool Function(String teacherName, String day, int period)
    isInCircularPath,
    required bool Function(String teacherName, String day, int period)
    isInDualPath,
    required bool Function(String teacherName, String day, int period)
    isInSelectedOneToOnePath,
    required Map<String, bool> localCache,
    required bool Function(String teacherName, String day, int period)
    isNonExchangeableTimeSlot,
    required bool Function(String day, int period) isFirstColumnOfDay,
  }) {
    final columnName = dataGridCell.columnName;
    final separator = columnName.indexOf('_');
    if (separator <= 0 || separator == columnName.length - 1) {
      return CellStateInfo.empty();
    }

    final String day = columnName.substring(0, separator);
    final int period = int.tryParse(columnName.substring(separator + 1)) ?? 0;
    if (period == 0) return CellStateInfo.empty();

    // `교사_요일_교시` 키는 한 셀에서 여러 번 쓰이므로 한 번만 만든다.
    final String cellKey = '${teacherName}_${day}_$period';

    final bool isSelected =
        cellState.selectedTeacher == teacherName &&
        cellState.selectedDay == day &&
        cellState.selectedPeriod == period;
    final bool isInDualPathValue = isInDualPath(teacherName, day, period);
    final bool isInSelectedPath = isInSelectedOneToOnePath(
      teacherName,
      day,
      period,
    );
    final bool isExchangedSourceCell = cellState.exchangedCells.contains(
      cellKey,
    );
    final bool isExchangedDestinationCell = cellState.exchangedDestinationCells
        .contains(cellKey);

    return CellStateInfo(
      isSelected: isSelected,
      isTargetCell:
          cellState.targetTeacher == teacherName &&
          cellState.targetDay == day &&
          cellState.targetPeriod == period,
      // 수업 칸은 "교체 가능" 배경·표시를 쓰지 않는다(교사명 열·헤더만 강조)
      isExchangeableTeacher: false,
      isInCircularPath: isInCircularPath(teacherName, day, period),
      isInDualPath: isInDualPathValue,
      isInSelectedPath: isInSelectedPath,
      isNonExchangeable: _getCachedOrCompute(
        localCache,
        cellKey,
        () => isNonExchangeableTimeSlot(teacherName, day, period),
      ),
      isExchangedSourceCell: isExchangedSourceCell,
      isExchangedDestinationCell: isExchangedDestinationCell,
      overlayDate:
          (isExchangedSourceCell || isExchangedDestinationCell)
              ? overlayLabels[cellKey]
              : null,
      isLastColumnOfDay: isLastColumnOfDay(day, period),
      isFirstColumnOfDay: isFirstColumnOfDay(day, period),
      circularPathStep: _getCircularPathStep(
        cellState,
        teacherName,
        day,
        period,
      ),
      // 셀 모서리 단계 번호 (1:1·2중 공통)
      // 1:1 화살표 방향 설정값에 따라 비선택 셀만(단방향) 또는 양쪽 셀(양방향)에 번호 표시
      pathStepNumber: resolvePathStepNumber(
        oneToOneArrowDirection: oneToOneArrowDirection,
        isInOneToOnePath: isInSelectedPath,
        isInDualPath: isInDualPathValue,
        isSelected: isSelected,
        dualPathStep: _getDualPathStep(cellState, teacherName, day, period),
      ),
      isTeacherNameSelected: false, // 데이터 셀은 교사 이름 선택 상태 적용 안함
      isHighlightedTeacher: isHighlightedTeacher,
    );
  }

  /// 교체불가 여부처럼 시간표가 바뀌기 전까지 변하지 않는 값만 캐시한다.
  static bool _getCachedOrCompute(
    Map<String, bool> cache,
    String cellKey,
    bool Function() compute,
  ) {
    final cached = cache[cellKey];
    if (cached != null) return cached;
    return cache[cellKey] = compute();
  }

  /// 순환교체 경로에서 해당 셀의 단계 번호 가져오기
  static int? _getCircularPathStep(
    CellSelectionState cellState,
    String teacherName,
    String day,
    int period,
  ) {
    final path = cellState.selectedCircularPath;
    if (path == null) return null;

    for (int i = 0; i < path.nodes.length; i++) {
      final node = path.nodes[i];
      if (node.teacherName == teacherName &&
          node.day == day &&
          node.period == period) {
        return i + 1; // 1부터 시작하는 단계 번호
      }
    }

    return null;
  }

  /// 2중교체 경로에서 해당 셀의 단계 번호 가져오기
  static int? _getDualPathStep(
    CellSelectionState cellState,
    String teacherName,
    String day,
    int period,
  ) {
    final path = cellState.selectedDualPath;
    if (path == null) return null;

    // 2중교체의 노드 순서: [node1, node2, nodeA, nodeB]
    for (int i = 0; i < path.nodes.length; i++) {
      final node = path.nodes[i];
      if (node.teacherName == teacherName &&
          node.day == day &&
          node.period == period) {
        // node1, node2는 1단계, nodeA, nodeB는 2단계
        return i < 2 ? 1 : 2;
      }
    }

    return null;
  }

  /// 교체된 칸에 붙일 꼬리표 계산 (S1.5, "?" 마커는 S1.10) — 날짜표시 OFF
  ///
  /// 실제 날짜(예: "10.07")를 꼬리표로 붙인다. 순환·2중 교체 등 참여 노드별
  /// 날짜를 알 수 없는 칸은 null을 반환해 생략한다 — 틀린 날짜를 보여주는
  /// 것보다 안전하다.
  static Map<String, String> overlayLabelsForUndatedHeader(
    List<ExchangeHistoryItem> activeItems,
  ) {
    final overlayDates = ExchangedCellOverlayDates.build(activeItems);
    return {
      for (final entry in overlayDates.entries)
        entry.key: WeekDateCalculator.formatDateShort(entry.value),
    };
  }

  /// 교체된 칸에 붙일 꼬리표 계산 — 날짜표시 ON
  ///
  /// 헤더에 이미 실제 날짜가 있으므로 원칙적으로 꼬리표가 필요 없지만,
  /// 순환·2중 교체처럼 날짜가 미확정인 칸은 "?"를 붙여 "이 칸의 날짜는
  /// 결강일 주에 임시로 묶여 표시된 것"임을 알린다 (`ExchangeCellDates`의
  /// `undatedKeys` — S1.10).
  static Map<String, String> overlayLabelsForDatedHeader(
    List<ExchangeHistoryItem> activeItems,
    DateTime selectedWeek,
  ) {
    final scoped = ExchangeCellDates.forWeek(activeItems, selectedWeek);
    return {for (final key in scoped.undatedKeys) key: '?'};
  }

  /// 교체된 칸에 그릴 날짜 꼬리표. 칸 안 배지가 아니라 그리드 위 층에서 쓴다.
  ///
  /// 예전에는 모든 행 × 모든 칸을 훑으며 칸마다 키 문자열을 다시 만들었다.
  /// 꼬리표가 붙는 칸은 교체된 칸뿐이므로, 꼬리표 목록 쪽에서 역으로 찾는다.
  static List<OverlayDateMark> collectOverlayDateMarks({
    required Map<String, String> labels,
    required List<GridColumn> columns,
    required List<DataGridRow> dataGridRows,
    required CellSelectionState cellState,
  }) {
    if (labels.isEmpty) return const [];

    final indexByName = <String, int>{
      for (var i = 0; i < columns.length; i++) columns[i].columnName: i,
    };
    final rowIndexByTeacher = <String, int>{};
    for (var rowIndex = 0; rowIndex < dataGridRows.length; rowIndex++) {
      rowIndexByTeacher.putIfAbsent(
        extractTeacherName(dataGridRows[rowIndex]),
        () => rowIndex,
      );
    }

    final marks = <OverlayDateMark>[];

    for (final entry in labels.entries) {
      final cellKey = entry.key;
      if (!cellState.exchangedCells.contains(cellKey) &&
          !cellState.exchangedDestinationCells.contains(cellKey)) {
        continue;
      }

      // 키 형식: `교사_요일_교시` — 교사명에 '_'가 들어갈 수 있으므로 뒤에서 자른다.
      final periodSep = cellKey.lastIndexOf('_');
      if (periodSep <= 0) continue;
      final daySep = cellKey.lastIndexOf('_', periodSep - 1);
      if (daySep <= 0) continue;

      final teacherName = cellKey.substring(0, daySep);
      final columnName = cellKey.substring(daySep + 1);

      final rowIndex = rowIndexByTeacher[teacherName];
      final columnIndex = indexByName[columnName];
      if (rowIndex == null || columnIndex == null) continue;

      marks.add(
        OverlayDateMark(
          teacherIndex: rowIndex,
          columnIndex: columnIndex,
          label: entry.value,
        ),
      );
    }

    return marks;
  }
}

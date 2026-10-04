import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/circular_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/dual_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../ui/widgets/simplified_timetable_cell.dart';
import '../providers/cell_selection_provider.dart';
import '../providers/cell_status_symbol_visibility_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/non_exchangeable_dated_cells_provider.dart';
import '../providers/selected_week_provider.dart';
import '../providers/services_provider.dart';
import '../providers/show_week_header_provider.dart';
import '../providers/timetable_registry_provider.dart';
import '../services/non_exchangeable_data_storage_service.dart';
import '../ui/widgets/timetable_grid/timetable_grid_constants.dart';
import 'exchange_algorithm.dart';
import 'overlay_date_chip_layout.dart';
import 'day_utils.dart';
import 'non_exchangeable_manager.dart';
import 'simplified_timetable_theme.dart';
import 'logger.dart';
import 'timetable_grid_source/cell_state_helper.dart';
import 'timetable_grid_source/cell_state_info.dart';

export 'timetable_grid_source/cell_state_info.dart' show CellStateInfo;

/// Syncfusion DataGrid용 시간표 데이터 소스
class TimetableDataSource extends DataGridSource {
  TimetableDataSource({
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
    required this.ref,
  }) {
    _initializeData(timeSlots, teachers);
  }

  /// 셀 상태를 읽을 때 쓰는 화면의 ref
  ///
  /// final이 아니다 — [attachRef] 참고.
  WidgetRef ref;

  /// 살아 있는 화면의 ref를 다시 연결한다.
  ///
  /// 이 데이터소스는 전역 `exchangeScreenProvider`에 담겨 있어서 그것을 만든
  /// 화면보다 오래 산다. 웹 로그인 게이트(`WebLoginGate`)가 로그아웃/재로그인
  /// 때 화면 트리를 통째로 새로 만들면, Provider에는 이미 사라진 화면의
  /// WidgetRef를 쥔 데이터소스가 남는다. 그 상태로 그리드를 그리면
  /// `Bad state: Cannot use "ref" after the widget was disposed`로 빨간 화면이
  /// 떴다(2026-10-01). 교체 화면이 빌드될 때마다 현재 ref를 다시 붙여 막는다.
  void attachRef(WidgetRef newRef) {
    if (identical(ref, newRef)) return;
    ref = newRef;
    _rowSignatures.clear();
    _rowAdapters.clear();
    // 이전 화면 기준으로 읽어 둔 값은 모두 버린다.
    _renderContext = null;
    _localCache.clear();
  }

  List<TimeSlot> _timeSlots = [];
  List<Teacher> _teachers = [];
  List<DataGridRow> _dataGridRows = [];

  /// 정렬된 요일 중 첫 요일(보통 '월') — 요일 구분선 생략 판단용
  String? _firstDayName;

  // 교체 옵션 정보
  List<ExchangeOption> _exchangeOptions = [];

  // 관리자 클래스들 (전역 Provider 사용으로 간소화)
  final NonExchangeableManager _nonExchangeableManager =
      NonExchangeableManager();

  // 로컬 캐시 관리 (위젯 빌드 중 안전하게 사용)
  final Map<String, bool> _localCache = {};

  /// 셀 렌더링용 프레임 스냅샷
  ///
  /// 예전에는 셀 하나를 그릴 때마다 `ref.read()`를 5~6번 하고 교체 날짜
  /// 꼬리표 맵을 통째로 다시 만들었다. 보이는 셀이 500개가 넘으므로 웹에서
  /// 체감 지연의 큰 원인이었다. 알림(notify) 한 번에 한 번만 모아 읽는다.
  _CellRenderContext? _renderContext;

  // Coalesce synchronous changes from selection, path reset and header refresh.
  int _batchDepth = 0;
  bool _pendingNotify = false;
  bool _structuralNotify = false;
  bool _disposed = false;
  final Map<DataGridRow, List<Object>> _rowSignatures = {};
  final Map<DataGridRow, DataGridRowAdapter> _rowAdapters = {};

  void runBatched(void Function() action) {
    _batchDepth++;
    try {
      action();
    } finally {
      _batchDepth--;
      if (_batchDepth == 0 && _pendingNotify) _scheduleNotify();
    }
  }

  void _notify({bool structural = false}) {
    _renderContext = null;
    _rowAdapters.clear();
    _structuralNotify |= structural;
    if (_pendingNotify) return;
    _pendingNotify = true;
    if (_batchDepth == 0) _scheduleNotify();
  }

  void _scheduleNotify() => scheduleMicrotask(_flushNotifications);

  List<Object> _signatures(DataGridRow row, _CellRenderContext ctx) {
    final teacher = _extractTeacherName(row);
    final highlighted = teacher.isNotEmpty && ctx.highlightedTeacher == teacher;
    return [
      for (final cell in row.getCells())
        (
          cell.value,
          (cell.columnName == 'teacher'
                  ? _createTeacherColumnState(ctx, teacher, highlighted)
                  : _createDataCellState(ctx, cell, teacher, highlighted))
              .visualSignature,
          ctx.showStatusSymbols,
          SimplifiedTimetableTheme.fontScaleFactor,
          SimplifiedTimetableTheme.nonExchangeableColor,
          SimplifiedTimetableTheme.highlightedTeacherColor,
        ),
    ];
  }

  void _flushNotifications() {
    if (_disposed || !_pendingNotify || _batchDepth > 0) return;
    _pendingNotify = false;
    if (_structuralNotify || _rowSignatures.isEmpty) {
      _structuralNotify = false;
      _rowSignatures.clear();
      notifyDataSourceListeners();
      return;
    }
    // A data source can outlive a login screen. Leave it invalidated until
    // attachRef reconnects it; never read a disposed WidgetRef asynchronously.
    _CellRenderContext ctx;
    try {
      ctx = _renderContext ??= _buildRenderContext();
    } on StateError {
      _rowSignatures.clear();
      return;
    }
    final changed = <RowColumnIndex>[];
    for (var rowIndex = 0; rowIndex < _dataGridRows.length; rowIndex++) {
      final row = _dataGridRows[rowIndex];
      final previous = _rowSignatures[row];
      if (previous == null) {
        continue; // Not built yet; it will read fresh state.
      }
      final next = _signatures(row, ctx);
      for (var column = 0; column < next.length; column++) {
        if (column >= previous.length || previous[column] != next[column]) {
          changed.add(RowColumnIndex(rowIndex, column));
        }
      }
      _rowSignatures[row] = next;
    }
    for (final cell in changed) {
      notifyDataSourceListeners(rowColumnIndex: cell);
    }
  }

  /// 공통 데이터 초기화 메서드
  void _initializeData(List<TimeSlot> timeSlots, List<Teacher> teachers) {
    _timeSlots = timeSlots;
    _teachers = teachers;
    _nonExchangeableManager.setTimeSlots(timeSlots);
    _buildDataGridRows();
  }

  /// 공통 캐시 초기화 및 UI 업데이트 메서드
  void _clearCacheAndNotify() {
    _localCache.clear();
    _notify();
  }

  /// DataGrid 행 데이터 빌드
  void _buildDataGridRows() {
    // 요일별로 데이터 그룹화
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData =
        _groupTimeSlotsByDayAndPeriod();

    // 요일 목록 추출 및 정렬
    List<String> days = groupedData.keys.toList()..sort(DayUtils.compareDays);
    _firstDayName = days.isEmpty ? null : days.first;

    _dataGridRows = _createRows(groupedData, days);
  }

  /// TimeSlot 리스트를 요일별, 교시별로 그룹화
  Map<String, Map<int, Map<String, TimeSlot?>>>
  _groupTimeSlotsByDayAndPeriod() {
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = {};

    for (TimeSlot slot in _timeSlots) {
      if (slot.dayOfWeek == null ||
          slot.period == null ||
          slot.teacher == null) {
        continue;
      }

      String dayName = DayUtils.getDayName(slot.dayOfWeek!);
      int period = slot.period!;
      String teacherName = slot.teacher!;

      // 요일별 데이터 초기화
      groupedData.putIfAbsent(dayName, () => {});

      // 교시별 데이터 초기화
      groupedData[dayName]!.putIfAbsent(period, () => {});

      // 교사별 데이터 저장
      groupedData[dayName]![period]![teacherName] = slot;
    }

    return groupedData;
  }

  /// DataGrid 행 생성
  List<DataGridRow> _createRows(
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData,
    List<String> days,
  ) {
    List<DataGridRow> rows = [];

    for (Teacher teacher in _teachers) {
      List<DataGridCell> cells = [];

      // 교사명 셀
      cells.add(
        DataGridCell<String>(columnName: 'teacher', value: teacher.name),
      );

      // 각 요일별 실제 존재하는 교시 데이터 추가
      for (String day in days) {
        // 해당 요일에 실제 존재하는 교시만 가져오기
        List<int> dayPeriods = (groupedData[day]?.keys.toList() ?? [])..sort();
        for (int period in dayPeriods) {
          String columnName = '${day}_$period';
          TimeSlot? slot = groupedData[day]?[period]?[teacher.name];

          String cellValue = '';
          if (slot != null && slot.isNotEmpty) {
            // 학급번호와 과목명을 줄바꿈으로 구분하여 표시
            if (slot.className != null && slot.className!.isNotEmpty) {
              cellValue += slot.className!;
            }
            if (slot.subject != null && slot.subject!.isNotEmpty) {
              if (cellValue.isNotEmpty) {
                cellValue += '\n';
              }
              cellValue += slot.subject!;
            }
          }

          cells.add(
            DataGridCell<String>(columnName: columnName, value: cellValue),
          );
        }
      }

      rows.add(DataGridRow(cells: cells));
    }

    return rows;
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final ctx = _renderContext ??= _buildRenderContext();
    final cached = _rowAdapters[row];
    if (cached != null) return cached;
    _rowSignatures[row] = _signatures(row, ctx);

    // 교사명은 행마다 한 번만 추출한다.
    // (예전에는 셀마다 행 전체를 훑어 셀 수의 제곱만큼 비교가 일어났다)
    final cells = row.getCells();
    final String teacherName = _extractTeacherName(row);
    final bool isHighlightedTeacher =
        teacherName.isNotEmpty && ctx.highlightedTeacher == teacherName;

    return _rowAdapters[row] = DataGridRowAdapter(
      cells: [
        for (final dataGridCell in cells)
          _buildCellWidget(
            ctx,
            dataGridCell,
            teacherName,
            isHighlightedTeacher,
          ),
      ],
    );
  }

  Widget _buildCellWidget(
    _CellRenderContext ctx,
    DataGridCell dataGridCell,
    String teacherName,
    bool isHighlightedTeacher,
  ) {
    final bool isTeacherColumn = dataGridCell.columnName == 'teacher';

    final CellStateInfo cellState =
        isTeacherColumn
            ? _createTeacherColumnState(ctx, teacherName, isHighlightedTeacher)
            : _createDataCellState(
              ctx,
              dataGridCell,
              teacherName,
              isHighlightedTeacher,
            );

    return SimplifiedTimetableCell(
      content: dataGridCell.value.toString(),
      isTeacherColumn: isTeacherColumn,
      isSelected: cellState.isSelected,
      isExchangeable: cellState.isExchangeableTeacher,
      isLastColumnOfDay: cellState.isLastColumnOfDay,
      isFirstColumnOfDay: cellState.isFirstColumnOfDay,
      isInCircularPath: cellState.isInCircularPath,
      circularPathStep: cellState.circularPathStep,
      isInSelectedPath: cellState.isInSelectedPath,
      isInDualPath: cellState.isInDualPath,
      pathStepNumber: cellState.pathStepNumber,
      isTargetCell: cellState.isTargetCell,
      isNonExchangeable: cellState.isNonExchangeable,
      isExchangedSourceCell: cellState.isExchangedSourceCell,
      isExchangedDestinationCell: cellState.isExchangedDestinationCell,
      overlayDate: cellState.overlayDate,
      isTeacherNameSelected: cellState.isTeacherNameSelected,
      isHighlightedTeacher: cellState.isHighlightedTeacher,
      showStatusSymbols: ctx.showStatusSymbols,
    );
  }

  /// 한 번의 알림(notify)마다 한 번만 읽어 두는 렌더링 스냅샷
  _CellRenderContext _buildRenderContext() {
    final cellState = ref.read(cellSelectionProvider);

    String highlightedTeacher = '';
    try {
      highlightedTeacher = ref.read(activeTeacherNameProvider).trim();
    } catch (e) {
      AppLogger.error('하이라이트 교사명 조회 중 오류: $e', e);
    }

    return _CellRenderContext(
      cellState: cellState,
      highlightedTeacher: highlightedTeacher,
      oneToOneArrowDirection: ref.read(oneToOneArrowDirectionProvider),
      showStatusSymbols: ref.read(cellStatusSymbolVisibilityProvider),
      overlayLabels: _overlayLabelsByCellKey(),
    );
  }

  /// 교사명 추출
  String _extractTeacherName(DataGridRow row) =>
      CellStateHelper.extractTeacherName(row);

  /// 교사명 열 상태 정보 생성
  CellStateInfo _createTeacherColumnState(
    _CellRenderContext ctx,
    String teacherName,
    bool isHighlightedTeacher,
  ) {
    return CellStateHelper.createTeacherColumnState(
      cellState: ctx.cellState,
      teacherName: teacherName,
      isHighlightedTeacher: isHighlightedTeacher,
      isInCircularPath: ctx.isInCircularPath,
      isInDualPath: ctx.isInDualPath,
      isInSelectedOneToOnePath: ctx.isInSelectedOneToOnePath,
    );
  }

  /// 데이터 셀 상태 정보 생성
  CellStateInfo _createDataCellState(
    _CellRenderContext ctx,
    DataGridCell dataGridCell,
    String teacherName,
    bool isHighlightedTeacher,
  ) {
    return CellStateHelper.createDataCellState(
      cellState: ctx.cellState,
      dataGridCell: dataGridCell,
      teacherName: teacherName,
      isHighlightedTeacher: isHighlightedTeacher,
      oneToOneArrowDirection: ctx.oneToOneArrowDirection,
      overlayLabels: ctx.overlayLabels,
      isInCircularPath: ctx.isInCircularPath,
      isInDualPath: ctx.isInDualPath,
      isInSelectedOneToOnePath: ctx.isInSelectedOneToOnePath,
      localCache: _localCache,
      isNonExchangeableTimeSlot:
          _nonExchangeableManager.isNonExchangeableTimeSlot,
      isFirstColumnOfDay: _isFirstColumnOfDay,
    );
  }

  /// 교사행 하이라이트 갱신 — 시간표의 교사가 바뀌었을 때 그리드를 다시 그린다
  void refreshHighlightedTeacherName() {
    _clearCacheAndNotify();
  }

  /// 교체된 칸에 붙일 꼬리표 계산 (S1.5, "?" 마커는 S1.10)
  ///
  /// 교체된 칸이 아니면(빠진 수업도 맡은 수업도 아니면) 꼬리표가 필요 없다.
  ///
  /// - **날짜표시 OFF**: 실제 날짜(예: "10.07")를 꼬리표로 붙인다. 순환·2중
  ///   교체 등 참여 노드별 날짜를 알 수 없는 칸은 null을 반환해 생략한다 —
  ///   틀린 날짜를 보여주는 것보다 안전하다.
  /// - **날짜표시 ON**: 헤더에 이미 실제 날짜가 있으므로 원칙적으로 꼬리표가
  ///   필요 없지만, 순환·2중 교체처럼 날짜가 미확정인 칸은 "?"를 붙여
  ///   "이 칸의 날짜는 결강일 주에 임시로 묶여 표시된 것"임을 알린다
  ///   (`ExchangeCellDates`의 `undatedKeys` — S1.10).
  /// 교체된 칸에 그릴 날짜 꼬리표. 칸 안 배지가 아니라 그리드 위 층에서 쓴다.
  ///
  /// 예전에는 모든 행 × 모든 칸을 훑으며 칸마다 키 문자열을 다시 만들었다.
  /// 꼬리표가 붙는 칸은 교체된 칸뿐이므로, 꼬리표 목록 쪽에서 역으로 찾는다.
  List<OverlayDateMark> collectOverlayDateMarks(List<GridColumn> columns) {
    final labels = _overlayLabelsByCellKey();
    if (labels.isEmpty) return const [];

    return CellStateHelper.collectOverlayDateMarks(
      labels: labels,
      columns: columns,
      dataGridRows: _dataGridRows,
      cellState: ref.read(cellSelectionProvider),
    );
  }

  /// 칸 키(`교사_요일_교시`) → 꼬리표 글자. 교체된 칸인지는 호출하는 쪽에서 거른다.
  Map<String, String> _overlayLabelsByCellKey() {
    final activeItems =
        ref.read(exchangeHistoryServiceProvider).getActiveExchangeList();

    if (!ref.read(showWeekHeaderProvider)) {
      return CellStateHelper.overlayLabelsForUndatedHeader(activeItems);
    }

    return CellStateHelper.overlayLabelsForDatedHeader(
      activeItems,
      ref.read(selectedWeekProvider),
    );
  }

  /// 요일별 첫 번째 교시 확인 (굵은 요일 구분선을 그릴지 여부)
  ///
  /// 첫 요일(보통 월)은 제외한다. 요일 구분선은 요일과 요일 "사이"를 나누는
  /// 선인데, 첫 요일 왼쪽은 이미 교사명 고정열 경계라 선이 겹쳐 보였다
  /// (2026-10-01 요청으로 제거 — 헤더의 `FixedHeaderStyleManager`와 같은 기준).
  bool _isFirstColumnOfDay(String day, int period) {
    return period == 1 && day != _firstDayName;
  }

  /// 선택 상태 업데이트 (재렌더링 방지)
  void updateSelection(String? teacher, String? day, int? period) {
    if (teacher != null && day != null && period != null) {
      ref.read(cellSelectionProvider.notifier).selectCell(teacher, day, period);
    }
    _localCache.clear(); // 로컬 캐시 초기화
    _notify(); // Syncfusion DataGrid 전용 메서드 사용 (재렌더링 방지)
  }

  /// 타겟 셀 상태 업데이트
  void updateTargetCell(String? teacher, String? day, int? period) {
    if (teacher != null && day != null && period != null) {
      ref
          .read(cellSelectionProvider.notifier)
          .selectTargetCell(teacher, day, period);
    }
    _localCache.clear(); // 로컬 캐시 초기화
    _notify(); // Syncfusion DataGrid 전용 메서드 사용
  }

  /// 교체 가능한 교사 정보 업데이트
  void updateExchangeableTeachers(
    List<Map<String, dynamic>> exchangeableTeachers,
  ) {
    ref
        .read(cellSelectionProvider.notifier)
        .updateExchangeableTeachers(exchangeableTeachers);
    _localCache.clear(); // 로컬 캐시 초기화
    _notify(); // Syncfusion DataGrid 전용 메서드 사용
  }

  /// 교체 옵션 업데이트
  void updateExchangeOptions(List<ExchangeOption> exchangeOptions) {
    _exchangeOptions = exchangeOptions;
    _notify(); // Syncfusion DataGrid 전용 메서드 사용
  }

  /// 교체 옵션 가져오기
  List<ExchangeOption> get exchangeOptions => _exchangeOptions;

  /// 교체 가능한 옵션 개수
  int get exchangeableCount =>
      _exchangeOptions.where((option) => option.isExchangeable).length;

  /// 선택된 순환교체 경로 업데이트
  void updateSelectedCircularPath(CircularExchangePath? path) {
    ref.read(cellSelectionProvider.notifier).setCircularPath(path);
    _clearCacheAndNotify();
  }

  /// 선택된 1:1 교체 경로 업데이트
  void updateSelectedOneToOnePath(OneToOneExchangePath? path) {
    ref.read(cellSelectionProvider.notifier).setOneToOnePath(path);
    _clearCacheAndNotify();
  }

  /// 선택된 2중교체 경로 업데이트
  void updateSelectedDualPath(DualExchangePath? path) {
    ref.read(cellSelectionProvider.notifier).setDualPath(path);
    _clearCacheAndNotify();
  }

  /// 선택된 보강 경로 업데이트
  void updateSelectedSupplementPath(SupplementExchangePath? path) {
    ref.read(cellSelectionProvider.notifier).setSupplementPath(path);
    _clearCacheAndNotify();
  }

  /// 데이터 업데이트
  void updateData(List<TimeSlot> timeSlots, List<Teacher> teachers) {
    final previousRows = _dataGridRows;
    _initializeData(timeSlots, teachers);
    _localCache.clear();
    final nextRows = _dataGridRows;
    final sameShape =
        previousRows.length == nextRows.length &&
        List.generate(nextRows.length, (i) {
          final before = previousRows[i].getCells();
          final after = nextRows[i].getCells();
          return before.length == after.length &&
              before.first.value == after.first.value &&
              List.generate(
                after.length,
                (j) => before[j].columnName == after[j].columnName,
              ).every((v) => v);
        }).every((v) => v);
    if (sameShape) {
      for (var i = 0; i < nextRows.length; i++) {
        final before = previousRows[i].getCells();
        final after = nextRows[i].getCells();
        for (var j = 0; j < after.length; j++) {
          if (before[j].value != after[j].value) before[j] = after[j];
        }
      }
      _dataGridRows = previousRows;
    }
    _notify(structural: !sameShape);
  }

  /// 교체불가 편집 모드 설정
  void setNonExchangeableEditMode(bool isEditMode) {
    if (isNonExchangeableEditMode == isEditMode) return;
    _nonExchangeableManager.setNonExchangeableEditMode(isEditMode);
    _clearCacheAndNotify();
  }

  /// 교체불가 편집 모드 상태 확인
  bool get isNonExchangeableEditMode =>
      _nonExchangeableManager.isNonExchangeableEditMode;

  /// UI 업데이트 전용 메서드 (데이터 변경 없이 UI만 갱신)
  void refreshUI() {
    _localCache.clear();
    _notify(structural: true);
  }

  /// 특정 교사의 모든 TimeSlot을 교체불가로 설정
  void setTeacherAsNonExchangeable(String teacherName) {
    _nonExchangeableManager.setTeacherAsNonExchangeable(teacherName);
    _clearCacheAndNotify();
  }

  /// 특정 교사의 모든 TimeSlot을 교체가능/교체불가로 토글
  void toggleTeacherAllTimes(String teacherName) {
    _nonExchangeableManager.toggleTeacherAllTimes(teacherName);

    // 교체불가 셀 데이터 저장 (별도 파일로 저장)
    _saveNonExchangeableCells();

    _clearCacheAndNotify();
  }

  /// 특정 셀을 교체불가로 설정 또는 해제 (토글 방식, 빈 셀 포함)
  void setCellAsNonExchangeable(String teacherName, String day, int period) {
    _nonExchangeableManager.setCellAsNonExchangeable(teacherName, day, period);

    // 교체불가 셀 테마 색상 저장 (현재 색상 유지하면서 저장)
    // 클릭 시마다 현재 색상 설정을 저장하여 일관성 유지
    SimplifiedTimetableTheme.setNonExchangeableColor(
      SimplifiedTimetableTheme.nonExchangeableColor,
    );

    // 교체불가 셀 데이터 저장 (별도 파일로 저장)
    _saveNonExchangeableCells();

    _clearCacheAndNotify();
  }

  /// 교체불가 셀 데이터 저장 (별도 파일로 저장)
  ///
  /// §10.6: 날짜 지정 셀은 TimeSlot에 굽지 않으므로 `extractNonExchangeableCellsFromTimeSlots`
  /// 결과(매주 반복 셀만)에는 나타나지 않는다. 이 결과로 그대로 덮어쓰면 사용자가
  /// 매주 반복 셀 하나만 토글해도 저장 파일에서 날짜 지정 셀이 조용히 사라진다 —
  /// `nonExchangeableDatedCellsProvider`에 보관해 둔 값과 합쳐서 저장한다.
  Future<void> _saveNonExchangeableCells() async {
    try {
      final storageService = NonExchangeableDataStorageService();
      final recurringCells = storageService
          .extractNonExchangeableCellsFromTimeSlots(_timeSlots);
      final datedCells = ref.read(nonExchangeableDatedCellsProvider);
      await storageService.saveNonExchangeableCells([
        ...recurringCells,
        ...datedCells,
      ]);
    } catch (e) {
      AppLogger.error('교체불가 셀 데이터 저장 중 오류: $e', e);
    }
  }

  /// 모든 교체불가 설정 초기화
  void resetAllNonExchangeableSettings() {
    _nonExchangeableManager.resetAllNonExchangeableSettings();
    _clearCacheAndNotify();
  }

  /// 모든 캐시 초기화 (외부에서 호출 가능)
  void clearAllCaches() {
    _localCache.clear();
    _notify();
  }

  /// 데이터 변경 알림 (외부에서 호출 가능) - 재렌더링 방지
  void notifyDataChanged() {
    // 캐시 초기화는 실제로 데이터가 변경된 경우에만 수행
    // 단순 UI 업데이트의 경우 캐시를 유지하여 성능 향상
    _notify();
  }

  /// 교체된 셀 상태 업데이트 (교체 리스트 변경 시 호출)
  void updateExchangedCells(List<String> exchangedCellKeys) {
    ref
        .read(cellSelectionProvider.notifier)
        .updateExchangedCells(exchangedCellKeys);
    _clearCacheAndNotify();
  }

  /// 교체된 목적지 셀 상태 업데이트
  void updateExchangedDestinationCells(List<String> destinationCellKeys) {
    ref
        .read(cellSelectionProvider.notifier)
        .updateExchangedDestinationCells(destinationCellKeys);
    _localCache.clear(); // 로컬 캐시 초기화
    _notify(); // Syncfusion DataGrid 전용 메서드 사용
  }

  /// 모든 선택 상태 초기화 (셀 선택, 타겟 셀, 교체 경로 등)
  void clearAllSelections() {
    ref.read(cellSelectionProvider.notifier).clearAllSelections();
    _localCache.clear(); // 로컬 캐시 초기화
    _notify(); // Syncfusion DataGrid 전용 메서드 사용
  }

  // ========================================
  // 배치 업데이트 메서드들
  // ========================================

  /// Level 1 전용 배치 업데이트: 경로 선택만 초기화
  void resetPathSelectionBatch() {
    ref.read(cellSelectionProvider.notifier).setCircularPath(null);
    ref.read(cellSelectionProvider.notifier).setOneToOnePath(null);
    ref.read(cellSelectionProvider.notifier).setDualPath(null);
    ref.read(cellSelectionProvider.notifier).setSupplementPath(null);
    _localCache.clear(); // 로컬 캐시 초기화
    _notify(); // 한 번만 UI 업데이트
  }

  /// Level 2 전용 배치 업데이트: 교체 상태 초기화
  void resetExchangeStatesBatch() {
    // 경로 선택 초기화
    ref.read(cellSelectionProvider.notifier).setCircularPath(null);
    ref.read(cellSelectionProvider.notifier).setOneToOnePath(null);
    ref.read(cellSelectionProvider.notifier).setDualPath(null);
    ref.read(cellSelectionProvider.notifier).setSupplementPath(null);

    // 교체 옵션 초기화
    _exchangeOptions = [];

    _localCache.clear(); // 로컬 캐시 초기화
    _notify(); // 한 번만 UI 업데이트
  }

  /// TimeSlot 리스트 접근자 (동기화용)
  List<TimeSlot> get timeSlots => _timeSlots;

  /// 선택된 순환교체 경로 접근자 (보기 모드용)
  CircularExchangePath? getSelectedCircularPath() {
    return ref.read(cellSelectionProvider).selectedCircularPath;
  }

  /// 선택된 1:1 교체 경로 접근자 (보기 모드용)
  OneToOneExchangePath? getSelectedOneToOnePath() {
    return ref.read(cellSelectionProvider).selectedOneToOnePath;
  }

  /// 선택된 2중교체 경로 접근자 (보기 모드용)
  DualExchangePath? getSelectedDualPath() {
    return ref.read(cellSelectionProvider).selectedDualPath;
  }

  /// 선택된 보강 경로 접근자 (보기 모드용)
  SupplementExchangePath? getSelectedSupplementPath() {
    return ref.read(cellSelectionProvider).selectedSupplementPath;
  }

  /// 타겟 셀의 요일 반환 (보기 모드용)
  String? get targetDay => ref.read(cellSelectionProvider).targetDay;

  /// 타겟 셀의 교시 반환 (보기 모드용)
  int? get targetPeriod => ref.read(cellSelectionProvider).targetPeriod;

  /// 메모리 정리 메서드 (dispose)
  @override
  void dispose() {
    _disposed = true;
    _rowSignatures.clear();
    _rowAdapters.clear();
    // 캐시 정리
    _localCache.clear();

    // 리스트 정리
    _timeSlots.clear();
    _teachers.clear();
    _dataGridRows.clear();
    _exchangeOptions.clear();

    // 관리자 정리
    _nonExchangeableManager.resetAllNonExchangeableSettings();

    super.dispose();
  }
}

/// 한 번의 DataGrid 재빌드 동안 바뀌지 않는 값들의 스냅샷
///
/// 셀마다 `ref.read()`를 반복하면 보이는 셀 수만큼 Provider 조회가 일어난다.
/// 알림 한 번에 한 번만 읽어 두고 모든 셀이 공유한다.
class _CellRenderContext {
  _CellRenderContext({
    required this.cellState,
    required this.highlightedTeacher,
    required this.oneToOneArrowDirection,
    required this.showStatusSymbols,
    required this.overlayLabels,
  });

  final CellSelectionState cellState;
  final String highlightedTeacher;
  final ArrowDirection oneToOneArrowDirection;
  final bool showStatusSymbols;
  final Map<String, String> overlayLabels;

  bool isInCircularPath(String teacherName, String day, int period) {
    final path = cellState.selectedCircularPath;
    if (path == null) return false;
    for (final node in path.nodes) {
      if (node.teacherName == teacherName &&
          node.day == day &&
          node.period == period) {
        return true;
      }
    }
    return false;
  }

  bool isInDualPath(String teacherName, String day, int period) {
    final path = cellState.selectedDualPath;
    if (path == null) return false;
    for (final node in [path.node1, path.node2, path.nodeA, path.nodeB]) {
      if (node.teacherName == teacherName &&
          node.day == day &&
          node.period == period) {
        return true;
      }
    }
    return false;
  }

  bool isInSelectedOneToOnePath(String teacherName, String day, int period) {
    final path = cellState.selectedOneToOnePath;
    if (path == null) return false;
    return (path.sourceNode.teacherName == teacherName &&
            path.sourceNode.day == day &&
            path.sourceNode.period == period) ||
        (path.targetNode.teacherName == teacherName &&
            path.targetNode.day == day &&
            path.targetNode.period == period);
  }
}

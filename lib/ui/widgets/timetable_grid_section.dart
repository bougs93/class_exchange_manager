import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/excel_service.dart';
import '../../services/exchange_service.dart';
import '../../providers/services_provider.dart';
import '../../providers/arrow_display_provider.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../models/exchange_mode.dart';
import '../../utils/timetable_data_source.dart';
import '../../utils/constants.dart';
import '../../utils/day_utils.dart';
import 'timetable_grid/widget_arrows_manager.dart';
import '../../utils/logger.dart';
import '../../models/exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/supplement_exchange_path.dart';
import '../../models/exchange_node.dart';
import '../../models/time_slot.dart';
import '../../services/exchange_history_service.dart';
import '../../utils/exchange_algorithm.dart';
import '../../models/exchange_history_item.dart';
import '../../providers/timetable_theme_provider.dart';
import '../../providers/state_reset_provider.dart';
import '../../utils/simplified_timetable_theme.dart';
import 'timetable_grid/timetable_grid_constants.dart';
import 'timetable_grid/exchange_arrow_style.dart';
import 'timetable_grid/exchange_arrow_painter.dart';
import 'timetable_grid/zoom_manager.dart';
import 'timetable_grid/exchange_view_manager.dart';
import 'timetable_grid/exchange_executor.dart';
import 'timetable_grid/grid_header_widgets.dart';

/// TimeSlots 백업 상태 관리
class TimeSlotsBackupState {
  final List<TimeSlot>? originalTimeSlots;
  final bool isValid;
  final int count;

  const TimeSlotsBackupState({
    this.originalTimeSlots,
    this.isValid = false,
    this.count = 0,
  });

  TimeSlotsBackupState copyWith({
    List<TimeSlot>? originalTimeSlots,
    bool? isValid,
    int? count,
  }) {
    return TimeSlotsBackupState(
      originalTimeSlots: originalTimeSlots ?? this.originalTimeSlots,
      isValid: isValid ?? this.isValid,
      count: count ?? this.count,
    );
  }
}

/// TimeSlots 백업 데이터 Notifier
class TimeSlotsBackupNotifier extends StateNotifier<TimeSlotsBackupState> {
  TimeSlotsBackupNotifier() : super(const TimeSlotsBackupState());

  /// 백업 데이터 생성
  void createBackup(List<TimeSlot> timeSlots) {
    try {
      final backupSlots = timeSlots.map((slot) => slot.copy()).toList();
      state = TimeSlotsBackupState(
        originalTimeSlots: backupSlots,
        isValid: true,
        count: backupSlots.length,
      );
      AppLogger.exchangeInfo('TimeSlots 백업 생성 완료: ${backupSlots.length}개');
    } catch (e) {
      AppLogger.exchangeDebug('TimeSlots 백업 생성 중 오류: $e');
      state = const TimeSlotsBackupState();
    }
  }

  /// 백업 데이터 복원
  List<TimeSlot>? restoreBackup() {
    if (state.isValid && state.originalTimeSlots != null) {
      return state.originalTimeSlots!.map((slot) => slot.copy()).toList();
    }
    return null;
  }

  /// 백업 데이터 초기화
  void clear() {
    state = const TimeSlotsBackupState();
    AppLogger.exchangeInfo('TimeSlots 백업 데이터 초기화 완료');
  }
}

/// TimeSlots 백업 데이터 Provider
final timeSlotsBackupProvider = StateNotifierProvider<TimeSlotsBackupNotifier, TimeSlotsBackupState>((ref) {
  return TimeSlotsBackupNotifier();
});

/// 교체된 셀의 원본 정보를 저장하는 클래스
/// 복원에 필요한 최소한의 정보만 포함
class ExchangeBackupInfo {
  final String teacher;      // 교사명
  final int dayOfWeek;       // 요일 (1-5)
  final int period;          // 교시
  final String? subject;     // 과목명
  final String? className;   // 학급명

  ExchangeBackupInfo({
    required this.teacher,
    required this.dayOfWeek,
    required this.period,
    this.subject,
    this.className,
  });

  /// TimeSlot에서 ExchangeBackupInfo 생성
  factory ExchangeBackupInfo.fromTimeSlot(TimeSlot slot) {
    return ExchangeBackupInfo(
      teacher: slot.teacher ?? '',
      dayOfWeek: slot.dayOfWeek ?? 0,
      period: slot.period ?? 0,
      subject: slot.subject,
      className: slot.className,
    );
  }

  /// 디버깅용 문자열 반환
  String get debugInfo {
    return 'ExchangeBackupInfo(teacher: $teacher, dayOfWeek: $dayOfWeek, period: $period, subject: $subject, className: $className)';
  }
}

/// 시간표 그리드 섹션 위젯
/// Syncfusion DataGrid를 사용한 시간표 표시를 담당
class TimetableGridSection extends ConsumerStatefulWidget {
  final TimetableData? timetableData;
  final TimetableDataSource? dataSource;
  final List<GridColumn> columns;
  final List<StackedHeaderRow> stackedHeaders;
  final bool isExchangeModeEnabled;
  final bool isCircularExchangeModeEnabled;
  final bool isChainExchangeModeEnabled;
  final int exchangeableCount;
  final Function(DataGridCellTapDetails) onCellTap;
  final ExchangePath? selectedExchangePath; // 선택된 교체 경로 (모든 타입 지원)
  final ExchangeArrowStyle? customArrowStyle; // 커스텀 화살표 스타일
  final VoidCallback? onHeaderThemeUpdate; // 헤더 테마 업데이트 콜백

  const TimetableGridSection({
    super.key,
    required this.timetableData,
    required this.dataSource,
    required this.columns,
    required this.stackedHeaders,
    required this.isExchangeModeEnabled,
    required this.isCircularExchangeModeEnabled,
    required this.isChainExchangeModeEnabled,
    required this.exchangeableCount,
    required this.onCellTap,
    this.selectedExchangePath,
    this.customArrowStyle,
    this.onHeaderThemeUpdate,
  });

  @override
  ConsumerState<TimetableGridSection> createState() => _TimetableGridSectionState();
}

class _TimetableGridSectionState extends ConsumerState<TimetableGridSection> {
  // 헬퍼 클래스들
  late ZoomManager _zoomManager;
  late ExchangeViewManager _exchangeViewManager;
  late ExchangeExecutor _exchangeExecutor;

  // 교체 히스토리 서비스
  final ExchangeHistoryService _historyService = ExchangeHistoryService();

  // 교체 서비스
  final ExchangeService _exchangeService = ExchangeService();

  // 내부적으로 관리하는 선택된 교체 경로 (교체된 셀 클릭 시 사용) - 제거됨
  // ExchangePath? _internalSelectedPath;

  // 교체 뷰 체크박스 상태
  bool _isExchangeViewEnabled = false;

  // 교체된 셀의 원본 정보를 저장하는 리스트 (복원용)
  final List<ExchangeBackupInfo> _exchangeListWork = [];

  // 이미 백업 완료된 교체 개수 (간단한 추적)
  int _backedUpCount = 0;

  // 싱글톤 화살표 매니저
  final WidgetArrowsManager _arrowsManager = WidgetArrowsManager();

  /// 현재 선택된 교체 경로 (Riverpod 기반)
  ExchangePath? get currentSelectedPath {
    final arrowState = ref.watch(arrowDisplayProvider);
    return arrowState.selectedPath ?? widget.selectedExchangePath;
  }

  /// 교체 모드인지 확인 (1:1, 순환, 연쇄 중 하나라도 활성화된 경우)
  bool get isInExchangeMode => widget.isExchangeModeEnabled ||
                               widget.isCircularExchangeModeEnabled ||
                               widget.isChainExchangeModeEnabled;
  
  /// 교체된 셀에서 선택된 경로인지 확인 (Riverpod 기반)
  bool get isFromExchangedCell {
    final arrowState = ref.watch(arrowDisplayProvider);
    return arrowState.isFromExchangedCell;
  }
  
  /// 셀이 선택된 상태인지 확인 (보강 버튼 활성화용)
  bool get isCellSelected {
    final themeState = ref.read(timetableThemeProvider);
    return themeState.selectedTeacher != null && 
           themeState.selectedDay != null && 
           themeState.selectedPeriod != null;
  }

  @override
  void initState() {
    super.initState();

    // ZoomManager 초기화
    _zoomManager = ZoomManager(
      onZoomChanged: () {
        if (mounted) setState(() {});
      },
    );
    _zoomManager.initialize();

    // ExchangeViewManager 초기화
    _exchangeViewManager = ExchangeViewManager(
      ref: ref,
      dataSource: widget.dataSource,
      timetableData: widget.timetableData,
      exchangeService: _exchangeService,
    );

    // ExchangeExecutor 초기화
    _exchangeExecutor = ExchangeExecutor(
      ref: ref,
      historyService: _historyService,
      dataSource: widget.dataSource,
      onExchangeViewUpdate: () {
        // 교체 실행 후 교체 뷰 상태 확인 및 업데이트
        if (_isExchangeViewEnabled) {
          AppLogger.exchangeDebug('🔄 교체 실행 후 교체 뷰 업데이트 필요');
          _enableExchangeView();
        } else {
          AppLogger.exchangeDebug('🔄 교체 실행 후 교체 뷰 업데이트 건너뜀 (비활성화 상태)');
          // 교체 뷰가 비활성화된 상태에서는 업데이트하지 않음
        }
      },
    );

    // 화살표 매니저 초기화
    _initializeArrowsManager();

    // 테이블 렌더링 완료 후 콜백 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.timetableData != null && widget.dataSource != null) {
        _notifyTableRenderingComplete();
      }
    });
  }

  @override
  void didUpdateWidget(TimetableGridSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 테이블 데이터나 데이터 소스가 변경된 경우 테이블 렌더링 완료 감지
    if (widget.timetableData != oldWidget.timetableData ||
        widget.dataSource != oldWidget.dataSource) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.timetableData != null && widget.dataSource != null) {
          _notifyTableRenderingComplete();
        }
      });
    }
  }

  @override
  void dispose() {
    // 화살표 매니저 정리 (싱글톤이므로 clearAllArrows만 호출)
    _arrowsManager.clearAllArrows();
    
    // 교체 뷰 관련 메모리 정리
    _exchangeListWork.clear();
    _backedUpCount = 0;
    
    // 기존 리소스 정리
    _zoomManager.dispose();
    super.dispose();
  }

  /// 테이블 렌더링 완료 알림
  void _notifyTableRenderingComplete() {
    widget.onHeaderThemeUpdate?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timetableData == null || widget.dataSource == null) {
      return const SizedBox.shrink();
    }

    // StateResetProvider 상태 감지 (화살표 초기화는 별도 처리)
    final resetState = ref.watch(stateResetProvider);
    
    // Level 3 초기화 시 교체 뷰 체크박스도 초기 상태로 되돌리기
    if (resetState.lastResetLevel == ResetLevel.allStates && _isExchangeViewEnabled) {
      _isExchangeViewEnabled = false;
      _disableExchangeView();
      AppLogger.exchangeDebug('[StateResetProvider 감지] 교체 뷰 체크박스 초기화 완료 (Level 3)');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            _buildHeader(),

            const SizedBox(height: 2),

            // Syncfusion DataGrid 위젯 (화살표와 함께)
            Expanded(
              child: _buildDataGridWithArrows(),
            ),
          ],
        ),
      ),
    );
  }

  /// 헤더 구성
  Widget _buildHeader() {
    return Row(
      children: [
        const SizedBox(width: 8),

        // 확대/축소 컨트롤
        ZoomControlWidget(
          zoomPercentage: _zoomManager.zoomPercentage,
          zoomFactor: _zoomManager.zoomFactor,
          minZoom: GridLayoutConstants.minZoom,
          maxZoom: GridLayoutConstants.maxZoom,
          onZoomIn: _zoomManager.zoomIn,
          onZoomOut: _zoomManager.zoomOut,
          onResetZoom: _zoomManager.resetZoom,
        ),

        const SizedBox(width: 8),

        // 전체 교사 수 표시
        TeacherCountWidget(
          teacherCount: widget.timetableData!.teachers.length,
        ),

        const SizedBox(width: 8),

        // 교체 뷰 체크박스
        ExchangeViewCheckbox(
          isEnabled: _isExchangeViewEnabled,
          onChanged: (bool? value) {
            setState(() {
              _isExchangeViewEnabled = value ?? false;
            });

            if (_isExchangeViewEnabled) {
              _enableExchangeView();
            } else {
              _disableExchangeView();
            }
          },
        ),

        const SizedBox(width: 8),

        const Spacer(),

        // 보강/교체 버튼들
        Builder(
          builder: (context) {
            // 보강 버튼 활성화 조건 확인
            final supplementEnabled = isInExchangeMode && isCellSelected;
            
            return ExchangeActionButtons(
              onUndo: () => _exchangeExecutor.undoLastExchange(context, _clearInternalPath),
              onRepeat: () => _exchangeExecutor.repeatLastExchange(context),
              onSupplement: supplementEnabled ? _enableTeacherNameSelectionForSupplement : null,
              onDelete: (currentSelectedPath != null && isFromExchangedCell)
                ? () => _exchangeExecutor.deleteFromExchangeList(currentSelectedPath!, context, _clearInternalPath)
                : null,
              onExchange: (isInExchangeMode && !isFromExchangedCell && currentSelectedPath != null)
                ? () => _exchangeExecutor.executeExchange(currentSelectedPath!, context, _clearInternalPath)
                : null,
              showDeleteButton: currentSelectedPath != null && isFromExchangedCell,
              showExchangeButton: isInExchangeMode && !isFromExchangedCell,
              showSupplementButton: isInExchangeMode, // 교체 모드에서만 보강 버튼 표시
            );
          },
        ),
      ],
    );
  }

  /// 화살표 매니저 초기화
  void _initializeArrowsManager() {
    if (widget.timetableData != null) {
      _arrowsManager.initialize(
        timetableData: widget.timetableData!,
        columns: widget.columns,
        zoomFactor: _zoomManager.zoomFactor,
      );
      
      AppLogger.exchangeDebug('화살표 매니저 싱글톤 초기화 완료');
    }
  }

  /// DataGrid와 화살표를 함께 구성
  Widget _buildDataGridWithArrows() {
    Widget dataGrid = _buildDataGrid();

    // 교체 경로가 선택된 경우에만 화살표 표시
    if (currentSelectedPath != null && widget.timetableData != null) {
      // 현재는 기존 CustomPainter 방식 사용 (안정적)
      return _buildDataGridWithLegacyArrows(dataGrid);
    }

    return dataGrid;
  }

  /// 기존 CustomPainter 기반 화살표 표시
  Widget _buildDataGridWithLegacyArrows(Widget dataGridWithGestures) {
    return Stack(
      children: [
        dataGridWithGestures,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: ExchangeArrowPainter(
                selectedPath: currentSelectedPath!,
                timetableData: widget.timetableData!,
                columns: widget.columns,
                customArrowStyle: widget.customArrowStyle,
                zoomFactor: _zoomManager.zoomFactor,
              ),
              child: RepaintBoundary(
                child: Container(),
              ),
            ),
          ),
        ),
      ],
    );
  }


  /// DataGrid 구성
  Widget _buildDataGrid() {
    Widget dataGridContainer = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.copyWith(
              bodyMedium: TextStyle(fontSize: _getScaledFontSize()),
              bodySmall: TextStyle(fontSize: _getScaledFontSize()),
              titleMedium: TextStyle(fontSize: _getScaledFontSize()),
              labelMedium: TextStyle(fontSize: _getScaledFontSize()),
              labelLarge: TextStyle(fontSize: _getScaledFontSize()),
              labelSmall: TextStyle(fontSize: _getScaledFontSize()),
            ),
          ),
          child: SfDataGrid(
            key: ValueKey('${widget.columns.length}_${widget.stackedHeaders.length}_${DateTime.now().millisecondsSinceEpoch}'),
            source: widget.dataSource!,
            columns: _getScaledColumns(),
            stackedHeaderRows: _getScaledStackedHeaders(),
            gridLinesVisibility: GridLinesVisibility.both,
            headerGridLinesVisibility: GridLinesVisibility.both,
            headerRowHeight: _getScaledHeaderHeight(),
            rowHeight: _getScaledRowHeight(),
            allowColumnsResizing: false,
            allowSorting: false,
            allowEditing: false,
            allowTriStateSorting: false,
            allowPullToRefresh: false,
            selectionMode: SelectionMode.none,
            columnWidthMode: ColumnWidthMode.none,
            frozenColumnsCount: GridLayoutConstants.frozenColumnsCount,
            onCellTap: _handleCellTap,
          ),
        ),
      ),
    );

    return dataGridContainer;
  }

  /// 확대/축소에 따른 실제 크기 조정된 열 반환
  List<GridColumn> _getScaledColumns() {
    return widget.columns.map((column) {
      return GridColumn(
        columnName: column.columnName,
        width: _getScaledColumnWidth(column.width),
        label: _getScaledTextWidget(column.label, isHeader: false),
      );
    }).toList();
  }

  /// 확대/축소에 따른 실제 크기 조정된 스택 헤더 반환
  List<StackedHeaderRow> _getScaledStackedHeaders() {
    return widget.stackedHeaders.map((headerRow) {
      return StackedHeaderRow(
        cells: headerRow.cells.map((cell) {
          return StackedHeaderCell(
            columnNames: cell.columnNames,
            child: _getScaledTextWidget(cell.child, isHeader: true),
          );
        }).toList(),
      );
    }).toList();
  }

  /// 확대/축소에 따른 실제 열 너비 반환
  double _getScaledColumnWidth(double baseWidth) {
    return baseWidth * _zoomManager.zoomFactor;
  }

  /// 확대/축소에 따른 실제 크기 조정된 텍스트 위젯 반환
  Widget _getScaledTextWidget(dynamic originalWidget, {required bool isHeader}) {
    if (originalWidget is Text) {
      return Text(
        originalWidget.data ?? '',
        style: TextStyle(
          fontSize: _getScaledFontSize(),
          fontWeight: FontWeight.w600,
          color: isHeader ? Colors.blue[700] : Colors.black87,
        ),
        textAlign: originalWidget.textAlign,
        overflow: originalWidget.overflow,
        maxLines: originalWidget.maxLines,
        textDirection: originalWidget.textDirection,
      );
    }

    if (originalWidget is Container && originalWidget.child is Text) {
      final text = originalWidget.child as Text;
      return Container(
        padding: originalWidget.padding,
        decoration: originalWidget.decoration,
        alignment: originalWidget.alignment,
        child: Text(
          text.data ?? '',
          style: TextStyle(
            fontSize: _getScaledFontSize(),
            fontWeight: FontWeight.w600,
            color: isHeader ? Colors.blue[700] : Colors.black87,
          ),
          textAlign: text.textAlign,
          overflow: text.overflow,
          maxLines: text.maxLines,
          textDirection: text.textDirection,
        ),
      );
    }

    return DefaultTextStyle(
      style: TextStyle(
        fontSize: _getScaledFontSize(),
        fontWeight: FontWeight.w600,
        color: isHeader ? Colors.blue[700] : Colors.black87,
      ),
      child: originalWidget ?? const Text(''),
    );
  }

  /// 확대/축소에 따른 실제 폰트 크기 반환
  double _getScaledFontSize() {
    return GridLayoutConstants.baseFontSize * _zoomManager.zoomFactor;
  }

  /// 확대/축소에 따른 실제 헤더 높이 반환
  double _getScaledHeaderHeight() {
    return AppConstants.headerRowHeight * _zoomManager.zoomFactor;
  }

  /// 확대/축소에 따른 실제 행 높이 반환
  double _getScaledRowHeight() {
    return AppConstants.dataRowHeight * _zoomManager.zoomFactor;
  }



  /// 보강을 위한 교사 이름 선택 기능 활성화
  void _enableTeacherNameSelectionForSupplement() {
    // 교사 이름 선택 기능 활성화
    ref.read(exchangeScreenProvider.notifier).enableTeacherNameSelection();
    
    // 스낵바 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('보강한 교사 이름을 선택하세요'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
    
    AppLogger.exchangeDebug('보강을 위한 교사 이름 선택 기능 활성화');
  }


  /// 보강교체 실행
  void _executeSupplementExchange(String targetTeacherName) {
    if (widget.timetableData == null) {
      AppLogger.exchangeDebug('보강교체 실행 실패: timetableData가 null입니다');
      return;
    }

    // 현재 선택된 셀 정보 가져오기
    final exchangeService = ExchangeService();
    if (!exchangeService.hasSelectedCell()) {
      AppLogger.exchangeDebug('보강교체 실행 실패: 선택된 셀이 없습니다');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('보강할 셀을 먼저 선택해주세요'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final sourceTeacher = exchangeService.selectedTeacher!;
    final sourceDay = exchangeService.selectedDay!;
    final sourcePeriod = exchangeService.selectedPeriod!;

    AppLogger.exchangeDebug('보강교체 실행: $sourceTeacher($sourceDay$sourcePeriod교시) → $targetTeacherName($sourceDay$sourcePeriod교시)');

    // 보강교체 실행
    final success = exchangeService.performSupplementExchange(
      widget.timetableData!.timeSlots,
      sourceTeacher,
      sourceDay,
      sourcePeriod,
      targetTeacherName,
      sourceDay,
      sourcePeriod,
    );

    if (success) {
      // 보강교체 성공 시 히스토리에 저장
      _saveSupplementExchangeToHistory(sourceTeacher, sourceDay, sourcePeriod, targetTeacherName);
      
      // 교체된 셀 상태 업데이트
      _updateExchangedCellsForSupplement(sourceTeacher, sourceDay, sourcePeriod, targetTeacherName);
      
      // 교사 이름 선택 기능 비활성화
      ref.read(exchangeScreenProvider.notifier).disableTeacherNameSelection();
      ref.read(timetableThemeProvider.notifier).updateSelectedTeacherName(null);
      
      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('보강 수업이 추가되었습니다: $targetTeacherName $sourceDay$sourcePeriod교시'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // UI 업데이트
      widget.onHeaderThemeUpdate?.call();
      
      AppLogger.exchangeDebug('보강교체 완료');
    } else {
      // 보강교체 실패 시 오류 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('보강 실패: $targetTeacherName의 $sourceDay$sourcePeriod교시가 빈 셀이 아닙니다'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 보강교체를 히스토리에 저장
  void _saveSupplementExchangeToHistory(String sourceTeacher, String sourceDay, int sourcePeriod, String targetTeacherName) {
    if (widget.timetableData == null) return;

    // 소스 셀의 정보 가져오기
    final sourceSlot = widget.timetableData!.timeSlots.firstWhere(
      (slot) => slot.teacher == sourceTeacher && 
                slot.dayOfWeek == DayUtils.getDayNumber(sourceDay) && 
                slot.period == sourcePeriod,
      orElse: () => TimeSlot(),
    );

    // SupplementExchangePath 생성
    final sourceNode = ExchangeNode(
      teacherName: sourceTeacher,
      day: sourceDay,
      period: sourcePeriod,
      className: sourceSlot.className ?? '',
      subjectName: sourceSlot.subject ?? '',
    );

    final targetNode = ExchangeNode(
      teacherName: targetTeacherName,
      day: sourceDay,
      period: sourcePeriod,
      className: '',  // 원래 빈 셀이었으므로 빈 문자열
      subjectName: '', // 원래 빈 셀이었으므로 빈 문자열
    );

    final supplementPath = SupplementExchangePath(
      sourceNode: sourceNode,
      targetNode: targetNode,
      option: ExchangeOption(
        teacherName: targetTeacherName,
        timeSlot: TimeSlot(
          teacher: targetTeacherName,
          dayOfWeek: DayUtils.getDayNumber(sourceDay),
          period: sourcePeriod,
          className: '',
          subject: '',
        ),
        type: ExchangeType.sameClass,
        priority: 1,
        reason: '보강교체',
      ),
    );

    // ExchangeHistoryService를 통해 히스토리에 저장
    final historyService = ExchangeHistoryService();
    historyService.executeExchange(
      supplementPath,
      customDescription: '보강교체: $sourceTeacher($sourceDay$sourcePeriod교시) → $targetTeacherName',
      additionalMetadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'supplement',
        'source': 'timetable_grid_section',
      },
    );

    AppLogger.exchangeDebug('보강교체 히스토리 저장 완료');
  }

  /// 보강교체 후 교체된 셀 상태 업데이트
  void _updateExchangedCellsForSupplement(String sourceTeacher, String sourceDay, int sourcePeriod, String targetTeacherName) {
    // 교체된 소스 셀과 목적지 셀을 교체된 셀 목록에 추가
    final themeState = ref.read(timetableThemeProvider);
    final themeNotifier = ref.read(timetableThemeProvider.notifier);
    
    // 소스 셀 (문유란 월2): 교체된 소스 셀로 표시
    final sourceCellKey = '${sourceTeacher}_${sourceDay}_$sourcePeriod';
    final currentExchangedCells = themeState.exchangedCells.toList();
    currentExchangedCells.add(sourceCellKey);
    themeNotifier.updateExchangedCells(currentExchangedCells);
    
    // 목적지 셀 (김연주 월2): 교체된 목적지 셀로 표시
    final targetCellKey = '${targetTeacherName}_${sourceDay}_$sourcePeriod';
    final currentDestinationCells = themeState.exchangedDestinationCells.toList();
    currentDestinationCells.add(targetCellKey);
    themeNotifier.updateExchangedDestinationCells(currentDestinationCells);
    
    AppLogger.exchangeDebug('보강교체 셀 상태 업데이트: 소스=$sourceCellKey, 목적지=$targetCellKey');
  }



  /// 교체된 셀 클릭 처리 (Riverpod 기반)
  void _handleExchangedCellClick(String teacherName, String day, int period) {
    AppLogger.exchangeDebug('🖱️ 교체된 셀 클릭: $teacherName | $day$period교시');
    
    // 교체된 셀 선택 상태 플래그 설정 (헤더 색상 비활성화용)
    SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(true);
    
    final exchangePath = _historyService.findExchangePathByCell(
      teacherName,
      day,
      period,
    );

    if (exchangePath != null) {
      AppLogger.exchangeDebug('✅ 교체 경로 발견: ${exchangePath.type} (ID: ${exchangePath.id})');
      
      ref.read(stateResetProvider.notifier).resetExchangeStates(
        reason: '교체된 셀 클릭 - 이전 교체 상태 초기화',
      );

      // Riverpod 기반 화살표 표시
      ref.read(arrowDisplayProvider.notifier).showArrowForExchangedCell(exchangePath);
      
      // 교체된 셀 클릭 시 교체 서비스 상태 업데이트 (헤더 업데이트를 위해)
      _updateExchangeServiceForExchangedCell(teacherName, day, period);
      
      widget.onHeaderThemeUpdate?.call();

      AppLogger.exchangeDebug(
        '교체된 셀 클릭: $teacherName | $day$period교시 → 경로 ID: ${exchangePath.id}',
      );
    } else {
      AppLogger.exchangeDebug('❌ 교체 경로를 찾을 수 없음: $teacherName | $day$period교시');
    }
  }


  /// 일반 셀 탭 시 화살표 숨기기 (Riverpod 기반)
  void _hideExchangeArrows() {
    // Riverpod 기반 화살표 숨기기
    ref.read(arrowDisplayProvider.notifier).hideArrow(
      reason: ArrowDisplayReason.manualHide,
    );
    
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '일반 셀 클릭 - 교체 화살표 숨김',
    );
    AppLogger.exchangeDebug('교체 화살표 숨김 (Riverpod)');
  }

  /// 화살표 상태 초기화 (외부에서 호출) - StateResetProvider에서 처리됨
  void clearAllArrowStates() {
    // 화살표 상태 초기화는 StateResetProvider에서 처리됨
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '외부 호출 - 화살표 상태 초기화',
    );
    AppLogger.exchangeDebug('[외부 호출] 화살표 상태 초기화 요청 (StateResetProvider에서 처리)');
  }

  /// Level 1 전용 화살표 초기화 (경로 선택만 해제) - StateResetProvider에서 처리됨
  void clearPathSelectionOnly() {
    // 화살표 초기화는 StateResetProvider에서 처리됨
    AppLogger.exchangeDebug('[Level 1] 경로 선택만 초기화 요청 (StateResetProvider에서 처리)');
  }

  /// 셀 탭 이벤트 처리
  void _handleCellTap(DataGridCellTapDetails details) {
    final teacherName = _extractTeacherNameFromRowIndex(
      details.rowColumnIndex.rowIndex,
    );
    final columnName = details.column.columnName;

    // 교사 이름 클릭 처리 (새로 추가)
    if (columnName == 'teacher') {
      _handleTeacherNameClick(teacherName);
      return;
    }

    if (columnName != 'teacher') {
      final parts = columnName.split('_');
      if (parts.length == 2) {
        final day = parts[0];
        final period = int.tryParse(parts[1]) ?? 0;

        final isExchangedCell = _historyService.isCellExchanged(teacherName, day, period);

        if (isExchangedCell) {
          _handleExchangedCellClick(teacherName, day, period);
          return;
        }
      }
    }

    // 일반 셀 클릭 시 교체된 셀 선택 상태 플래그 해제 (헤더 색상 복원용)
    SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(false);

    _hideExchangeArrows();
    widget.onCellTap(details);
    widget.onHeaderThemeUpdate?.call();
  }

  /// 교사 이름 클릭 처리 (교체 모드 또는 교체불가 편집 모드에서 동작)
  void _handleTeacherNameClick(String teacherName) {
    // 현재 모드 및 교사 이름 선택 기능 활성화 상태 확인
    final screenState = ref.read(exchangeScreenProvider);
    final currentMode = screenState.currentMode;
    final isNonExchangeableEditMode = currentMode == ExchangeMode.nonExchangeableEdit;
    final isTeacherNameSelectionEnabled = screenState.isTeacherNameSelectionEnabled;
    
    // 교체불가 편집 모드인 경우 교사 전체 시간 토글 기능 사용
    if (isNonExchangeableEditMode) {
      AppLogger.exchangeDebug('교체불가 편집 모드: 교사 전체 시간 토글 기능 사용 - $teacherName');
      _toggleTeacherAllTimesInNonExchangeableMode(teacherName);
      return;
    }
    
    // 교체 모드이지만 교사 이름 선택 기능이 비활성화된 경우 아무 동작하지 않음
    if (!isInExchangeMode || !isTeacherNameSelectionEnabled) {
      AppLogger.exchangeDebug('교사 이름 클릭: 교체 모드가 아니거나 교사 이름 선택 기능이 비활성화됨');
      return;
    }
    
    // 교체 모드인 경우 교사 이름 선택 기능 사용
    final themeNotifier = ref.read(timetableThemeProvider.notifier);
    final themeState = ref.read(timetableThemeProvider);
    
    // 현재 선택된 교사 이름과 같은지 확인
    if (themeState.selectedTeacherName == teacherName) {
      // 같은 교사 이름을 다시 클릭하면 선택 해제
      themeNotifier.updateSelectedTeacherName(null);
      AppLogger.exchangeDebug('교사 이름 선택 해제: $teacherName');
    } else {
      // 다른 교사 이름을 클릭하면 선택
      themeNotifier.updateSelectedTeacherName(teacherName);
      AppLogger.exchangeDebug('교사 이름 선택: $teacherName');
      
      // 교사 이름 선택 후 보강교체 실행
      _executeSupplementExchange(teacherName);
    }
    
    // UI 업데이트
    widget.onHeaderThemeUpdate?.call();
  }
  
  /// 교체불가 편집 모드에서 교사 전체 시간 토글 처리
  void _toggleTeacherAllTimesInNonExchangeableMode(String teacherName) {
    if (widget.timetableData == null) return;
    
    AppLogger.exchangeDebug('교체불가 편집 모드: 교사 $teacherName의 모든 시간 토글');
    
    // TimetableDataSource의 toggleTeacherAllTimes 메서드 사용
    widget.dataSource?.toggleTeacherAllTimes(teacherName);
    
    // UI 업데이트
    widget.onHeaderThemeUpdate?.call();
    
    AppLogger.exchangeDebug('교사 $teacherName의 모든 시간 토글 완료');
  }

  /// 행 인덱스에서 교사명 추출
  String _extractTeacherNameFromRowIndex(int rowIndex) {
    const int headerRowCount = 2;
    int actualRowIndex = rowIndex - headerRowCount;

    if (widget.timetableData == null || actualRowIndex < 0 || actualRowIndex >= widget.timetableData!.teachers.length) {
      return '';
    }

    return widget.timetableData!.teachers[actualRowIndex].name;
  }

  /// 교체된 셀 클릭 시 교체 서비스 상태 업데이트 (화살표 보존)
  void _updateExchangeServiceForExchangedCell(String teacherName, String day, int period) {
    try {
      // ExchangeService에 선택된 셀 정보 설정 (헤더 업데이트를 위해)
      // 하지만 실제 교체 서비스 로직은 실행하지 않음
      final exchangeService = ref.read(exchangeServiceProvider);
      
      // 선택된 셀 정보만 설정 (교체 가능한 교사 정보 수집을 위해)
      exchangeService.selectCell(teacherName, day, period);
      
      // TimetableThemeProvider 상태도 업데이트 (교사 이름 컬럼 하이라이트를 위해)
      final themeNotifier = ref.read(timetableThemeProvider.notifier);
      themeNotifier.updateSelection(teacherName, day, period);
      
      AppLogger.exchangeDebug('📝 교체 서비스 상태 업데이트 완료: $teacherName $day$period교시');
    } catch (e) {
      AppLogger.error('교체 서비스 상태 업데이트 실패: $e');
    }
  }


  /// 내부 선택된 경로 초기화 (StateResetProvider에서 처리됨)
  void _clearInternalPath() {
    // 화살표 상태 초기화는 StateResetProvider에서 처리됨
    ref.read(stateResetProvider.notifier).resetExchangeStates(
      reason: '내부 경로 초기화',
    );
    
    // 싱글톤 화살표 매니저를 통한 화살표 정리
    _arrowsManager.clearAllArrows();
    AppLogger.exchangeDebug('화살표 초기화 요청 (StateResetProvider에서 처리)');
  }

  /// 교체 실행 전에 원본 정보를 백업하는 메서드
  /// 
  /// 매개변수:
  /// - `exchangeItem`: 교체할 항목 정보 (ExchangeHistoryItem 또는 ExchangePath)
  /// - `timeSlots`: 현재 시간표 데이터
  void _backupOriginalSlotInfo(dynamic exchangeItem, List<TimeSlot> timeSlots) {
    try {
      ExchangePath? exchangePath;
      
      // ExchangeHistoryItem인 경우 실제 경로 추출
      if (exchangeItem is ExchangeHistoryItem) {
        exchangePath = exchangeItem.originalPath;
        AppLogger.exchangeDebug('ExchangeHistoryItem에서 경로 추출: ${exchangePath.type}');
      } else if (exchangeItem is ExchangePath) {
        exchangePath = exchangeItem;
        AppLogger.exchangeDebug('ExchangePath 직접 사용: ${exchangePath.type}');
      }
      
      if (exchangePath == null) {
        AppLogger.exchangeDebug('교체 경로를 찾을 수 없음: ${exchangeItem.runtimeType}');
        return;
      }
      
      // 교체 타입에 따라 다르게 처리
      if (exchangePath is OneToOneExchangePath) {
        // 1:1 교체의 경우 sourceSlot과 targetSlot 백업
        _backupOneToOneExchange(exchangePath, timeSlots);
      } else if (exchangePath is CircularExchangePath) {
        // 순환 교체의 경우 모든 교체되는 셀들 백업
        _backupCircularExchange(exchangePath, timeSlots);
      } else if (exchangePath is ChainExchangePath) {
        // 연쇄 교체의 경우 모든 교체되는 셀들 백업
        _backupChainExchange(exchangePath, timeSlots);
      }
      
      AppLogger.exchangeDebug('교체 백업 완료: ${_exchangeListWork.length}개 항목 저장됨');
    } catch (e) {
      AppLogger.exchangeDebug('교체 백업 중 오류 발생: $e');
    }
  }

  /// 1:1 교체의 원본 정보 백업
  void _backupOneToOneExchange(OneToOneExchangePath exchangeItem, List<TimeSlot> timeSlots) {
    // 1. sourceNode의 원래 위치 백업
    _backupNodeData(exchangeItem.sourceNode, timeSlots);
    
    // 2. targetNode의 원래 위치 백업
    _backupNodeData(exchangeItem.targetNode, timeSlots);
    
    // 3. sourceNode가 이동할 목적지 위치 백업 (targetNode의 위치)
    _backupNodeData({
      'teacherName': exchangeItem.sourceNode.teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.targetNode.day),
      'period': exchangeItem.targetNode.period,
    }, timeSlots);
    
    // 4. targetNode가 이동할 목적지 위치 백업 (sourceNode의 위치)
    _backupNodeData({
      'teacherName': exchangeItem.targetNode.teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.sourceNode.day),
      'period': exchangeItem.sourceNode.period,
    }, timeSlots);
  }

  /// 순환 교체의 원본 정보 백업 (마지막 노드 제외)
  void _backupCircularExchange(CircularExchangePath exchangeItem, List<TimeSlot> timeSlots) {
    // 각 노드의 원본 정보 백업
    for (int i = 0; i < exchangeItem.nodes.length - 1; i++) {
      _backupNodeData(exchangeItem.nodes[i], timeSlots);

      _backupNodeData({
      'teacherName': exchangeItem.nodes[i].teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.nodes[i+1].day),
      'period': exchangeItem.nodes[i+1].period,
    }, timeSlots);
    }

  }

  /// 연쇄 교체의 원본 정보 백업 (8개 백업)
  void _backupChainExchange(ChainExchangePath exchangeItem, List<TimeSlot> timeSlots) {
    // 연쇄교체는 4개 노드 + 4개 목적지 = 총 8개 백업 필요
    
    // 1. 4개 노드의 원본 위치 백업
    _backupNodeData(exchangeItem.nodeA, timeSlots);  // 결강 수업
    _backupNodeData(exchangeItem.nodeB, timeSlots);  // 대체 가능 수업
    _backupNodeData(exchangeItem.node1, timeSlots);  // 1단계 교환 대상
    _backupNodeData(exchangeItem.node2, timeSlots); // A 교사의 B 시간 수업
    
    // 2. 1단계 교체 후 목적지 위치 백업
    // node1 교사가 node2 위치로 이동
    _backupNodeData({
      'teacherName': exchangeItem.node1.teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.node2.day),
      'period': exchangeItem.node2.period,
    }, timeSlots);
    
    // node2 교사가 node1 위치로 이동
    _backupNodeData({
      'teacherName': exchangeItem.node2.teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.node1.day),
      'period': exchangeItem.node1.period,
    }, timeSlots);
    
    // [중복] 3. 2단계 교체 후 목적지 위치 백업
    // nodeA 교사가 nodeB 위치로 이동 (최종 목적지)
    // _backupNodeData({
    //   'teacherName': exchangeItem.nodeA.teacherName,
    //   'dayOfWeek': DayUtils.getDayNumber(exchangeItem.nodeB.day),
    //   'period': exchangeItem.nodeB.period,
    // }, timeSlots);
    
    // nodeB 교사가 nodeA 위치로 이동 (최종 목적지)
    _backupNodeData({
      'teacherName': exchangeItem.nodeB.teacherName,
      'dayOfWeek': DayUtils.getDayNumber(exchangeItem.nodeA.day),
      'period': exchangeItem.nodeA.period,
    }, timeSlots);
    
    AppLogger.exchangeDebug('연쇄교체 백업 완료: 7개 항목 (4개 노드 + 3개 목적지)');
  }

  /// ExchangeNode 또는 특정 위치의 데이터를 백업
  void _backupNodeData(dynamic node, List<TimeSlot> timeSlots) {
    try {
      String teacher;
      int dayOfWeek;
      int period;
      
      // Map 타입인 경우 (1:1 교체에서 목적지 위치 백업용)
      if (node is Map<String, dynamic>) {
        teacher = node['teacherName'] ?? '';
        dayOfWeek = node['dayOfWeek'] ?? 0;
        period = node['period'] ?? 0;
        AppLogger.exchangeDebug('Map 데이터 백업: teacher=$teacher, dayOfWeek=$dayOfWeek, period=$period');
      } 
      // ExchangeNode 타입인 경우
      else {
        teacher = node.teacherName ?? '';
        // ExchangeNode의 day 문자열을 dayOfWeek 숫자로 변환
        dayOfWeek = DayUtils.getDayNumber(node.day);
        period = node.period ?? 0;
        AppLogger.exchangeDebug('ExchangeNode 데이터 백업: teacher=$teacher, day=${node.day}, dayOfWeek=$dayOfWeek, period=$period');
      }
      
      // TimeSlots에서 현재 subject와 className만 조회
      String? currentSubject;
      String? currentClassName;
      
      for (TimeSlot slot in timeSlots) {
        if (slot.teacher == teacher && 
            slot.dayOfWeek == dayOfWeek && 
            slot.period == period) {
          currentSubject = slot.subject;
          currentClassName = slot.className;
          break;
        }
      }
      
      // ExchangeBackupInfo 생성하여 리스트에 추가
      ExchangeBackupInfo backupInfo = ExchangeBackupInfo(
        teacher: teacher,
        dayOfWeek: dayOfWeek,
        period: period,
        subject: currentSubject,
        className: currentClassName,
      );
      
      _exchangeListWork.add(backupInfo);
      AppLogger.exchangeDebug('노드 데이터 백업: ${backupInfo.debugInfo}');
      
    } catch (e) {
      AppLogger.exchangeDebug('노드 데이터 백업 중 오류: $e');
    }
  }

  /// 교체 뷰 활성화
  void _enableExchangeView() {
    try {
      AppLogger.exchangeInfo('[wg]교체 뷰 활성화 시작');
      
      // 교체 뷰 활성화 시 모든 셀 선택 해제
      ref.read(exchangeServiceProvider).clearCellSelection();
      ref.read(circularExchangeServiceProvider).clearCellSelection();
      ref.read(chainExchangeServiceProvider).clearCellSelection();
      
      // 교체 리스트 조회
      final exchangeList = _historyService.getExchangeList();
      
      AppLogger.exchangeDebug('[백업 추적] exchangeList: ${exchangeList.length}, backedUp: $_backedUpCount, work: ${_exchangeListWork.length}');
      
      if (exchangeList.isEmpty) {
        AppLogger.exchangeInfo('교체 리스트가 비어있습니다');
        return;
      }
      
      // 새로운 교체만 추출 (백업된 개수 이후부터)
      final newExchanges = exchangeList.skip(_backedUpCount).toList();
      AppLogger.exchangeDebug('[새로운 교체] skip($_backedUpCount): ${newExchanges.length}개');
      
      if (newExchanges.isEmpty) {
        AppLogger.exchangeInfo('새로운 교체가 없습니다 (이미 $_backedUpCount개 백업됨)');
        return;
      }
      
      AppLogger.exchangeInfo('새로운 교체 ${newExchanges.length}개 발견 (전체 ${exchangeList.length}개, 기존 백업 $_backedUpCount개)');
      
      // 1단계: 새로운 교체만 백업
      AppLogger.exchangeDebug('1단계: 신규 교체 ${newExchanges.length}개 백업 시작');
      final beforeBackupCount = _exchangeListWork.length;
      for (var item in newExchanges) {
        _backupOriginalSlotInfo(item, widget.dataSource!.timeSlots);
      }
      _backedUpCount = exchangeList.length;
      AppLogger.exchangeDebug('[백업 결과] $beforeBackupCount개 → ${_exchangeListWork.length}개 (추가: ${_exchangeListWork.length - beforeBackupCount})');
      
      // 2단계: 새로운 교체만 실행
      AppLogger.exchangeDebug('2단계: 신규 교체 ${newExchanges.length}개 실행 시작');
      int successCount = 0;
      for (var item in newExchanges) {
        if (_exchangeViewManager.executeExchangeFromHistory(
          item,
          widget.dataSource!.timeSlots,
          widget.timetableData!.teachers,
        )) {
          successCount++;
        }
      }
      
      // 선택 상태 초기화
      ref.read(stateResetProvider.notifier).resetExchangeStates(
        reason: '교체 뷰 활성화 - 선택 상태 초기화',
      );
      
      // UI 업데이트 (교체 성공 시에만)
      if (successCount > 0) {
        widget.dataSource?.updateData(widget.dataSource!.timeSlots, widget.timetableData!.teachers);
        widget.onHeaderThemeUpdate?.call();
        if (mounted) setState(() {});
        AppLogger.exchangeInfo('교체 뷰 활성화 완료 - $successCount/${newExchanges.length}개 적용');
      }
      
    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 활성화 중 오류 발생: $e');
    }
  }

  /// 교체 뷰 비활성화 (원래 상태로 되돌리기)
  void _disableExchangeView() {
    try {
      AppLogger.exchangeInfo('교체 뷰 비활성화 시작');
      
      // 교체 뷰 비활성화 시 모든 셀 선택 해제
      ref.read(exchangeServiceProvider).clearCellSelection();
      ref.read(circularExchangeServiceProvider).clearCellSelection();
      ref.read(chainExchangeServiceProvider).clearCellSelection();

      if (_exchangeListWork.isEmpty || widget.dataSource == null) {
        AppLogger.exchangeDebug('복원할 교체 백업 데이터가 없습니다');
        return;
      }

      // 역순으로 복원 (마지막에 교체된 것부터 먼저 되돌리기)
      int restoredCount = 0;
      for (int i = _exchangeListWork.length - 1; i >= 0; i--) {
        final backupInfo = _exchangeListWork[i];
        final targetSlot = _findTimeSlotByBackupInfo(backupInfo, widget.dataSource!.timeSlots);

        if (targetSlot != null) {
          targetSlot.subject = backupInfo.subject;
          targetSlot.className = backupInfo.className;
          restoredCount++;
        }
      }

      // UI 업데이트
      if (widget.timetableData != null) {
        widget.dataSource!.updateData(widget.dataSource!.timeSlots, widget.timetableData!.teachers);
      }
      widget.onHeaderThemeUpdate?.call();
      if (mounted) setState(() {});

      // 백업 데이터 초기화
      _exchangeListWork.clear();
      _backedUpCount = 0;

      AppLogger.exchangeInfo('교체 뷰 비활성화 완료 - $restoredCount개 셀 복원됨');
    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 비활성화 중 오류 발생: $e');
    }
  }

  /// 백업 정보로 TimeSlot 찾기
  TimeSlot? _findTimeSlotByBackupInfo(ExchangeBackupInfo backupInfo, List<TimeSlot> timeSlots) {
    for (TimeSlot slot in timeSlots) {
      if (slot.teacher == backupInfo.teacher && 
          slot.dayOfWeek == backupInfo.dayOfWeek && 
          slot.period == backupInfo.period) {
        return slot;
      }
    }
    return null;
  }
}


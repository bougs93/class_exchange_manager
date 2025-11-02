import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/circular_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../ui/widgets/simplified_timetable_cell.dart';
import '../providers/cell_selection_provider.dart';
import '../services/non_exchangeable_data_storage_service.dart';
import '../services/pdf_export_settings_storage_service.dart';
import 'exchange_algorithm.dart';
import 'day_utils.dart';
import 'non_exchangeable_manager.dart';
import 'simplified_timetable_theme.dart';
import 'logger.dart';

/// 셀 상태 정보를 담는 클래스
class CellStateInfo {
  final bool isSelected;
  final bool isTargetCell;
  final bool isExchangeableTeacher;
  final bool isLastColumnOfDay;
  final bool isFirstColumnOfDay;
  final bool isInCircularPath;
  final int? circularPathStep;
  final bool isInSelectedPath;
  final bool isInChainPath;
  final int? chainPathStep;
  final bool isNonExchangeable;
  final bool isExchangedSourceCell; // 교체된 소스 셀인지 여부
  final bool isExchangedDestinationCell; // 교체된 목적지 셀인지 여부
  final bool isTeacherNameSelected; // 교사 이름 선택 상태 (새로 추가)
  final bool isHighlightedTeacher; // 하이라이트된 교사 행인지 여부 (새로 추가)

  CellStateInfo({
    required this.isSelected,
    required this.isTargetCell,
    required this.isExchangeableTeacher,
    required this.isLastColumnOfDay,
    required this.isFirstColumnOfDay,
    required this.isInCircularPath,
    this.circularPathStep,
    required this.isInSelectedPath,
    required this.isInChainPath,
    this.chainPathStep,
    required this.isNonExchangeable,
    required this.isExchangedSourceCell,
    required this.isExchangedDestinationCell,
    required this.isTeacherNameSelected, // 새로 추가
    required this.isHighlightedTeacher, // 새로 추가
  });

  factory CellStateInfo.empty() {
    return CellStateInfo(
      isSelected: false,
      isTargetCell: false,
      isExchangeableTeacher: false,
      isLastColumnOfDay: false,
      isFirstColumnOfDay: false,
      isInCircularPath: false,
      circularPathStep: null,
      isInSelectedPath: false,
      isInChainPath: false,
      chainPathStep: null,
      isNonExchangeable: false,
      isExchangedSourceCell: false,
      isExchangedDestinationCell: false,
      isTeacherNameSelected: false, // 새로 추가
      isHighlightedTeacher: false, // 새로 추가
    );
  }
}

/// Syncfusion DataGrid용 시간표 데이터 소스
class TimetableDataSource extends DataGridSource {
  TimetableDataSource({
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
    required this.ref,
  }) {
    _initializeData(timeSlots, teachers);
  }

  final WidgetRef ref;
  List<TimeSlot> _timeSlots = [];
  List<Teacher> _teachers = [];
  List<DataGridRow> _dataGridRows = [];
  
  // 교체 옵션 정보
  List<ExchangeOption> _exchangeOptions = [];
  
  // 관리자 클래스들 (전역 Provider 사용으로 간소화)
  final NonExchangeableManager _nonExchangeableManager = NonExchangeableManager();
  
  // 로컬 캐시 관리 (위젯 빌드 중 안전하게 사용)
  final Map<String, bool> _localCache = {};
  
  // 하이라이트할 교사명 캐시 (성능 최적화)
  String? _highlightedTeacherName;
  bool _highlightedTeacherNameLoaded = false;

  /// 공통 데이터 초기화 메서드
  void _initializeData(List<TimeSlot> timeSlots, List<Teacher> teachers) {
    _timeSlots = timeSlots;
    _teachers = teachers;
    _nonExchangeableManager.setTimeSlots(timeSlots);
    // 하이라이트할 교사명 미리 로드
    _loadHighlightedTeacherName();
    _buildDataGridRows();
  }

  /// 공통 캐시 초기화 및 UI 업데이트 메서드
  void _clearCacheAndNotify() {
    _localCache.clear();
    notifyDataSourceListeners();
  }

  /// DataGrid 행 데이터 빌드
  void _buildDataGridRows() {
    // 요일별로 데이터 그룹화
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = _groupTimeSlotsByDayAndPeriod();
    
    // 요일 목록 추출 및 정렬
    List<String> days = groupedData.keys.toList()..sort(DayUtils.compareDays);
    
    _dataGridRows = _createRows(groupedData, days);
  }

  /// TimeSlot 리스트를 요일별, 교시별로 그룹화
  Map<String, Map<int, Map<String, TimeSlot?>>> _groupTimeSlotsByDayAndPeriod() {
    Map<String, Map<int, Map<String, TimeSlot?>>> groupedData = {};
    
    for (TimeSlot slot in _timeSlots) {
      if (slot.dayOfWeek == null || slot.period == null || slot.teacher == null) {
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
        DataGridCell<String>(
          columnName: 'teacher',
          value: teacher.name,
        ),
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
            DataGridCell<String>(
              columnName: columnName,
              value: cellValue,
            ),
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
    return DataGridRowAdapter(
      cells: row.getCells().asMap().entries.map<Widget>((entry) {
        DataGridCell dataGridCell = entry.value;
        bool isTeacherColumn = dataGridCell.columnName == 'teacher';
        
        // 교사명 추출
        String teacherName = _extractTeacherName(row);
        
        // 셀 상태 정보 생성
        CellStateInfo cellState = _createCellStateInfo(
          dataGridCell, 
          teacherName, 
          isTeacherColumn
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
          isInChainPath: cellState.isInChainPath,
          chainPathStep: cellState.chainPathStep,
          isTargetCell: cellState.isTargetCell,
          isNonExchangeable: cellState.isNonExchangeable,
          isExchangedSourceCell: cellState.isExchangedSourceCell,
          isExchangedDestinationCell: cellState.isExchangedDestinationCell,
          isTeacherNameSelected: cellState.isTeacherNameSelected, // 새로 추가
          isHighlightedTeacher: cellState.isHighlightedTeacher, // 새로 추가
        );
      }).toList(),
    );
  }

  /// 교사명 추출
  String _extractTeacherName(DataGridRow row) {
    for (DataGridCell rowCell in row.getCells()) {
      if (rowCell.columnName == 'teacher') {
        return rowCell.value.toString();
      }
    }
    return '';
  }

  /// 셀 상태 정보 생성
  CellStateInfo _createCellStateInfo(DataGridCell dataGridCell, String teacherName, bool isTeacherColumn) {
    if (isTeacherColumn) {
      return _createTeacherColumnState(teacherName);
    } else {
      return _createDataCellState(dataGridCell, teacherName);
    }
  }

  /// 교사명 열 상태 정보 생성
  CellStateInfo _createTeacherColumnState(String teacherName) {
    final cellNotifier = ref.read(cellSelectionProvider.notifier);
    final cellState = ref.read(cellSelectionProvider);
    
    // 교사 이름 컬럼은 해당 교사의 선택 상태를 확인
    // 선택된 교사인지 확인 (selectedTeacher와 비교)
    bool isTeacherSelected = cellState.selectedTeacher == teacherName;
    
    // 교사 이름 선택 상태 확인 (새로 추가)
    bool isTeacherNameSelected = cellState.selectedTeacherName == teacherName;
    
    // 교사가 교체 가능한지 확인 (교체 가능한 교사 목록에 포함되어 있는지)
    bool isTeacherExchangeable = cellState.exchangeableTeachers.any(
      (teacher) => teacher['teacherName'] == teacherName
    );
    
    // 하이라이트된 교사 행인지 확인
    bool isHighlighted = _isHighlightedTeacher(teacherName);
    
    return CellStateInfo(
      isSelected: isTeacherSelected, // 교사 이름 선택은 isSelected에 포함하지 않음
      isExchangeableTeacher: isTeacherExchangeable,
      isInCircularPath: cellNotifier.isInCircularPath(teacherName, '', 0),
      isInChainPath: cellNotifier.isInChainPath(teacherName, '', 0),
      isInSelectedPath: cellNotifier.isInSelectedOneToOnePath(teacherName, '', 0),
      isNonExchangeable: false,
      isExchangedSourceCell: false, // 교사명 열은 교체된 소스 셀 상태 적용 안함
      isExchangedDestinationCell: false, // 교사명 열은 교체된 목적지 셀 상태 적용 안함
      isTargetCell: false,
      isLastColumnOfDay: false,
      isFirstColumnOfDay: false,
      circularPathStep: null,
      chainPathStep: null,
      isTeacherNameSelected: isTeacherNameSelected, // 새로 추가
      isHighlightedTeacher: isHighlighted, // 새로 추가
    );
  }

  /// 데이터 셀 상태 정보 생성
  CellStateInfo _createDataCellState(DataGridCell dataGridCell, String teacherName) {
    List<String> parts = dataGridCell.columnName.split('_');
    if (parts.length != 2) {
      return CellStateInfo.empty();
    }
    
    String day = parts[0];
    int period = int.tryParse(parts[1]) ?? 0;
    
    // 전역 Provider에서 상태 정보 가져오기
    final cellNotifier = ref.read(cellSelectionProvider.notifier);
    
    return CellStateInfo(
      isSelected: _getCachedOrCompute(
        'cellSelection', 
        teacherName, day, period,
        () => cellNotifier.isCellSelected(teacherName, day, period)
      ),
      isTargetCell: _getCachedOrCompute(
        'cellTarget', 
        teacherName, day, period,
        () => cellNotifier.isCellTarget(teacherName, day, period)
      ),
      isExchangeableTeacher: _getCachedOrCompute(
        'exchangeable', 
        teacherName, day, period,
        () => cellNotifier.isExchangeableTeacher(teacherName, day, period)
      ),
      isInCircularPath: _getCachedOrCompute(
        'circularPath', 
        teacherName, day, period,
        () => cellNotifier.isInCircularPath(teacherName, day, period)
      ),
      isInChainPath: _getCachedOrCompute(
        'chainPath', 
        teacherName, day, period,
        () => cellNotifier.isInChainPath(teacherName, day, period)
      ),
      isInSelectedPath: cellNotifier.isInSelectedOneToOnePath(teacherName, day, period),
      isNonExchangeable: _getCachedOrCompute(
        'nonExchangeable', 
        teacherName, day, period,
        () => _nonExchangeableManager.isNonExchangeableTimeSlot(teacherName, day, period)
      ),
      isExchangedSourceCell: cellNotifier.isCellExchangedSource(teacherName, day, period),
      isExchangedDestinationCell: cellNotifier.isCellExchangedDestination(teacherName, day, period),
      isLastColumnOfDay: _isLastColumnOfDay(day, period),
      isFirstColumnOfDay: _isFirstColumnOfDay(day, period),
      circularPathStep: _getCircularPathStep(teacherName, day, period),
      chainPathStep: _getChainPathStep(teacherName, day, period),
      isTeacherNameSelected: false, // 데이터 셀은 교사 이름 선택 상태 적용 안함
      isHighlightedTeacher: _isHighlightedTeacher(teacherName), // 새로 추가
    );
  }
  
  /// 하이라이트된 교사인지 확인
  /// 
  /// 설정에서 저장한 defaultTeacherName과 현재 교사명을 비교합니다.
  /// 결과는 캐시하여 성능을 최적화합니다.
  bool _isHighlightedTeacher(String teacherName) {
    // 교사명 비교 (빈 문자열이면 하이라이트 안함)
    if (_highlightedTeacherName == null || _highlightedTeacherName!.isEmpty) {
      return false;
    }
    
    return _highlightedTeacherName == teacherName;
  }
  
  /// 하이라이트할 교사명 로드
  /// 
  /// 설정에서 defaultTeacherName을 로드합니다.
  /// 비동기로 로드하며, 완료되면 캐시를 갱신하고 UI를 업데이트합니다.
  void _loadHighlightedTeacherName() {
    if (_highlightedTeacherNameLoaded) {
      return; // 이미 로드 완료
    }
    
    try {
      final pdfSettings = PdfExportSettingsStorageService();
      // 비동기 로드
      pdfSettings.loadDefaultTeacherAndSchoolName().then((defaults) {
        final newTeacherName = defaults['defaultTeacherName'] ?? '';
        if (_highlightedTeacherName != newTeacherName) {
          _highlightedTeacherName = newTeacherName.isEmpty ? null : newTeacherName;
          _highlightedTeacherNameLoaded = true;
          // UI 업데이트 (캐시 초기화)
          _clearCacheAndNotify();
        } else {
          _highlightedTeacherNameLoaded = true;
        }
      }).catchError((e) {
        AppLogger.error('하이라이트 교사명 로드 중 오류: $e', e);
        _highlightedTeacherName = null;
        _highlightedTeacherNameLoaded = true;
      });
    } catch (e) {
      AppLogger.error('하이라이트 교사명 로드 중 오류: $e', e);
      _highlightedTeacherName = null;
      _highlightedTeacherNameLoaded = true;
    }
  }
  
  /// 하이라이트 교사명 캐시 초기화
  /// 
  /// 설정에서 교사명이 변경되었을 때 호출하여 캐시를 갱신합니다.
  void refreshHighlightedTeacherName() {
    _highlightedTeacherNameLoaded = false;
    _highlightedTeacherName = null;
    _loadHighlightedTeacherName();
    // _loadHighlightedTeacherName() 내부에서 _clearCacheAndNotify()를 호출하므로 중복 호출 불필요
  }

  /// 캐시에서 값을 가져오거나 계산하여 캐시에 저장
  bool _getCachedOrCompute(String cacheType, String teacherName, String day, int period, bool Function() compute) {
    final key = '${cacheType}_${teacherName}_${day}_$period';
    
    // 로컬 캐시에서 먼저 확인
    if (_localCache.containsKey(key)) {
      return _localCache[key]!;
    }
    
    // 캐시에 없으면 계산하여 저장
    final result = compute();
    _localCache[key] = result;
    
    return result;
  }

  /// 순환교체 경로에서 해당 셀의 단계 번호 가져오기
  int? _getCircularPathStep(String teacherName, String day, int period) {
    final cellState = ref.read(cellSelectionProvider);
    if (cellState.selectedCircularPath == null) return null;
    
    for (int i = 0; i < cellState.selectedCircularPath!.nodes.length; i++) {
      final node = cellState.selectedCircularPath!.nodes[i];
      if (node.teacherName == teacherName &&
          node.day == day &&
          node.period == period) {
        return i + 1; // 1부터 시작하는 단계 번호
      }
    }
    
    return null;
  }

  /// 연쇄교체 경로에서 해당 셀의 단계 번호 가져오기
  int? _getChainPathStep(String teacherName, String day, int period) {
    final cellState = ref.read(cellSelectionProvider);
    if (cellState.selectedChainPath == null) return null;
    
    // 연쇄교체의 노드 순서: [node1, node2, nodeA, nodeB]
    for (int i = 0; i < cellState.selectedChainPath!.nodes.length; i++) {
      final node = cellState.selectedChainPath!.nodes[i];
      if (node.teacherName == teacherName &&
          node.day == day &&
          node.period == period) {
        // node1, node2는 1단계, nodeA, nodeB는 2단계
        if (i < 2) {
          return 1; // 1단계
        } else {
          return 2; // 2단계
        }
      }
    }
    
    return null;
  }

  /// 요일별 마지막 교시 확인
  bool _isLastColumnOfDay(String day, int period) {
    bool isLastPeriod = period == 7;
    bool isLastDay = day == '금';
    return isLastPeriod && !isLastDay;
  }
  
  /// 요일별 첫 번째 교시 확인
  bool _isFirstColumnOfDay(String day, int period) {
    return period == 1; // 모든 요일의 첫 번째 교시
  }

  /// 선택 상태 업데이트 (재렌더링 방지)
  void updateSelection(String? teacher, String? day, int? period) {
    if (teacher != null && day != null && period != null) {
      ref.read(cellSelectionProvider.notifier).selectCell(teacher, day, period);
    }
    _localCache.clear(); // 로컬 캐시 초기화
    notifyDataSourceListeners(); // Syncfusion DataGrid 전용 메서드 사용 (재렌더링 방지)
  }
  
  /// 타겟 셀 상태 업데이트
  void updateTargetCell(String? teacher, String? day, int? period) {
    if (teacher != null && day != null && period != null) {
      ref.read(cellSelectionProvider.notifier).selectTargetCell(teacher, day, period);
    }
    _localCache.clear(); // 로컬 캐시 초기화
    notifyDataSourceListeners(); // Syncfusion DataGrid 전용 메서드 사용
  }
  
  
  /// 교체 가능한 교사 정보 업데이트
  void updateExchangeableTeachers(List<Map<String, dynamic>> exchangeableTeachers) {
    ref.read(cellSelectionProvider.notifier).updateExchangeableTeachers(exchangeableTeachers);
    _localCache.clear(); // 로컬 캐시 초기화
    notifyDataSourceListeners(); // Syncfusion DataGrid 전용 메서드 사용
  }
  
  /// 교체 옵션 업데이트
  void updateExchangeOptions(List<ExchangeOption> exchangeOptions) {
    _exchangeOptions = exchangeOptions;
    notifyDataSourceListeners(); // Syncfusion DataGrid 전용 메서드 사용
  }
  
  /// 교체 옵션 가져오기
  List<ExchangeOption> get exchangeOptions => _exchangeOptions;
  
  /// 교체 가능한 옵션 개수
  int get exchangeableCount => _exchangeOptions.where((option) => option.isExchangeable).length;
  
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

  /// 선택된 연쇄교체 경로 업데이트
  void updateSelectedChainPath(ChainExchangePath? path) {
    ref.read(cellSelectionProvider.notifier).setChainPath(path);
    _clearCacheAndNotify();
  }

  /// 선택된 보강교체 경로 업데이트
  void updateSelectedSupplementPath(SupplementExchangePath? path) {
    ref.read(cellSelectionProvider.notifier).setSupplementPath(path);
    _clearCacheAndNotify();
  }
  
  

  /// 데이터 업데이트
  void updateData(List<TimeSlot> timeSlots, List<Teacher> teachers) {
    _initializeData(timeSlots, teachers);
    notifyDataSourceListeners();
  }

  /// 교체불가 편집 모드 설정
  void setNonExchangeableEditMode(bool isEditMode) {
    _nonExchangeableManager.setNonExchangeableEditMode(isEditMode);
    _clearCacheAndNotify();
  }

  /// 교체불가 편집 모드 상태 확인
  bool get isNonExchangeableEditMode => _nonExchangeableManager.isNonExchangeableEditMode;

  /// UI 업데이트 전용 메서드 (데이터 변경 없이 UI만 갱신)
  void refreshUI() {
    _clearCacheAndNotify();
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
    SimplifiedTimetableTheme.setNonExchangeableColor(SimplifiedTimetableTheme.nonExchangeableColor);
    
    // 교체불가 셀 데이터 저장 (별도 파일로 저장)
    _saveNonExchangeableCells();
    
    _clearCacheAndNotify();
  }
  
  /// 교체불가 셀 데이터 저장 (별도 파일로 저장)
  Future<void> _saveNonExchangeableCells() async {
    try {
      // 싱글톤 인스턴스 가져오기
      final storageService = NonExchangeableDataStorageService();
      final cells = storageService.extractNonExchangeableCellsFromTimeSlots(_timeSlots);
      await storageService.saveNonExchangeableCells(cells);
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
    notifyDataSourceListeners();
  }

  /// 데이터 변경 알림 (외부에서 호출 가능) - 재렌더링 방지
  void notifyDataChanged() {
    // 캐시 초기화는 실제로 데이터가 변경된 경우에만 수행
    // 단순 UI 업데이트의 경우 캐시를 유지하여 성능 향상
    notifyDataSourceListeners();
  }
  
  /// 교체된 셀 상태 업데이트 (교체 리스트 변경 시 호출)
  void updateExchangedCells(List<String> exchangedCellKeys) {
    ref.read(cellSelectionProvider.notifier).updateExchangedCells(exchangedCellKeys);
    _clearCacheAndNotify();
  }

  /// 교체된 목적지 셀 상태 업데이트
  void updateExchangedDestinationCells(List<String> destinationCellKeys) {
    ref.read(cellSelectionProvider.notifier).updateExchangedDestinationCells(destinationCellKeys);
    _localCache.clear(); // 로컬 캐시 초기화
    notifyDataSourceListeners(); // Syncfusion DataGrid 전용 메서드 사용
  }

  /// 모든 선택 상태 초기화 (셀 선택, 타겟 셀, 교체 경로 등)
  void clearAllSelections() {
    ref.read(cellSelectionProvider.notifier).clearAllSelections();
    _localCache.clear(); // 로컬 캐시 초기화
    notifyDataSourceListeners(); // Syncfusion DataGrid 전용 메서드 사용
  }

  // ========================================
  // 배치 업데이트 메서드들
  // ========================================

  /// Level 1 전용 배치 업데이트: 경로 선택만 초기화
  void resetPathSelectionBatch() {
    ref.read(cellSelectionProvider.notifier).setCircularPath(null);
    ref.read(cellSelectionProvider.notifier).setOneToOnePath(null);
    ref.read(cellSelectionProvider.notifier).setChainPath(null);
    _localCache.clear(); // 로컬 캐시 초기화
    notifyDataSourceListeners(); // 한 번만 UI 업데이트
  }

  /// Level 2 전용 배치 업데이트: 교체 상태 초기화
  void resetExchangeStatesBatch() {
    // 경로 선택 초기화
    ref.read(cellSelectionProvider.notifier).setCircularPath(null);
    ref.read(cellSelectionProvider.notifier).setOneToOnePath(null);
    ref.read(cellSelectionProvider.notifier).setChainPath(null);
    
    // 교체 옵션 초기화
    _exchangeOptions = [];
    
    _localCache.clear(); // 로컬 캐시 초기화
    notifyDataSourceListeners(); // 한 번만 UI 업데이트
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
  
  /// 선택된 연쇄교체 경로 접근자 (보기 모드용)
  ChainExchangePath? getSelectedChainPath() {
    return ref.read(cellSelectionProvider).selectedChainPath;
  }

  /// 선택된 보강교체 경로 접근자 (보기 모드용)
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

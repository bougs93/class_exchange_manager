import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/circular_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../ui/widgets/simplified_timetable_cell.dart';
import 'exchange_algorithm.dart';
import 'day_utils.dart';
import 'cell_cache_manager.dart';
import 'cell_state_manager.dart';
import 'non_exchangeable_manager.dart';

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
  final bool isExchangedSourceCell; // 교체완료 소스 셀인지 여부

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
    );
  }
}

/// Syncfusion DataGrid용 시간표 데이터 소스
class TimetableDataSource extends DataGridSource {
  TimetableDataSource({
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
  }) {
    _timeSlots = timeSlots;
    _teachers = teachers;
    _nonExchangeableManager.setTimeSlots(timeSlots);
    _buildDataGridRows();
  }

  List<TimeSlot> _timeSlots = [];
  List<Teacher> _teachers = [];
  List<DataGridRow> _dataGridRows = [];
  
  // 교체 옵션 정보
  List<ExchangeOption> _exchangeOptions = [];

  // UI 업데이트 콜백
  VoidCallback? _onDataChanged;
  
  // 관리자 클래스들
  final CellCacheManager _cacheManager = CellCacheManager();
  final CellStateManager _stateManager = CellStateManager();
  final NonExchangeableManager _nonExchangeableManager = NonExchangeableManager();

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
    return CellStateInfo(
      isSelected: _cacheManager.getCellSelectionCached(
        teacherName, '', 0, 
        () => _stateManager.isTeacherSelected(teacherName)
      ),
      isExchangeableTeacher: _stateManager.isExchangeableTeacherForTeacher(teacherName),
      isInCircularPath: _stateManager.isTeacherInCircularPath(teacherName),
      isInChainPath: _stateManager.isTeacherInChainPath(teacherName),
      isInSelectedPath: _stateManager.isInSelectedOneToOnePath(teacherName),
      isNonExchangeable: false,
      isExchangedSourceCell: false, // 교사명 열은 교체완료 소스 셀 상태 적용 안함
      isTargetCell: false,
      isLastColumnOfDay: false,
      isFirstColumnOfDay: false,
      circularPathStep: null,
      chainPathStep: null,
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
    
    return CellStateInfo(
      isSelected: _cacheManager.getCellSelectionCached(
        teacherName, day, period,
        () => _stateManager.isCellSelected(teacherName, day, period)
      ),
      isTargetCell: _cacheManager.getCellTargetCached(
        teacherName, day, period,
        () => _stateManager.isCellTarget(teacherName, day, period)
      ),
      isExchangeableTeacher: _cacheManager.getExchangeableCached(
        teacherName, day, period,
        () => _stateManager.isExchangeableTeacher(teacherName, day, period)
      ),
      isInCircularPath: _cacheManager.getCircularPathCached(
        teacherName, day, period,
        () => _stateManager.isInCircularPath(teacherName, day, period)
      ),
      isInChainPath: _cacheManager.getChainPathCached(
        teacherName, day, period,
        () => _stateManager.isInChainPath(teacherName, day, period)
      ),
      isInSelectedPath: _stateManager.isInSelectedOneToOnePath(teacherName, day: day, period: period),
      isNonExchangeable: _cacheManager.getNonExchangeableCached(
        teacherName, day, period,
        () => _nonExchangeableManager.isNonExchangeableTimeSlot(teacherName, day, period)
      ),
      isExchangedSourceCell: _stateManager.isCellExchangedSource(teacherName, day, period),
      isLastColumnOfDay: _isLastColumnOfDay(day, period),
      isFirstColumnOfDay: _isFirstColumnOfDay(day, period),
      circularPathStep: _stateManager.getCircularPathStep(teacherName, day, period),
      chainPathStep: _stateManager.getChainPathStep(teacherName, day, period),
    );
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

  /// 선택 상태 업데이트
  void updateSelection(String? teacher, String? day, int? period) {
    _stateManager.updateSelection(teacher, day, period);
    _cacheManager.clearAllCaches();
    notifyListeners();
  }
  
  /// 타겟 셀 상태 업데이트
  void updateTargetCell(String? teacher, String? day, int? period) {
    _stateManager.updateTargetCell(teacher, day, period);
    _cacheManager.clearAllCaches();
    notifyListeners();
  }
  
  
  /// 교체 가능한 교사 정보 업데이트
  void updateExchangeableTeachers(List<Map<String, dynamic>> exchangeableTeachers) {
    _stateManager.updateExchangeableTeachers(exchangeableTeachers);
    _cacheManager.clearAllCaches();
    notifyListeners();
  }
  
  /// 교체 옵션 업데이트
  void updateExchangeOptions(List<ExchangeOption> exchangeOptions) {
    _exchangeOptions = exchangeOptions;
    notifyListeners(); // UI 갱신
  }
  
  /// 교체 옵션 가져오기
  List<ExchangeOption> get exchangeOptions => _exchangeOptions;
  
  /// 교체 가능한 옵션 개수
  int get exchangeableCount => _exchangeOptions.where((option) => option.isExchangeable).length;
  
  /// 선택된 순환교체 경로 업데이트
  void updateSelectedCircularPath(CircularExchangePath? path) {
    _stateManager.updateSelectedCircularPath(path);
    _cacheManager.clearCircularPathCache(); // 선택적 캐시 무효화로 성능 최적화
    notifyListeners();
  }
  
  /// 선택된 1:1 교체 경로 업데이트
  void updateSelectedOneToOnePath(OneToOneExchangePath? path) {
    _stateManager.updateSelectedOneToOnePath(path);
    _cacheManager.clearOneToOnePathCache(); // 선택적 캐시 무효화로 성능 최적화
    notifyListeners();
  }
  
  /// 선택된 연쇄교체 경로 업데이트
  void updateSelectedChainPath(ChainExchangePath? path) {
    _stateManager.updateSelectedChainPath(path);
    _cacheManager.clearChainPathCache(); // 선택적 캐시 무효화로 성능 최적화
    notifyListeners();
  }
  
  

  /// 데이터 업데이트
  void updateData(List<TimeSlot> timeSlots, List<Teacher> teachers) {
    _timeSlots = timeSlots;
    _teachers = teachers;
    _nonExchangeableManager.setTimeSlots(timeSlots);
    _buildDataGridRows();
    notifyListeners();
  }

  /// 교체불가 편집 모드 설정
  void setNonExchangeableEditMode(bool isEditMode) {
    _nonExchangeableManager.setNonExchangeableEditMode(isEditMode);
    _cacheManager.clearAllCaches();
    notifyListeners();
    _onDataChanged?.call();
  }

  /// 교체불가 편집 모드 상태 확인
  bool get isNonExchangeableEditMode => _nonExchangeableManager.isNonExchangeableEditMode;

  /// UI 업데이트 콜백 설정
  void setOnDataChanged(VoidCallback? callback) {
    _onDataChanged = callback;
  }

  /// 특정 교사의 모든 TimeSlot을 교체불가로 설정
  void setTeacherAsNonExchangeable(String teacherName) {
    _nonExchangeableManager.setTeacherAsNonExchangeable(teacherName);
    _cacheManager.clearAllCaches(); // 캐시 무효화 추가
    notifyListeners();
    _onDataChanged?.call();
  }

  /// 특정 교사의 모든 TimeSlot을 교체가능/교체불가로 토글
  void toggleTeacherAllTimes(String teacherName) {
    _nonExchangeableManager.toggleTeacherAllTimes(teacherName);
    _cacheManager.clearAllCaches(); // 캐시 무효화
    notifyDataSourceListeners(); // Syncfusion DataGrid를 위한 notifyDataSourceListeners 사용
    _onDataChanged?.call();
  }

  /// 특정 셀을 교체불가로 설정 또는 해제 (토글 방식, 빈 셀 포함)
  void setCellAsNonExchangeable(String teacherName, String day, int period) {
    _nonExchangeableManager.setCellAsNonExchangeable(teacherName, day, period);
    _cacheManager.clearAllCaches(); // 캐시 무효화 추가
    notifyDataSourceListeners(); // Syncfusion DataGrid를 위한 notifyDataSourceListeners 사용
    _onDataChanged?.call();
  }

  /// 모든 교체불가 설정 초기화
  void resetAllNonExchangeableSettings() {
    _nonExchangeableManager.resetAllNonExchangeableSettings();
    _cacheManager.clearAllCaches(); // 캐시 무효화 추가
    notifyListeners();
    _onDataChanged?.call();
  }

  /// 모든 캐시 초기화 (외부에서 호출 가능)
  void clearAllCaches() {
    _cacheManager.clearAllCaches();
    notifyListeners();
    _onDataChanged?.call();
  }

  /// 데이터 변경 알림 (외부에서 호출 가능)
  void notifyDataChanged() {
    // 캐시 초기화는 실제로 데이터가 변경된 경우에만 수행
    // 단순 UI 업데이트의 경우 캐시를 유지하여 성능 향상
    notifyListeners();
    _onDataChanged?.call();
  }
  
  /// 교체된 셀 상태 업데이트 (교체 리스트 변경 시 호출)
  void updateExchangedCells(List<String> exchangedCellKeys) {
    _stateManager.updateExchangedCells(exchangedCellKeys);
    _cacheManager.clearAllCaches();
    notifyListeners();
    _onDataChanged?.call();
  }
  
  /// 모든 선택 상태 초기화 (셀 선택, 타겟 셀, 교체 경로 등)
  void clearAllSelections() {
    _stateManager.clearAllSelections();
    _cacheManager.clearAllCaches();
    notifyListeners();
    _onDataChanged?.call();
  }


  /// TimeSlot 리스트 접근자 (동기화용)
  List<TimeSlot> get timeSlots => _timeSlots;
  
  /// 선택된 순환교체 경로 접근자 (보기 모드용)
  CircularExchangePath? getSelectedCircularPath() {
    return _stateManager.getSelectedCircularPath();
  }
  
  /// 선택된 1:1 교체 경로 접근자 (보기 모드용)
  OneToOneExchangePath? getSelectedOneToOnePath() {
    return _stateManager.getSelectedOneToOnePath();
  }
  
  /// 선택된 연쇄교체 경로 접근자 (보기 모드용)
  ChainExchangePath? getSelectedChainPath() {
    return _stateManager.getSelectedChainPath();
  }

  /// 타겟 셀의 요일 반환 (보기 모드용)
  String? get targetDay => _stateManager.targetDay;

  /// 타겟 셀의 교시 반환 (보기 모드용)
  int? get targetPeriod => _stateManager.targetPeriod;
}

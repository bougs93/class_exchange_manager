import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/circular_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/chain_exchange_path.dart';

/// 시간표 테마 상태 클래스
class TimetableThemeState {
  // 셀 선택 관련 상태
  final String? selectedTeacher;
  final String? selectedDay;
  final int? selectedPeriod;
  
  // 타겟 셀 관련 상태
  final String? targetTeacher;
  final String? targetDay;
  final int? targetPeriod;
  
  // 교체 가능한 교사 정보
  final List<Map<String, dynamic>> exchangeableTeachers;
  
  // 선택된 경로들
  final CircularExchangePath? selectedCircularPath;
  final OneToOneExchangePath? selectedOneToOnePath;
  final ChainExchangePath? selectedChainPath;
  
  // 교체된 셀 관리
  final Set<String> exchangedCells;
  final Set<String> exchangedDestinationCells;
  
  // 교사 이름 선택 상태 (새로 추가)
  final String? selectedTeacherName;
  
  // 캐시 무효화 플래그 (실제 캐시는 별도 관리)
  final bool cacheInvalidated;

  const TimetableThemeState({
    this.selectedTeacher,
    this.selectedDay,
    this.selectedPeriod,
    this.targetTeacher,
    this.targetDay,
    this.targetPeriod,
    this.exchangeableTeachers = const [],
    this.selectedCircularPath,
    this.selectedOneToOnePath,
    this.selectedChainPath,
    this.exchangedCells = const {},
    this.exchangedDestinationCells = const {},
    this.selectedTeacherName, // 새로 추가
    this.cacheInvalidated = false,
  });

  TimetableThemeState copyWith({
    String? selectedTeacher,
    String? selectedDay,
    int? selectedPeriod,
    String? targetTeacher,
    String? targetDay,
    int? targetPeriod,
    List<Map<String, dynamic>>? exchangeableTeachers,
    CircularExchangePath? selectedCircularPath,
    OneToOneExchangePath? selectedOneToOnePath,
    ChainExchangePath? selectedChainPath,
    Set<String>? exchangedCells,
    Set<String>? exchangedDestinationCells,
    String? selectedTeacherName, // 새로 추가
    bool? cacheInvalidated,
    bool clearSelection = false,
    bool clearTarget = false,
    bool clearPaths = false,
    bool clearExchangedCells = false,
    bool clearCaches = false,
    bool clearTeacherNameSelection = false, // 새로 추가
  }) {
    return TimetableThemeState(
      selectedTeacher: clearSelection ? null : (selectedTeacher ?? this.selectedTeacher),
      selectedDay: clearSelection ? null : (selectedDay ?? this.selectedDay),
      selectedPeriod: clearSelection ? null : (selectedPeriod ?? this.selectedPeriod),
      targetTeacher: clearTarget ? null : (targetTeacher ?? this.targetTeacher),
      targetDay: clearTarget ? null : (targetDay ?? this.targetDay),
      targetPeriod: clearTarget ? null : (targetPeriod ?? this.targetPeriod),
      exchangeableTeachers: exchangeableTeachers ?? this.exchangeableTeachers,
      selectedCircularPath: clearPaths ? null : (selectedCircularPath ?? this.selectedCircularPath),
      selectedOneToOnePath: clearPaths ? null : (selectedOneToOnePath ?? this.selectedOneToOnePath),
      selectedChainPath: clearPaths ? null : (selectedChainPath ?? this.selectedChainPath),
      exchangedCells: clearExchangedCells ? <String>{} : (exchangedCells ?? this.exchangedCells),
      exchangedDestinationCells: clearExchangedCells ? <String>{} : (exchangedDestinationCells ?? this.exchangedDestinationCells),
      selectedTeacherName: clearTeacherNameSelection ? null : (selectedTeacherName ?? this.selectedTeacherName), // 새로 추가
      cacheInvalidated: clearCaches ? true : (cacheInvalidated ?? this.cacheInvalidated),
    );
  }
}

/// 시간표 테마 상태를 관리하는 Notifier
class TimetableThemeNotifier extends StateNotifier<TimetableThemeState> {
  TimetableThemeNotifier() : super(const TimetableThemeState());

  /// 셀 선택 상태 업데이트
  void updateSelection(String? teacher, String? day, int? period) {
    state = state.copyWith(
      selectedTeacher: teacher,
      selectedDay: day,
      selectedPeriod: period,
    );
  }

  /// 타겟 셀 상태 업데이트
  void updateTargetCell(String? teacher, String? day, int? period) {
    state = state.copyWith(
      targetTeacher: teacher,
      targetDay: day,
      targetPeriod: period,
    );
  }

  /// 교체 가능한 교사 정보 업데이트
  void updateExchangeableTeachers(List<Map<String, dynamic>> teachers) {
    state = state.copyWith(exchangeableTeachers: teachers);
  }

  /// 순환교체 경로 업데이트
  void updateSelectedCircularPath(CircularExchangePath? path) {
    state = state.copyWith(selectedCircularPath: path);
  }

  /// 1:1 교체 경로 업데이트
  void updateSelectedOneToOnePath(OneToOneExchangePath? path) {
    state = state.copyWith(selectedOneToOnePath: path);
  }

  /// 연쇄교체 경로 업데이트
  void updateSelectedChainPath(ChainExchangePath? path) {
    state = state.copyWith(selectedChainPath: path);
  }

  /// 교체된 셀 상태 업데이트
  void updateExchangedCells(List<String> cellKeys) {
    state = state.copyWith(exchangedCells: cellKeys.toSet());
  }

  /// 교체된 목적지 셀 상태 업데이트
  void updateExchangedDestinationCells(List<String> cellKeys) {
    state = state.copyWith(exchangedDestinationCells: cellKeys.toSet());
  }

  /// 교사 이름 선택 상태 업데이트 (새로 추가)
  void updateSelectedTeacherName(String? teacherName) {
    state = state.copyWith(
      selectedTeacherName: teacherName,
      clearCaches: true,
    );
  }

  /// 캐시 무효화 (실제 캐시는 TimetableDataSource에서 관리)
  void invalidateCache() {
    state = state.copyWith(cacheInvalidated: true);
  }

  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    state = state.copyWith(
      clearSelection: true,
      clearTarget: true,
      clearPaths: true,
      exchangeableTeachers: [],
      clearTeacherNameSelection: true, // 교사 이름 선택 상태도 초기화
    );
  }

  /// 모든 캐시 초기화
  void clearAllCaches() {
    state = state.copyWith(clearCaches: true);
  }

  /// 교체된 셀 상태 초기화
  void clearExchangedCells() {
    state = state.copyWith(clearExchangedCells: true);
  }

  /// 특정 셀이 선택된 상태인지 확인
  bool isCellSelected(String teacherName, String day, int period) {
    return state.selectedTeacher == teacherName && 
           state.selectedDay == day && 
           state.selectedPeriod == period;
  }

  /// 특정 셀이 타겟 셀인지 확인
  bool isCellTarget(String teacherName, String day, int period) {
    return state.targetTeacher == teacherName && 
           state.targetDay == day && 
           state.targetPeriod == period;
  }

  /// 특정 셀이 교체된 소스 셀인지 확인
  bool isCellExchangedSource(String teacherName, String day, int period) {
    final cellKey = '${teacherName}_${day}_$period';
    return state.exchangedCells.contains(cellKey);
  }

  /// 특정 셀이 교체된 목적지 셀인지 확인
  bool isCellExchangedDestination(String teacherName, String day, int period) {
    final cellKey = '${teacherName}_${day}_$period';
    return state.exchangedDestinationCells.contains(cellKey);
  }

  /// 교체 가능한 교사인지 확인
  bool isExchangeableTeacher(String teacherName, String day, int period) {
    return state.exchangeableTeachers.any((teacher) => 
      teacher['teacherName'] == teacherName &&
      teacher['day'] == day &&
      teacher['period'] == period
    );
  }

  /// 순환교체 경로에 포함된 셀인지 확인
  bool isInCircularPath(String teacherName, String day, int period) {
    if (state.selectedCircularPath == null) return false;
    
    return state.selectedCircularPath!.nodes.any((node) => 
      node.teacherName == teacherName &&
      node.day == day &&
      node.period == period
    );
  }

  /// 연쇄교체 경로에 포함된 셀인지 확인
  bool isInChainPath(String teacherName, String day, int period) {
    if (state.selectedChainPath == null) return false;
    
    return state.selectedChainPath!.nodes.any((node) => 
      node.teacherName == teacherName &&
      node.day == day &&
      node.period == period
    );
  }

  /// 선택된 1:1 교체 경로에 포함된 셀인지 확인
  bool isInSelectedOneToOnePath(String teacherName, String day, int period) {
    if (state.selectedOneToOnePath == null) return false;
    
    return state.selectedOneToOnePath!.sourceNode.teacherName == teacherName &&
           state.selectedOneToOnePath!.sourceNode.day == day &&
           state.selectedOneToOnePath!.sourceNode.period == period ||
           state.selectedOneToOnePath!.targetNode.teacherName == teacherName &&
           state.selectedOneToOnePath!.targetNode.day == day &&
           state.selectedOneToOnePath!.targetNode.period == period;
  }

  // ========================================
  // 배치 업데이트 메서드들
  // ========================================

  /// Level 3 전용 배치 업데이트: 모든 상태 초기화
  void resetAllStatesBatch() {
    state = state.copyWith(
      // 선택 상태 초기화
      clearSelection: true,
      clearTarget: true,
      clearPaths: true,
      exchangeableTeachers: [],
      // 교체된 셀 초기화
      clearExchangedCells: true,
      // 교사 이름 선택 초기화
      clearTeacherNameSelection: true,
      // 캐시 초기화
      clearCaches: true,
    );
  }
}

/// 시간표 테마 Provider
final timetableThemeProvider = StateNotifierProvider<TimetableThemeNotifier, TimetableThemeState>((ref) {
  return TimetableThemeNotifier();
});

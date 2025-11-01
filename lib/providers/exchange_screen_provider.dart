import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/excel_service.dart';
import '../models/exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../models/exchange_mode.dart';
import '../utils/timetable_data_source.dart';
import '../utils/logger.dart';

/// ExchangeScreen 상태 클래스
class ExchangeScreenState {
  final File? selectedFile;
  final TimetableData? timetableData;
  final TimetableDataSource? dataSource;
  final List<GridColumn> columns;
  final List<StackedHeaderRow> stackedHeaders;
  final bool isLoading;
  final String? errorMessage;
  final ExchangeMode currentMode;

  // 🔥 통합된 교체 경로 리스트 (3개 → 1개로 통합)
  final List<ExchangePath> availablePaths;
  final bool isPathsLoading;
  final double loadingProgress;

  // 선택된 경로들 (타입별로 유지)
  final OneToOneExchangePath? selectedOneToOnePath;
  final CircularExchangePath? selectedCircularPath;
  final ChainExchangePath? selectedChainPath;
  final SupplementExchangePath? selectedSupplementPath;

  final bool isSidebarVisible;
  final String searchQuery;
  final List<int> availableSteps;
  final int? selectedStep;
  final String? selectedDay;
  final bool isNonExchangeableEditMode;
  final bool isTeacherNameSelectionEnabled; // 교사 이름 선택 기능 활성화 상태

  // 파일 로드 시에만 변경되는 고유 ID (SfDataGrid ValueKey용)
  final int fileLoadId;

  const ExchangeScreenState({
    this.selectedFile,
    this.timetableData,
    this.dataSource,
    this.columns = const [],
    this.stackedHeaders = const [],
    this.isLoading = false,
    this.errorMessage,
    this.currentMode = ExchangeMode.view,
    this.availablePaths = const [],
    this.isPathsLoading = false,
    this.loadingProgress = 0.0,
    this.selectedOneToOnePath,
    this.selectedCircularPath,
    this.selectedChainPath,
    this.selectedSupplementPath,
    this.isSidebarVisible = false,
    this.searchQuery = '',
    this.availableSteps = const [],
    this.selectedStep,
    this.selectedDay,
    this.isNonExchangeableEditMode = false,
    this.isTeacherNameSelectionEnabled = false, // 기본값: 비활성화
    this.fileLoadId = 0, // 기본값: 0
  });

  ExchangeScreenState copyWith({
    File? Function()? selectedFile,
    TimetableData? Function()? timetableData,
    TimetableDataSource? Function()? dataSource,
    List<GridColumn>? columns,
    List<StackedHeaderRow>? stackedHeaders,
    bool? isLoading,
    String? Function()? errorMessage,
    ExchangeMode? currentMode,
    List<ExchangePath>? availablePaths,
    bool? isPathsLoading,
    double? loadingProgress,
    OneToOneExchangePath? Function()? selectedOneToOnePath,
    CircularExchangePath? Function()? selectedCircularPath,
    ChainExchangePath? Function()? selectedChainPath,
    SupplementExchangePath? Function()? selectedSupplementPath,
    bool? isSidebarVisible,
    String? searchQuery,
    List<int>? availableSteps,
    int? Function()? selectedStep,
    String? Function()? selectedDay,
    bool? isNonExchangeableEditMode,
    bool? isTeacherNameSelectionEnabled,
    int? fileLoadId,
  }) {
    return ExchangeScreenState(
      selectedFile: selectedFile != null ? selectedFile() : this.selectedFile,
      timetableData:
          timetableData != null ? timetableData() : this.timetableData,
      dataSource: dataSource != null ? dataSource() : this.dataSource,
      columns: columns ?? this.columns,
      stackedHeaders: stackedHeaders ?? this.stackedHeaders,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      currentMode: currentMode ?? this.currentMode,
      availablePaths: availablePaths ?? this.availablePaths,
      isPathsLoading: isPathsLoading ?? this.isPathsLoading,
      loadingProgress: loadingProgress ?? this.loadingProgress,
      selectedOneToOnePath: selectedOneToOnePath != null ? selectedOneToOnePath() : this.selectedOneToOnePath,
      selectedCircularPath: selectedCircularPath != null ? selectedCircularPath() : this.selectedCircularPath,
      selectedChainPath: selectedChainPath != null ? selectedChainPath() : this.selectedChainPath,
      selectedSupplementPath: selectedSupplementPath != null ? selectedSupplementPath() : this.selectedSupplementPath,
      isSidebarVisible: isSidebarVisible ?? this.isSidebarVisible,
      searchQuery: searchQuery ?? this.searchQuery,
      availableSteps: availableSteps ?? this.availableSteps,
      selectedStep: selectedStep != null ? selectedStep() : this.selectedStep,
      selectedDay: selectedDay != null ? selectedDay() : this.selectedDay,
      isNonExchangeableEditMode: isNonExchangeableEditMode ?? this.isNonExchangeableEditMode,
      isTeacherNameSelectionEnabled: isTeacherNameSelectionEnabled ?? this.isTeacherNameSelectionEnabled,
      fileLoadId: fileLoadId ?? this.fileLoadId,
    );
  }
}

/// ExchangeScreen 상태를 관리하는 StateNotifier
class ExchangeScreenNotifier extends StateNotifier<ExchangeScreenState> {
  ExchangeScreenNotifier() : super(const ExchangeScreenState());

  void setSelectedFile(File? file) {
    state = state.copyWith(selectedFile: () => file);
  }

  void setTimetableData(TimetableData? data) {
    // 데이터 검증 로그 추가
    if (data != null) {
      AppLogger.exchangeDebug('📊 [ExchangeScreenProvider] timetableData 설정: ${data.teachers.length}명 교사, ${data.timeSlots.length}개 TimeSlot');
      
      // 비어있지 않은 TimeSlot 개수 확인
      final nonEmptySlots = data.timeSlots.where((slot) => slot.isNotEmpty).length;
      AppLogger.exchangeDebug('📊 [ExchangeScreenProvider] 수업이 있는 TimeSlot: $nonEmptySlots개 / 전체 ${data.timeSlots.length}개');
      
      // 샘플 TimeSlot 확인 (최대 5개)
      final sampleSlots = data.timeSlots.where((slot) => slot.isNotEmpty).take(5).toList();
      AppLogger.exchangeDebug('📊 [ExchangeScreenProvider] TimeSlot 샘플 (최대 5개):');
      for (var slot in sampleSlots) {
        AppLogger.exchangeDebug('  - teacher=${slot.teacher}, dayOfWeek=${slot.dayOfWeek}, period=${slot.period}, subject=${slot.subject}, className=${slot.className}');
      }
    } else {
      AppLogger.exchangeDebug('📊 [ExchangeScreenProvider] timetableData를 null로 설정');
    }
    
    state = state.copyWith(
      timetableData: () => data,
      // 파일 로드 시 fileLoadId 증가 (SfDataGrid 재생성용)
      fileLoadId: state.fileLoadId + 1,
    );
  }

  void setDataSource(TimetableDataSource? dataSource) {
    // 이전 dataSource 정리 (메모리 누수 방지)
    final previousDataSource = state.dataSource;
    if (previousDataSource != null) {
      AppLogger.exchangeDebug('🧹 [ExchangeScreenProvider] 이전 TimetableDataSource 정리');
      previousDataSource.dispose();
    }
    
    state = state.copyWith(dataSource: () => dataSource);
  }

  void setColumns(List<GridColumn> columns) {
    state = state.copyWith(columns: columns);
  }

  void setStackedHeaders(List<StackedHeaderRow> headers) {
    state = state.copyWith(stackedHeaders: headers);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setErrorMessage(String? message) {
    state = state.copyWith(errorMessage: () => message);
  }

  void setCurrentMode(ExchangeMode mode) {
    state = state.copyWith(currentMode: mode);
  }

  // 🔥 통합된 교체 경로 관리 메서드들
  
  /// 모든 교체 경로 설정 (통합)
  void setAvailablePaths(List<ExchangePath> paths) {
    state = state.copyWith(availablePaths: paths);
  }
  
  /// 교체 경로 로딩 상태 설정
  void setPathsLoading(bool loading) {
    state = state.copyWith(isPathsLoading: loading);
  }
  
  /// 로딩 진행률 설정
  void setLoadingProgress(double progress) {
    state = state.copyWith(loadingProgress: progress);
  }

  void setSidebarVisible(bool visible) {
    state = state.copyWith(isSidebarVisible: visible);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedOneToOnePath(OneToOneExchangePath? path) {
    state = state.copyWith(selectedOneToOnePath: () => path);
  }

  void setSelectedCircularPath(CircularExchangePath? path) {
    state = state.copyWith(selectedCircularPath: () => path);
  }

  void setSelectedChainPath(ChainExchangePath? path) {
    state = state.copyWith(selectedChainPath: () => path);
  }

  void setSelectedSupplementPath(SupplementExchangePath? path) {
    state = state.copyWith(selectedSupplementPath: () => path);
  }

  void setAvailableSteps(List<int> steps) {
    state = state.copyWith(availableSteps: steps);
  }

  void setSelectedStep(int? step) {
    state = state.copyWith(selectedStep: () => step);
  }

  void setSelectedDay(String? day) {
    state = state.copyWith(selectedDay: () => day);
  }

  /// 교체 모드 활성화 상태 설정 (Deprecated)
  /// setCurrentMode()를 사용하세요.
  @Deprecated('setCurrentMode()를 사용하세요.')
  void setExchangeModeEnabled(bool enabled) {
    // ExchangeMode.oneToOneExchange / ExchangeMode.view 사용
  }

  /// 순환 교체 모드 활성화 상태 설정 (Deprecated)
  /// setCurrentMode()를 사용하세요.
  @Deprecated('setCurrentMode()를 사용하세요.')
  void setCircularExchangeModeEnabled(bool enabled) {
    // ExchangeMode.circularExchange / ExchangeMode.view 사용
  }

  /// 체인 교체 모드 활성화 상태 설정 (Deprecated)
  /// setCurrentMode()를 사용하세요.
  @Deprecated('setCurrentMode()를 사용하세요.')
  void setChainExchangeModeEnabled(bool enabled) {
    // ExchangeMode.chainExchange / ExchangeMode.view 사용
  }

  /// 교체불가 편집 모드 설정
  void setNonExchangeableEditMode(bool enabled) {
    state = state.copyWith(isNonExchangeableEditMode: enabled);
  }

  // ========================================
  // 배치 업데이트 메서드들
  // ========================================

  /// 여러 상태를 한 번에 업데이트 (UI 업데이트 최적화)
  void updateMultipleStates({
    File? selectedFile,
    TimetableData? timetableData,
    TimetableDataSource? dataSource,
    List<GridColumn>? columns,
    List<StackedHeaderRow>? stackedHeaders,
    bool? isLoading,
    String? errorMessage,
    ExchangeMode? currentMode,
    List<CircularExchangePath>? circularPaths,
    bool? isCircularPathsLoading,
    double? loadingProgress,
    List<ChainExchangePath>? chainPaths,
    bool? isChainPathsLoading,
    List<OneToOneExchangePath>? oneToOnePaths,
    bool? isSidebarVisible,
    String? searchQuery,
    OneToOneExchangePath? selectedOneToOnePath,
    CircularExchangePath? selectedCircularPath,
    ChainExchangePath? selectedChainPath,
    List<int>? availableSteps,
    int? selectedStep,
    String? selectedDay,
    bool? isNonExchangeableEditMode,
  }) {
    state = state.copyWith(
      selectedFile: selectedFile != null ? () => selectedFile : null,
      timetableData: timetableData != null ? () => timetableData : null,
      dataSource: dataSource != null ? () => dataSource : null,
      columns: columns,
      stackedHeaders: stackedHeaders,
      isLoading: isLoading,
      errorMessage: errorMessage != null ? () => errorMessage : null,
      currentMode: currentMode,
      availablePaths: [], // 통합된 경로 리스트 초기화
      isPathsLoading: false,
      loadingProgress: loadingProgress,
      isSidebarVisible: isSidebarVisible,
      searchQuery: searchQuery,
      selectedOneToOnePath: selectedOneToOnePath != null ? () => selectedOneToOnePath : null,
      selectedCircularPath: selectedCircularPath != null ? () => selectedCircularPath : null,
      selectedChainPath: selectedChainPath != null ? () => selectedChainPath : null,
      availableSteps: availableSteps,
      selectedStep: selectedStep != null ? () => selectedStep : null,
      selectedDay: selectedDay != null ? () => selectedDay : null,
      isNonExchangeableEditMode: isNonExchangeableEditMode,
    );
  }

  /// Level 1 전용 배치 업데이트: 경로 선택만 초기화
  void resetPathSelectionBatch() {
    state = state.copyWith(
      selectedOneToOnePath: () => null,
      selectedCircularPath: () => null,
      selectedChainPath: () => null,
    );
  }

  /// Level 2 전용 배치 업데이트: 교체 상태 초기화
  void resetExchangeStatesBatch() {
    state = state.copyWith(
      // 경로 선택 초기화
      selectedOneToOnePath: () => null,
      selectedCircularPath: () => null,
      selectedChainPath: () => null,
      // 통합된 경로 리스트 초기화
      availablePaths: [],
      // UI 상태 초기화
      isSidebarVisible: false,
      isPathsLoading: false,
      loadingProgress: 0.0,
      // 필터 상태 초기화
      searchQuery: '',
      availableSteps: [],
      selectedStep: () => null,
    );
  }

  /// 교사 이름 선택 기능 활성화
  void enableTeacherNameSelection() {
    state = state.copyWith(isTeacherNameSelectionEnabled: true);
  }

  /// 교사 이름 선택 기능 비활성화
  void disableTeacherNameSelection() {
    state = state.copyWith(isTeacherNameSelectionEnabled: false);
  }
}

/// ExchangeScreen 상태 Provider
final exchangeScreenProvider =
    StateNotifierProvider<ExchangeScreenNotifier, ExchangeScreenState>((ref) {
  return ExchangeScreenNotifier();
});

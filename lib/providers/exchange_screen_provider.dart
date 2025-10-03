import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/excel_service.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../utils/timetable_data_source.dart';

/// ExchangeScreen 상태 클래스
class ExchangeScreenState {
  final File? selectedFile;
  final TimetableData? timetableData;
  final TimetableDataSource? dataSource;
  final List<GridColumn> columns;
  final List<StackedHeaderRow> stackedHeaders;
  final bool isLoading;
  final String? errorMessage;
  final bool isExchangeModeEnabled;
  final bool isCircularExchangeModeEnabled;
  final bool isChainExchangeModeEnabled;
  final List<CircularExchangePath> circularPaths;
  final bool isCircularPathsLoading;
  final double loadingProgress;
  final List<ChainExchangePath> chainPaths;
  final bool isChainPathsLoading;
  final List<OneToOneExchangePath> oneToOnePaths;
  final OneToOneExchangePath? selectedOneToOnePath;
  final CircularExchangePath? selectedCircularPath;
  final ChainExchangePath? selectedChainPath;
  final bool isSidebarVisible;
  final String searchQuery;
  final List<int> availableSteps;
  final int? selectedStep;
  final String? selectedDay;

  const ExchangeScreenState({
    this.selectedFile,
    this.timetableData,
    this.dataSource,
    this.columns = const [],
    this.stackedHeaders = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isExchangeModeEnabled = false,
    this.isCircularExchangeModeEnabled = false,
    this.isChainExchangeModeEnabled = false,
    this.circularPaths = const [],
    this.isCircularPathsLoading = false,
    this.loadingProgress = 0.0,
    this.chainPaths = const [],
    this.isChainPathsLoading = false,
    this.oneToOnePaths = const [],
    this.selectedOneToOnePath,
    this.selectedCircularPath,
    this.selectedChainPath,
    this.isSidebarVisible = false,
    this.searchQuery = '',
    this.availableSteps = const [],
    this.selectedStep,
    this.selectedDay,
  });

  ExchangeScreenState copyWith({
    File? Function()? selectedFile,
    TimetableData? Function()? timetableData,
    TimetableDataSource? Function()? dataSource,
    List<GridColumn>? columns,
    List<StackedHeaderRow>? stackedHeaders,
    bool? isLoading,
    String? Function()? errorMessage,
    bool? isExchangeModeEnabled,
    bool? isCircularExchangeModeEnabled,
    bool? isChainExchangeModeEnabled,
    List<CircularExchangePath>? circularPaths,
    bool? isCircularPathsLoading,
    double? loadingProgress,
    List<ChainExchangePath>? chainPaths,
    bool? isChainPathsLoading,
    List<OneToOneExchangePath>? oneToOnePaths,
    OneToOneExchangePath? Function()? selectedOneToOnePath,
    CircularExchangePath? Function()? selectedCircularPath,
    ChainExchangePath? Function()? selectedChainPath,
    bool? isSidebarVisible,
    String? searchQuery,
    List<int>? availableSteps,
    int? Function()? selectedStep,
    String? Function()? selectedDay,
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
      isExchangeModeEnabled:
          isExchangeModeEnabled ?? this.isExchangeModeEnabled,
      isCircularExchangeModeEnabled: isCircularExchangeModeEnabled ??
          this.isCircularExchangeModeEnabled,
      isChainExchangeModeEnabled:
          isChainExchangeModeEnabled ?? this.isChainExchangeModeEnabled,
      circularPaths: circularPaths ?? this.circularPaths,
      isCircularPathsLoading:
          isCircularPathsLoading ?? this.isCircularPathsLoading,
      loadingProgress: loadingProgress ?? this.loadingProgress,
      chainPaths: chainPaths ?? this.chainPaths,
      isChainPathsLoading: isChainPathsLoading ?? this.isChainPathsLoading,
      oneToOnePaths: oneToOnePaths ?? this.oneToOnePaths,
      selectedOneToOnePath: selectedOneToOnePath != null ? selectedOneToOnePath() : this.selectedOneToOnePath,
      selectedCircularPath: selectedCircularPath != null ? selectedCircularPath() : this.selectedCircularPath,
      selectedChainPath: selectedChainPath != null ? selectedChainPath() : this.selectedChainPath,
      isSidebarVisible: isSidebarVisible ?? this.isSidebarVisible,
      searchQuery: searchQuery ?? this.searchQuery,
      availableSteps: availableSteps ?? this.availableSteps,
      selectedStep: selectedStep != null ? selectedStep() : this.selectedStep,
      selectedDay: selectedDay != null ? selectedDay() : this.selectedDay,
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
    state = state.copyWith(timetableData: () => data);
  }

  void setDataSource(TimetableDataSource? dataSource) {
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

  void setExchangeModeEnabled(bool enabled) {
    state = state.copyWith(isExchangeModeEnabled: enabled);
  }

  void setCircularExchangeModeEnabled(bool enabled) {
    state = state.copyWith(isCircularExchangeModeEnabled: enabled);
  }

  void setChainExchangeModeEnabled(bool enabled) {
    state = state.copyWith(isChainExchangeModeEnabled: enabled);
  }

  void setCircularPaths(List<CircularExchangePath> paths) {
    state = state.copyWith(circularPaths: paths);
  }

  void setCircularPathsLoading(bool loading) {
    state = state.copyWith(isCircularPathsLoading: loading);
  }

  void setLoadingProgress(double progress) {
    state = state.copyWith(loadingProgress: progress);
  }

  void setChainPaths(List<ChainExchangePath> paths) {
    state = state.copyWith(chainPaths: paths);
  }

  void setChainPathsLoading(bool loading) {
    state = state.copyWith(isChainPathsLoading: loading);
  }

  void setOneToOnePaths(List<OneToOneExchangePath> paths) {
    state = state.copyWith(oneToOnePaths: paths);
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

  void setAvailableSteps(List<int> steps) {
    state = state.copyWith(availableSteps: steps);
  }

  void setSelectedStep(int? step) {
    state = state.copyWith(selectedStep: () => step);
  }

  void setSelectedDay(String? day) {
    state = state.copyWith(selectedDay: () => day);
  }
}

/// ExchangeScreen 상태 Provider
final exchangeScreenProvider =
    StateNotifierProvider<ExchangeScreenNotifier, ExchangeScreenState>((ref) {
  return ExchangeScreenNotifier();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exchange_path.dart';

/// 화살표 표시 상태 클래스
class ArrowDisplayState {
  /// 현재 표시할 교체 경로
  final ExchangePath? selectedPath;
  
  /// 화살표 표시 여부
  final bool isVisible;
  
  /// 화살표 표시 원인 (디버깅용)
  final ArrowDisplayReason reason;
  
  /// 교체된 셀에서 선택된 경로인지 여부
  final bool isFromExchangedCell;
  
  /// 마지막 업데이트 시간 (디버깅용)
  final DateTime lastUpdated;

  const ArrowDisplayState({
    this.selectedPath,
    this.isVisible = false,
    this.reason = ArrowDisplayReason.none,
    this.isFromExchangedCell = false,
    required this.lastUpdated,
  });

  ArrowDisplayState copyWith({
    ExchangePath? selectedPath,
    bool? isVisible,
    ArrowDisplayReason? reason,
    bool? isFromExchangedCell,
    DateTime? lastUpdated,
  }) {
    return ArrowDisplayState(
      selectedPath: selectedPath ?? this.selectedPath,
      isVisible: isVisible ?? this.isVisible,
      reason: reason ?? this.reason,
      isFromExchangedCell: isFromExchangedCell ?? this.isFromExchangedCell,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'ArrowDisplayState('
        'selectedPath: ${selectedPath?.type}, '
        'isVisible: $isVisible, '
        'reason: $reason, '
        'isFromExchangedCell: $isFromExchangedCell, '
        'lastUpdated: $lastUpdated'
        ')';
  }
}

/// 화살표 표시 원인 열거형
enum ArrowDisplayReason {
  none,                    // 표시 안함
  pathSelected,           // 경로 선택됨
  exchangedCellClicked,   // 교체된 셀 클릭됨
  manualShow,             // 수동으로 표시
  manualHide,             // 수동으로 숨김
}

/// 화살표 표시 상태를 관리하는 Notifier
class ArrowDisplayNotifier extends StateNotifier<ArrowDisplayState> {
  ArrowDisplayNotifier() : super(ArrowDisplayState(lastUpdated: DateTime.now()));

  /// 경로 선택 시 화살표 표시
  void showArrowForPath(ExchangePath path, {bool isFromExchangedCell = false}) {
    state = state.copyWith(
      selectedPath: path,
      isVisible: true,
      reason: isFromExchangedCell 
          ? ArrowDisplayReason.exchangedCellClicked 
          : ArrowDisplayReason.pathSelected,
      isFromExchangedCell: isFromExchangedCell,
      lastUpdated: DateTime.now(),
    );
  }

  /// 교체된 셀 클릭 시 화살표 표시
  void showArrowForExchangedCell(ExchangePath path) {
    state = state.copyWith(
      selectedPath: path,
      isVisible: true,
      reason: ArrowDisplayReason.exchangedCellClicked,
      isFromExchangedCell: true,
      lastUpdated: DateTime.now(),
    );
  }

  /// 화살표 숨기기
  void hideArrow({ArrowDisplayReason reason = ArrowDisplayReason.manualHide}) {
    state = state.copyWith(
      selectedPath: null,
      isVisible: false,
      reason: reason,
      isFromExchangedCell: false,
      lastUpdated: DateTime.now(),
    );
  }

  /// 모든 상태 초기화
  void reset() {
    state = ArrowDisplayState(lastUpdated: DateTime.now());
  }

  /// 현재 선택된 경로가 있는지 확인
  bool get hasSelectedPath => state.selectedPath != null;

  /// 화살표가 표시 중인지 확인
  bool get isArrowVisible => state.isVisible && state.selectedPath != null;
}

/// 화살표 표시 상태 Provider
final arrowDisplayProvider = StateNotifierProvider<ArrowDisplayNotifier, ArrowDisplayState>(
  (ref) => ArrowDisplayNotifier(),
);

/// 화살표 표시 여부만 반환하는 간단한 Provider
final isArrowVisibleProvider = Provider<bool>((ref) {
  final arrowState = ref.watch(arrowDisplayProvider);
  return arrowState.isVisible && arrowState.selectedPath != null;
});

/// 현재 선택된 경로만 반환하는 Provider
final selectedPathProvider = Provider<ExchangePath?>((ref) {
  final arrowState = ref.watch(arrowDisplayProvider);
  return arrowState.selectedPath;
});

/// 교체된 셀에서 선택된 경로인지 확인하는 Provider
final isFromExchangedCellProvider = Provider<bool>((ref) {
  final arrowState = ref.watch(arrowDisplayProvider);
  return arrowState.isFromExchangedCell;
});

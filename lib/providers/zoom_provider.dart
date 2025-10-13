import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/widgets/timetable_grid/timetable_grid_constants.dart';
import '../utils/simplified_timetable_theme.dart';
import '../utils/logger.dart';

/// 줌 상태를 관리하는 클래스
/// 
/// 확대/축소 비율과 관련된 모든 상태를 중앙에서 관리하며,
/// UI 반응성을 개선하기 위해 Riverpod을 사용합니다.
class ZoomState {
  /// 현재 확대 비율 (1.0 = 100%)
  final double zoomFactor;
  
  /// 확대 비율을 퍼센트로 변환한 값
  final int zoomPercentage;
  
  /// 최소 확대 비율
  final double minZoom;
  
  /// 최대 확대 비율
  final double maxZoom;
  
  /// 확대/축소 단계
  final double zoomStep;
  
  /// 기본 확대 비율
  final double defaultZoomFactor;

  const ZoomState({
    required this.zoomFactor,
    required this.zoomPercentage,
    required this.minZoom,
    required this.maxZoom,
    required this.zoomStep,
    required this.defaultZoomFactor,
  });

  /// 줌 상태 복사본 생성
  ZoomState copyWith({
    double? zoomFactor,
    int? zoomPercentage,
    double? minZoom,
    double? maxZoom,
    double? zoomStep,
    double? defaultZoomFactor,
  }) {
    return ZoomState(
      zoomFactor: zoomFactor ?? this.zoomFactor,
      zoomPercentage: zoomPercentage ?? this.zoomPercentage,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      zoomStep: zoomStep ?? this.zoomStep,
      defaultZoomFactor: defaultZoomFactor ?? this.defaultZoomFactor,
    );
  }

  /// 줌이 가능한지 확인 (확대)
  bool get canZoomIn => zoomFactor < maxZoom;
  
  /// 줌이 가능한지 확인 (축소)
  bool get canZoomOut => zoomFactor > minZoom;
  
  /// 기본 줌 상태인지 확인
  bool get isDefaultZoom => zoomFactor == defaultZoomFactor;

  @override
  String toString() {
    return 'ZoomState(zoomFactor: $zoomFactor, zoomPercentage: $zoomPercentage%, canZoomIn: $canZoomIn, canZoomOut: $canZoomOut)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZoomState &&
        other.zoomFactor == zoomFactor &&
        other.zoomPercentage == zoomPercentage &&
        other.minZoom == minZoom &&
        other.maxZoom == maxZoom &&
        other.zoomStep == zoomStep &&
        other.defaultZoomFactor == defaultZoomFactor;
  }

  @override
  int get hashCode {
    return Object.hash(
      zoomFactor,
      zoomPercentage,
      minZoom,
      maxZoom,
      zoomStep,
      defaultZoomFactor,
    );
  }
}

/// 줌 상태를 관리하는 Notifier 클래스
/// 
/// 확대/축소 기능과 관련된 모든 비즈니스 로직을 담당하며,
/// 상태 변경 시 자동으로 UI가 업데이트됩니다.
class ZoomNotifier extends StateNotifier<ZoomState> {
  ZoomNotifier() : super(_createInitialState()) {
    // 초기화 시 폰트 스케일 팩터 설정
    _updateFontScaleFactor();
  }

  /// 초기 상태 생성
  static ZoomState _createInitialState() {
    return ZoomState(
      zoomFactor: GridLayoutConstants.defaultZoomFactor,
      zoomPercentage: (GridLayoutConstants.defaultZoomFactor * 100).round(),
      minZoom: GridLayoutConstants.minZoom,
      maxZoom: GridLayoutConstants.maxZoom,
      zoomStep: GridLayoutConstants.zoomStep,
      defaultZoomFactor: GridLayoutConstants.defaultZoomFactor,
    );
  }

  /// 그리드 확대
  /// 
  /// 최대 확대 비율을 초과하지 않는 범위에서 확대합니다.
  void zoomIn() {
    if (!state.canZoomIn) {
      AppLogger.exchangeDebug('줌 인 불가: 이미 최대 확대 비율에 도달함 (${state.zoomPercentage}%)');
      return;
    }

    final newZoomFactor = (state.zoomFactor + state.zoomStep)
        .clamp(state.minZoom, state.maxZoom);
    
    _updateZoomFactor(newZoomFactor);
    AppLogger.exchangeDebug('줌 인: ${state.zoomPercentage}% → ${(newZoomFactor * 100).round()}%');
  }

  /// 그리드 축소
  /// 
  /// 최소 확대 비율을 하회하지 않는 범위에서 축소합니다.
  void zoomOut() {
    if (!state.canZoomOut) {
      AppLogger.exchangeDebug('줌 아웃 불가: 이미 최소 확대 비율에 도달함 (${state.zoomPercentage}%)');
      return;
    }

    final newZoomFactor = (state.zoomFactor - state.zoomStep)
        .clamp(state.minZoom, state.maxZoom);
    
    _updateZoomFactor(newZoomFactor);
    AppLogger.exchangeDebug('줌 아웃: ${state.zoomPercentage}% → ${(newZoomFactor * 100).round()}%');
  }

  /// 확대/축소 초기화
  /// 
  /// 기본 확대 비율(100%)로 되돌립니다.
  void resetZoom() {
    if (state.isDefaultZoom) {
      AppLogger.exchangeDebug('줌 리셋 불필요: 이미 기본 확대 비율임 (${state.zoomPercentage}%)');
      return;
    }

    _updateZoomFactor(state.defaultZoomFactor);
    AppLogger.exchangeDebug('줌 리셋: ${state.zoomPercentage}% → ${(state.defaultZoomFactor * 100).round()}%');
  }

  /// 특정 확대 비율로 설정
  /// 
  /// [zoomFactor] 설정할 확대 비율 (minZoom ~ maxZoom 범위)
  void setZoomFactor(double zoomFactor) {
    final clampedZoomFactor = zoomFactor.clamp(state.minZoom, state.maxZoom);
    
    if (clampedZoomFactor == state.zoomFactor) {
      AppLogger.exchangeDebug('줌 설정 불필요: 이미 동일한 확대 비율임 (${state.zoomPercentage}%)');
      return;
    }

    _updateZoomFactor(clampedZoomFactor);
    AppLogger.exchangeDebug('줌 설정: ${state.zoomPercentage}% → ${(clampedZoomFactor * 100).round()}%');
  }

  /// 확대 비율 업데이트 (내부 메서드)
  /// 
  /// [newZoomFactor] 새로운 확대 비율
  void _updateZoomFactor(double newZoomFactor) {
    final newZoomPercentage = (newZoomFactor * 100).round();
    
    state = state.copyWith(
      zoomFactor: newZoomFactor,
      zoomPercentage: newZoomPercentage,
    );
    
    // 폰트 스케일 팩터 업데이트
    _updateFontScaleFactor();
  }

  /// 폰트 스케일 팩터 업데이트
  /// 
  /// SimplifiedTimetableTheme에 현재 줌 팩터를 적용합니다.
  void _updateFontScaleFactor() {
    SimplifiedTimetableTheme.setFontScaleFactor(state.zoomFactor);
    AppLogger.exchangeDebug('폰트 스케일 팩터 업데이트: ${state.zoomFactor}');
  }

  /// 줌 상태 초기화
  /// 
  /// 모든 줌 관련 상태를 기본값으로 되돌립니다.
  void reset() {
    state = _createInitialState();
    _updateFontScaleFactor();
    AppLogger.exchangeDebug('줌 상태 초기화 완료');
  }

  /// 줌 설정 정보 조회
  /// 
  /// 현재 줌 상태와 설정 가능한 범위를 반환합니다.
  Map<String, dynamic> getZoomInfo() {
    return {
      'currentZoomFactor': state.zoomFactor,
      'currentZoomPercentage': state.zoomPercentage,
      'minZoom': state.minZoom,
      'maxZoom': state.maxZoom,
      'zoomStep': state.zoomStep,
      'canZoomIn': state.canZoomIn,
      'canZoomOut': state.canZoomOut,
      'isDefaultZoom': state.isDefaultZoom,
    };
  }
}

/// 줌 상태 Provider
/// 
/// 앱 전체에서 줌 상태를 공유하고 관리합니다.
final zoomProvider = StateNotifierProvider<ZoomNotifier, ZoomState>((ref) {
  return ZoomNotifier();
});

/// 줌 팩터만을 반환하는 Provider (성능 최적화용)
/// 
/// 줌 팩터만 필요한 경우 사용하여 불필요한 리빌드를 방지합니다.
final zoomFactorProvider = Provider<double>((ref) {
  return ref.watch(zoomProvider).zoomFactor;
});

/// 줌 퍼센트만을 반환하는 Provider (성능 최적화용)
/// 
/// 줌 퍼센트만 필요한 경우 사용하여 불필요한 리빌드를 방지합니다.
final zoomPercentageProvider = Provider<int>((ref) {
  return ref.watch(zoomProvider).zoomPercentage;
});

/// 줌 가능 여부를 반환하는 Provider들 (성능 최적화용)
final canZoomInProvider = Provider<bool>((ref) {
  return ref.watch(zoomProvider).canZoomIn;
});

final canZoomOutProvider = Provider<bool>((ref) {
  return ref.watch(zoomProvider).canZoomOut;
});

/// 줌 정보를 반환하는 Provider
/// 
/// 디버깅이나 상태 확인용으로 사용합니다.
final zoomInfoProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.watch(zoomProvider.notifier).getZoomInfo();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'exchange_screen_provider.dart';

/// 교체 모드 타입
enum ExchangeMode {
  none,
  oneToOne,
  circular,
  chain,
}

/// 교체 모드 상태 관리
class ExchangeModeState {
  final ExchangeMode currentMode;

  const ExchangeModeState({
    this.currentMode = ExchangeMode.none,
  });

  ExchangeModeState copyWith({
    ExchangeMode? currentMode,
  }) {
    return ExchangeModeState(
      currentMode: currentMode ?? this.currentMode,
    );
  }
}

/// 교체 모드 Provider
class ExchangeModeNotifier extends StateNotifier<ExchangeModeState> {
  ExchangeModeNotifier(this.ref) : super(const ExchangeModeState());

  final Ref ref;

  void setMode(ExchangeMode mode) {
    state = state.copyWith(currentMode: mode);

    // 화면 상태 업데이트
    final screenNotifier = ref.read(exchangeScreenProvider.notifier);
    screenNotifier.setExchangeModeEnabled(mode == ExchangeMode.oneToOne);
    screenNotifier.setCircularExchangeModeEnabled(mode == ExchangeMode.circular);
    screenNotifier.setChainExchangeModeEnabled(mode == ExchangeMode.chain);
    
    // 교체 모드가 활성화되면 교체불가 편집 모드는 비활성화
    if (mode != ExchangeMode.none) {
      screenNotifier.setNonExchangeableEditMode(false);
    }
  }

  void toggleOneToOne() {
    if (state.currentMode == ExchangeMode.oneToOne) {
      setMode(ExchangeMode.none);
    } else {
      setMode(ExchangeMode.oneToOne);
      // setMode에서 이미 교체불가 편집 모드가 비활성화되므로 별도 초기화 불필요
      // _clearAllSelections(); // 중복 초기화 제거
    }
  }

  void toggleCircular() {
    if (state.currentMode == ExchangeMode.circular) {
      setMode(ExchangeMode.none);
    } else {
      setMode(ExchangeMode.circular);
      // setMode에서 이미 교체불가 편집 모드가 비활성화되므로 별도 초기화 불필요
      // _clearAllSelections(); // 중복 초기화 제거
    }
  }

  void toggleChain() {
    if (state.currentMode == ExchangeMode.chain) {
      setMode(ExchangeMode.none);
    } else {
      setMode(ExchangeMode.chain);
      // setMode에서 이미 교체불가 편집 모드가 비활성화되므로 별도 초기화 불필요
      // _clearAllSelections(); // 중복 초기화 제거
    }
  }

}

final exchangeModeProvider = StateNotifierProvider<ExchangeModeNotifier, ExchangeModeState>((ref) {
  return ExchangeModeNotifier(ref);
});


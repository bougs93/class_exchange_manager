import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'exchange_screen_provider.dart';
import '../models/exchange_mode.dart';

/// 교체 모드 상태 관리
class ExchangeModeState {
  final ExchangeMode currentMode;

  const ExchangeModeState({
    this.currentMode = ExchangeMode.view,
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
    screenNotifier.setCurrentMode(mode);

    // 교체 모드가 활성화되면 교체불가 편집 모드는 비활성화
    if (mode != ExchangeMode.view) {
      screenNotifier.setNonExchangeableEditMode(false);
    }
  }

  void toggleOneToOne() {
    if (state.currentMode == ExchangeMode.oneToOneExchange) {
      setMode(ExchangeMode.view);
    } else {
      setMode(ExchangeMode.oneToOneExchange);
    }
  }

  void toggleCircular() {
    if (state.currentMode == ExchangeMode.circularExchange) {
      setMode(ExchangeMode.view);
    } else {
      setMode(ExchangeMode.circularExchange);
    }
  }

  void toggleChain() {
    if (state.currentMode == ExchangeMode.chainExchange) {
      setMode(ExchangeMode.view);
    } else {
      setMode(ExchangeMode.chainExchange);
    }
  }

}

final exchangeModeProvider = StateNotifierProvider<ExchangeModeNotifier, ExchangeModeState>((ref) {
  return ExchangeModeNotifier(ref);
});


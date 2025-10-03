import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'exchange_screen_provider.dart';
import 'services_provider.dart';

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
  }

  void toggleOneToOne() {
    if (state.currentMode == ExchangeMode.oneToOne) {
      setMode(ExchangeMode.none);
    } else {
      setMode(ExchangeMode.oneToOne);
      _clearAllSelections();
    }
  }

  void toggleCircular() {
    if (state.currentMode == ExchangeMode.circular) {
      setMode(ExchangeMode.none);
    } else {
      setMode(ExchangeMode.circular);
      _clearAllSelections();
    }
  }

  void toggleChain() {
    if (state.currentMode == ExchangeMode.chain) {
      setMode(ExchangeMode.none);
    } else {
      setMode(ExchangeMode.chain);
      _clearAllSelections();
    }
  }

  void _clearAllSelections() {
    final exchangeService = ref.read(exchangeServiceProvider);
    final circularService = ref.read(circularExchangeServiceProvider);
    final chainService = ref.read(chainExchangeServiceProvider);

    exchangeService.clearAllSelections();
    circularService.clearAllSelections();
    chainService.clearAllSelections();

    final screenNotifier = ref.read(exchangeScreenProvider.notifier);
    screenNotifier.setOneToOnePaths([]);
    screenNotifier.setCircularPaths([]);
    screenNotifier.setChainPaths([]);
    screenNotifier.setSelectedOneToOnePath(null);
    screenNotifier.setSelectedCircularPath(null);
    screenNotifier.setSelectedChainPath(null);
  }
}

final exchangeModeProvider = StateNotifierProvider<ExchangeModeNotifier, ExchangeModeState>((ref) {
  return ExchangeModeNotifier(ref);
});

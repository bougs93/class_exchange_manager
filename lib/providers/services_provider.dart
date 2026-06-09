import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/excel_service.dart';
import '../services/exchange_service.dart';
import '../services/exchange_history_service.dart';
import '../services/circular_exchange_service.dart';
import '../services/dual_exchange_service.dart';
import '../services/timetable_storage_service.dart';

/// ExcelService Provider
final excelServiceProvider = Provider<ExcelService>((ref) {
  return ExcelService();
});

/// TimetableStorageService Provider
final timetableStorageServiceProvider = Provider<TimetableStorageService>((ref) {
  return TimetableStorageService();
});

/// ExchangeService Provider (1:1 교체)
final exchangeServiceProvider = Provider<ExchangeService>((ref) {
  return ExchangeService();
});

/// ExchangeHistoryService Provider (교체 히스토리 관리)
final exchangeHistoryServiceProvider = Provider<ExchangeHistoryService>((ref) {
  final historyService = ExchangeHistoryService();
  
  // 🔥 교체 리스트 변경 시 버전 Provider 업데이트
  // ExchangeHistoryService에서 버전이 변경되면 이 콜백이 호출되어
  // exchangeListVersionProvider의 상태가 업데이트됩니다.
  historyService.setVersionChangedCallback(() {
    // ref.read를 사용하여 StateNotifier에 접근하고 버전을 증가시킵니다.
    ref.read(exchangeListVersionProvider.notifier).increment();
  });
  
  return historyService;
});

/// CircularExchangeService Provider (순환 교체)
final circularExchangeServiceProvider = Provider<CircularExchangeService>((ref) {
  return CircularExchangeService();
});

/// DualExchangeService Provider (2중 교체)
final dualExchangeServiceProvider = Provider<DualExchangeService>((ref) {
  return DualExchangeService();
});

/// 교체 리스트 버전 상태 관리용 StateNotifier
/// 
/// 교체 리스트가 변경될 때마다 버전을 증가시켜 변경을 추적합니다.
class ExchangeListVersionNotifier extends StateNotifier<int> {
  ExchangeListVersionNotifier() : super(0);

  /// 버전 증가 (교체 리스트 변경 시 호출)
  void increment() {
    state = state + 1;
  }

  /// 버전 조회
  int getVersion() => state;
}

/// 교체 리스트 버전 추적 Provider
/// 
/// 이 Provider를 watch하면 교체 리스트가 변경될 때마다 값을 감지할 수 있습니다.
/// ExchangeHistoryService에서 버전을 증가시키면 이 Provider가 자동으로 업데이트됩니다.
final exchangeListVersionProvider = StateNotifierProvider<ExchangeListVersionNotifier, int>((ref) {
  return ExchangeListVersionNotifier();
});
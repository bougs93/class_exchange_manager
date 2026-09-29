import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/excel_service.dart';
import '../services/exchange_event_mirror.dart';
import '../services/exchange_service.dart';
import '../services/exchange_history_service.dart';
import '../services/circular_exchange_service.dart';
import '../services/dual_exchange_service.dart';
import '../services/timetable_storage_service.dart';
import 'timetable_repository_provider.dart';

/// ExcelService Provider
final excelServiceProvider = Provider<ExcelService>((ref) {
  return ExcelService();
});

/// TimetableStorageService Provider
final timetableStorageServiceProvider = Provider<TimetableStorageService>((
  ref,
) {
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

  // S5.1: 교체 리스트가 JSON에 저장/삭제될 때마다 SQLite 저널에도 같은
  // 내용을 미러링한다. JSON이 여전히 진실 원본이다 — 이 싱크가 실패해도
  // (예: DB가 아직 준비 안 됨) ExchangeHistoryService 내부에서 로그만
  // 남기고 JSON 저장·삭제에는 전혀 영향을 주지 않는다.
  historyService.mirrorSink = (items, timetableId) async {
    final repo = await ref.read(timetableRepositoryProvider.future);
    await repo.replaceExchangeEventsFor(
      timetableId,
      toExchangeEventRecords(items, timetableId),
    );
    // S5.4a: 저널을 갱신한 직후 같은 큐에서 lessons에도 재생한다 — lessons는
    // 이 저널의 파생 뷰일 뿐이다. 실패해도(예: DB 미준비) 위 저널 쓰기·JSON
    // 저장에는 영향이 없다(별개의 큐 작업으로 감싸져 예외가 여기서 끝난다).
    await repo.replayInto(timetableId);
  };
  historyService.mirrorClearSink = (timetableId) async {
    final repo = await ref.read(timetableRepositoryProvider.future);
    await repo.deleteExchangeEventsFor(timetableId);
    await repo.replayInto(timetableId);
  };

  return historyService;
});

/// CircularExchangeService Provider (순환 교체)
final circularExchangeServiceProvider = Provider<CircularExchangeService>((
  ref,
) {
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
final exchangeListVersionProvider =
    StateNotifierProvider<ExchangeListVersionNotifier, int>((ref) {
      return ExchangeListVersionNotifier();
    });

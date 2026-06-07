import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/providers/app_settings_provider.dart';
import 'package:class_exchange_manager/services/app_settings_storage_service.dart';

class FakeChainExchangeSettingsStorage implements ChainExchangeSettingsStorage {
  bool enabled;
  int saveCallCount = 0;

  FakeChainExchangeSettingsStorage({this.enabled = false});

  @override
  Future<bool> getChainExchangeEnabled() async => enabled;

  @override
  Future<bool> saveChainExchangeEnabled(bool value) async {
    saveCallCount++;
    enabled = value;
    return true;
  }
}

void main() {
  group('ChainExchangeEnabledNotifier', () {
    test('setEnabled(true) → 상태 및 저장소 갱신', () async {
      final storage = FakeChainExchangeSettingsStorage(enabled: false);
      final notifier = ChainExchangeEnabledNotifier(
        storageService: storage,
        skipInitialLoad: true,
        initialValue: false,
      );

      final success = await notifier.setEnabled(true);

      expect(success, isTrue);
      expect(notifier.state, isTrue);
      expect(storage.enabled, isTrue);
      expect(storage.saveCallCount, 1);
    });

    test('setEnabled(false) → 상태 및 저장소 갱신', () async {
      final storage = FakeChainExchangeSettingsStorage(enabled: true);
      final notifier = ChainExchangeEnabledNotifier(
        storageService: storage,
        skipInitialLoad: true,
        initialValue: true,
      );

      final success = await notifier.setEnabled(false);

      expect(success, isTrue);
      expect(notifier.state, isFalse);
      expect(storage.enabled, isFalse);
      expect(storage.saveCallCount, 1);
    });

    test('동일 값 저장 시 불필요한 저장 생략', () async {
      final storage = FakeChainExchangeSettingsStorage(enabled: false);
      final notifier = ChainExchangeEnabledNotifier(
        storageService: storage,
        skipInitialLoad: true,
        initialValue: false,
      );

      final success = await notifier.setEnabled(false);

      expect(success, isTrue);
      expect(storage.saveCallCount, 0);
    });
  });
}

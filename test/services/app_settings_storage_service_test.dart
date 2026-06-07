import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/services/app_settings_storage_service.dart';

/// 테스트용 in-memory 저장소
class FakeChainExchangeSettingsStorage implements ChainExchangeSettingsStorage {
  Map<String, dynamic> settings = {};

  @override
  Future<bool> getChainExchangeEnabled() async {
    return settings['chainExchangeEnabled'] as bool? ?? false;
  }

  @override
  Future<bool> saveChainExchangeEnabled(bool enabled) async {
    settings['chainExchangeEnabled'] = enabled;
    return true;
  }
}

void main() {
  group('ChainExchangeSettingsStorage', () {
    test('설정 없음 → 기본값 false', () async {
      final storage = FakeChainExchangeSettingsStorage();

      expect(await storage.getChainExchangeEnabled(), isFalse);
    });

    test('save 후 load → 저장값 반환', () async {
      final storage = FakeChainExchangeSettingsStorage();

      expect(await storage.saveChainExchangeEnabled(true), isTrue);
      expect(await storage.getChainExchangeEnabled(), isTrue);

      expect(await storage.saveChainExchangeEnabled(false), isTrue);
      expect(await storage.getChainExchangeEnabled(), isFalse);
    });

    test('null 값은 false로 처리', () async {
      final storage = FakeChainExchangeSettingsStorage()
        ..settings['chainExchangeEnabled'] = null;

      expect(await storage.getChainExchangeEnabled(), isFalse);
    });
  });
}

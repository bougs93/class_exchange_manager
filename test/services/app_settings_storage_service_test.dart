import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/services/app_settings_storage_service.dart';

/// 테스트용 in-memory 저장소
class FakeDualExchangeSettingsStorage implements DualExchangeSettingsStorage {
  Map<String, dynamic> settings = {};

  @override
  Future<bool> getDualExchangeEnabled() async {
    return settings['dualExchangeEnabled'] as bool? ?? true;
  }

  @override
  Future<bool> saveDualExchangeEnabled(bool enabled) async {
    settings['dualExchangeEnabled'] = enabled;
    return true;
  }
}

void main() {
  group('DualExchangeSettingsStorage', () {
    test('설정 없음 → 기본값 true', () async {
      final storage = FakeDualExchangeSettingsStorage();

      expect(await storage.getDualExchangeEnabled(), isTrue);
    });

    test('save 후 load → 저장값 반환', () async {
      final storage = FakeDualExchangeSettingsStorage();

      expect(await storage.saveDualExchangeEnabled(true), isTrue);
      expect(await storage.getDualExchangeEnabled(), isTrue);

      expect(await storage.saveDualExchangeEnabled(false), isTrue);
      expect(await storage.getDualExchangeEnabled(), isFalse);
    });

    test('null 값은 true로 처리', () async {
      final storage =
          FakeDualExchangeSettingsStorage()
            ..settings['dualExchangeEnabled'] = null;

      expect(await storage.getDualExchangeEnabled(), isTrue);
    });
  });
}

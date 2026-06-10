import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/exchange_mode.dart';
import 'package:class_exchange_manager/services/app_settings_storage_service.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/timetable_grid_constants.dart';

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

/// 화살표 방향 설정 테스트용 in-memory 저장소
///
/// 실제 서비스와 동일하게 JSON 문자열로 저장/로드하며, 키가 없으면 기본값을 반환한다.
class FakeArrowDirectionSettingsStorage implements ArrowDirectionSettingsStorage {
  Map<String, dynamic> settings = {};

  @override
  Future<ArrowDirection> getOneToOneArrowDirection() async {
    return arrowDirectionFromJson(
      settings['oneToOneArrowDirection'] as String?,
      ArrowDirection.bidirectional,
    );
  }

  @override
  Future<bool> saveOneToOneArrowDirection(ArrowDirection direction) async {
    settings['oneToOneArrowDirection'] = arrowDirectionToJson(direction);
    return true;
  }

  @override
  Future<ArrowDirection> getDualArrowDirection() async {
    return arrowDirectionFromJson(
      settings['dualArrowDirection'] as String?,
      ArrowDirection.bidirectional,
    );
  }

  @override
  Future<bool> saveDualArrowDirection(ArrowDirection direction) async {
    settings['dualArrowDirection'] = arrowDirectionToJson(direction);
    return true;
  }
}

/// 마지막 교체 모드 테스트용 in-memory 저장소
class FakeLastExchangeModeStorage implements LastExchangeModeStorage {
  Map<String, dynamic> settings = {};

  @override
  Future<ExchangeMode?> getLastExchangeMode() async {
    return exchangeModeFromJson(settings['lastExchangeMode'] as String?);
  }

  @override
  Future<bool> saveLastExchangeMode(ExchangeMode mode) async {
    if (mode == ExchangeMode.view) {
      return true;
    }
    settings['lastExchangeMode'] = exchangeModeToJson(mode);
    return true;
  }
}

void main() {
  group('AppSettingsDefaults', () {
    test('기타 설정 기본값 상수', () {
      expect(AppSettingsDefaults.languageCode, 'ko');
      expect(AppSettingsDefaults.dualExchangeEnabled, isTrue);
      expect(AppSettingsDefaults.circularExchangeEnabled, isFalse);
      expect(
        AppSettingsDefaults.oneToOneArrowDirection,
        ArrowDirection.bidirectional,
      );
      expect(
        AppSettingsDefaults.dualArrowDirection,
        ArrowDirection.bidirectional,
      );
      expect(AppSettingsDefaults.highlightedTeacherColorArgb, 0xFFE0F2F1);
    });
  });

  group('ExchangeMode JSON 직렬화', () {
    test('toJson / fromJson 라운드트립', () {
      for (final mode in ExchangeMode.values) {
        expect(exchangeModeFromJson(exchangeModeToJson(mode)), mode);
      }
    });

    test('fromJson: null → null (최초 실행)', () {
      expect(exchangeModeFromJson(null), isNull);
    });

    test('fromJson: 알 수 없는 값 → null', () {
      expect(exchangeModeFromJson('invalid_mode'), isNull);
    });
  });

  group('LastExchangeModeStorage', () {
    test('설정 없음 → null', () async {
      final storage = FakeLastExchangeModeStorage();

      expect(await storage.getLastExchangeMode(), isNull);
    });

    test('save 후 load → 저장값 반환', () async {
      final storage = FakeLastExchangeModeStorage();

      expect(
        await storage.saveLastExchangeMode(ExchangeMode.dualExchange),
        isTrue,
      );
      expect(await storage.getLastExchangeMode(), ExchangeMode.dualExchange);
    });

    test('view 모드는 저장하지 않음', () async {
      final storage = FakeLastExchangeModeStorage()
        ..settings['lastExchangeMode'] = exchangeModeToJson(
          ExchangeMode.circularExchange,
        );

      expect(await storage.saveLastExchangeMode(ExchangeMode.view), isTrue);
      expect(
        await storage.getLastExchangeMode(),
        ExchangeMode.circularExchange,
      );
    });
  });

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

  group('ArrowDirection JSON 직렬화', () {
    test('toJson: enum → 문자열', () {
      expect(arrowDirectionToJson(ArrowDirection.forward), 'forward');
      expect(
        arrowDirectionToJson(ArrowDirection.bidirectional),
        'bidirectional',
      );
    });

    test('fromJson: 문자열 → enum', () {
      expect(
        arrowDirectionFromJson('forward', ArrowDirection.bidirectional),
        ArrowDirection.forward,
      );
      expect(
        arrowDirectionFromJson('bidirectional', ArrowDirection.forward),
        ArrowDirection.bidirectional,
      );
    });

    test('fromJson: null(키 없음) → fallback 기본값', () {
      expect(
        arrowDirectionFromJson(null, ArrowDirection.forward),
        ArrowDirection.forward,
      );
      expect(
        arrowDirectionFromJson(null, ArrowDirection.bidirectional),
        ArrowDirection.bidirectional,
      );
    });

    test('fromJson: 알 수 없는 문자열 → fallback 기본값', () {
      expect(
        arrowDirectionFromJson('diagonal', ArrowDirection.forward),
        ArrowDirection.forward,
      );
      expect(
        arrowDirectionFromJson('', ArrowDirection.bidirectional),
        ArrowDirection.bidirectional,
      );
    });
  });

  group('ArrowDirectionSettingsStorage', () {
    test('설정 없음 → 기본값 (1:1·2중 모두 bidirectional)', () async {
      final storage = FakeArrowDirectionSettingsStorage();

      expect(
        await storage.getOneToOneArrowDirection(),
        ArrowDirection.bidirectional,
      );
      expect(
        await storage.getDualArrowDirection(),
        ArrowDirection.bidirectional,
      );
    });

    test('save 후 load → 저장값 반환 (라운드트립)', () async {
      final storage = FakeArrowDirectionSettingsStorage();

      expect(
        await storage.saveOneToOneArrowDirection(ArrowDirection.bidirectional),
        isTrue,
      );
      expect(
        await storage.getOneToOneArrowDirection(),
        ArrowDirection.bidirectional,
      );

      expect(
        await storage.saveDualArrowDirection(ArrowDirection.forward),
        isTrue,
      );
      expect(await storage.getDualArrowDirection(), ArrowDirection.forward);
    });

    test('잘못된 문자열이 저장되어 있으면 기본값으로 fallback', () async {
      final storage =
          FakeArrowDirectionSettingsStorage()
            ..settings['oneToOneArrowDirection'] = 'invalid';

      expect(
        await storage.getOneToOneArrowDirection(),
        ArrowDirection.bidirectional,
      );
    });
  });
}

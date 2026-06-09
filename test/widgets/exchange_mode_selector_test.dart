import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:class_exchange_manager/models/exchange_mode.dart';
import 'package:class_exchange_manager/providers/app_settings_provider.dart';
import 'package:class_exchange_manager/services/app_settings_storage_service.dart';
import 'package:class_exchange_manager/ui/widgets/exchange_control_panel.dart';

class FakeDualExchangeSettingsStorage implements DualExchangeSettingsStorage {
  bool enabled;

  FakeDualExchangeSettingsStorage({this.enabled = true});

  @override
  Future<bool> getDualExchangeEnabled() async => enabled;

  @override
  Future<bool> saveDualExchangeEnabled(bool value) async {
    enabled = value;
    return true;
  }
}

class FakeCircularExchangeSettingsStorage
    implements CircularExchangeSettingsStorage {
  bool enabled;

  FakeCircularExchangeSettingsStorage({this.enabled = false});

  @override
  Future<bool> getCircularExchangeEnabled() async => enabled;

  @override
  Future<bool> saveCircularExchangeEnabled(bool value) async {
    enabled = value;
    return true;
  }
}

Widget _buildSelector({
  required bool dualExchangeEnabled,
  bool circularExchangeEnabled = false,
  ExchangeMode currentMode = ExchangeMode.view,
}) {
  return ProviderScope(
    overrides: [
      dualExchangeEnabledProvider.overrideWith(
        (ref) => DualExchangeEnabledNotifier(
          storageService: FakeDualExchangeSettingsStorage(
            enabled: dualExchangeEnabled,
          ),
          skipInitialLoad: true,
          initialValue: dualExchangeEnabled,
        ),
      ),
      circularExchangeEnabledProvider.overrideWith(
        (ref) => CircularExchangeEnabledNotifier(
          storageService: FakeCircularExchangeSettingsStorage(
            enabled: circularExchangeEnabled,
          ),
          skipInitialLoad: true,
          initialValue: circularExchangeEnabled,
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ExchangeModeSelector(
          currentMode: currentMode,
          onModeChanged: (_) {},
          labelStyle: ExchangeModeLabelStyle.full,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('2중 교체 OFF → 2중교체 버튼 숨김', (tester) async {
    await tester.pumpWidget(
      _buildSelector(
        dualExchangeEnabled: false,
        circularExchangeEnabled: true,
      ),
    );

    expect(find.text('1:1교체'), findsOneWidget);
    expect(find.text('순환교체'), findsOneWidget);
    expect(find.text('보강'), findsOneWidget);
    expect(find.text('2중교체'), findsNothing);
  });

  testWidgets('2중 교체 ON → 2중교체 버튼 표시', (tester) async {
    await tester.pumpWidget(_buildSelector(dualExchangeEnabled: true));

    expect(find.text('2중교체'), findsOneWidget);
  });

  testWidgets('기본값 → 2중교체 ON, 순환교체 OFF', (tester) async {
    await tester.pumpWidget(_buildSelector(dualExchangeEnabled: true));

    expect(find.text('2중교체'), findsOneWidget);
    expect(find.text('순환교체'), findsNothing);
  });
}

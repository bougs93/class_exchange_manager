import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:class_exchange_manager/models/exchange_mode.dart';
import 'package:class_exchange_manager/providers/app_settings_provider.dart';
import 'package:class_exchange_manager/services/app_settings_storage_service.dart';
import 'package:class_exchange_manager/ui/widgets/exchange_control_panel.dart';

class FakeChainExchangeSettingsStorage implements ChainExchangeSettingsStorage {
  bool enabled;

  FakeChainExchangeSettingsStorage({this.enabled = false});

  @override
  Future<bool> getChainExchangeEnabled() async => enabled;

  @override
  Future<bool> saveChainExchangeEnabled(bool value) async {
    enabled = value;
    return true;
  }
}

Widget _buildSelector({
  required bool chainExchangeEnabled,
  ExchangeMode currentMode = ExchangeMode.view,
}) {
  return ProviderScope(
    overrides: [
      chainExchangeEnabledProvider.overrideWith(
        (ref) => ChainExchangeEnabledNotifier(
          storageService: FakeChainExchangeSettingsStorage(
            enabled: chainExchangeEnabled,
          ),
          skipInitialLoad: true,
          initialValue: chainExchangeEnabled,
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
  testWidgets('연쇄 교체 OFF → 연쇄교체 버튼 숨김', (tester) async {
    await tester.pumpWidget(_buildSelector(chainExchangeEnabled: false));

    expect(find.text('1:1교체'), findsOneWidget);
    expect(find.text('순환교체'), findsOneWidget);
    expect(find.text('보강'), findsOneWidget);
    expect(find.text('연쇄교체'), findsNothing);
  });

  testWidgets('연쇄 교체 ON → 연쇄교체 버튼 표시', (tester) async {
    await tester.pumpWidget(_buildSelector(chainExchangeEnabled: true));

    expect(find.text('연쇄교체'), findsOneWidget);
  });
}

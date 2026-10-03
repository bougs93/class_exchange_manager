import 'package:class_exchange_manager/constants/app_assets.dart';
import 'package:class_exchange_manager/constants/login_notice_default.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('login_notice_default.txt 에셋을 읽는다', () async {
    final text = await rootBundle.loadString(AppAssets.loginNoticeDefault);
    expect(text.trim(), isNotEmpty);
    expect(text, contains('베타'));
  });

  test('폴백 상수와 에셋 내용이 같다', () async {
    final asset = (await rootBundle.loadString(AppAssets.loginNoticeDefault))
        .replaceAll('\r\n', '\n')
        .trim();
    final fallback = kLoginNoticeDefaultText.replaceAll('\r\n', '\n').trim();
    expect(asset, fallback);
  });
}

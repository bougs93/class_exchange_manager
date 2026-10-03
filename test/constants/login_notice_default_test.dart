import 'package:class_exchange_manager/constants/login_notice_default.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('기본 안내 문구 상수가 비어 있지 않다', () {
    final text = kLoginNoticeDefaultText.replaceAll('\r\n', '\n').trim();
    expect(text, isNotEmpty);
    expect(text, contains('베타'));
  });
}

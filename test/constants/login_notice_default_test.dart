import 'package:class_exchange_manager/constants/login_notice_default.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('기본 안내 문구 상수가 비어 있지 않다', () {
    final text = kLoginNoticeDefaultText.replaceAll('\r\n', '\n').trim();
    expect(text, isNotEmpty);
    // 표기는 '베타'/'beta' 둘 다 쓰인 적이 있어 한쪽으로 못 박지 않는다
    // (2026-10-03 'beta(테스트)'로 바뀌며 이 단언이 깨졌다).
    expect(text.toLowerCase(), anyOf(contains('베타'), contains('beta')));
  });
}

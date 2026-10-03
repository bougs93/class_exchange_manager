import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/services/web_auth_service.dart';

void main() {
  group('WebAuthService.hashPassword', () {
    test('같은 salt·비밀번호면 같은 해시가 나온다', () {
      expect(
        WebAuthService.hashPassword('1234', 'salt'),
        WebAuthService.hashPassword('1234', 'salt'),
      );
    });

    test('salt가 다르면 해시도 다르다', () {
      expect(
        WebAuthService.hashPassword('1234', 'saltA'),
        isNot(WebAuthService.hashPassword('1234', 'saltB')),
      );
    });

    test('비밀번호가 다르면 해시도 다르다', () {
      expect(
        WebAuthService.hashPassword('1234', 'salt'),
        isNot(WebAuthService.hashPassword('12345', 'salt')),
      );
    });
  });

  group('WebPasswordResult', () {
    // "틀림"과 "확인 불가"를 구분하지 않으면, 접속 흐름의 3초 타임아웃에
    // 걸릴 때마다 맞는 비밀번호에도 "비밀번호가 맞지 않습니다"가 떠서
    // 교사가 비밀번호를 의심하게 된다 (2026-10-03).
    test('틀림과 확인 불가는 서로 다른 값이다', () {
      expect(WebPasswordResult.wrong, isNot(WebPasswordResult.unavailable));
    });

    test('세 가지 상태를 모두 제공한다', () {
      expect(WebPasswordResult.values, hasLength(3));
      expect(
        WebPasswordResult.values,
        containsAll(<WebPasswordResult>[
          WebPasswordResult.ok,
          WebPasswordResult.wrong,
          WebPasswordResult.unavailable,
        ]),
      );
    });
  });
}

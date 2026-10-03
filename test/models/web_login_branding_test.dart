import 'dart:convert';

import 'package:class_exchange_manager/models/web_login_branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebLoginBranding', () {
    test('fromMap은 loginMessage와 신규 필드를 읽는다', () {
      final branding = WebLoginBranding.fromMap({
        'loginMessage': '월계중학교 2026년 2학기 시간표',
        'loginNotice': '선생님 전용입니다.',
        'schoolHomeUrl': 'https://example.sen.ms.kr',
        'schoolLogoUrl': 'https://example.com/logo.png',
        'schoolLogoBase64': base64Encode([1, 2, 3]),
        'schoolLogoUpdatedAt': 123,
      });

      expect(branding.title, '월계중학교 2026년 2학기 시간표');
      expect(branding.notice, '선생님 전용입니다.');
      expect(branding.homeUrl, 'https://example.sen.ms.kr');
      expect(branding.logoUrl, 'https://example.com/logo.png');
      expect(branding.logoBytes, [1, 2, 3]);
      expect(branding.logoUpdatedAt, 123);
      expect(branding.hasLogo, isTrue);
    });

    test('LoginMessage 대문자 키도 제목으로 읽는다', () {
      final branding = WebLoginBranding.fromMap({
        'LoginMessage': '제목',
      });
      expect(branding.title, '제목');
    });

    test('toPublicFields는 저장용 맵을 만든다', () {
      final branding = WebLoginBranding(
        title: '제목',
        notice: '안내',
        homeUrl: 'https://a.example',
        logoUrl: 'https://b.example/l.png',
        logoBase64: 'abc',
        logoUpdatedAt: 9,
      );
      expect(branding.toPublicFields(), {
        'loginMessage': '제목',
        'loginNotice': '안내',
        'schoolHomeUrl': 'https://a.example',
        'schoolLogoUrl': 'https://b.example/l.png',
        'schoolLogoBase64': 'abc',
        'schoolLogoUpdatedAt': 9,
      });
    });
  });
}

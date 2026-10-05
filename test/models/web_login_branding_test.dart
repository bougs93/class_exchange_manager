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
        'guideButtonLabel': '사용 안내',
        'guideButtonUrl': 'https://example.com/guide',
        'schoolLogoUrl': 'https://example.com/logo.png',
        'schoolLogoBase64': base64Encode([1, 2, 3]),
        'schoolLogoUpdatedAt': 123,
      });

      expect(branding.title, '월계중학교 2026년 2학기 시간표');
      expect(branding.notice, '선생님 전용입니다.');
      expect(branding.homeUrl, 'https://example.sen.ms.kr');
      expect(branding.guideButtonLabel, '사용 안내');
      expect(branding.guideButtonUrl, 'https://example.com/guide');
      expect(branding.hasGuideButton, isTrue);
      expect(branding.displayGuideButtonLabel, '사용 안내');
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

    test('사용법 링크가 없으면 버튼을 숨기고, 이름만 비우면 기본값을 쓴다', () {
      const emptyUrl = WebLoginBranding(guideButtonLabel: '매뉴얼');
      expect(emptyUrl.hasGuideButton, isFalse);

      const defaultLabel = WebLoginBranding(
        guideButtonUrl: 'https://example.com/guide',
      );
      expect(defaultLabel.hasGuideButton, isTrue);
      expect(
        defaultLabel.displayGuideButtonLabel,
        WebLoginBranding.defaultGuideButtonLabel,
      );
    });

    test('toPublicFields는 저장용 맵을 만든다', () {
      final branding = WebLoginBranding(
        title: '제목',
        notice: '안내',
        homeUrl: 'https://a.example',
        guideButtonLabel: '사용법',
        guideButtonUrl: 'https://guide.example',
        logoUrl: 'https://b.example/l.png',
        logoBase64: 'abc',
        logoUpdatedAt: 9,
      );
      expect(branding.toPublicFields(), {
        'loginMessage': '제목',
        'loginNotice': '안내',
        'schoolHomeUrl': 'https://a.example',
        'guideButtonLabel': '사용법',
        'guideButtonUrl': 'https://guide.example',
        'schoolLogoUrl': 'https://b.example/l.png',
        'schoolLogoBase64': 'abc',
        'schoolLogoUpdatedAt': 9,
      });
    });
  });
}

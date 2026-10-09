import 'package:class_exchange_manager/models/web_login_branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandingHtml.looksLikeHtml', () {
    test('태그가 있으면 true', () {
      expect(BrandingHtml.looksLikeHtml('<b>제목</b>'), isTrue);
      expect(BrandingHtml.looksLikeHtml('첫줄<br>둘째줄'), isTrue);
    });

    test('일반 텍스트·부등호만 있으면 false', () {
      expect(BrandingHtml.looksLikeHtml('월계중학교 2026년 2학기 시간표'), isFalse);
      expect(BrandingHtml.looksLikeHtml('1 < 2, 3 > 2'), isFalse);
      expect(BrandingHtml.looksLikeHtml(''), isFalse);
    });
  });

  group('BrandingHtml.toHtml', () {
    test('일반 텍스트는 이스케이프 후 줄바꿈을 <br>로 바꾼다', () {
      expect(BrandingHtml.toHtml('첫줄\n둘째줄'), '첫줄<br>둘째줄');
      expect(BrandingHtml.toHtml('1 < 2 & 3 > 2'), '1 &lt; 2 &amp; 3 &gt; 2');
    });

    test('HTML은 그대로 둔다', () {
      const html = '<b>제목</b><br>둘째줄';
      expect(BrandingHtml.toHtml(html), html);
    });

    test('빈 문자열은 빈 문자열', () {
      expect(BrandingHtml.toHtml(''), '');
      expect(BrandingHtml.toHtml('   '), '');
    });
  });

  group('BrandingHtml.stripTags', () {
    test('태그를 걷어 내고 <br>·블록 끝은 줄바꿈으로 바꾼다', () {
      expect(BrandingHtml.stripTags('<b>굵게</b> 보통<br>다음'), '굵게 보통\n다음');
      expect(
        BrandingHtml.stripTags('<div style="text-align: center;">가운데</div>'),
        '가운데',
      );
    });
  });

  group('WebLoginBranding 표시용 HTML', () {
    test('서식 도입 전 일반 텍스트 저장분도 그대로 보인다', () {
      const branding = WebLoginBranding(
        title: '월계중학교 2026년 2학기 시간표',
        notice: '첫줄\n둘째줄',
      );
      expect(branding.displayTitleHtml, '월계중학교 2026년 2학기 시간표');
      expect(branding.displayNoticeHtml, '첫줄<br>둘째줄');
    });

    test('HTML 저장분은 그대로 쓴다', () {
      const branding = WebLoginBranding(
        title: '<b>제목</b>',
        notice: '<span style="color: #D32F2F;">빨강</span>',
      );
      expect(branding.displayTitleHtml, '<b>제목</b>');
      expect(
        branding.displayNoticeHtml,
        '<span style="color: #D32F2F;">빨강</span>',
      );
    });
  });
}

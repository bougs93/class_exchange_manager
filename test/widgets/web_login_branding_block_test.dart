import 'package:class_exchange_manager/models/web_login_branding.dart';
import 'package:class_exchange_manager/ui/widgets/web_login_branding_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('제목 아래에 사용법 버튼이 보인다', (tester) async {
    await tester.pumpWidget(
      wrap(
        const WebLoginBrandingBlock(
          branding: WebLoginBranding(
            title: '월계중학교 2026년 2학기 시간표',
            guideButtonLabel: '사용 안내',
            guideButtonUrl: 'https://example.com/guide',
            notice: '안내 문구',
          ),
        ),
      ),
    );

    expect(
      find.text('월계중학교 2026년 2학기 시간표', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('사용 안내'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.text('안내 문구', findRichText: true), findsOneWidget);
  });

  testWidgets('링크가 없으면 사용법 버튼을 숨긴다', (tester) async {
    await tester.pumpWidget(
      wrap(
        const WebLoginBrandingBlock(
          branding: WebLoginBranding(
            title: '제목',
            guideButtonLabel: '사용법 보기',
            notice: '안내',
          ),
        ),
      ),
    );

    expect(find.text('사용법 보기'), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
  });

  testWidgets('버튼 이름이 비어 있으면 기본값을 쓴다', (tester) async {
    await tester.pumpWidget(
      wrap(
        const WebLoginBrandingBlock(
          branding: WebLoginBranding(
            title: '제목',
            guideButtonUrl: 'https://example.com/guide',
          ),
        ),
      ),
    );

    expect(find.text(WebLoginBranding.defaultGuideButtonLabel), findsOneWidget);
  });

  group('서식 HTML 표시 (박스 없음)', () {
    testWidgets('HTML 서식이 적용돼 보인다', (tester) async {
      await tester.pumpWidget(
        wrap(
          const WebLoginBrandingBlock(
            branding: WebLoginBranding(
              title: '<b>굵은 제목</b>',
              notice: '<span style="color: #D32F2F;">빨강</span>과 <u>밑줄</u>',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('굵은 제목', findRichText: true), findsOneWidget);
      // 인접 서식은 하나의 RichText로 합쳐지므로 부분 일치로 찾는다.
      expect(find.textContaining('빨강', findRichText: true), findsWidgets);
      expect(find.textContaining('밑줄', findRichText: true), findsWidgets);
      // 사각형 박스 장식이 없다 — HtmlWidget 렌더로 바뀐다.
      expect(find.byType(HtmlWidget), findsNWidgets(2));
    });

    testWidgets('서식 도입 전 일반 텍스트도 그대로 보인다', (tester) async {
      await tester.pumpWidget(
        wrap(
          const WebLoginBrandingBlock(
            branding: WebLoginBranding(
              title: '월계중학교 2026년 2학기 시간표',
              notice: '첫줄\n둘째줄',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('월계중학교 2026년 2학기 시간표', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('첫줄', findRichText: true), findsWidgets);
      expect(find.textContaining('둘째줄', findRichText: true), findsWidgets);
    });
  });
}

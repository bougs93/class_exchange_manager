import 'package:class_exchange_manager/models/web_login_branding.dart';
import 'package:class_exchange_manager/ui/widgets/web_login_branding_block.dart';
import 'package:flutter/material.dart';
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

    expect(find.text('월계중학교 2026년 2학기 시간표'), findsOneWidget);
    expect(find.text('사용 안내'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.text('안내 문구'), findsOneWidget);
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

    expect(
      find.text(WebLoginBranding.defaultGuideButtonLabel),
      findsOneWidget,
    );
  });
}

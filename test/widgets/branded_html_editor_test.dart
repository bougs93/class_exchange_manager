import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/ui/screens/web_admin/branded_html_editor.dart';

void main() {
  testWidgets('좁은 화면에서 툴바가 줄바꿈되고 가로 스크롤이 없다', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final html = TextEditingController();
    addTearDown(html.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: BrandedHtmlEditor(controller: html, labelText: '안내'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(QuillSimpleToolbar)).height,
      greaterThan(44),
    );
    expect(
      tester
          .widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar))
          .config
          .multiRowsDisplay,
      isTrue,
    );
    expect(
      tester.getTopLeft(find.byTooltip('정렬')).dx,
      tester.getTopRight(find.byTooltip('글자 크기 줄이기')).dx,
    );
    expect(
      tester.getTopLeft(find.byTooltip('목록 서식')).dx,
      tester.getTopRight(find.byTooltip('정렬')).dx,
    );
    expect(
      tester.getSize(find.byTooltip('정렬')).width,
      tester.getSize(find.byTooltip('목록 서식')).width,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('크기 메뉴 없이 정렬·머릿글·목록을 묶어 표시한다', (tester) async {
    final html = TextEditingController(text: '한 줄');
    addTearDown(html.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: BrandedHtmlEditor(controller: html, labelText: '안내'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('글자 크기 선택'), findsNothing);
    expect(find.byType(QuillToolbarFontSizeButton), findsNothing);
    expect(find.byTooltip('정렬'), findsOneWidget);
    expect(
      find.byType(QuillToolbarSelectHeaderStyleDropdownButton),
      findsOneWidget,
    );
    await tester.tap(find.byType(QuillToolbarSelectHeaderStyleDropdownButton));
    await tester.pumpAndSettle();
    expect(find.text('일반'), findsNWidgets(2));
    expect(find.text('일반 텍스트'), findsNothing);
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('목록 서식'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('번호 목록'));
    await tester.pump();
    final editor =
        tester
            .widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar))
            .controller;
    expect(
      editor.document.toDelta().toJson().last['attributes']['list'],
      'ordered',
    );
    await tester.tap(find.byTooltip('정렬'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가운데 정렬'));
    await tester.pump();
    expect(
      editor.document.toDelta().toJson().last['attributes']['align'],
      'center',
    );
  });

  testWidgets('저장된 br을 다시 편집해도 줄바꿈을 유지한다', (tester) async {
    final html = TextEditingController(text: '<p>첫줄<br>둘째줄</p>');
    addTearDown(html.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: BrandedHtmlEditor(controller: html, labelText: '안내'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor =
        tester
            .widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar))
            .controller;
    expect(editor.document.toPlainText(), '첫줄\u2028둘째줄\n');
    editor.moveCursorToPosition(1);
    await tester.pump();
    expect(html.text, contains('<br>'));
  });

  testWidgets('Enter는 br, Shift+Enter는 문단 줄바꿈으로 저장한다', (tester) async {
    final html = TextEditingController(text: '첫줄');
    addTearDown(html.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: BrandedHtmlEditor(controller: html, labelText: '안내'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor =
        tester
            .widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar))
            .controller;
    editor.moveCursorToPosition(2);
    await tester.tap(find.byType(QuillEditor));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(html.text, contains('<br>'));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(html.text, contains('</p><p>'));
  });

  testWidgets('커서가 위치한 글자의 크기를 숫자 입력칸에 표시한다', (tester) async {
    final html = TextEditingController(
      text:
          '<span style="font-size:24px">큰</span>'
          '<span style="font-size:12px">작은</span>일반',
    );
    addTearDown(html.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: BrandedHtmlEditor(controller: html, labelText: '제목'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor =
        tester
            .widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar))
            .controller;
    editor.updateSelection(
      const TextSelection.collapsed(offset: 1),
      ChangeSource.local,
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '24',
    );

    editor.updateSelection(
      const TextSelection.collapsed(offset: 3),
      ChangeSource.local,
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '12',
    );

    editor.updateSelection(
      const TextSelection.collapsed(offset: 4),
      ChangeSource.local,
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '16',
    );
  });

  testWidgets('숫자로 선택 영역의 글자 크기를 지정해 HTML에 저장한다', (tester) async {
    final html = TextEditingController(text: '학교');
    addTearDown(html.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: BrandedHtmlEditor(controller: html, labelText: '제목'),
        ),
      ),
    );

    final editor =
        tester
            .widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar))
            .controller;
    editor.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 2),
      ChangeSource.local,
    );
    await tester.enterText(find.byType(TextField), '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(
      editor.document.toDelta().toJson().first['attributes']['size'],
      24.0,
    );
    expect(html.text, contains('24'));

    await tester.tap(find.byTooltip('글자 크기 늘리기'));
    await tester.pump();
    expect(
      editor.document.toDelta().toJson().first['attributes']['size'],
      25.0,
    );

    await tester.tap(find.byTooltip('글자 크기 줄이기'));
    await tester.pump();
    expect(
      editor.document.toDelta().toJson().first['attributes']['size'],
      24.0,
    );

    editor.formatSelection(Attribute.fromKeyValue(Attribute.size.key, 'small'));
    await tester.pump();
    await tester.tap(find.byTooltip('글자 크기 늘리기'));
    await tester.pump();
    expect(
      editor.document.toDelta().toJson().first['attributes']['size'],
      11.0,
    );
  });
}

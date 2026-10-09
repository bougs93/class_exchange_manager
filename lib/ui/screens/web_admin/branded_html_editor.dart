import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:quill_delta_html/quill_delta_html.dart';

import '../../../models/web_login_branding.dart';

/// 제목·안내 문구를 한 문서로 편집하고 기존 HTML 저장값과 동기화한다.
class BrandedHtmlEditor extends StatefulWidget {
  const BrandedHtmlEditor({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.minHeight = 150,
    this.enabled = true,
    this.previewAlign = TextAlign.left,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final double minHeight;
  final bool enabled;
  final TextAlign previewAlign;

  @override
  State<BrandedHtmlEditor> createState() => _BrandedHtmlEditorState();
}

class _BrandedHtmlEditorState extends State<BrandedHtmlEditor> {
  final QuillHtmlCodec _codec = QuillHtmlCodec(
    options: const HtmlOptions(wrapDocument: false),
  );
  late final QuillController _editor;
  final TextEditingController _fontSizeController = TextEditingController();
  final FocusNode _fontSizeFocusNode = FocusNode();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _editor = QuillController(
      document: _documentFromHtml(widget.controller.text),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: !widget.enabled,
    )..addListener(_onEditorChanged);
    widget.controller.addListener(_onHtmlChanged);
    _syncFontSize();
  }

  Document _documentFromHtml(String raw) {
    var html = BrandingHtml.toHtml(raw);
    if (widget.previewAlign == TextAlign.center &&
        html.isNotEmpty &&
        !html.contains('text-align')) {
      html = '<div style="text-align:center">$html</div>';
    }
    try {
      return _decode(html);
    } catch (_) {
      return _decode(BrandingHtml.toHtml(BrandingHtml.stripTags(raw)));
    }
  }

  Document _decode(String html) {
    if (html.isEmpty) return Document();
    final delta = _codec.decode(
      html.replaceAll(RegExp(r'<br\b[^>]*>', caseSensitive: false), '&#8232;'),
    );
    if (delta.isEmpty) return Document();
    final last = delta.toList().last.data;
    if (last is! String || !last.endsWith('\n')) delta.insert('\n');
    return Document.fromDelta(delta);
  }

  void _onEditorChanged() {
    if (_loading) return;
    _syncFontSize();
    final html = _codec
        .encode(_editor.document.toDelta())
        .replaceAll('&#8232;', '<br>');
    if (html == widget.controller.text) return;
    _loading = true;
    widget.controller.text = html;
    _loading = false;
  }

  double _selectedFontSize() {
    final size =
        _editor.getSelectionStyle().attributes[Attribute.size.key]?.value;
    return switch (size) {
      'small' => 10,
      'large' => 18,
      'huge' => 22,
      _ => double.tryParse(size?.toString() ?? '') ?? 16,
    };
  }

  void _syncFontSize() {
    if (_fontSizeFocusNode.hasFocus) return;
    final size = _selectedFontSize();
    _fontSizeController.text =
        size == size.truncateToDouble()
            ? size.toInt().toString()
            : size.toString();
  }

  void _applyFontSize(String value) {
    final size = double.tryParse(value);
    if (size != null && size >= 1 && size <= 200) {
      _editor.formatSelection(Attribute.fromKeyValue(Attribute.size.key, size));
    }
    _fontSizeFocusNode.unfocus();
    _syncFontSize();
  }

  void _stepFontSize(int step) {
    final current =
        double.tryParse(_fontSizeController.text) ?? _selectedFontSize();
    _applyFontSize((current + step).clamp(1, 200).toString());
  }

  KeyEventResult _handleEditorKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter)) {
      return KeyEventResult.ignored;
    }
    final selection = _editor.selection;
    _editor.replaceText(
      selection.start,
      selection.end - selection.start,
      HardwareKeyboard.instance.isShiftPressed ? '\n' : '\u2028',
      selection,
    );
    return KeyEventResult.handled;
  }

  void _onHtmlChanged() {
    if (_loading) return;
    _loading = true;
    try {
      _editor.document = _documentFromHtml(widget.controller.text);
    } finally {
      _loading = false;
    }
    _syncFontSize();
  }

  @override
  void didUpdateWidget(BrandedHtmlEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onHtmlChanged);
      widget.controller.addListener(_onHtmlChanged);
      _onHtmlChanged();
    }
    _editor.readOnly = !widget.enabled;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onHtmlChanged);
    _editor.removeListener(_onEditorChanged);
    _editor.dispose();
    _fontSizeController.dispose();
    _fontSizeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.labelText,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (widget.enabled)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 54,
                child: TextField(
                  controller: _fontSizeController,
                  focusNode: _fontSizeFocusNode,
                  style: const TextStyle(fontSize: 12),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: '크기',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: _applyFontSize,
                  onTapOutside: (_) => _applyFontSize(_fontSizeController.text),
                ),
              ),
              SizedBox(
                width: 20,
                height: 32,
                child: Column(
                  children: [
                    Tooltip(
                      message: '글자 크기 늘리기',
                      child: InkWell(
                        onTap: () => _stepFontSize(1),
                        child: const SizedBox(
                          width: 20,
                          height: 16,
                          child: Icon(Icons.keyboard_arrow_up, size: 15),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: '글자 크기 줄이기',
                      child: InkWell(
                        onTap: () => _stepFontSize(-1),
                        child: const SizedBox(
                          width: 20,
                          height: 16,
                          child: Icon(Icons.keyboard_arrow_down, size: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 24,
                height: 32,
                child: PopupMenuButton<Attribute>(
                  tooltip: '정렬',
                  padding: EdgeInsets.zero,
                  onSelected: _editor.formatSelection,
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem(
                          value: Attribute.leftAlignment,
                          child: Text('왼쪽 정렬'),
                        ),
                        PopupMenuItem(
                          value: Attribute.centerAlignment,
                          child: Text('가운데 정렬'),
                        ),
                        PopupMenuItem(
                          value: Attribute.rightAlignment,
                          child: Text('오른쪽 정렬'),
                        ),
                        PopupMenuItem(
                          value: Attribute.justifyAlignment,
                          child: Text('양쪽 정렬'),
                        ),
                      ],
                  child: const Icon(Icons.format_align_left, size: 15),
                ),
              ),
              SizedBox(
                width: 24,
                height: 32,
                child: PopupMenuButton<int>(
                  tooltip: '목록 서식',
                  padding: EdgeInsets.zero,
                  onSelected:
                      (value) => _editor.formatSelection(switch (value) {
                        1 => Attribute.ol,
                        2 => Attribute.ul,
                        _ => Attribute.fromKeyValue(Attribute.ol.key, null),
                      }),
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem(value: 1, child: Text('번호 목록')),
                        PopupMenuItem(value: 2, child: Text('글머리 기호')),
                        PopupMenuItem(value: 0, child: Text('목록 해제')),
                      ],
                  child: const Icon(Icons.format_list_numbered, size: 15),
                ),
              ),
              Expanded(
                child: QuillSimpleToolbar(
                  controller: _editor,
                  config: const QuillSimpleToolbarConfig(
                    toolbarIconAlignment: WrapAlignment.start,
                    multiRowsDisplay: true,
                    toolbarSize: 28,
                    toolbarRunSpacing: 0,
                    toolbarSectionSpacing: 0,
                    buttonOptions: QuillSimpleToolbarButtonOptions(
                      base: QuillToolbarBaseButtonOptions(
                        iconSize: 15,
                        iconButtonFactor: 1.6,
                      ),
                      fontFamily: QuillToolbarFontFamilyButtonOptions(
                        style: TextStyle(fontSize: 12),
                      ),
                      selectHeaderStyleDropdownButton:
                          QuillToolbarSelectHeaderStyleDropdownButtonOptions(
                            textStyle: TextStyle(fontSize: 12),
                            defaultDisplayText: '일반',
                          ),
                    ),
                    showFontSize: false,
                    showDividers: false,
                    showHeaderStyle: true,
                    showInlineCode: false,
                    showBackgroundColorButton: false,
                    showListCheck: false,
                    showListNumbers: false,
                    showListBullets: false,
                    showCodeBlock: false,
                    showQuote: false,
                    showIndent: false,
                    showSearchButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showAlignmentButtons: false,
                  ),
                ),
              ),
            ],
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: QuillEditor.basic(
            controller: _editor,
            config: QuillEditorConfig(
              // ignore: experimental_member_use
              onKeyPressed: (event, _) => _handleEditorKey(event),
              scrollable: false,
              minHeight: widget.minHeight,
              padding: const EdgeInsets.all(12),
              placeholder: widget.hintText,
            ),
          ),
        ),
      ],
    );
  }
}

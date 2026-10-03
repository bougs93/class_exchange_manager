import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../constants/korean_fonts.dart';
import '../../constants/screen_usage_hints.dart';
import '../../models/notice_message.dart';
import '../../providers/notice_message_provider.dart';
import '../../services/class_notice_pdf_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/snackbar_helper.dart';
import '../screens/plan_output/pdf_preview_screen.dart';
import 'content_toolbar_layout.dart';
import 'content_usage_hint_bar.dart';
import 'timetable_grid/grid_header_widgets.dart';

/// 안내 메시지 제어 패널 설정값
class NoticeControlPanelConfig {
  static const double cardPadding = 1.0;
  static const double contentPadding = ContentToolbarLayout.toolbarInset;
  static const double fontSize = 14.0;

  /// 안내 방식 버튼 고정 폭 (질문 / 교체 안내 / 수업 안내)
  static const double messageOptionButtonWidth = 96.0;

  /// 안내 방식 버튼 간격
  static const double messageOptionButtonGap = 4.0;

  /// 학급안내 폰트 드롭다운 폭
  static const double pdfFontDropdownWidth = 128.0;

  /// 선택 인쇄 버튼 폭
  static const double selectPrintButtonWidth = 100.0;

  /// 전체 복사 라벨 버튼 최소 폭 (고정 width면 말줄임되므로 minWidth만 사용)
  static const double copyAllButtonMinWidth = 96.0;

  /// 학급안내 우측(구분선·폰트·드롭다운·선택 인쇄) 예약 폭
  static double get classNoticeRightSideWidth =>
      ContentToolbarLayout.buttonGap +
      1 + // 구분선
      ContentToolbarLayout.buttonGap +
      28 + // '폰트' 라벨 대략 폭
      6 +
      pdfFontDropdownWidth +
      ContentToolbarLayout.buttonGap +
      selectPrintButtonWidth;

  /// 라벨+아이콘 버튼 표시에 필요한 최소 가로 폭
  static double minWidthForFullLabels(int buttonCount) {
    if (buttonCount <= 0) return 0;
    return messageOptionButtonWidth * buttonCount +
        messageOptionButtonGap * (buttonCount - 1);
  }

  /// 전체 복사에 텍스트 라벨을 붙일 수 있는 최소 툴바 폭
  static double minWidthForCopyLabel({
    required int optionButtonCount,
    required bool isClassNotice,
  }) {
    final optionsWidth = minWidthForFullLabels(optionButtonCount);
    final right = isClassNotice ? classNoticeRightSideWidth : 0.0;
    return ContentToolbarLayout.buttonHeight +
        ContentToolbarLayout.buttonGap +
        optionsWidth +
        ContentToolbarLayout.buttonGap +
        copyAllButtonMinWidth +
        right;
  }
}

/// 안내 메시지 제어 패널 위젯
///
/// 새로고침 버튼과 안내 방식 선택 버튼을 포함하는 공통 위젯입니다.
/// - 교사안내: 질문 / 교체 안내 / 수업 안내
/// - 학급안내: 교체 안내 / 수업 안내 + 폰트 선택 + 선택 인쇄
class NoticeControlPanel extends ConsumerWidget {
  /// 메시지 타입 (학급 또는 교사)
  final NoticeMessageType messageType;

  /// 새로고침 버튼 색상 (기본값: 파란색)
  final Color? refreshButtonColor;

  /// 안내 방식 선택 버튼 정의
  static const List<({MessageOption option, IconData icon})>
  _messageOptionButtons = [
    (option: MessageOption.option1, icon: Icons.help_outline),
    (option: MessageOption.option2, icon: Icons.swap_horiz),
    (option: MessageOption.option3, icon: Icons.menu_book_outlined),
  ];

  const NoticeControlPanel({
    super.key,
    required this.messageType,
    this.refreshButtonColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticeState = ref.watch(noticeMessageProvider);
    final noticeNotifier = ref.read(noticeMessageProvider.notifier);
    final currentOption = _getCurrentMessageOption(noticeState);
    final optionButtons = _availableMessageOptionButtons();
    final tokens = context.tokens;
    const buttonHeight = ContentToolbarLayout.buttonHeight;
    final isClassNotice = messageType == NoticeMessageType.classNotice;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(NoticeControlPanelConfig.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContentUsageHintBar(
              message: _usageHintMessage,
              accentColor: refreshButtonColor ?? tokens.primary,
              padded: true,
            ),
            ContentToolbarLayout.hintToToolbarSpacer,
            Padding(
              padding: ContentToolbarLayout.toolbarPadding,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showCopyLabel =
                      constraints.maxWidth >=
                      NoticeControlPanelConfig.minWidthForCopyLabel(
                        optionButtonCount: optionButtons.length,
                        isClassNotice: isClassNotice,
                      );
                  final neutral = _neutralActionColors(tokens);

                  return Row(
                    children: [
                      CompactToolbarIconButton(
                        onPressed:
                            noticeState.isGeneratingPdf
                                ? null
                                : () => noticeNotifier.refreshAllMessages(),
                        icon: Icons.refresh,
                        tooltip: '새로고침',
                        backgroundColor: neutral.background,
                        foregroundColor: neutral.foreground,
                        borderColor: neutral.border,
                        iconSize: ContentToolbarLayout.buttonIconSize,
                        size: buttonHeight,
                      ),
                      const SizedBox(width: ContentToolbarLayout.buttonGap),

                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, optionConstraints) {
                            final showLabels =
                                optionConstraints.maxWidth >=
                                NoticeControlPanelConfig.minWidthForFullLabels(
                                  optionButtons.length,
                                );

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (
                                  int i = 0;
                                  i < optionButtons.length;
                                  i++
                                ) ...[
                                  _buildMessageOptionButton(
                                    option: optionButtons[i].option,
                                    icon: optionButtons[i].icon,
                                    label:
                                        optionButtons[i].option.toolbarLabel,
                                    currentOption: currentOption,
                                    buttonHeight: buttonHeight,
                                    showLabel: showLabels,
                                    tokens: tokens,
                                    onSelected:
                                        (option) => _setMessageOption(
                                          noticeNotifier,
                                          option,
                                        ),
                                  ),
                                  if (i < optionButtons.length - 1)
                                    const SizedBox(
                                      width:
                                          NoticeControlPanelConfig
                                              .messageOptionButtonGap,
                                    ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),

                      _buildCopyAllButton(
                        showLabel: showCopyLabel,
                        buttonHeight: buttonHeight,
                        tokens: tokens,
                        enabled: !noticeState.isGeneratingPdf,
                        onPressed:
                            () => _copyAllMessages(context, noticeState),
                      ),

                      if (isClassNotice) ...[
                        const SizedBox(width: ContentToolbarLayout.buttonGap),
                        Container(
                          width: 1,
                          height: buttonHeight * 0.7,
                          color: tokens.cardBorder,
                        ),
                        const SizedBox(width: ContentToolbarLayout.buttonGap),
                        Text(
                          '폰트',
                          style: TextStyle(
                            fontSize: ContentToolbarLayout.buttonFontSize,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: NoticeControlPanelConfig.pdfFontDropdownWidth,
                          height: buttonHeight,
                          child: _buildPdfFontDropdown(
                            tokens: tokens,
                            selectedFont: noticeState.effectivePdfFont,
                            enabled: !noticeState.isGeneratingPdf,
                            onChanged: noticeNotifier.setSelectedPdfFont,
                          ),
                        ),
                        const SizedBox(width: ContentToolbarLayout.buttonGap),
                        CompactToolbarLabelButton(
                          onPressed:
                              noticeState.isGeneratingPdf
                                  ? null
                                  : () => _printSelectedClassNotices(
                                    context,
                                    ref,
                                  ),
                          icon:
                              noticeState.isGeneratingPdf
                                  ? Icons.hourglass_top
                                  : Icons.print,
                          label: '선택 인쇄',
                          tooltip: '선택한 학급 안내 PDF 미리보기',
                          backgroundColor: neutral.background,
                          foregroundColor: neutral.foreground,
                          borderColor: neutral.border,
                          width:
                              NoticeControlPanelConfig.selectPrintButtonWidth,
                          height: buttonHeight,
                          fontSize: ContentToolbarLayout.buttonFontSize,
                          iconSize: ContentToolbarLayout.buttonIconSize,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfFontDropdown({
    required DesignTokens tokens,
    required String selectedFont,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) {
    final items = KoreanFontConstants.platformFontListWithNames;
    final value =
        items.any((f) => f['file'] == selectedFont)
            ? selectedFont
            : KoreanFontConstants.platformDefaultFont;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(6),
        color: tokens.sectionBackground,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: TextStyle(color: tokens.textPrimary, fontSize: 12),
          items:
              items
                  .map(
                    (font) => DropdownMenuItem(
                      value: font['file']!,
                      child: Text(
                        font['name']!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged:
              enabled
                  ? (newFont) {
                    if (newFont != null) onChanged(newFont);
                  }
                  : null,
        ),
      ),
    );
  }

  /// 메시지 타입별 사용 안내 문구
  String get _usageHintMessage =>
      messageType == NoticeMessageType.classNotice
          ? ScreenUsageHints.classNotice
          : ScreenUsageHints.teacherNotice;

  /// 메시지 타입별 표시할 안내 방식 버튼 (학급안내는 질문 제외)
  List<({MessageOption option, IconData icon})>
  _availableMessageOptionButtons() {
    if (messageType == NoticeMessageType.classNotice) {
      return _messageOptionButtons
          .where((item) => item.option != MessageOption.option1)
          .toList(growable: false);
    }
    return _messageOptionButtons;
  }

  /// 전체 복사 — 폭이 충분하면 라벨 표시
  Widget _buildCopyAllButton({
    required bool showLabel,
    required double buttonHeight,
    required DesignTokens tokens,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final neutral = _neutralActionColors(tokens);
    final action = enabled ? onPressed : null;

    if (!showLabel) {
      return CompactToolbarIconButton(
        onPressed: action,
        icon: Icons.copy,
        tooltip: '전체 복사',
        backgroundColor: neutral.background,
        foregroundColor: neutral.foreground,
        borderColor: neutral.border,
        iconSize: ContentToolbarLayout.buttonIconSize,
        size: buttonHeight,
      );
    }

    return CompactToolbarLabelButton(
      onPressed: action,
      icon: Icons.copy,
      label: '전체 복사',
      tooltip: '전체 복사',
      backgroundColor: neutral.background,
      foregroundColor: neutral.foreground,
      borderColor: neutral.border,
      minWidth: NoticeControlPanelConfig.copyAllButtonMinWidth,
      height: buttonHeight,
      fontSize: ContentToolbarLayout.buttonFontSize,
      iconSize: ContentToolbarLayout.buttonIconSize,
    );
  }

  /// 안내 방식 선택 버튼 (교체 화면 CompactToolbar 스타일)
  Widget _buildMessageOptionButton({
    required MessageOption option,
    required IconData icon,
    required String label,
    required MessageOption currentOption,
    required double buttonHeight,
    required bool showLabel,
    required DesignTokens tokens,
    required ValueChanged<MessageOption> onSelected,
  }) {
    final isSelected = currentOption == option;
    final selectedColors = _refreshColors(tokens);
    final backgroundColor =
        isSelected ? selectedColors.background : tokens.sectionBackground;
    final foregroundColor =
        isSelected ? selectedColors.foreground : tokens.textSecondary;
    final borderColor = isSelected ? selectedColors.border : tokens.cardBorder;

    if (!showLabel) {
      return CompactToolbarIconButton(
        onPressed: () => onSelected(option),
        icon: icon,
        tooltip: label,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        borderColor: borderColor,
        iconSize: ContentToolbarLayout.buttonIconSize,
        size: buttonHeight,
      );
    }

    return CompactToolbarLabelButton(
      onPressed: () => onSelected(option),
      icon: icon,
      label: label,
      tooltip: label,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor,
      width: NoticeControlPanelConfig.messageOptionButtonWidth,
      height: buttonHeight,
      fontSize: ContentToolbarLayout.buttonFontSize,
      iconSize: ContentToolbarLayout.buttonIconSize,
    );
  }

  ({Color background, Color foreground, Color border}) _neutralActionColors(
    DesignTokens tokens,
  ) {
    return (
      background: ContentToolbarLayout.neutralButtonBackground(tokens),
      foreground: ContentToolbarLayout.neutralButtonForeground(tokens),
      border: ContentToolbarLayout.neutralButtonBorder(tokens),
    );
  }

  ({Color background, Color foreground, Color border}) _refreshColors(
    DesignTokens tokens,
  ) {
    final color = refreshButtonColor;
    if (color == Colors.green) {
      return (
        background: Colors.green.shade100,
        foreground: Colors.green.shade700,
        border: Colors.green.shade300,
      );
    }
    if (color == Colors.orange.shade600) {
      return (
        background: Colors.orange.shade100,
        foreground: Colors.orange.shade600,
        border: Colors.orange.shade300,
      );
    }
    return (
      background: tokens.primary.withValues(alpha: 0.2),
      foreground: tokens.primary,
      border: tokens.cardBorder,
    );
  }

  MessageOption _getCurrentMessageOption(NoticeMessageState noticeState) {
    final option =
        messageType == NoticeMessageType.classNotice
            ? noticeState.classMessageOption
            : noticeState.teacherMessageOption;

    if (messageType == NoticeMessageType.classNotice &&
        option == MessageOption.option1) {
      return MessageOption.option2;
    }
    return option;
  }

  void _setMessageOption(
    NoticeMessageNotifier noticeNotifier,
    MessageOption option,
  ) =>
      messageType == NoticeMessageType.classNotice
          ? noticeNotifier.setClassMessageOption(option)
          : noticeNotifier.setTeacherMessageOption(option);

  Future<void> _copyAllMessages(
    BuildContext context,
    NoticeMessageState noticeState,
  ) async {
    try {
      final messageGroups =
          messageType == NoticeMessageType.classNotice
              ? noticeState.classMessageGroups
              : noticeState.teacherMessageGroups;

      if (messageGroups.isEmpty) {
        if (context.mounted) {
          SnackBarHelper.showWarning(context, '복사할 메시지가 없습니다.');
        }
        return;
      }

      final buffer = StringBuffer();
      for (int i = 0; i < messageGroups.length; i++) {
        final group = messageGroups[i];
        buffer.write(group.combinedContent);
        if (i < messageGroups.length - 1) {
          buffer.write('\n\n');
        }
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (context.mounted) {
        SnackBarHelper.showSuccess(
          context,
          '${messageGroups.length}개의 메시지가 클립보드에 복사되었습니다.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.showError(context, '복사 중 오류가 발생했습니다: $e');
      }
    }
  }

  /// 선택한 학급 안내 → PDF 생성 → 미리보기
  Future<void> _printSelectedClassNotices(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final noticeNotifier = ref.read(noticeMessageProvider.notifier);
    noticeNotifier.ensurePdfFontInitialized();

    final selectedGroups = noticeNotifier.selectedClassMessageGroups;
    if (selectedGroups.isEmpty) {
      if (context.mounted) {
        SnackBarHelper.showWarning(context, '인쇄할 학급을 선택하세요.');
      }
      return;
    }

    final noticeState = ref.read(noticeMessageProvider);
    final messageOption =
        noticeState.classMessageOption == MessageOption.option1
            ? MessageOption.option2
            : noticeState.classMessageOption;
    final fontType = noticeState.effectivePdfFont;

    noticeNotifier.setGeneratingPdf(true);
    try {
      final pdfBytes = await ClassNoticePdfService.generate(
        groups: selectedGroups,
        messageOption: messageOption,
        fontType: fontType,
      );

      if (!context.mounted) return;

      if (pdfBytes == null) {
        SnackBarHelper.showError(context, 'PDF 미리보기 생성에 실패했습니다.');
        return;
      }

      final fileName = ClassNoticePdfService.buildFileName();

      if (kIsWeb) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => PdfPreviewScreen(
                  pdfBytes: pdfBytes,
                  initialFileName: fileName,
                ),
          ),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}${Platform.pathSeparator}class_notice_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(tempPath);
      await file.writeAsBytes(pdfBytes, flush: true);

      if (!context.mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => PdfPreviewScreen(
                pdfPath: tempPath,
                initialFileName: fileName,
              ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.showError(context, 'PDF 생성 중 오류가 발생했습니다: $e');
      }
    } finally {
      noticeNotifier.setGeneratingPdf(false);
    }
  }
}

/// 안내 메시지 타입 열거형
enum NoticeMessageType {
  /// 학급안내
  classNotice,

  /// 교사안내
  teacherNotice,
}

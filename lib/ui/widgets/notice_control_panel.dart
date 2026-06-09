import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/screen_usage_hints.dart';
import '../../models/notice_message.dart';
import '../../providers/notice_message_provider.dart';
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

  /// 라벨+아이콘 버튼 표시에 필요한 최소 가로 폭
  static double minWidthForFullLabels(int buttonCount) {
    if (buttonCount <= 0) return 0;
    return messageOptionButtonWidth * buttonCount +
        messageOptionButtonGap * (buttonCount - 1);
  }
}

/// 안내 메시지 제어 패널 위젯
///
/// 새로고침 버튼과 안내 방식 선택 버튼을 포함하는 공통 위젯입니다.
/// - 교사안내: 질문 / 교체 안내 / 수업 안내
/// - 학급안내: 교체 안내 / 수업 안내 (질문 미지원)
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
    const buttonHeight = ContentToolbarLayout.buttonHeight;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(NoticeControlPanelConfig.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContentUsageHintBar(
              message: _usageHintMessage,
              accentColor: refreshButtonColor ?? Colors.blue,
              padded: true,
            ),
            ContentToolbarLayout.hintToToolbarSpacer,
            Padding(
              padding: ContentToolbarLayout.toolbarPadding,
              child: Row(
                children: [
                  // 새로고침 — 중립 스타일 (선택된 안내 방식 버튼과 구분)
                  CompactToolbarIconButton(
                    onPressed: () => noticeNotifier.refreshAllMessages(),
                    icon: Icons.refresh,
                    tooltip: '새로고침',
                    backgroundColor: _neutralActionColors.background,
                    foregroundColor: _neutralActionColors.foreground,
                    borderColor: _neutralActionColors.border,
                    iconSize: ContentToolbarLayout.buttonIconSize,
                    size: buttonHeight,
                  ),
                  const SizedBox(width: ContentToolbarLayout.buttonGap),

                  // 공간 부족 시 아이콘만, 충분하면 고정 폭 라벨 버튼
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final showLabels =
                            constraints.maxWidth >=
                            NoticeControlPanelConfig.minWidthForFullLabels(
                              optionButtons.length,
                            );

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < optionButtons.length; i++) ...[
                              _buildMessageOptionButton(
                                option: optionButtons[i].option,
                                icon: optionButtons[i].icon,
                                label: optionButtons[i].option.toolbarLabel,
                                currentOption: currentOption,
                                buttonHeight: buttonHeight,
                                showLabel: showLabels,
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
                  // 전체 복사 — 중립 스타일 (선택 상태처럼 보이지 않도록)
                  CompactToolbarIconButton(
                    onPressed: () => _copyAllMessages(context, noticeState),
                    icon: Icons.copy,
                    tooltip: '전체 복사',
                    backgroundColor: _neutralActionColors.background,
                    foregroundColor: _neutralActionColors.foreground,
                    borderColor: _neutralActionColors.border,
                    iconSize: ContentToolbarLayout.buttonIconSize,
                    size: buttonHeight,
                  ),
                ],
              ),
            ),
          ],
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

  /// 안내 방식 선택 버튼 (교체 화면 CompactToolbar 스타일)
  Widget _buildMessageOptionButton({
    required MessageOption option,
    required IconData icon,
    required String label,
    required MessageOption currentOption,
    required double buttonHeight,
    required bool showLabel,
    required ValueChanged<MessageOption> onSelected,
  }) {
    final isSelected = currentOption == option;
    final selectedColors = _refreshColors;
    final backgroundColor =
        isSelected ? selectedColors.background : Colors.grey.shade100;
    final foregroundColor =
        isSelected ? selectedColors.foreground : Colors.grey.shade700;
    final borderColor =
        isSelected ? selectedColors.border : Colors.grey.shade300;

    // 가로 폭 부족: 아이콘만 표시 (Tooltip으로 라벨 제공)
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

  /// 일반 동작 버튼(새로고침·복사) — 문서 툴바와 동일한 중립 색
  ({Color background, Color foreground, Color border})
  get _neutralActionColors => (
    background: ContentToolbarLayout.neutralButtonBackground,
    foreground: ContentToolbarLayout.neutralButtonForeground,
    border: ContentToolbarLayout.neutralButtonBorder,
  );

  /// 선택된 안내 방식 버튼 강조 색 (탭별 주황·초록 등)
  ({Color background, Color foreground, Color border}) get _refreshColors {
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
      background: Colors.blue.shade100,
      foreground: Colors.blue.shade700,
      border: Colors.blue.shade300,
    );
  }

  /// 현재 메시지 옵션 가져오기
  MessageOption _getCurrentMessageOption(NoticeMessageState noticeState) {
    final option =
        messageType == NoticeMessageType.classNotice
            ? noticeState.classMessageOption
            : noticeState.teacherMessageOption;

    // 학급안내는 질문(option1) 미지원 — 표시/선택 상태도 교체 안내로 맞춤
    if (messageType == NoticeMessageType.classNotice &&
        option == MessageOption.option1) {
      return MessageOption.option2;
    }
    return option;
  }

  /// 메시지 옵션 설정하기
  void _setMessageOption(
    NoticeMessageNotifier noticeNotifier,
    MessageOption option,
  ) =>
      messageType == NoticeMessageType.classNotice
          ? noticeNotifier.setClassMessageOption(option)
          : noticeNotifier.setTeacherMessageOption(option);

  /// 전체 메시지를 클립보드에 복사
  Future<void> _copyAllMessages(
    BuildContext context,
    NoticeMessageState noticeState,
  ) async {
    try {
      // 메시지 타입에 따라 메시지 그룹 선택
      final messageGroups =
          messageType == NoticeMessageType.classNotice
              ? noticeState.classMessageGroups
              : noticeState.teacherMessageGroups;

      if (messageGroups.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('복사할 메시지가 없습니다.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 모든 메시지를 하나의 문자열로 합치기 (개별 복사와 동일하게 본문만)
      final buffer = StringBuffer();
      for (int i = 0; i < messageGroups.length; i++) {
        final group = messageGroups[i];
        buffer.write(group.combinedContent);
        if (i < messageGroups.length - 1) {
          buffer.write('\n\n');
        }
      }

      // 클립보드에 복사
      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${messageGroups.length}개의 메시지가 클립보드에 복사되었습니다.'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('복사 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

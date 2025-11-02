import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notice_message.dart';
import '../../providers/notice_message_provider.dart';

/// 안내 메시지 제어 패널 설정값
class NoticeControlPanelConfig {
  static const double cardPadding = 1.0;
  static const double contentPadding = 5.0;
  static const double iconSize = 20.0;
  static const double switchScale = 0.7;
  static const double horizontalSpacing = 12.0;
  static const double fontSize = 14.0;
}

/// 안내 메시지 제어 패널 위젯
///
/// 새로고침 버튼과 "수업으로 안내" 스위치를 포함하는 공통 위젯입니다.
/// 학급안내와 교사안내에서 재사용됩니다.
class NoticeControlPanel extends ConsumerWidget {
  /// 메시지 타입 (학급 또는 교사)
  final NoticeMessageType messageType;
  
  /// 새로고침 버튼 색상 (기본값: 파란색)
  final Color? refreshButtonColor;

  const NoticeControlPanel({
    super.key,
    required this.messageType,
    this.refreshButtonColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticeState = ref.watch(noticeMessageProvider);
    final noticeNotifier = ref.read(noticeMessageProvider.notifier);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(NoticeControlPanelConfig.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(NoticeControlPanelConfig.contentPadding),
              child: Row(
                children: [
                  // 새로고침 버튼 (아이콘만)
                  IconButton(
                    onPressed: () => noticeNotifier.refreshAllMessages(),
                    icon: const Icon(Icons.refresh, size: NoticeControlPanelConfig.iconSize),
                    tooltip: '새로고침',
                    style: IconButton.styleFrom(
                      backgroundColor: (refreshButtonColor ?? Colors.blue.shade600).withValues(alpha: 0.1),
                      foregroundColor: refreshButtonColor ?? Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: NoticeControlPanelConfig.horizontalSpacing),

                  // 스위치 옵션
                  Transform.scale(
                    scale: NoticeControlPanelConfig.switchScale,
                    child: Switch(
                      value: _getCurrentMessageOption(noticeState) == MessageOption.option2,
                      onChanged: (value) {
                        _setMessageOption(noticeNotifier, value ? MessageOption.option2 : MessageOption.option1);
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeThumbColor: Colors.blue.shade600,
                      activeTrackColor: Colors.blue.shade200,
                      inactiveThumbColor: Colors.grey.shade400,
                      inactiveTrackColor: Colors.grey.shade300,
                    ),
                  ),
                  Text(
                    '수업으로 안내',
                    style: TextStyle(
                      fontSize: NoticeControlPanelConfig.fontSize,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  // 전체 복사 버튼 (오른쪽)
                  IconButton(
                    onPressed: () => _copyAllMessages(context, noticeState),
                    icon: const Icon(Icons.copy, size: NoticeControlPanelConfig.iconSize),
                    tooltip: '전체 복사',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 현재 메시지 옵션 가져오기
  MessageOption _getCurrentMessageOption(NoticeMessageState noticeState) =>
      messageType == NoticeMessageType.classNotice
          ? noticeState.classMessageOption
          : noticeState.teacherMessageOption;

  /// 메시지 옵션 설정하기
  void _setMessageOption(NoticeMessageNotifier noticeNotifier, MessageOption option) =>
      messageType == NoticeMessageType.classNotice
          ? noticeNotifier.setClassMessageOption(option)
          : noticeNotifier.setTeacherMessageOption(option);

  /// 전체 메시지를 클립보드에 복사
  Future<void> _copyAllMessages(BuildContext context, NoticeMessageState noticeState) async {
    try {
      // 메시지 타입에 따라 메시지 그룹 선택
      final messageGroups = messageType == NoticeMessageType.classNotice
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

      // 모든 메시지를 하나의 문자열로 합치기
      final buffer = StringBuffer();
      for (int i = 0; i < messageGroups.length; i++) {
        final group = messageGroups[i];
        buffer.write('${group.groupIdentifier}: ');
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

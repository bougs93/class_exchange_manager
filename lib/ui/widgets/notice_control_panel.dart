import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notice_message.dart';
import '../../providers/notice_message_provider.dart';

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
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  // 새로고침 버튼
                  ElevatedButton.icon(
                    onPressed: () => noticeNotifier.refreshAllMessages(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('새로고침'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: refreshButtonColor ?? Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // 스위치 옵션
                  Transform.scale(
                    scale: 0.7,
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
                      fontSize: 14,
                      color: Colors.grey.shade700,
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
  MessageOption _getCurrentMessageOption(NoticeMessageState noticeState) {
    switch (messageType) {
      case NoticeMessageType.classNotice:
        return noticeState.classMessageOption;
      case NoticeMessageType.teacherNotice:
        return noticeState.teacherMessageOption;
    }
  }

  /// 메시지 옵션 설정하기
  void _setMessageOption(NoticeMessageNotifier noticeNotifier, MessageOption option) {
    switch (messageType) {
      case NoticeMessageType.classNotice:
        noticeNotifier.setClassMessageOption(option);
        break;
      case NoticeMessageType.teacherNotice:
        noticeNotifier.setTeacherMessageOption(option);
        break;
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

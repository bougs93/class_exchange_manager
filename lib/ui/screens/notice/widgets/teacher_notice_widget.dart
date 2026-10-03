import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/notice_message_provider.dart';
import '../../../widgets/notice_message_card.dart';
import '../../../widgets/notice_control_panel.dart';

/// 교사안내 위젯
///
/// 교사별로 그룹화된 교체 안내 메시지를 표시합니다.
/// 라디오 버튼으로 메시지 옵션(옵션1/옵션2)을 선택할 수 있습니다.
class TeacherNoticeWidget extends ConsumerStatefulWidget {
  const TeacherNoticeWidget({super.key});

  @override
  ConsumerState<TeacherNoticeWidget> createState() =>
      _TeacherNoticeWidgetState();
}

class _TeacherNoticeWidgetState extends ConsumerState<TeacherNoticeWidget> {
  @override
  void initState() {
    super.initState();
    // 위젯 초기화 시 메시지 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(noticeMessageProvider.notifier).refreshAllMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final noticeState = ref.watch(noticeMessageProvider);

    return Container(
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 공통 제어 패널 사용 (오렌지 색상)
          NoticeControlPanel(
            messageType: NoticeMessageType.teacherNotice,
            refreshButtonColor: Colors.orange.shade600,
          ),

          // 메시지 카드 리스트
          Expanded(child: _buildMessageList(noticeState)),
        ],
      ),
    );
  }

  /// 메시지 리스트 위젯 생성
  Widget _buildMessageList(NoticeMessageState noticeState) {
    if (noticeState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (noticeState.errorMessage != null) {
      return _buildErrorState(noticeState.errorMessage!);
    }

    if (noticeState.teacherMessageGroups.isEmpty) {
      return const NoticeMessageCardList(
        messageGroups: [],
        emptyMessage: '교사별 교체 안내 메시지가 없습니다.',
        emptyIcon: Icons.person_outline,
      );
    }

    return NoticeMessageCardList(
      messageGroups: noticeState.teacherMessageGroups,
      cardColor: Colors.orange.shade50,
    );
  }

  /// 에러 상태 위젯 생성
  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            '오류가 발생했습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage,
              style: TextStyle(fontSize: 14, color: Colors.red.shade500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(noticeMessageProvider.notifier).refreshAllMessages();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 교사안내 통계 위젯
///
/// 교사별 메시지 통계를 표시하는 위젯입니다.

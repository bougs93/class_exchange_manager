import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/notice_message_provider.dart';
import '../../../widgets/notice_message_card.dart';
import '../../../widgets/notice_control_panel.dart';

/// 학급안내 위젯
///
/// 학급별로 그룹화된 교체 안내 메시지를 표시합니다.
/// 라디오 버튼으로 메시지 옵션(옵션1/옵션2)을 선택할 수 있습니다.
class ClassNoticeWidget extends ConsumerStatefulWidget {
  const ClassNoticeWidget({super.key});

  @override
  ConsumerState<ClassNoticeWidget> createState() => _ClassNoticeWidgetState();
}

class _ClassNoticeWidgetState extends ConsumerState<ClassNoticeWidget> {
  @override
  void initState() {
    super.initState();
    // 위젯 초기화 시 메시지 새로고침 + PDF 폰트 초기값
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(noticeMessageProvider.notifier);
      notifier.ensurePdfFontInitialized();
      notifier.refreshAllMessages();
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
          // 공통 제어 패널 사용 (학급안내 탭 색상과 동일)
          NoticeControlPanel(
            messageType: NoticeMessageType.classNotice,
            refreshButtonColor: Colors.green,
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

    if (noticeState.classMessageGroups.isEmpty) {
      return const NoticeMessageCardList(
        messageGroups: [],
        emptyMessage: '학급별 교체 안내 메시지가 없습니다.',
        emptyIcon: Icons.class_outlined,
      );
    }

    return NoticeMessageCardList(
      messageGroups: noticeState.classMessageGroups,
      cardColor: Colors.green.shade50,
      showCheckbox: true,
      selectedIdentifiers: noticeState.selectedClassIdentifiers,
      onSelectionChanged: (identifier, selected) {
        ref
            .read(noticeMessageProvider.notifier)
            .setClassSelected(identifier, selected);
      },
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

/// 학급안내 통계 위젯
///
/// 학급별 메시지 통계를 표시하는 위젯입니다.

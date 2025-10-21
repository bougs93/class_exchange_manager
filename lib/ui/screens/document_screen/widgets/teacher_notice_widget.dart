import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/notice_message.dart';
import '../../../../providers/notice_message_provider.dart';
import '../../../widgets/notice_message_card.dart';

/// 교사안내 위젯
/// 
/// 교사별로 그룹화된 교체 안내 메시지를 표시합니다.
/// 라디오 버튼으로 메시지 옵션(옵션1/옵션2)을 선택할 수 있습니다.
class TeacherNoticeWidget extends ConsumerStatefulWidget {
  const TeacherNoticeWidget({super.key});

  @override
  ConsumerState<TeacherNoticeWidget> createState() => _TeacherNoticeWidgetState();
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
    final noticeNotifier = ref.read(noticeMessageProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 메시지 옵션 선택 (새로고침 버튼 포함)
          _buildMessageOptionSelector(noticeState, noticeNotifier),
          
          // 메시지 카드 리스트
          Expanded(
            child: _buildMessageList(noticeState),
          ),
        ],
      ),
    );
  }


  /// 메시지 옵션 선택 위젯 생성 (새로고침 버튼 포함)
  Widget _buildMessageOptionSelector(
    NoticeMessageState noticeState,
    NoticeMessageNotifier noticeNotifier,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                children: [
                  // 새로고침 버튼과 라디오 버튼 옵션을 한 줄에 배치
                  Row(
                    children: [
                      // 새로고침 버튼 (원형 아이콘) - 오렌지 색상 유지
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => noticeNotifier.refreshAllMessages(),
                          icon: Icon(
                            Icons.refresh,
                            size: 18,
                            color: Colors.orange.shade700,
                          ),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // 라디오 버튼 옵션
                      Expanded(
                        child: RadioGroup<MessageOption>(
                          groupValue: noticeState.teacherMessageOption,
                          onChanged: (value) {
                            if (value != null) {
                              noticeNotifier.setTeacherMessageOption(value);
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioListTile<MessageOption>(
                                  title: const Text('화살표로 안내'),
                                  // subtitle: const Text('교체 형태로 표시'),
                                  value: MessageOption.option1,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                  dense: true,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<MessageOption>(
                                  title: const Text('수업으로 안내 '),
                                  // subtitle: const Text('교체된 수업 형태로 표시'),
                                  value: MessageOption.option2,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 메시지 리스트 위젯 생성
  Widget _buildMessageList(NoticeMessageState noticeState) {
    if (noticeState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade500,
              ),
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
class TeacherNoticeStatsWidget extends ConsumerWidget {
  const TeacherNoticeStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticeState = ref.watch(noticeMessageProvider);
    
    if (noticeState.teacherMessageGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    final noticeNotifier = ref.read(noticeMessageProvider.notifier);
    final totalMessages = noticeNotifier.totalTeacherMessages;
    final exchangeTypeStats = noticeNotifier.teacherExchangeTypeStats;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              color: Colors.orange.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '총 ${noticeState.teacherMessageGroups.length}명 교사, $totalMessages개 메시지',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.orange.shade700,
              ),
            ),
            const Spacer(),
            if (exchangeTypeStats.isNotEmpty) ...[
              ...exchangeTypeStats.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: entry.key == ExchangeType.substitution 
                          ? Colors.blue.shade100 
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.key.displayName} ${entry.value}개',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: entry.key == ExchangeType.substitution 
                            ? Colors.blue.shade800 
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

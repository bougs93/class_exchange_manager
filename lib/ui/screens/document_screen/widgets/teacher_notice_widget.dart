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
          // 새로고침 버튼과 메시지 옵션 선택
          Row(
            children: [
              // 새로고침 버튼 (카드 밖으로 분리) - 오렌지 색상 유지
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
              
              // 메시지 옵션 선택 (새로고침 버튼 제외)
              Expanded(
                child: _buildMessageOptionSelector(noticeState, noticeNotifier),
              ),
            ],
          ),
          
          // 메시지 카드 리스트
          Expanded(
            child: _buildMessageList(noticeState),
          ),
        ],
      ),
    );
  }


  /// 메시지 옵션 선택 위젯 생성 (새로고침 버튼 제외)
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
                  // 스위치 옵션
                  Row(
                    children: [
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: noticeState.teacherMessageOption == MessageOption.option2,
                          onChanged: (value) {
                            noticeNotifier.setTeacherMessageOption(
                              value ? MessageOption.option2 : MessageOption.option1
                            );
                          },
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          activeThumbColor: Colors.blue.shade600,
                          activeTrackColor: Colors.blue.shade200,
                          inactiveThumbColor: Colors.grey.shade400,
                          inactiveTrackColor: Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '수업 안내',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
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

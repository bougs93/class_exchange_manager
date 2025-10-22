import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/notice_message.dart';

/// 안내 메시지 카드 위젯
/// 
/// 학급안내와 교사안내에서 공통으로 사용되는 메시지 카드입니다.
/// 제목, 메시지 내용, 복사 버튼을 포함합니다.
class NoticeMessageCard extends StatelessWidget {
  /// 메시지 그룹
  final NoticeMessageGroup messageGroup;
  
  /// 카드 색상 테마
  final Color? cardColor;
  
  /// 복사 성공 시 표시할 스낵바 메시지
  final String? copySuccessMessage;

  const NoticeMessageCard({
    super.key,
    required this.messageGroup,
    this.cardColor,
    this.copySuccessMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: cardColor ?? _getDefaultCardColor(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (제목 + 복사 버튼)
            _buildHeader(context),
            const SizedBox(height: 4),
            
            // 메시지 내용
            _buildMessageContent(),
          ],
        ),
      ),
    );
  }

  /// 헤더 위젯 생성 (제목 + 교체 유형 + 복사 버튼)
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        // 그룹 식별자 (학급명 또는 교사명)
        Text(
          messageGroup.groupIdentifier,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 교체 유형 칩들 (다중 유형인 경우 개별 칩으로 표시)
        if (messageGroup.messages.isNotEmpty) ...[
          Builder(
            builder: (context) {
              final firstMessage = messageGroup.messages.first;
              if (firstMessage.exchangeTypeCombination != null && 
                  firstMessage.exchangeTypeCombination!.types.length > 1) {
                // 다중 유형: 개별 칩으로 표시
                return Row(
                  children: firstMessage.exchangeTypeCombination!.types.map((type) => 
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _buildSingleExchangeTypeChip(type),
                    )
                  ).toList(),
                );
              } else {
                // 단일 유형: 기존 로직
                return _buildSingleExchangeTypeChip(firstMessage.exchangeType);
              }
            },
          ),
        ],
        
        const Spacer(),
        
        // 복사 버튼
        IconButton(
          onPressed: () => _copyToClipboard(context),
          icon: const Icon(Icons.copy, size: 20),
          tooltip: '클립보드에 복사',
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  /// 메시지 내용 위젯 생성
  Widget _buildMessageContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messageGroup.messages.map((message) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 메시지 내용
                Text(
                  message.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
                
                // 마지막 메시지가 아니면 구분선 추가
                if (message != messageGroup.messages.last) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: Colors.grey.shade300,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 단일 교체 유형 칩 위젯 생성
  Widget _buildSingleExchangeTypeChip(ExchangeType exchangeType) {
    Color chipColor;
    String chipText;
    
    switch (exchangeType) {
      case ExchangeType.substitution:
        chipColor = Colors.blue.shade100;
        chipText = '수업교체';
        break;
      case ExchangeType.supplement:
        chipColor = Colors.orange.shade100;
        chipText = '보강';
        break;
      case ExchangeType.circular:
        chipColor = Colors.purple.shade100;
        chipText = '순환교체';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        chipText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: chipColor == Colors.blue.shade100 
              ? Colors.blue.shade800 
              : chipColor == Colors.orange.shade100 
                  ? Colors.orange.shade800 
                  : Colors.purple.shade800,
        ),
      ),
    );
  }


  /// 클립보드에 복사
  Future<void> _copyToClipboard(BuildContext context) async {
    try {
      // 모든 메시지를 하나의 문자열로 합치기
      final combinedContent = messageGroup.combinedContent;
      
      await Clipboard.setData(ClipboardData(text: combinedContent));
      
      // 성공 메시지 표시
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              copySuccessMessage ?? 
              '${messageGroup.groupIdentifier} 메시지가 클립보드에 복사되었습니다.',
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // 복사 실패 시 에러 메시지 표시
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('복사 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 기본 카드 색상 반환
  Color _getDefaultCardColor() {
    switch (messageGroup.groupType) {
      case GroupType.classGroup:
        return Colors.green.shade50;
      case GroupType.teacherGroup:
        return Colors.orange.shade50;
    }
  }
}

/// 안내 메시지 카드 리스트 위젯
/// 
/// 여러 개의 NoticeMessageCard를 스크롤 가능한 리스트로 표시합니다.
class NoticeMessageCardList extends StatelessWidget {
  /// 메시지 그룹 리스트
  final List<NoticeMessageGroup> messageGroups;
  
  /// 빈 상태일 때 표시할 메시지
  final String emptyMessage;
  
  /// 빈 상태일 때 표시할 아이콘
  final IconData emptyIcon;
  
  /// 카드 색상 테마
  final Color? cardColor;

  const NoticeMessageCardList({
    super.key,
    required this.messageGroups,
    this.emptyMessage = '표시할 메시지가 없습니다.',
    this.emptyIcon = Icons.message_outlined,
    this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    if (messageGroups.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 0),
      itemCount: messageGroups.length,
      itemBuilder: (context, index) {
        final messageGroup = messageGroups[index];
        return NoticeMessageCard(
          messageGroup: messageGroup,
          cardColor: cardColor,
        );
      },
    );
  }

  /// 빈 상태 위젯 생성
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            emptyIcon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '교체를 실행하면 여기에 안내 메시지가 표시됩니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

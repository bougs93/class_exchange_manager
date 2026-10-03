import 'package:flutter/material.dart';

import '../../../../../theme/design_tokens.dart';
import '../../../../widgets/empty_state_message.dart';

/// 결보강 일정 그리드(`ContentInputGrid`)의 로딩 상태 표시 위젯.
class PlanGridLoadingIndicator extends StatelessWidget {
  const PlanGridLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.tokens.cardBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// 결보강 일정 그리드(`ContentInputGrid`)의 빈 상태(교체 기록 없음) 표시 위젯.
class PlanGridEmptyState extends StatelessWidget {
  const PlanGridEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.tokens.cardBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: EmptyStateMessage(
            icon: Icons.description_outlined,
            iconSize: 50,
            message: '교체 기록이 없습니다',
            messageFontSize: 18,
            messageFontWeight: FontWeight.w500,
            subMessage: '교체를 실행하면 여기에 기록이 표시됩니다',
            expand: false,
          ),
        ),
      ),
    );
  }
}

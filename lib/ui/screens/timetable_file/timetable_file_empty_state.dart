import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

/// 시간표 관리 화면의 빈 상태 안내
///
/// 등록된 시간표가 하나도 없을 때 표시됩니다.
class TimetableFileEmptyState extends StatelessWidget {
  const TimetableFileEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.table_chart_outlined, size: 48, color: tokens.textMuted),
          const SizedBox(height: 12),
          Text(
            '등록된 시간표가 없습니다',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '상단의 [시간표 추가] 버튼으로\n엑셀 시간표를 등록하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

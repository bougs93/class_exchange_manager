import 'package:flutter/material.dart';

/// 카드 하단 액션 버튼들 (전환 / 이름 변경 / 삭제)
///
/// 실제 동작(상태 변경·다이얼로그 흐름)은 상위 State가 소유하며,
/// 이 위젯은 콜백을 받아 버튼만 그립니다.
class TimetableCardActions extends StatelessWidget {
  const TimetableCardActions({
    super.key,
    required this.isActive,
    required this.onSwitch,
    required this.onRename,
    required this.onDelete,
  });

  final bool isActive;
  final VoidCallback onSwitch;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!isActive)
          TextButton.icon(
            onPressed: onSwitch,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('전환'),
          ),
        TextButton.icon(
          onPressed: onRename,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('이름 변경'),
        ),
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('삭제'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
      ],
    );
  }
}

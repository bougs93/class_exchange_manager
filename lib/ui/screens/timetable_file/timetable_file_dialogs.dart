import 'package:flutter/material.dart';

import '../../../models/timetable_registry.dart';
import '../../../providers/timetable_summary_provider.dart';

/// 시간표 이름 입력 다이얼로그
///
/// [showCancel]이 true면 취소 버튼을 표시하고 취소 시 null을 반환합니다.
Future<String?> showTimetableNameDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  bool showCancel = true,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '예: 월계중1학기',
            labelText: '시간표 이름',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
          ElevatedButton(
            onPressed:
                () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}

/// 확인 다이얼로그의 "삭제됨 / 유지됨" 한 줄
Widget _confirmLine({
  required IconData icon,
  required Color color,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      SizedBox(
        width: 52,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
    ],
  );
}

/// 원본 내용 변경 확인 다이얼로그
///
/// 무엇이 지워지고 무엇이 남는지 건수로 보여준 뒤에만 진행합니다.
Future<bool?> showConfirmContentChangeDialog(
  BuildContext context,
  TimetableRegistryEntry entry,
  TimetableSummary summary,
) {
  final removed = <String>[
    if (summary.exchangeCount > 0) '교체 ${summary.exchangeCount}건',
    if (summary.planEntryCount > 0) '결보강 입력 ${summary.planEntryCount}건',
  ];

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('시간표 내용이 변경되었습니다')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "'${entry.name}'의 원본 파일 내용이 이전과 다릅니다.\n"
              '기존 교체 결과는 새 시간표와 맞지 않아 초기화해야 합니다.',
            ),
            const SizedBox(height: 14),
            _confirmLine(
              icon: Icons.delete_outline,
              color: Colors.red,
              label: '삭제됨',
              value: removed.isEmpty ? '없음' : removed.join(' · '),
            ),
            const SizedBox(height: 6),
            _confirmLine(
              icon: Icons.check_circle_outline,
              color: Colors.green,
              label: '유지됨',
              value:
                  summary.profileCount > 0
                      ? '계획서 ${summary.profileCount}개'
                      : '없음',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('갱신'),
          ),
        ],
      );
    },
  );
}

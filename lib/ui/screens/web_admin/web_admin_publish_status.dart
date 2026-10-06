import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/timetable_registry_provider.dart';

/// 공용 시간표 올리기 진행·결과 표시.
///
/// 진행 중이면 스피너+메시지를, 끝났으면 성공/실패 배너와 현재 활성
/// 시간표 이름(및 삭제 버튼)을 보여준다. 실제 삭제 동작([onDelete])과
/// 진행 상태는 [WebAdminSettingsScreen]이 `setState`로 관리하고, 이
/// 위젯은 그 값을 그대로 받아 그리기만 한다.
class WebAdminPublishStatus extends ConsumerWidget {
  const WebAdminPublishStatus({
    super.key,
    required this.publishing,
    required this.publishMessage,
    required this.publishResult,
    required this.publishFailed,
    required this.publishedName,
    required this.deleting,
    required this.onDelete,
    this.showDeleteButton = true,
  });

  final bool publishing;
  final String? publishMessage;
  final String? publishResult;
  final bool publishFailed;
  final String? publishedName;
  final bool deleting;
  final VoidCallback? onDelete;

  /// 삭제 버튼 표시 여부 (기본 true).
  ///
  /// 접속 설정 시간표 탭은 삭제를 별도 위험 구역 카드로 분리하므로
  /// false로 둔다 — 같은 화면에 삭제 버튼이 두 개 생기지 않게 한다.
  final bool showDeleteButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeTimetableEntryProvider);
    final activeName = active?.name;
    final currentName =
        (publishedName != null && publishedName!.isNotEmpty)
            ? publishedName!
            : activeName;

    if (publishing) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              publishMessage ?? '공용 시간표를 올리는 중…',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (publishResult != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: publishFailed ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    publishFailed ? Colors.red.shade200 : Colors.green.shade200,
              ),
            ),
            child: Text(
              publishResult!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    publishFailed ? Colors.red.shade700 : Colors.green.shade800,
              ),
            ),
          ),
        if (currentName != null && currentName.isNotEmpty) ...[
          if (publishResult != null) const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '현재 시간표: $currentName',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (active != null && showDeleteButton)
                TextButton(
                  onPressed: deleting ? null : onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(deleting ? '삭제 중…' : '삭제'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

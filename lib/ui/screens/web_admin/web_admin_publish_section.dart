import 'package:flutter/material.dart';

import 'web_admin_publish_status.dart';

/// 공용 시간표 올리기/삭제 섹션.
///
/// `WebAdminSettingsScreen`의 build()에서 분리된 순수 위젯이다. 실제 게시·
/// 삭제 동작(비동기)은 콜백으로 부모에게 넘기고, 이 위젯은 제목·설명과
/// [WebAdminPublishStatus], 게시 버튼만 그린다.
class WebAdminPublishSection extends StatelessWidget {
  const WebAdminPublishSection({
    super.key,
    required this.publishing,
    required this.publishMessage,
    required this.publishResult,
    required this.publishFailed,
    required this.publishedName,
    required this.deleting,
    required this.onDelete,
    required this.onPublish,
  });

  final bool publishing;
  final String? publishMessage;
  final String? publishResult;
  final bool publishFailed;
  final String? publishedName;
  final bool deleting;
  final VoidCallback? onDelete;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '공용 시간표 올리기',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          '엑셀 파일을 고르면 등록부터 서버 게시까지 한 번에 처리합니다. '
          '버전부터 올린 뒤 파일을 전송하므로, 실패해도 접속자는 구버전을 유지합니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        WebAdminPublishStatus(
          publishing: publishing,
          publishMessage: publishMessage,
          publishResult: publishResult,
          publishFailed: publishFailed,
          publishedName: publishedName,
          deleting: deleting,
          onDelete: onDelete,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: publishing ? null : onPublish,
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('공용 시간표 게시'),
          ),
        ),
      ],
    );
  }
}

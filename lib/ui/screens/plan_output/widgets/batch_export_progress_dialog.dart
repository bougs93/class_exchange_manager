import 'package:flutter/material.dart';

/// 일괄 출력 진행 상태
class BatchExportProgress {
  final int done;
  final int total;
  final String fileName;

  const BatchExportProgress({
    required this.done,
    required this.total,
    required this.fileName,
  });

  double get ratio => total == 0 ? 0 : done / total;
}

/// 일괄 출력 진행 다이얼로그
///
/// 건당 수 초가 걸릴 수 있어, 스낵바만 띄우고 블로킹하면 멈춘 것처럼 보입니다.
/// 진행률(n/N)·현재 파일명·[취소]를 제공합니다(문서 §3④).
///
/// [controller]로 진행 상황을 밀어 넣고, [onCancel]로 취소 요청을 받습니다.
class BatchExportProgressDialog extends StatefulWidget {
  const BatchExportProgressDialog({
    super.key,
    required this.initialTotal,
    required this.progressStream,
    required this.onCancel,
  });

  /// 전체 건수 (첫 진행 콜백 전에도 표시하기 위해 필요)
  final int initialTotal;

  /// 진행 상황 스트림
  final Stream<BatchExportProgress> progressStream;

  /// [취소] 클릭 시 호출 — 진행 중인 1건까지만 마치고 중단한다
  final VoidCallback onCancel;

  @override
  State<BatchExportProgressDialog> createState() =>
      _BatchExportProgressDialogState();
}

class _BatchExportProgressDialogState extends State<BatchExportProgressDialog> {
  bool _cancelRequested = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 진행 중 뒤로가기로 닫히면 상태를 알 수 없게 되므로 [취소]로만 중단한다
      canPop: false,
      child: AlertDialog(
        title: const Text('일괄 출력 중…'),
        content: StreamBuilder<BatchExportProgress>(
          stream: widget.progressStream,
          builder: (context, snapshot) {
            final progress = snapshot.data;
            final done = progress?.done ?? 0;
            final total = progress?.total ?? widget.initialTotal;

            return SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('진행률', style: TextStyle(fontSize: 13)),
                      Text(
                        '$done / $total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress?.ratio ?? 0,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    progress?.fileName ?? '준비 중…',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_cancelRequested) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '취소 요청됨 — 진행 중인 1건을 마치고 중단합니다.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: _cancelRequested
                ? null
                : () {
                    setState(() => _cancelRequested = true);
                    widget.onCancel();
                  },
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}

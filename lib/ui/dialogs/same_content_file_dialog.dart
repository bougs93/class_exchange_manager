import 'package:flutter/material.dart';

/// 동일한 내용의 파일 선택 시 표시되는 확인 다이얼로그
/// 
/// 사용자에게 기존 작업 정보를 초기화할지 보존할지 확인합니다.
class SameContentFileDialog extends StatelessWidget {
  /// 표시할 메시지
  final String message;
  
  const SameContentFileDialog({
    super.key,
    this.message = '선택한 전체 교사 시간표 파일이 현재의 내용과 동일합니다.\n\n초기화 하겠습니까?',
  });

  /// 다이얼로그를 표시하고 사용자 선택 결과를 반환합니다.
  /// 
  /// 매개변수:
  /// - `context`: BuildContext
  /// 
  /// 반환값:
  /// - `Future<bool?>`: 사용자 선택 결과
  ///   - `true`: YES (기존 작업 정보 초기화)
  ///   - `false`: NO (기존 작업 정보 보존) - 기본값
  ///   - `null`: 다이얼로그 닫기 (기본값 false로 처리)
  static Future<bool?> show(BuildContext context, {String? message}) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // 외부 터치로 닫기 불가능
      builder: (BuildContext context) {
        return SameContentFileDialog(
          message: message ?? '선택한 교사 시간표 파일이 현재의 시간표와 동일합니다.\n초기화 하겠습니까?',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 뒤로 가기나 ESC 키로 닫을 때 기본값 NO 반환
      // canPop: false로 설정하여 기본 pop 동작을 막고,
      // onPopInvokedWithResult에서 false 값을 반환하도록 처리합니다.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // didPop이 false인 경우 (pop이 시도되었지만 막힌 경우)
        // false 값을 반환하여 기본값 NO 처리
        if (!didPop) {
          Navigator.of(context).pop(false); // 기본값 NO
        }
      },
      child: AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade400,
                    Colors.blue.shade600,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.info_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                '작업 정보 초기화',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'YES: 기존 작업 정보 초기화',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'NO: 기존 작업 정보 보존',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          // NO 버튼 (기존 작업 정보 보존) - 기본값 (ElevatedButton으로 강조)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('NO'),
          ),
          // YES 버튼 (기존 작업 정보 초기화)
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('YES'),
          ),
        ],
      ),
    );
  }
}

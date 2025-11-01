import 'package:flutter/material.dart';

/// 엑셀 파일 변경 감지 시 표시되는 초기화 확인 다이얼로그
/// 
/// 사용자에게 시간표 데이터와 교체 리스트를 초기화할지 확인합니다.
class ExchangeDataResetDialog extends StatelessWidget {
  /// 표시할 메시지
  final String message;
  
  const ExchangeDataResetDialog({
    super.key,
    this.message = '엑셀 파일이 변경되었습니다. 저장된 데이터를 초기화하시겠습니까?',
  });

  /// 다이얼로그를 표시하고 사용자 선택 결과를 반환합니다.
  /// 
  /// 매개변수:
  /// - `context`: BuildContext
  /// 
  /// 반환값:
  /// - `Future<bool?>`: 사용자 선택 결과
  ///   - `true`: 초기화 확인
  ///   - `false`: 초기화 취소
  ///   - `null`: 다이얼로그 닫기 (취소)
  static Future<bool?> show(BuildContext context, {String? message}) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // 외부 터치로 닫기 불가능
      builder: (BuildContext context) {
        return ExchangeDataResetDialog(message: message ?? '엑셀 파일이 변경되었습니다. 저장된 데이터를 초기화하시겠습니까?');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 24),
          SizedBox(width: 8),
          Text('데이터 초기화 확인'),
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
            '초기화하면 다음 데이터가 삭제됩니다:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '• 저장된 시간표 데이터\n• 교체 리스트',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        // 취소 버튼
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        // 초기화 버튼
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('초기화'),
        ),
      ],
    );
  }
}



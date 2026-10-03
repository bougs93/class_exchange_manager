import 'package:flutter/material.dart';
import '../../../../theme/design_tokens.dart';

/// "데이터 초기화" 카드 내용 (제목·설명 + 삭제 버튼)
///
/// [StartSettingsCard]의 `_buildDataResetCardContent`를 그대로 옮긴 순수
/// 표현 위젯이다. 진행 상태·탭 콜백을 매개변수로 받는다.
class DataResetCardContent extends StatelessWidget {
  const DataResetCardContent({
    super.key,
    required this.isResetting,
    required this.onPressed,
    this.stretchHeight = false,
  });

  final bool isResetting;
  final VoidCallback? onPressed;
  final bool stretchHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: stretchHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const Text(
          '데이터 초기화',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '모든 저장된 데이터를 삭제합니다.',
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
        if (stretchHeight) const Spacer() else const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isResetting ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child:
                isResetting
                    ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text('모든 데이터 삭제', style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

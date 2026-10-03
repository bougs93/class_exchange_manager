import 'package:flutter/material.dart';

/// "기본값 복원" 카드 내용 (제목 + 복원 버튼)
///
/// [StartSettingsCard]의 `_buildRestoreDefaultsCardContent`를 그대로 옮긴
/// 순수 표현 위젯이다. 진행 상태·탭 콜백을 매개변수로 받는다.
class RestoreDefaultsCardContent extends StatelessWidget {
  const RestoreDefaultsCardContent({
    super.key,
    required this.isRestoring,
    required this.onPressed,
    this.stretchHeight = false,
  });

  final bool isRestoring;
  final VoidCallback? onPressed;
  final bool stretchHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: stretchHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const Text(
          '기본값 복원',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        if (stretchHeight) const Spacer() else const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isRestoring ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primaryColor,
              side: BorderSide(
                color: theme.primaryColor.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon:
                isRestoring
                    ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryColor,
                        ),
                      ),
                    )
                    : Icon(Icons.restore, size: 18, color: theme.primaryColor),
            label: const Text('기본값 복원', style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../constants/app_info.dart';

/// 사용 기간을 한 줄로 컴팩트하게 표시하는 위젯
///
/// - 제한 없음: `사용 기간 : 제한 없음`
/// - 기한 있음: `사용 기간 : 2027년 2월 28일까지 · 30일 남음`
class UsagePeriodCompactText extends StatelessWidget {
  const UsagePeriodCompactText({super.key, this.fontSize = 12});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: fontSize,
      color: Colors.grey.shade700,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = TextStyle(
      fontSize: fontSize,
      color: Colors.grey.shade800,
      fontWeight: FontWeight.w600,
    );
    final remainingColor = _remainingPeriodColor();

    // 기한이 없으면 한 번만 표시
    if (AppInfo.expiryDate == null) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '사용 기간 : ', style: labelStyle),
            TextSpan(
              text: '제한 없음',
              style: valueStyle.copyWith(color: remainingColor),
            ),
          ],
        ),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '사용 기간 : ', style: labelStyle),
          TextSpan(text: AppInfo.availablePeriodDisplay, style: valueStyle),
          TextSpan(text: ' · ', style: labelStyle),
          TextSpan(
            text: AppInfo.remainingPeriodDisplay,
            style: valueStyle.copyWith(color: remainingColor),
          ),
        ],
      ),
    );
  }

  Color _remainingPeriodColor() {
    switch (AppInfo.remainingPeriodStatus) {
      case RemainingPeriodStatus.unlimited:
      case RemainingPeriodStatus.normal:
        return Colors.green.shade700;
      case RemainingPeriodStatus.expired:
        return Colors.red.shade700;
      case RemainingPeriodStatus.urgent:
        return Colors.orange.shade700;
      case RemainingPeriodStatus.unknown:
        return Colors.grey.shade700;
    }
  }
}

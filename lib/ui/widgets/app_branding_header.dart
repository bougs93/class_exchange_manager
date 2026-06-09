import 'package:flutter/material.dart';

import '../../constants/app_assets.dart';
import '../../constants/app_info.dart';
import 'usage_period_compact_text.dart';

/// 앱 아이콘 + 프로그램명 헤더 (카드 안에 배치 — [AppContentCard]와 함께 사용)
class AppBrandingHeader extends StatelessWidget {
  const AppBrandingHeader({
    super.key,
    this.showVersionAndPeriod = false,
  });

  /// true: 프로그램명 아래 버전·사용 기간 표시 (정보 화면용)
  final bool showVersionAndPeriod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          AppAssets.appIcon,
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: showVersionAndPeriod
              ? _buildTitleWithPeriodInfo(theme)
              : Text(
                  AppInfo.programName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
        ),
      ],
    );
  }

  /// 프로그램명 + 버전·기간 정보 (정보 화면 헤더용)
  Widget _buildTitleWithPeriodInfo(ThemeData theme) {
    const metaFontSize = 12.0;
    final labelStyle = TextStyle(
      fontSize: metaFontSize,
      color: Colors.grey.shade700,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = TextStyle(
      fontSize: metaFontSize,
      color: Colors.grey.shade800,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppInfo.programName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 2,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Version : ', style: labelStyle),
                  TextSpan(text: AppInfo.version, style: valueStyle),
                ],
              ),
            ),
            const UsagePeriodCompactText(fontSize: metaFontSize),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import 'usage_stats_body.dart';

/// 관리자 전용 웹 사용 통계 화면.
///
/// 껍데기(Scaffold + AppBar)만 두고 본문은 [UsageStatsBody]가 그린다.
/// 접속 설정 4탭 개편의 통계 탭에도 같은 본문을 임베드한다.
class UsageStatsScreen extends StatelessWidget {
  const UsageStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용 통계')),
      body: const SafeArea(child: UsageStatsBody()),
    );
  }
}

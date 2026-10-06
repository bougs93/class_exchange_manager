import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/usage_event.dart';
import '../../../providers/web_services_provider.dart';
import '../../../utils/logger.dart';
import '../../../utils/usage_stats_aggregator.dart';
import 'usage_stats_screen.dart';

/// 웹 사용 통계 섹션 (관리자 접속 설정 화면 전용).
///
/// 오늘 접속 수·사용 교사 수 한 줄 요약과 상세 화면 진입 버튼만 둔다.
class WebAdminUsageStatsSection extends ConsumerStatefulWidget {
  const WebAdminUsageStatsSection({super.key});

  @override
  ConsumerState<WebAdminUsageStatsSection> createState() =>
      _WebAdminUsageStatsSectionState();
}

class _WebAdminUsageStatsSectionState
    extends ConsumerState<WebAdminUsageStatsSection> {
  String _summary = '오늘 통계를 불러오는 중…';

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    String text;
    try {
      final today = DateTime.parse(UsageStatsAggregator.todayKstId());
      final days = await ref
          .read(usageStatsServiceProvider)
          .fetchRange(today, today);
      final s = UsageStatsAggregator.aggregate(days, UsagePeriodUnit.day);
      text = '오늘 접속 ${s.count(UsageKeys.visits)}회 · 사용 교사 ${s.activeTeachers}명';
    } catch (e) {
      AppLogger.warning('오늘 사용 통계 조회 실패: $e');
      text = '오늘 통계를 불러오지 못했습니다.';
    }
    if (!mounted) return;
    setState(() => _summary = text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '사용 통계',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _summary,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UsageStatsScreen(),
                ),
              );
              if (mounted) _loadToday();
            },
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('사용 통계 보기'),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/usage_event.dart';
import 'package:class_exchange_manager/utils/usage_stats_aggregator.dart';

UsageDay day(
  String date, {
  int visits = 0,
  Map<String, Map<String, int>> teachers = const {},
  Set<String> visitors = const {},
  Map<String, int> extra = const {},
}) {
  return UsageDay(
    date: date,
    totals: {UsageKeys.visits: visits, ...extra},
    teachers: teachers,
    visitors: visitors,
  );
}

void main() {
  group('UsageStatsAggregator', () {
    test('빈 기간은 0과 빈 목록', () {
      final s = UsageStatsAggregator.aggregate(const [], UsagePeriodUnit.day);
      expect(s.buckets, isEmpty);
      expect(s.teachers, isEmpty);
      expect(s.uniqueVisitors, 0);
      expect(s.totals[UsageKeys.visits] ?? 0, 0);
    });

    test('일 버킷은 날짜별로 정렬된다', () {
      final s = UsageStatsAggregator.aggregate([
        day('2026-10-07', visits: 2),
        day('2026-10-06', visits: 1),
      ], UsagePeriodUnit.day);
      expect(s.buckets.map((b) => b.label), ['2026-10-06', '2026-10-07']);
      expect(s.totals[UsageKeys.visits], 3);
    });

    test('주 버킷은 월요일 시작 (일요일은 직전 월요일 주)', () {
      // 2026-10-05 월, 10-11 일, 10-12 월
      final s = UsageStatsAggregator.aggregate([
        day('2026-10-05', visits: 1),
        day('2026-10-11', visits: 2),
        day('2026-10-12', visits: 4),
      ], UsagePeriodUnit.week);
      expect(s.buckets.length, 2);
      expect(s.buckets[0].label, '2026-10-05');
      expect(s.buckets[0].totals[UsageKeys.visits], 3);
      expect(s.buckets[1].label, '2026-10-12');
      expect(s.buckets[1].totals[UsageKeys.visits], 4);
    });

    test('월 버킷은 월말 경계를 나눈다', () {
      final s = UsageStatsAggregator.aggregate([
        day('2026-09-30', visits: 1),
        day('2026-10-01', visits: 2),
      ], UsagePeriodUnit.month);
      expect(s.buckets.map((b) => b.label), ['2026-09', '2026-10']);
    });

    test('고유 접속자는 기간 내 uid 합집합', () {
      final s = UsageStatsAggregator.aggregate([
        day('2026-10-06', visitors: {'a', 'b'}),
        day('2026-10-07', visitors: {'b', 'c'}),
      ], UsagePeriodUnit.day);
      expect(s.uniqueVisitors, 3);
    });

    test('교사별 합계·마지막 사용일·이름 미설정 버킷', () {
      final s = UsageStatsAggregator.aggregate([
        day(
          '2026-10-06',
          teachers: {
            '김교사': {UsageKeys.visits: 1, UsageKeys.pdfSave: 2},
            kUsageUnnamedTeacher: {UsageKeys.visits: 1},
          },
        ),
        day(
          '2026-10-08',
          teachers: {
            '김교사': {UsageKeys.visits: 2},
          },
        ),
      ], UsagePeriodUnit.day);
      expect(s.activeTeachers, 2);
      final kim = s.teachers.firstWhere((t) => t.name == '김교사');
      expect(kim.count(UsageKeys.visits), 3);
      expect(kim.count(UsageKeys.pdfSave), 2);
      expect(kim.lastSeen, '2026-10-08');
      expect(s.teachers.any((t) => t.name == kUsageUnnamedTeacher), isTrue);
    });

    test('탭 카운트와 UsageDay.fromMap', () {
      final d = UsageDay.fromMap('2026-10-06', {
        'totals': {'visits': 1, 'tab_1': 3, 'tab_2': 1},
        'teachers': {
          'a.b': {'visits': 1, 'lastSeen': 5},
        },
        'visitors': {'u1': true},
      });
      expect(d.visitors, {'u1'});
      expect(d.teachers['a.b']!['visits'], 1);
      final s = UsageStatsAggregator.aggregate([d], UsagePeriodUnit.day);
      expect(s.totals['tab_1'], 3);
    });
  });
}

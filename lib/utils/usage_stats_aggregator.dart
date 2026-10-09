import '../models/usage_event.dart';

/// 통계 보기 단위.
enum UsagePeriodUnit { day, week, month }

/// 일/주/월 버킷 하나.
class UsageBucket {
  const UsageBucket({required this.label, required this.totals});
  final String label;
  final Map<String, int> totals;

  int count(String key) => totals[key] ?? 0;
}

/// 교사 한 명의 기간 합계.
class TeacherUsage {
  const TeacherUsage({
    required this.name,
    required this.counts,
    required this.lastSeen,
  });
  final String name;
  final Map<String, int> counts;

  /// 마지막으로 기록된 날짜 `yyyy-MM-dd`
  final String lastSeen;

  int count(String key) => counts[key] ?? 0;
}

/// 기간 집계 결과.
class UsageSummary {
  const UsageSummary({
    required this.totals,
    required this.buckets,
    required this.teachers,
    required this.uniqueVisitors,
  });

  final Map<String, int> totals;
  final List<UsageBucket> buckets;
  final List<TeacherUsage> teachers;
  final int uniqueVisitors;

  int get activeTeachers => teachers.length;
  int count(String key) => totals[key] ?? 0;
}

/// 일별 문서 목록을 일/주/월로 합산하는 순수 함수 모음.
class UsageStatsAggregator {
  UsageStatsAggregator._();

  static UsageSummary aggregate(List<UsageDay> days, UsagePeriodUnit unit) {
    final totals = <String, int>{};
    final buckets = <String, Map<String, int>>{};
    final teachers = <String, Map<String, int>>{};
    final lastSeen = <String, String>{};
    final visitors = <String>{};

    for (final d in days) {
      final label = bucketLabel(d.date, unit);
      final bucket = buckets.putIfAbsent(label, () => <String, int>{});
      for (final key in UsageKeys.all) {
        final v =
            (d.totals[key] ?? 0) - (d.teachers[kUsageAdminBucket]?[key] ?? 0);
        if (v <= 0) continue;
        totals[key] = (totals[key] ?? 0) + v;
        bucket[key] = (bucket[key] ?? 0) + v;
      }
      visitors.addAll(d.visitors);
      for (final e in d.teachers.entries) {
        if (e.key == kUsageAdminBucket) continue;
        final t = teachers.putIfAbsent(e.key, () => <String, int>{});
        for (final key in UsageKeys.all) {
          final v = e.value[key];
          if (v == null || v == 0) continue;
          t[key] = (t[key] ?? 0) + v;
        }
        final prev = lastSeen[e.key];
        if (prev == null || d.date.compareTo(prev) > 0) {
          lastSeen[e.key] = d.date;
        }
      }
    }

    final bucketList =
        buckets.entries
            .map((e) => UsageBucket(label: e.key, totals: e.value))
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    final teacherList =
        teachers.entries
            .map(
              (e) => TeacherUsage(
                name: e.key,
                counts: e.value,
                lastSeen: lastSeen[e.key] ?? '',
              ),
            )
            .toList()
          ..sort((a, b) {
            final c = b
                .count(UsageKeys.visits)
                .compareTo(a.count(UsageKeys.visits));
            return c != 0 ? c : a.name.compareTo(b.name);
          });

    return UsageSummary(
      totals: totals,
      buckets: bucketList,
      teachers: teacherList,
      uniqueVisitors: visitors.length,
    );
  }

  /// `yyyy-MM-dd` 날짜가 속한 버킷 라벨.
  /// 일: 날짜 그대로, 주: 그 주 월요일 날짜, 월: `yyyy-MM`.
  static String bucketLabel(String date, UsagePeriodUnit unit) {
    switch (unit) {
      case UsagePeriodUnit.day:
        return date;
      case UsagePeriodUnit.month:
        return date.length >= 7 ? date.substring(0, 7) : date;
      case UsagePeriodUnit.week:
        final parsed = DateTime.tryParse(date);
        if (parsed == null) return date;
        final monday = DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
        ).subtract(Duration(days: parsed.weekday - DateTime.monday));
        return dateId(monday);
    }
  }

  /// `yyyy-MM-dd` 문서 id.
  static String dateId(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }

  /// 지금 시각 기준 KST 날짜 id.
  static String todayKstId([DateTime? now]) {
    final kst = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
    return dateId(kst);
  }
}

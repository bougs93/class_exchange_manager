import 'package:class_exchange_manager/models/usage_event.dart';
import 'package:class_exchange_manager/services/usage_stats_service.dart';

/// 인메모리 통계 저장소 (테스트용).
class FakeUsageBackend implements UsageStatsBackend {
  FakeUsageBackend({List<UsageDay> days = const [], this.failWrites = false})
    : days = List.of(days);

  final List<UsageDay> days;
  final List<UsageDelta> writes = [];
  bool failWrites;

  @override
  Future<void> writeDelta(UsageDelta delta) async {
    if (failWrites) throw StateError('fail');
    writes.add(delta);
  }

  bool _in(String id, String? f, String? t) =>
      (f == null || id.compareTo(f) >= 0) &&
      (t == null || id.compareTo(t) <= 0);

  @override
  Future<List<UsageDay>> fetchRange(String fromId, String toId) async =>
      days.where((d) => _in(d.date, fromId, toId)).toList();

  @override
  Future<int> countRange(String? f, String? t) async =>
      days.where((d) => _in(d.date, f, t)).length;

  @override
  Future<int> deleteRange(String? f, String? t) async {
    final before = days.length;
    days.removeWhere((d) => _in(d.date, f, t));
    return before - days.length;
  }

  @override
  Future<int> deleteTeacher(String? f, String? t, String teacherName) async {
    var touched = 0;
    final next =
        days.map((d) {
          if (!_in(d.date, f, t) || !d.teachers.containsKey(teacherName)) {
            return d;
          }
          touched++;
          final removed = d.teachers[teacherName]!;
          final totals = Map<String, int>.of(d.totals);
          for (final e in removed.entries) {
            totals[e.key] = (totals[e.key] ?? 0) - e.value < 0
                ? 0
                : (totals[e.key] ?? 0) - e.value;
          }
          final teachers = Map<String, Map<String, int>>.of(d.teachers)
            ..remove(teacherName);
          return UsageDay(
            date: d.date,
            totals: totals,
            teachers: teachers,
            visitors: d.visitors,
          );
        }).toList();
    days
      ..clear()
      ..addAll(next);
    return touched;
  }
}

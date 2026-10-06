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
}

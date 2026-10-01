import '../../models/time_slot.dart';
import 'circular_search.dart';
import 'dual_search.dart';

/// The worker protocol contains JSON values only; no Flutter objects cross it.
List<Map<String, dynamic>> executeSearch(Map<String, dynamic> request) {
  final slots =
      (request['timeSlots'] as List)
          .map(
            (value) =>
                TimeSlot.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
  final teacher = request['teacher'] as String;
  final day = request['day'] as String;
  final period = request['period'] as int;
  switch (request['kind']) {
    case 'circular':
      final engine = CircularSearchEngine()..selectCell(teacher, day, period);
      return engine
          .findCircularExchangePaths(slots, [])
          .map((p) => p.toJson())
          .toList();
    case 'dual':
      final engine = DualSearchEngine()..selectCell(teacher, day, period);
      return engine
          .findDualExchangePaths(slots, [])
          .map((p) => p.toJson())
          .toList();
    default:
      throw ArgumentError('Unknown exchange search: ${request['kind']}');
  }
}

import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/search/circular_search.dart';
import 'package:class_exchange_manager/services/search/dual_search.dart';
import 'package:class_exchange_manager/services/search/search_request.dart';
import 'package:flutter_test/flutter_test.dart';

TimeSlot lesson(String teacher, int period, String className) => TimeSlot(
  teacher: teacher,
  dayOfWeek: 1,
  period: period,
  subject: '과목',
  className: className,
);

void main() {
  test(
    'circular search returns a closed path and respects blocked empty cells',
    () {
      final slots = [lesson('A', 1, '1-1'), lesson('B', 2, '1-1')];
      final engine = CircularSearchEngine()..selectCell('A', '월', 1);
      final paths = engine.findCircularExchangePaths(slots, []);
      expect(paths, hasLength(1));
      expect(paths.single.nodes.map((n) => n.teacherName), ['A', 'B', 'A']);
      slots.add(
        TimeSlot(
          teacher: 'A',
          dayOfWeek: 1,
          period: 2,
          isExchangeable: false,
          exchangeReason: '교체불가',
        ),
      );
      expect(engine.findCircularExchangePaths(slots, []), isEmpty);
      slots.last.isExchangeable = true;
      expect(engine.findCircularExchangePaths(slots, []), hasLength(1));
    },
  );

  test('dual search clears a blocking lesson before exchanging A and B', () {
    final slots = [
      lesson('A', 1, '1-1'),
      lesson('B', 2, '1-1'),
      lesson('A', 2, '2-1'),
      lesson('C', 3, '2-1'),
    ];
    final engine = DualSearchEngine()..selectCell('A', '월', 1);
    final paths = engine.findDualExchangePaths(slots, []);
    expect(paths, hasLength(1));
    expect(paths.single.node1.teacherName, 'C');
    expect(paths.single.node2.teacherName, 'A');
    expect(paths.single.nodeB.teacherName, 'B');
    slots.add(
      TimeSlot(
        teacher: 'C',
        dayOfWeek: 1,
        period: 2,
        isExchangeable: false,
        exchangeReason: '교체불가',
      ),
    );
    expect(engine.findDualExchangePaths(slots, []), isEmpty);
  });

  test('worker protocol round trips complete path metadata', () {
    final paths = executeSearch({
      'kind': 'circular',
      'teacher': 'A',
      'day': '월',
      'period': 1,
      'timeSlots': [
        lesson('A', 1, '1-1').toJson(),
        lesson('B', 2, '1-1').toJson(),
      ],
    });
    expect(paths, hasLength(1));
    expect((paths.single['nodes'] as List).first['subjectName'], '과목');
    expect(
      () => executeSearch({
        'kind': 'invalid',
        'timeSlots': [],
        'teacher': 'A',
        'day': '월',
        'period': 1,
      }),
      throwsArgumentError,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/exchange_history_service.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

OneToOneExchangePath _samplePath() {
  final targetSlot = TimeSlot(
    teacher: '박은선',
    subject: '기술가정',
    className: '3-8',
    dayOfWeek: 1,
    period: 1,
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: '정원길',
      day: '수',
      period: 1,
      className: '3-8',
      subjectName: '기술가정',
    ),
    targetNode: ExchangeNode(
      teacherName: '박은선',
      day: '월',
      period: 1,
      className: '3-8',
      subjectName: '기술가정',
    ),
    option: ExchangeOption(
      timeSlot: targetSlot,
      teacherName: '박은선',
      type: ExchangeType.sameClass,
      priority: 1,
      reason: 'test',
    ),
  );
}

void main() {
  final service = ExchangeHistoryService();

  setUp(() {
    service.resetForTesting();
  });

  test('unassignProfile은 해당 계획서가 지정된 교체 건만 미지정으로 되돌린다', () {
    service.addExchange(
      _samplePath(),
      absenceDate: DateTime(2026, 10, 7),
      substitutionDate: DateTime(2026, 10, 12),
    );
    service.addExchange(
      _samplePath(),
      absenceDate: DateTime(2026, 10, 8),
      substitutionDate: DateTime(2026, 10, 13),
    );
    final items = service.getExchangeList();
    service.assignProfile(items[0].id, 'pp_1');
    service.assignProfile(items[1].id, 'pp_2');

    service.unassignProfile('pp_1');

    final updated = service.getExchangeList();
    expect(updated.firstWhere((e) => e.id == items[0].id).profileId, isNull);
    expect(
      updated.firstWhere((e) => e.id == items[1].id).profileId,
      'pp_2',
    );
  });

  test('일치하는 항목이 없으면 버전이 올라가지 않는다', () {
    service.addExchange(
      _samplePath(),
      absenceDate: DateTime(2026, 10, 7),
      substitutionDate: DateTime(2026, 10, 12),
    );
    final versionBefore = service.getExchangeListVersion();

    service.unassignProfile('없는_계획서_id');

    expect(service.getExchangeListVersion(), versionBefore);
  });
}

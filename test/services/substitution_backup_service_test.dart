import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/print_profile.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/substitution_backup_service.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

/// 정원길(기술가정 3-8, 수1) <-> 박은선(기술가정 3-8, 월1) 1:1 교체 픽스처.
OneToOneExchangePath _wonGilEunSunPath() {
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

ExchangeHistoryItem _historyItem({
  required OneToOneExchangePath path,
  required DateTime absenceDate,
  required DateTime substitutionDate,
  String? customId,
}) {
  return ExchangeHistoryItem.fromExchangePath(
    path,
    absenceDate: absenceDate,
    substitutionDate: substitutionDate,
    customId: customId,
  );
}

List<TimeSlot> _matchingTimetable() {
  return [
    TimeSlot(
      teacher: '정원길',
      subject: '기술가정',
      className: '3-8',
      dayOfWeek: 3, // 수
      period: 1,
    ),
    TimeSlot(
      teacher: '박은선',
      subject: '기술가정',
      className: '3-8',
      dayOfWeek: 1, // 월
      period: 1,
    ),
  ];
}

void main() {
  final backup = const SubstitutionBackupService();

  test('encode/decode 왕복하면 내용이 그대로 복원된다', () {
    final item = _historyItem(
      path: _wonGilEunSunPath(),
      absenceDate: DateTime(2026, 10, 7),
      substitutionDate: DateTime(2026, 10, 12),
      customId: 'e1',
    );
    final profile = PrintProfile(
      id: 'pp_1',
      name: '계획서1',
      teacherName: '정원길',
      templateIndex: 0,
      fontSize: 10,
      remarksFontSize: 7,
      selectedFont: 'hanbatang.ttf',
      includeRemarks: true,
    );
    final bundle = SubstitutionBackupBundle(
      timetableName: '월계중1학기',
      teacherName: '정원길',
      schoolName: '월계중',
      exchangeItems: [item],
      printProfiles: [profile],
    );

    final decoded = backup.decode(backup.encode(bundle));

    expect(decoded.timetableName, '월계중1학기');
    expect(decoded.exchangeItems, hasLength(1));
    expect(decoded.exchangeItems.single.id, 'e1');
    expect(decoded.printProfiles, hasLength(1));
    expect(decoded.printProfiles.single.id, 'pp_1');
  });

  test('형식 마커가 없는 JSON은 FormatException을 던진다', () {
    expect(() => backup.decode('{"foo": 1}'), throwsFormatException);
  });

  test('원본 칸 정보가 현재 시간표와 같으면 matchesCurrentTimetable은 true', () {
    final item = _historyItem(
      path: _wonGilEunSunPath(),
      absenceDate: DateTime(2026, 10, 7),
      substitutionDate: DateTime(2026, 10, 12),
    );

    expect(
      backup.matchesCurrentTimetable([item], _matchingTimetable()),
      isTrue,
    );
  });

  test('과목이 다른 시간표면 matchesCurrentTimetable은 false', () {
    final item = _historyItem(
      path: _wonGilEunSunPath(),
      absenceDate: DateTime(2026, 10, 7),
      substitutionDate: DateTime(2026, 10, 12),
    );

    final differentTimetable = [
      TimeSlot(
        teacher: '정원길',
        subject: '수학', // 원본은 기술가정 — 다른 시간표
        className: '3-8',
        dayOfWeek: 3,
        period: 1,
      ),
      TimeSlot(
        teacher: '박은선',
        subject: '기술가정',
        className: '3-8',
        dayOfWeek: 1,
        period: 1,
      ),
    ];

    expect(
      backup.matchesCurrentTimetable([item], differentTimetable),
      isFalse,
    );
  });

  test('결강일/교시가 겹치면 hasDateConflict는 true', () {
    final existing = _historyItem(
      path: _wonGilEunSunPath(),
      absenceDate: DateTime(2026, 10, 7),
      substitutionDate: DateTime(2026, 10, 12),
      customId: 'existing',
    );
    final imported = _historyItem(
      path: _wonGilEunSunPath(),
      absenceDate: DateTime(2026, 10, 7), // 같은 결강일·교시
      substitutionDate: DateTime(2026, 10, 19),
      customId: 'imported',
    );

    expect(backup.hasDateConflict([imported], [existing]), isTrue);
  });

  test('날짜가 전혀 겹치지 않으면 hasDateConflict는 false', () {
    final existing = _historyItem(
      path: _wonGilEunSunPath(),
      absenceDate: DateTime(2026, 10, 7),
      substitutionDate: DateTime(2026, 10, 12),
      customId: 'existing',
    );
    final imported = _historyItem(
      path: _wonGilEunSunPath(),
      absenceDate: DateTime(2026, 10, 14),
      substitutionDate: DateTime(2026, 10, 19),
      customId: 'imported',
    );

    expect(backup.hasDateConflict([imported], [existing]), isFalse);
  });

  test('되돌린(비활성) 건은 충돌 검사에서 제외된다', () {
    final existing = _historyItem(
      path: _wonGilEunSunPath(),
      absenceDate: DateTime(2026, 10, 7),
      substitutionDate: DateTime(2026, 10, 12),
      customId: 'existing',
    )..isReverted = true;
    final imported = _historyItem(
      path: _wonGilEunSunPath(),
      absenceDate: DateTime(2026, 10, 7),
      substitutionDate: DateTime(2026, 10, 12),
      customId: 'imported',
    );

    expect(backup.hasDateConflict([imported], [existing]), isFalse);
  });
}

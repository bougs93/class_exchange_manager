import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/exchange_history_service.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

/// 테스트 기본 결강일 (월요일)
final DateTime _testAbsenceDate = DateTime(2026, 8, 24);

/// 테스트 기본 교체일 (화요일, 같은 주)
final DateTime _testSubstitutionDate = DateTime(2026, 8, 25);

/// 테스트용 1:1 교체 경로 생성
OneToOneExchangePath _createTestPath(String label) {
  final targetSlot = TimeSlot(
    teacher: '교사B',
    subject: '국어',
    className: '1-2',
    dayOfWeek: 2,
    period: 2,
  );
  final option = ExchangeOption(
    timeSlot: targetSlot,
    teacherName: '교사B',
    type: ExchangeType.sameClass,
    priority: 1,
    reason: 'test',
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: '교사A-$label',
      day: '월',
      period: 1,
      className: '1-1',
      subjectName: '수학',
    ),
    targetNode: ExchangeNode(
      teacherName: '교사B-$label',
      day: '화',
      period: 2,
      className: '1-2',
      subjectName: '국어',
    ),
    option: option,
  );
}

/// 테스트용 교체 추가 — absenceDate/substitutionDate가 필수가 된 이후
/// (§10) 매 호출마다 반복 지정하지 않도록 기본 날짜를 채워주는 헬퍼.
void _addTestExchange(
  ExchangeHistoryService service,
  String label, {
  required String description,
  DateTime? absenceDate,
  DateTime? substitutionDate,
}) {
  service.addExchange(
    _createTestPath(label),
    customDescription: description,
    absenceDate: absenceDate ?? _testAbsenceDate,
    substitutionDate: substitutionDate ?? _testSubstitutionDate,
  );
}

/// 활성 교체 설명 목록 (순서 유지)
List<String> _activeDescriptions(ExchangeHistoryService service) {
  return service
      .getActiveExchangeList()
      .map((item) => item.description)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExchangeHistoryService service;

  setUp(() {
    service = ExchangeHistoryService();
    service.resetForTesting();
    // 시간표 스코프 지정 (스코프 없으면 저장이 건너뛰어짐)
    service.timetableId = 'tt_test_scope';
  });

  group('ExchangeHistoryService undo/redo', () {
    test('교체 3건 추가 후 undo 3회 → 모두 되돌림', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');
      _addTestExchange(service, '3', description: 'C');

      expect(_activeDescriptions(service), ['A', 'B', 'C']);
      expect(service.canUndo, isTrue);
      expect(service.canRedo, isFalse);

      expect(service.undoLastExchange()?.description, 'C');
      expect(_activeDescriptions(service), ['A', 'B']);
      expect(service.canRedo, isTrue);

      expect(service.undoLastExchange()?.description, 'B');
      expect(_activeDescriptions(service), ['A']);

      expect(service.undoLastExchange()?.description, 'A');
      expect(_activeDescriptions(service), isEmpty);
      expect(service.canUndo, isFalse);
      expect(service.canRedo, isTrue);
      expect(service.getRedoStack().map((e) => e.description).toList(), [
        'C',
        'B',
        'A',
      ]);
    });

    test('undo 3회 후 redo 3회 → 원래 상태 복구', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');
      _addTestExchange(service, '3', description: 'C');

      service.undoLastExchange();
      service.undoLastExchange();
      service.undoLastExchange();

      expect(service.redoLastExchange()?.description, 'A');
      expect(_activeDescriptions(service), ['A']);

      expect(service.redoLastExchange()?.description, 'B');
      expect(_activeDescriptions(service), ['A', 'B']);

      expect(service.redoLastExchange()?.description, 'C');
      expect(_activeDescriptions(service), ['A', 'B', 'C']);
      expect(service.canRedo, isFalse);
      expect(service.canUndo, isTrue);
    });

    test('undo 2회 → redo 1회 → undo 1회 → 교차 동작', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');
      _addTestExchange(service, '3', description: 'C');

      service.undoLastExchange(); // C 되돌림
      service.undoLastExchange(); // B 되돌림
      expect(_activeDescriptions(service), ['A']);

      service.redoLastExchange(); // B 복구
      expect(_activeDescriptions(service), ['A', 'B']);

      service.undoLastExchange(); // B 다시 되돌림
      expect(_activeDescriptions(service), ['A']);
      expect(service.getExchangeList().length, 3); // 리스트에서 삭제되지 않음
    });

    test('undo 후 새 교체 실행 → redo 스택 초기화', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');

      service.undoLastExchange();
      expect(service.canRedo, isTrue);

      _addTestExchange(service, '3', description: 'C');
      expect(service.canRedo, isFalse);
      expect(_activeDescriptions(service), ['A', 'C']);
    });

    test('clearExchangeList → undo/redo 모두 불가', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');
      service.undoLastExchange();

      service.clearExchangeList();

      expect(service.canUndo, isFalse);
      expect(service.canRedo, isFalse);
      expect(service.getExchangeList(), isEmpty);
    });

    test('removeFromExchangeList → 스택에서도 제거', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');
      final itemB = service.getExchangeList().last;

      service.removeFromExchangeList(itemB.id);

      expect(_activeDescriptions(service), ['A']);
      expect(service.getUndoStack().map((e) => e.description), ['A']);
      expect(service.undoLastExchange()?.description, 'A');
      expect(service.canUndo, isFalse);
    });

    test('maxUndoItems(10) 초과 시 스택은 10개만 유지', () {
      for (var i = 1; i <= 11; i++) {
        _addTestExchange(service, '$i', description: 'E$i');
      }

      expect(service.getExchangeList().length, 11);
      expect(service.getUndoStack().length, 10);
      expect(service.getUndoStack().first.description, 'E2');
      expect(service.getUndoStack().last.description, 'E11');

      // 스택에 있는 10건만 undo 가능
      for (var i = 0; i < 10; i++) {
        expect(service.canUndo, isTrue);
        service.undoLastExchange();
      }
      expect(service.canUndo, isFalse);
      // E1은 스택 밖이라 여전히 활성
      expect(_activeDescriptions(service), ['E1']);
    });

    test('되돌린 항목은 getActiveExchangeList에서 제외', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');

      service.undoLastExchange();

      expect(service.getExchangeList().length, 2);
      expect(service.getActiveExchangeList().length, 1);
      expect(
        service.getExchangeList().every((item) {
          if (item.description == 'B') return item.isReverted;
          return !item.isReverted;
        }),
        isTrue,
      );
    });
  });

  group('ExchangeHistoryService 날짜 필드 (§10)', () {
    test('addExchange로 만든 항목은 지정한 absenceDate/substitutionDate를 그대로 가진다', () {
      _addTestExchange(service, '1', description: 'A');

      final item = service.getExchangeList().single;
      expect(item.absenceDate, _testAbsenceDate);
      expect(item.substitutionDate, _testSubstitutionDate);
    });

    test('weekMonday는 absenceDate가 속한 주의 월요일이다 (주중 아무 날짜든)', () {
      // 2026-08-27(목)이 결강일이면 그 주 월요일은 2026-08-24
      _addTestExchange(
        service,
        '1',
        description: 'A',
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );

      final item = service.getExchangeList().single;
      expect(item.weekMonday, DateTime(2026, 8, 24));
    });

    test('결강일이 다른 주면 weekMonday도 다르다 — 주 사이의 독립을 보장', () {
      _addTestExchange(
        service,
        '1',
        description: '8월4주',
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );
      _addTestExchange(
        service,
        '2',
        description: '9월1주',
        absenceDate: DateTime(2026, 9, 3),
        substitutionDate: DateTime(2026, 9, 4),
      );

      final weeks =
          service.getExchangeList().map((item) => item.weekMonday).toSet();
      expect(weeks, {DateTime(2026, 8, 24), DateTime(2026, 8, 31)});
    });

    test('결강일이 금요일, 교체일이 다음 주 월요일이어도 weekMonday는 결강일 기준이다 (§10.5 A안)', () {
      // 결강 금(2026-09-04), 보강 다음주 월(2026-09-07)
      _addTestExchange(
        service,
        '1',
        description: '주 경계',
        absenceDate: DateTime(2026, 9, 4),
        substitutionDate: DateTime(2026, 9, 7),
      );

      final item = service.getExchangeList().single;
      // 결강일이 속한 주(8/31~9/4)의 월요일
      expect(item.weekMonday, DateTime(2026, 8, 31));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/exchange_history_service.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

/// 테스트용 순환 교체 경로 생성 (S5.6 `updateNodeDate` 테스트용)
CircularExchangePath _createTestCircularPath() {
  final a = ExchangeNode(
    teacherName: 'A',
    day: '월',
    period: 1,
    className: '1-1',
    subjectName: '수학',
  );
  final b = ExchangeNode(
    teacherName: 'B',
    day: '화',
    period: 2,
    className: '1-1',
    subjectName: '영어',
  );
  final c = ExchangeNode(
    teacherName: 'C',
    day: '수',
    period: 3,
    className: '1-1',
    subjectName: '과학',
  );
  return CircularExchangePath.fromNodes([a, b, c, a]);
}

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

      expect(service.undoLastExchange()?.items.single.description, 'C');
      expect(_activeDescriptions(service), ['A', 'B']);
      expect(service.canRedo, isTrue);

      expect(service.undoLastExchange()?.items.single.description, 'B');
      expect(_activeDescriptions(service), ['A']);

      expect(service.undoLastExchange()?.items.single.description, 'A');
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

      expect(service.redoLastExchange()?.items.single.description, 'A');
      expect(_activeDescriptions(service), ['A']);

      expect(service.redoLastExchange()?.items.single.description, 'B');
      expect(_activeDescriptions(service), ['A', 'B']);

      expect(service.redoLastExchange()?.items.single.description, 'C');
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

    test('clearExchangeList → 되돌리기 1번에 전체 복원, 다시 실행하면 재삭제', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');
      service.undoLastExchange(); // B 되돌림 → redo 대기 [B]
      expect(service.canRedo, isTrue);

      service.clearExchangeList();

      expect(service.getExchangeList(), isEmpty);
      // redo는 새 조작(전체 삭제)으로 비워진다
      expect(service.canRedo, isFalse);
      // 묶음이 undo 스택에 남으므로 되돌리기 가능
      expect(service.canUndo, isTrue);

      // 되돌리기 1번에 전체 복원 (B는 되돌려진 상태 그대로 돌아온다)
      final undone = service.undoLastExchange();
      expect(undone?.wasBulk, isTrue);
      expect(undone?.wasDelete, isTrue);
      expect(undone?.items.map((e) => e.description).toList(), ['A', 'B']);
      expect(_activeDescriptions(service), ['A']);
      expect(service.canRedo, isTrue);

      // 다시 실행하면 묶음이 통째로 재삭제된다
      final redone = service.redoLastExchange();
      expect(redone?.wasBulk, isTrue);
      expect(_activeDescriptions(service), isEmpty);

      // 되돌리면 다시 전체 복원된다
      expect(service.undoLastExchange()?.wasBulk, isTrue);
      expect(_activeDescriptions(service), ['A']);
    });

    test('전체 삭제 복원 후에도 이전 동작의 되돌리기가 이어진다', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');

      service.clearExchangeList();
      expect(service.getExchangeList(), isEmpty);

      // 1번에 전체 복원
      service.undoLastExchange();
      expect(_activeDescriptions(service), ['A', 'B']);

      // 이전 동작(B 실행 취소)이 이어진다 — 단일 기록이 보존됐기 때문
      final undoneB = service.undoLastExchange();
      expect(undoneB?.wasBulk, isFalse);
      expect(undoneB?.items.single.description, 'B');
      expect(_activeDescriptions(service), ['A']);

      // 그 이전 동작(A 실행 취소)도 이어진다
      final undoneA = service.undoLastExchange();
      expect(undoneA?.items.single.description, 'A');
      expect(_activeDescriptions(service), isEmpty);
      expect(service.canUndo, isFalse);
    });

    test('전체 삭제 후 새 실행 → 새 항목이 LIFO 순서로 먼저 되돌려진다', () {
      _addTestExchange(service, '1', description: 'A');

      service.clearExchangeList();

      _addTestExchange(service, '2', description: 'B');

      // 가장 최근 조작(B 실행)이 먼저 되돌려진다
      expect(service.undoLastExchange()?.items.single.description, 'B');
      expect(_activeDescriptions(service), isEmpty);

      // 다음은 묶음(A 전체 삭제)이 되돌려진다
      final undone = service.undoLastExchange();
      expect(undone?.wasBulk, isTrue);
      expect(_activeDescriptions(service), ['A']);
    });

    test('묶음 복원 후 새 실행 → redo 불가 (표준 동작)', () {
      _addTestExchange(service, '1', description: 'A');

      service.clearExchangeList();
      service.undoLastExchange(); // A 복원 → redo 대기
      expect(service.canRedo, isTrue);

      _addTestExchange(service, '2', description: 'B');
      expect(service.canRedo, isFalse);
      expect(_activeDescriptions(service), ['A', 'B']);
    });

    test('다른 주 교체도 묶음으로 함께 복원된다', () {
      _addTestExchange(service, '1', description: '8월4주');
      _addTestExchange(
        service,
        '2',
        description: '9월1주',
        absenceDate: DateTime(2026, 9, 3),
        substitutionDate: DateTime(2026, 9, 4),
      );

      service.clearExchangeList();
      final undone = service.undoLastExchange();

      expect(undone?.wasBulk, isTrue);
      expect(_activeDescriptions(service), ['8월4주', '9월1주']);
    });

    test('계획서 삭제로 묶음 redo 스냅샷이 비면 redo 불가', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');

      service.clearExchangeList();
      service.undoLastExchange(); // 복원 → redo 묶음 [[A, B]] 대기
      expect(service.canRedo, isTrue);

      // 두 항목을 같은 계획서에 묶은 뒤 계획서 삭제
      for (final item in service.getExchangeList()) {
        service.assignProfile(item.id, 'p1');
      }
      service.removeExchangeItemsByProfile('p1');

      // 대기 중이던 묶음 redo도 함께 정리된다
      expect(service.getExchangeList(), isEmpty);
      expect(service.canRedo, isFalse);
      expect(service.canUndo, isFalse);
    });

    test('removeFromExchangeList → 삭제도 되돌릴 수 있다', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');
      final itemB = service.getExchangeList().last;

      service.removeFromExchangeList(itemB.id);

      expect(_activeDescriptions(service), ['A']);
      // 삭제가 undo 스택에 남는다
      expect(service.canUndo, isTrue);

      // 되돌리면 삭제됐던 B가 복원된다
      final undone = service.undoLastExchange();
      expect(undone?.items.single.description, 'B');
      expect(undone?.wasDelete, isTrue);
      expect(_activeDescriptions(service), ['A', 'B']);
      expect(service.canRedo, isTrue);

      // 다시 실행하면 B가 다시 삭제된다
      final redone = service.redoLastExchange();
      expect(redone?.items.single.description, 'B');
      expect(redone?.wasDelete, isTrue);
      expect(_activeDescriptions(service), ['A']);
      expect(service.canUndo, isTrue);
    });

    test('실행→삭제→되돌리기→다시실행 교차 동작', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');
      final itemB = service.getExchangeList().last;

      // B 삭제 후 되돌리면 B 복원
      service.removeFromExchangeList(itemB.id);
      expect(service.undoLastExchange()?.wasDelete, isTrue);
      expect(_activeDescriptions(service), ['A', 'B']);

      // 다음 되돌리기는 그 앞 동작(A 실행 취소) — B의 실행 항목은
      // 삭제 시점에 스택에서 빠졌으므로 건너뛰어진다
      final undone = service.undoLastExchange();
      expect(undone?.wasDelete, isFalse);
      expect(undone?.items.single.description, 'A');
      expect(_activeDescriptions(service), ['B']);

      // 다시 실행하면 A 활성화
      expect(service.redoLastExchange()?.wasDelete, isFalse);
      expect(_activeDescriptions(service), ['A', 'B']);
    });

    test('삭제 후 새 교체 실행 → redo 스택 초기화', () {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');
      final itemB = service.getExchangeList().last;

      service.removeFromExchangeList(itemB.id);
      service.undoLastExchange(); // B 복원 → redo 가능
      expect(service.canRedo, isTrue);

      _addTestExchange(service, '3', description: 'C');
      expect(service.canRedo, isFalse);
      expect(_activeDescriptions(service), ['A', 'B', 'C']);
    });

    test('없는 항목 삭제 → 아무 일도 일어나지 않음', () {
      _addTestExchange(service, '1', description: 'A');

      service.removeFromExchangeList('no-such-id');

      expect(_activeDescriptions(service), ['A']);
      // 삭제가 일어나지 않았으므로 undo 대상은 A의 실행뿐
      expect(service.getUndoStack().length, 1);
    });

    test('findDeletableItem → 동일 경로 중복 실행 시 활성·최신을 우선', () {
      // 같은 경로 객체로 두 번 실행 → originalPath.id 중복
      final path = _createTestPath('dup');
      service.addExchange(
        path,
        customDescription: '첫째',
        absenceDate: _testAbsenceDate,
        substitutionDate: _testSubstitutionDate,
      );
      service.addExchange(
        path,
        customDescription: '둘째',
        absenceDate: _testAbsenceDate,
        substitutionDate: _testSubstitutionDate,
      );

      // 둘 다 활성이면 가장 최근(둘째) 선택
      expect(service.findDeletableItem(path.id)?.description, '둘째');

      // 둘째를 되돌리면(비활성) 활성 상태인 첫째가 선택됨
      service.undoLastExchange();
      expect(service.findDeletableItem(path.id)?.description, '첫째');
    });

    test('findDeletableItem → 전부 되돌려졌으면 가장 최근 반환, 없으면 null', () {
      final path = _createTestPath('dup');
      service.addExchange(
        path,
        customDescription: '첫째',
        absenceDate: _testAbsenceDate,
        substitutionDate: _testSubstitutionDate,
      );

      service.undoLastExchange();
      expect(service.findDeletableItem(path.id)?.description, '첫째');
      expect(service.findDeletableItem('no-such-path'), isNull);
    });

    test('maxUndoItems(50) 초과 시 스택은 50개만 유지', () {
      for (var i = 1; i <= 51; i++) {
        _addTestExchange(service, '$i', description: 'E$i');
      }

      expect(service.getExchangeList().length, 51);
      expect(service.getUndoStack().length, 50);
      expect(service.getUndoStack().first.description, 'E2');
      expect(service.getUndoStack().last.description, 'E51');

      // 스택에 있는 50건만 undo 가능
      for (var i = 0; i < 50; i++) {
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

  group('ExchangeHistoryService.updateDates (§10.10 — savedDates 대체)', () {
    test('id로 대상을 찾아 absenceDate/substitutionDate를 갱신한다', () {
      _addTestExchange(service, '1', description: 'A');
      final id = service.getExchangeList().single.id;

      final updated = service.updateDates(
        id,
        absenceDate: DateTime(2026, 9, 3),
        substitutionDate: DateTime(2026, 9, 4),
      );

      expect(updated, isNotNull);
      expect(updated!.absenceDate, DateTime(2026, 9, 3));
      expect(updated.substitutionDate, DateTime(2026, 9, 4));

      final stored = service.getExchangeItem(id);
      expect(stored!.absenceDate, DateTime(2026, 9, 3));
      expect(stored.substitutionDate, DateTime(2026, 9, 4));
    });

    test('한쪽 날짜만 지정하면 다른 쪽은 유지된다', () {
      _addTestExchange(service, '1', description: 'A');
      final id = service.getExchangeList().single.id;

      final updated = service.updateDates(
        id,
        absenceDate: DateTime(2026, 9, 3),
      );

      expect(updated!.absenceDate, DateTime(2026, 9, 3));
      expect(updated.substitutionDate, _testSubstitutionDate);
    });

    test('존재하지 않는 id면 null을 반환하고 기존 데이터는 그대로다', () {
      _addTestExchange(service, '1', description: 'A');

      final updated = service.updateDates(
        'no-such-id',
        absenceDate: DateTime(2026, 9, 3),
      );

      expect(updated, isNull);
      expect(service.getExchangeList().single.absenceDate, _testAbsenceDate);
    });

    test('갱신 후 weekMonday도 새 absenceDate 기준으로 바뀐다', () {
      _addTestExchange(
        service,
        '1',
        description: 'A',
        absenceDate: DateTime(2026, 8, 27),
        substitutionDate: DateTime(2026, 8, 28),
      );
      final id = service.getExchangeList().single.id;

      final updated = service.updateDates(
        id,
        absenceDate: DateTime(2026, 9, 3),
      );

      expect(updated!.weekMonday, DateTime(2026, 8, 31));
    });
  });

  group('ExchangeHistoryService.updateNodeDate (S5.6)', () {
    test('순환 교체의 노드 슬롯에 확정 날짜를 저장한다', () {
      service.addExchange(
        _createTestCircularPath(),
        customDescription: '순환',
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );
      final id = service.getExchangeList().single.id;

      final updated = service.updateNodeDate(
        id,
        dayName: '화',
        period: 2,
        date: DateTime(2026, 9, 8), // 화요일
      );

      expect(updated, isNotNull);
      expect(updated!.nodeDateFor('화', 2), DateTime(2026, 9, 8));
      final stored = service.getExchangeItem(id);
      expect(stored!.nodeDateFor('화', 2), DateTime(2026, 9, 8));
    });

    test('1:1 교체(순환·2중이 아님)에는 적용되지 않고 null과 함께 상태도 그대로다', () {
      _addTestExchange(service, '1', description: 'A');
      final id = service.getExchangeList().single.id;

      final updated = service.updateNodeDate(
        id,
        dayName: '월',
        period: 1,
        date: DateTime(2026, 8, 31), // 월요일
      );

      expect(updated, isNull);
      expect(service.getExchangeItem(id)!.nodeDates, isEmpty);
    });

    test('슬롯 요일과 실제 날짜의 요일이 다르면 null을 반환하고 상태를 바꾸지 않는다', () {
      service.addExchange(
        _createTestCircularPath(),
        customDescription: '순환',
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );
      final id = service.getExchangeList().single.id;

      // '화' 슬롯인데 월요일 날짜를 넘긴다 — 요일 불일치.
      final updated = service.updateNodeDate(
        id,
        dayName: '화',
        period: 2,
        date: DateTime(2026, 9, 7), // 월요일
      );

      expect(updated, isNull);
      expect(service.getExchangeItem(id)!.nodeDates, isEmpty);
    });

    test('버전이 증가해 계획서·SQLite 캐시 무효화 리스너가 반응할 수 있다', () {
      service.addExchange(
        _createTestCircularPath(),
        customDescription: '순환',
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );
      final id = service.getExchangeList().single.id;
      final versionBefore = service.getExchangeListVersion();

      service.updateNodeDate(
        id,
        dayName: '화',
        period: 2,
        date: DateTime(2026, 9, 8),
      );

      expect(service.getExchangeListVersion(), greaterThan(versionBefore));
    });

    test('존재하지 않는 id면 null을 반환한다', () {
      _addTestExchange(service, '1', description: 'A');

      final updated = service.updateNodeDate(
        'no-such-id',
        dayName: '월',
        period: 1,
        date: DateTime(2026, 8, 31),
      );

      expect(updated, isNull);
    });
  });

  group('ExchangeHistoryService.addExchange(nodeDates:) (S5.6.7)', () {
    test('순환 교체 실행 시 nodeDates를 넘기면 저장된다', () {
      service.addExchange(
        _createTestCircularPath(),
        customDescription: '순환',
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
        nodeDates: {'화|2': DateTime(2026, 8, 25)},
      );

      final item = service.getExchangeList().single;
      expect(item.nodeDateFor('화', 2), DateTime(2026, 8, 25));
    });

    test('nodeDates를 넘기지 않으면(기존 호출부) 순환 교체도 빈 맵이다', () {
      service.addExchange(
        _createTestCircularPath(),
        customDescription: '순환',
        absenceDate: DateTime(2026, 8, 24),
        substitutionDate: DateTime(2026, 8, 25),
      );

      final item = service.getExchangeList().single;
      expect(item.nodeDates, isEmpty);
    });
  });

  group('묶음 삭제 bulkExtra', () {
    void seedAndClear() {
      _addTestExchange(service, '1', description: 'A');
      _addTestExchange(service, '2', description: 'B');
      service.clearExchangeList(bulkExtra: 'X');
    }

    test('undo는 묶음에 붙은 bulkExtra를 돌려준다', () {
      seedAndClear();
      final r = service.undoLastExchange();
      expect(r, isNotNull);
      expect(r!.wasBulk, isTrue);
      expect(r.bulkExtra, 'X');
    });

    test('콜백 없는 redo는 X를 돌려주고 다음 undo도 X를 돌려준다', () {
      seedAndClear();
      service.undoLastExchange();
      final redo = service.redoLastExchange();
      expect(redo!.wasBulk, isTrue);
      expect(redo.bulkExtra, 'X');
      expect(service.undoLastExchange()!.bulkExtra, 'X');
    });

    test('recaptureBulkExtra가 있으면 redo는 X, 다음 undo는 Y', () {
      seedAndClear();
      service.undoLastExchange();
      Object? seen;
      final redo = service.redoLastExchange(
        recaptureBulkExtra: (p) {
          seen = p;
          return 'Y';
        },
      );
      expect(redo!.bulkExtra, 'X');
      expect(seen, 'X');
      expect(service.undoLastExchange()!.bulkExtra, 'Y');
    });

    test('단일 undo/redo의 bulkExtra는 null', () {
      _addTestExchange(service, '1', description: 'A');
      final undo = service.undoLastExchange();
      expect(undo!.wasBulk, isFalse);
      expect(undo.bulkExtra, isNull);
      final redo = service.redoLastExchange();
      expect(redo!.wasBulk, isFalse);
      expect(redo.bulkExtra, isNull);
    });
  });
}

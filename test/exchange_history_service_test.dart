import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/exchange_history_service.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';

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
  });

  group('ExchangeHistoryService undo/redo', () {
    test('교체 3건 추가 후 undo 3회 → 모두 되돌림', () {
      service.addExchange(_createTestPath('1'), customDescription: 'A');
      service.addExchange(_createTestPath('2'), customDescription: 'B');
      service.addExchange(_createTestPath('3'), customDescription: 'C');

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
      service.addExchange(_createTestPath('1'), customDescription: 'A');
      service.addExchange(_createTestPath('2'), customDescription: 'B');
      service.addExchange(_createTestPath('3'), customDescription: 'C');

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
      service.addExchange(_createTestPath('1'), customDescription: 'A');
      service.addExchange(_createTestPath('2'), customDescription: 'B');
      service.addExchange(_createTestPath('3'), customDescription: 'C');

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
      service.addExchange(_createTestPath('1'), customDescription: 'A');
      service.addExchange(_createTestPath('2'), customDescription: 'B');

      service.undoLastExchange();
      expect(service.canRedo, isTrue);

      service.addExchange(_createTestPath('3'), customDescription: 'C');
      expect(service.canRedo, isFalse);
      expect(_activeDescriptions(service), ['A', 'C']);
    });

    test('clearExchangeList → undo/redo 모두 불가', () {
      service.addExchange(_createTestPath('1'), customDescription: 'A');
      service.addExchange(_createTestPath('2'), customDescription: 'B');
      service.undoLastExchange();

      service.clearExchangeList();

      expect(service.canUndo, isFalse);
      expect(service.canRedo, isFalse);
      expect(service.getExchangeList(), isEmpty);
    });

    test('removeFromExchangeList → 스택에서도 제거', () {
      service.addExchange(_createTestPath('1'), customDescription: 'A');
      service.addExchange(_createTestPath('2'), customDescription: 'B');
      final itemB = service.getExchangeList().last;

      service.removeFromExchangeList(itemB.id);

      expect(_activeDescriptions(service), ['A']);
      expect(service.getUndoStack().map((e) => e.description), ['A']);
      expect(service.undoLastExchange()?.description, 'A');
      expect(service.canUndo, isFalse);
    });

    test('maxUndoItems(10) 초과 시 스택은 10개만 유지', () {
      for (var i = 1; i <= 11; i++) {
        service.addExchange(_createTestPath('$i'), customDescription: 'E$i');
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
      service.addExchange(_createTestPath('1'), customDescription: 'A');
      service.addExchange(_createTestPath('2'), customDescription: 'B');

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
}

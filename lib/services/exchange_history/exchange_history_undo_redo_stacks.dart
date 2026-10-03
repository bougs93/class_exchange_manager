import '../../models/exchange_history_item.dart';

/// 되돌리기/다시 실행 스택(및 "삭제" 표시 집합)을 소유하는 클래스.
///
/// [ExchangeHistoryService]에서 분리했다 — 스택 자체의 push/pop/정리 같은
/// 저수준 연산만 여기서 담당하고, `_exchangeList`나 로컬 저장소와 얽힌
/// undo/redo "실행" 로직(`undoLastExchange`/`redoLastExchange`)은 여전히
/// 서비스 쪽에 남아 이 클래스의 저수준 연산들을 조합해서 사용한다.
///
/// 삭제 동작 표시(`_deletedUndoIds`/`_deletedRedoIds`): 스택 자체는 그대로
/// [ExchangeHistoryItem]을 들고, 삭제 여부만 별도 Set으로 표시한다. 교체
/// 실행과 삭제가 하나의 LIFO 순서로 되돌려지므로, 스택 타입을 바꾸지 않고
/// 삭제 undo/redo를 지원한다.
class ExchangeHistoryUndoRedoStacks {
  // 되돌리기용 스택 (메모리 저장, 최근 50개)
  final List<ExchangeHistoryItem> _undoStack = [];

  // 다시 실행용 스택 (되돌리기 후 1단계씩 복구)
  final List<ExchangeHistoryItem> _redoStack = [];

  final Set<String> _deletedUndoIds = {};
  final Set<String> _deletedRedoIds = {};

  // 최대 되돌리기 항목 수
  static const int maxUndoItems = 50;

  /// 되돌리기 스택 조회
  List<ExchangeHistoryItem> get undoStack => List.from(_undoStack);

  /// 다시 실행 스택 조회
  List<ExchangeHistoryItem> get redoStack => List.from(_redoStack);

  /// 되돌리기 가능 여부
  bool get canUndo => _undoStack.isNotEmpty;

  /// 다시 실행 가능 여부 (되돌리기 직후에만)
  bool get canRedo => _redoStack.isNotEmpty;

  int get undoLength => _undoStack.length;
  int get redoLength => _redoStack.length;

  bool get isUndoEmpty => _undoStack.isEmpty;
  bool get isRedoEmpty => _redoStack.isEmpty;

  /// undo 스택에 추가 (상한 초과 시 가장 오래된 것부터 버리고 표시 정리).
  void pushUndo(ExchangeHistoryItem item) {
    _undoStack.add(item);
    while (_undoStack.length > maxUndoItems) {
      final evicted = _undoStack.removeAt(0);
      _deletedUndoIds.remove(evicted.id);
    }
  }

  ExchangeHistoryItem removeLastUndo() => _undoStack.removeLast();

  /// 꺼낸 항목을 되돌릴 수 없을 때(예: 목록에서 찾지 못함) 되돌려 넣는다.
  void pushBackUndo(ExchangeHistoryItem item) => _undoStack.add(item);

  void addToRedo(ExchangeHistoryItem item) => _redoStack.add(item);

  ExchangeHistoryItem removeLastRedo() => _redoStack.removeLast();

  /// 꺼낸 항목을 되돌릴 수 없을 때(예: 목록에서 찾지 못함) 되돌려 넣는다.
  void pushBackRedo(ExchangeHistoryItem item) => _redoStack.add(item);

  bool removeDeletedUndoMark(String itemId) => _deletedUndoIds.remove(itemId);

  void addDeletedUndoMark(String itemId) => _deletedUndoIds.add(itemId);

  bool removeDeletedRedoMark(String itemId) => _deletedRedoIds.remove(itemId);

  void addDeletedRedoMark(String itemId) => _deletedRedoIds.add(itemId);

  /// 새 교체 실행/삭제 시 다시 실행 스택 초기화 (표준 undo/redo 동작)
  void clearRedo() {
    _redoStack.clear();
    _deletedRedoIds.clear();
  }

  /// 되돌리기 스택 초기화 (undo/redo 모두, 삭제 표시 포함)
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _deletedUndoIds.clear();
    _deletedRedoIds.clear();
  }

  /// undo/redo 스택만 비운다 (삭제 표시 Set은 그대로 둔다).
  ///
  /// 원본 코드의 `resetInMemoryState`/`loadFromLocalStorage`가 스택만
  /// 비우고 `_deletedUndoIds`/`_deletedRedoIds`는 건드리지 않던 동작을
  /// 그대로 보존하기 위한 메서드다 — [clear]와 섞어 쓰지 않는다.
  void clearStacksOnly() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// undo/redo 스택에서 특정 항목 제거
  void purgeItem(String itemId) {
    _undoStack.removeWhere((item) => item.id == itemId);
    _redoStack.removeWhere((item) => item.id == itemId);
    _deletedUndoIds.remove(itemId);
    _deletedRedoIds.remove(itemId);
  }
}

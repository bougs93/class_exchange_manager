import '../../models/exchange_history_item.dart';

/// 묶음 삭제(전체 삭제) 1건.
///
/// [extra]는 교체 목록 밖에서 함께 지워진 상태(계획서·보강 과목 등)의
/// 스냅샷이다. 서비스는 내용을 해석하지 않고 그대로 들고 다니기만 한다 —
/// 넣고 꺼내 쓰는 쪽은 UI 계층(`ExchangeExecutor`)이다.
class ExchangeBulkEntry {
  ExchangeBulkEntry(List<ExchangeHistoryItem> items, {this.extra})
    : items = List.of(items);

  final List<ExchangeHistoryItem> items;
  final Object? extra;
}

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

  // 묶음 삭제(전체 삭제)용 스택 — 한 번의 되돌리기로 통째로 복원한다.
  // 단일 항목과 섞여도 LIFO가 깨지지 않도록 [_opSeq]로 push 순서를 기록하고,
  // 되돌리기·다시실행은 양쪽 끝에서 번호가 더 큰 쪽을 먼저 꺼낸다.
  final List<ExchangeBulkEntry> _bulkUndo = [];
  final List<ExchangeBulkEntry> _bulkRedo = [];
  int _opSeq = 0;
  final List<int> _undoSeq = [];
  final List<int> _redoSeq = [];
  final List<int> _bulkUndoSeq = [];
  final List<int> _bulkRedoSeq = [];

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
    _undoSeq.add(_opSeq++);
    while (_undoStack.length > maxUndoItems) {
      final evicted = _undoStack.removeAt(0);
      _undoSeq.removeAt(0);
      _deletedUndoIds.remove(evicted.id);
    }
  }

  ExchangeHistoryItem removeLastUndo() {
    _undoSeq.removeLast();
    return _undoStack.removeLast();
  }

  /// 꺼낸 항목을 되돌릴 수 없을 때(예: 목록에서 찾지 못함) 되돌려 넣는다.
  void pushBackUndo(ExchangeHistoryItem item) => pushUndo(item);

  void addToRedo(ExchangeHistoryItem item) {
    _redoStack.add(item);
    _redoSeq.add(_opSeq++);
  }

  ExchangeHistoryItem removeLastRedo() {
    _redoSeq.removeLast();
    return _redoStack.removeLast();
  }

  /// 꺼낸 항목을 되돌릴 수 없을 때(예: 목록에서 찾지 못함) 되돌려 넣는다.
  void pushBackRedo(ExchangeHistoryItem item) => addToRedo(item);

  /// 묶음 삭제 스냅샷을 undo에 추가 (상한 초과 시 가장 오래된 묶음부터 버린다).
  void pushBulkUndo(List<ExchangeHistoryItem> items, {Object? extra}) {
    if (items.isEmpty) return;
    _bulkUndo.add(ExchangeBulkEntry(items, extra: extra));
    _bulkUndoSeq.add(_opSeq++);
    while (_bulkUndo.length > maxUndoItems) {
      _bulkUndo.removeAt(0);
      _bulkUndoSeq.removeAt(0);
    }
  }

  /// 묶음 삭제 스냅샷을 redo에 추가.
  void pushBulkRedo(List<ExchangeHistoryItem> items, {Object? extra}) {
    if (items.isEmpty) return;
    _bulkRedo.add(ExchangeBulkEntry(items, extra: extra));
    _bulkRedoSeq.add(_opSeq++);
  }

  ExchangeBulkEntry? popBulkUndo() {
    if (_bulkUndo.isEmpty) return null;
    _bulkUndoSeq.removeLast();
    return _bulkUndo.removeLast();
  }

  ExchangeBulkEntry? popBulkRedo() {
    if (_bulkRedo.isEmpty) return null;
    _bulkRedoSeq.removeLast();
    return _bulkRedo.removeLast();
  }

  bool get hasBulkUndo => _bulkUndo.isNotEmpty;

  bool get hasBulkRedo => _bulkRedo.isNotEmpty;

  /// 대기 중인 묶음 개수 (디버그 출력용)
  int get bulkUndoCount => _bulkUndo.length;

  /// 대기 중인 묶음 다시실행 개수 (디버그 출력용)
  int get bulkRedoCount => _bulkRedo.length;

  /// 가장 최근 조작이 묶음 삭제인지 (단일보다 번호가 크거나 단일 스택이 비었을 때).
  bool get isBulkUndoNewest =>
      hasBulkUndo && (_undoStack.isEmpty || _bulkUndoSeq.last > _undoSeq.last);

  /// 가장 최근 되돌리기가 묶음 복원인지.
  bool get isBulkRedoNewest =>
      hasBulkRedo && (_redoStack.isEmpty || _bulkRedoSeq.last > _redoSeq.last);

  bool removeDeletedUndoMark(String itemId) => _deletedUndoIds.remove(itemId);

  void addDeletedUndoMark(String itemId) => _deletedUndoIds.add(itemId);

  bool removeDeletedRedoMark(String itemId) => _deletedRedoIds.remove(itemId);

  void addDeletedRedoMark(String itemId) => _deletedRedoIds.add(itemId);

  /// 새 교체 실행/삭제 시 다시 실행 스택 초기화 (표준 undo/redo 동작).
  /// 단일·묶음 redo를 함께 비운다.
  void clearRedo() {
    _redoStack.clear();
    _redoSeq.clear();
    _deletedRedoIds.clear();
    _bulkRedo.clear();
    _bulkRedoSeq.clear();
  }

  /// 되돌리기 스택 초기화 (undo/redo 모두, 단일·묶음·삭제 표시 포함)
  void clear() {
    _undoStack.clear();
    _undoSeq.clear();
    _redoStack.clear();
    _redoSeq.clear();
    _deletedUndoIds.clear();
    _deletedRedoIds.clear();
    _bulkUndo.clear();
    _bulkUndoSeq.clear();
    _bulkRedo.clear();
    _bulkRedoSeq.clear();
  }

  /// undo/redo 스택만 비운다 (삭제 표시 Set은 그대로 둔다).
  ///
  /// 원본 코드의 `resetInMemoryState`/`loadFromLocalStorage`가 스택만
  /// 비우고 `_deletedUndoIds`/`_deletedRedoIds`는 건드리지 않던 동작을
  /// 그대로 보존하기 위한 메서드다 — [clear]와 섞어 쓰지 않는다.
  /// 시간표 스코프가 바뀌면 묶음 스냅샷도 무효이므로 함께 비운다.
  void clearStacksOnly() {
    _undoStack.clear();
    _undoSeq.clear();
    _redoStack.clear();
    _redoSeq.clear();
    _bulkUndo.clear();
    _bulkUndoSeq.clear();
    _bulkRedo.clear();
    _bulkRedoSeq.clear();
  }

  /// undo/redo 스택에서 특정 항목 제거.
  /// 대기 중인 묶음 스냅샷에 같은 id가 있으면 거기서도 지우고,
  /// 빈 묶음은 버린다 (부분 재삭제 같은 엉뚱한 redo 방지).
  /// 평행한 seq 리스트는 같은 인덱스로 함께 지워 상대 순서가 유지된다.
  void purgeItem(String itemId) {
    _purgeStack(_undoStack, _undoSeq, itemId);
    _purgeStack(_redoStack, _redoSeq, itemId);
    _deletedUndoIds.remove(itemId);
    _deletedRedoIds.remove(itemId);
    _scrubBulk(_bulkUndo, _bulkUndoSeq, itemId);
    _scrubBulk(_bulkRedo, _bulkRedoSeq, itemId);
  }

  void _purgeStack(
    List<ExchangeHistoryItem> stack,
    List<int> seqs,
    String itemId,
  ) {
    for (var i = stack.length - 1; i >= 0; i--) {
      if (stack[i].id == itemId) {
        stack.removeAt(i);
        seqs.removeAt(i);
      }
    }
  }

  void _scrubBulk(
    List<ExchangeBulkEntry> snapshots,
    List<int> seqs,
    String itemId,
  ) {
    for (var i = snapshots.length - 1; i >= 0; i--) {
      snapshots[i].items.removeWhere((item) => item.id == itemId);
      if (snapshots[i].items.isEmpty) {
        snapshots.removeAt(i);
        seqs.removeAt(i);
      }
    }
  }
}

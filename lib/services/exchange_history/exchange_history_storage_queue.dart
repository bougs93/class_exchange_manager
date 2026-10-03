import '../../models/exchange_history_item.dart';
import '../../utils/logger.dart';
import '../exchange_list_storage_service.dart';

/// 교체 리스트의 로컬 저장소(JSON) 쓰기를 순서대로 처리하는 큐.
///
/// 공개 히스토리 API는 동기로 유지되지만, 겹쳐서 날아가는(unawaited) 파일
/// 쓰기는 Windows에서 서로 경합할 수 있다 — 이 클래스는 모든 쓰기 작업을
/// 하나의 `Future` 체인에 직렬로 연결해 순서를 보장한다
/// ([ExchangeHistoryService]에서 옮겨온 것으로, 로직은 그대로다).
class ExchangeHistoryStorageQueue {
  final ExchangeListStorageService _storageService =
      ExchangeListStorageService();

  Future<void> _storageQueue = Future<void>.value();

  Future<void> enqueueOperation(
    Future<void> Function() operation,
    String errorMessage,
  ) {
    _storageQueue = _storageQueue.then((_) => operation()).catchError((error) {
      AppLogger.error('$errorMessage: $error', error);
    });
    return _storageQueue;
  }

  /// 교체 리스트 전체를 저장하고(JSON), 필요하면 같은 큐에 SQLite 미러
  /// 쓰기를 이어붙인다.
  ///
  /// [mirrorSink]는 null이거나 [timetableId]가 null이면 건너뛴다 — JSON
  /// 저장과 순서는 보장되지만, 실패해도(sink==null 포함) JSON 경로에는
  /// 아무 영향이 없다(부가 기록일 뿐이다).
  void enqueueExchangeListSave(
    List<ExchangeHistoryItem> snapshot,
    String? timetableId,
    Future<void> Function(List<ExchangeHistoryItem> items, String timetableId)?
    mirrorSink,
    String errorMessage,
  ) {
    enqueueOperation(
      () =>
          _storageService.saveExchangeList(snapshot, timetableId: timetableId),
      errorMessage,
    );

    final sink = mirrorSink;
    if (sink != null && timetableId != null) {
      enqueueOperation(
        () => sink(snapshot, timetableId),
        '교체 이벤트 SQLite 미러 저장 실패',
      );
    }
  }

  /// 로컬 저장소에서 교체 리스트 전체를 삭제하고, 필요하면 SQLite 저널
  /// 미러도 함께 비운다.
  void clearLocalStorage(
    String? timetableId,
    Future<void> Function(String timetableId)? mirrorClearSink,
  ) {
    enqueueOperation(
      () => _storageService.clearExchangeList(timetableId: timetableId),
      '교체 리스트 삭제 실패',
    );

    final clearSink = mirrorClearSink;
    if (clearSink != null && timetableId != null) {
      enqueueOperation(() => clearSink(timetableId), '교체 이벤트 SQLite 미러 삭제 실패');
    }
  }

  /// 지금까지 큐에 쌓인 저장 작업이 모두 끝날 때까지 기다린다.
  Future<void> flushPendingWrites() => _storageQueue;

  /// 예약된 저장을 마친 뒤 특정 시간표의 교체 목록 파일을 삭제합니다.
  Future<void> clearStoredDataForTimetable(String timetableId) {
    return enqueueOperation(
      () => _storageService.clearExchangeList(timetableId: timetableId),
      '교체 리스트 삭제 실패',
    );
  }

  /// 로컬 저장소에서 교체 리스트를 로드합니다. [loadFromLocalStorage]가
  /// 읽기 전 모든 이전 쓰기가 끝나길 기다리기 위해 사용한다.
  Future<ExchangeListLoadResult> loadExchangeList({String? timetableId}) {
    return _storageService.loadExchangeList(timetableId: timetableId);
  }
}

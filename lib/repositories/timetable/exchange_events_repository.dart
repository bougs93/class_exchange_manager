import 'package:sqflite_common/sqlite_api.dart';

import '../../models/exchange_event_record.dart';

/// 교체 이벤트 저널(`exchange_events`) 전용 저장소 (S5.0).
///
/// "언제 누가 무엇을 바꿨는가"만 기록하는 저널 CRUD이며, `lessons`(현재
/// 배치)에는 아무 영향을 주지 않는다 — S5 설계 검토서 §4 S5.0 참조.
/// 원래 `TimetableRepository`의 일부였던 메서드를 분리했다.
class ExchangeEventsRepository {
  final Database db;

  const ExchangeEventsRepository(this.db);

  /// 한 시간표의 활성 교체 이벤트 전체를 upsert한다 (S5.1에서 사용 예정).
  ///
  /// 같은 `id`가 이미 있으면 덮어쓴다(`ConflictAlgorithm.replace`) — 기존
  /// JSON 저장(`ExchangeListStorageService`)이 "리스트 전체를 매번 다시
  /// 쓰기" 방식이라 멱등인 것과 동일한 성질을 유지하기 위해서다.
  Future<void> upsertExchangeEvents(List<ExchangeEventRecord> events) async {
    if (events.isEmpty) return;
    final batch = db.batch();
    for (final event in events) {
      batch.insert(
        'exchange_events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 시간표의 교체 이벤트를 [events]로 완전히 교체한다 (S5.1 미러 쓰기).
  ///
  /// 기존 JSON 저장(`ExchangeListStorageService`)의 "리스트 전체를 매번
  /// 다시 쓰기"와 같은 의미론을 한 트랜잭션으로 재현한다 — 삭제 후 삽입을
  /// 묶어서, 메모리에서 삭제된 교체 건(`removeFromExchangeList`)이 저널에
  /// 유령처럼 남지 않게 한다.
  Future<void> replaceExchangeEventsFor(
    String timetableId,
    List<ExchangeEventRecord> events,
  ) async {
    await db.transaction((txn) async {
      await txn.delete(
        'exchange_events',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
      );
      if (events.isEmpty) return;
      final batch = txn.batch();
      for (final event in events) {
        batch.insert('exchange_events', event.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  /// 한 시간표의 교체 이벤트를 적용 순서(`seq`)대로 조회한다.
  Future<List<ExchangeEventRecord>> getExchangeEvents(
    String timetableId,
  ) async {
    final rows = await db.query(
      'exchange_events',
      where: 'timetable_id = ?',
      whereArgs: [timetableId],
      orderBy: 'seq ASC',
    );
    return rows.map(ExchangeEventRecord.fromMap).toList();
  }

  /// 한 시간표의 교체 이벤트를 전부 지운다(시간표 삭제 시
  /// `TimetableRepository.deleteTimetable`이 이미 처리하므로, 그 외에
  /// 저널만 초기화하고 싶을 때 사용).
  Future<void> deleteExchangeEventsFor(String timetableId) async {
    await db.delete(
      'exchange_events',
      where: 'timetable_id = ?',
      whereArgs: [timetableId],
    );
  }
}

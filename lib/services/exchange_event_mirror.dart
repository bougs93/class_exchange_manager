import 'dart:convert';

import '../models/exchange_event_record.dart';
import '../models/exchange_history_item.dart';

/// [ExchangeHistoryItem] 목록을 SQLite `exchange_events` 저널 행으로 변환한다
/// (S5.1).
///
/// 순수 변환 함수다 — SQLite에 쓰지 않는다(호출부가 `TimetableRepository
/// .upsertExchangeEvents`로 저장한다). 이 시점에는 **JSON이 여전히 진실
/// 원본**이므로, 이 함수의 결과가 잘못되어도 JSON에는 영향이 없다.
///
/// [pathJson]은 `ExchangePath.toJson()`을 그대로 문자열로 담는다 —
/// `ExchangeListStorageService`가 JSON 파일에 쓰는 것과 같은 포맷이다
/// (S5 설계 검토 R1: 직렬화기를 두 개로 나누지 않는다).
///
/// `seq`는 [items]에 주어진 순서(= `ExchangeHistoryService._exchangeList`의
/// 삽입 순서, 곧 실행 순서)를 그대로 쓴다 — 투영(재생)이 이 순서대로
/// 적용되어야 하기 때문이다(S5.4a에서 사용 예정).
List<ExchangeEventRecord> toExchangeEventRecords(
  List<ExchangeHistoryItem> items,
  String timetableId,
) {
  return [
    for (var i = 0; i < items.length; i++)
      _toRecord(items[i], timetableId, seq: i),
  ];
}

ExchangeEventRecord _toRecord(
  ExchangeHistoryItem item,
  String timetableId, {
  required int seq,
}) {
  return ExchangeEventRecord(
    id: item.id,
    timetableId: timetableId,
    seq: seq,
    type: item.type.name,
    absenceDate: item.absenceDate,
    substitutionDate: item.substitutionDate,
    isReverted: item.isReverted,
    pathJson: jsonEncode(item.originalPath.toJson()),
    description: item.description,
    notes: item.notes,
    tags: item.tags,
    profileId: item.profileId,
    metadata: item.metadata,
    createdAt: item.timestamp,
  );
}

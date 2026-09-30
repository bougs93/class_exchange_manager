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
    // S5.6: 비어 있으면(1:1·보강, 또는 노드 날짜를 아직 지정하지 않은
    // 순환·2중) null로 둔다 — toJson()이 빈 맵일 때 키를 생략하는 것과
    // 같은 이유(구 행과 바이트 단위로 같은 의미를 유지).
    nodeDatesJson:
        item.nodeDates.isEmpty
            ? null
            : jsonEncode({
              for (final entry in item.nodeDates.entries)
                entry.key: entry.value.toIso8601String(),
            }),
    description: item.description,
    notes: item.notes,
    tags: item.tags,
    profileId: item.profileId,
    metadata: item.metadata,
    createdAt: item.timestamp,
  );
}

/// [ExchangeEventRecord] 저널 행을 [ExchangeHistoryItem]으로 되돌린다 (S5.4a).
///
/// `lesson_projection.project()`가 `ExchangeHistoryItem`을 받으므로, SQLite에서
/// 읽은 저널로 재생(replay)하려면 이 변환이 필요하다. [ExchangeHistoryItem
/// .fromJson]을 그대로 재사용한다 — 역직렬화 규칙을 두 곳에 두지 않기 위해서다
/// (toExchangeEventRecords의 pathJson이 애초에 `ExchangePath.toJson()`과 같은
/// 포맷이므로 그대로 맞아떨어진다).
ExchangeHistoryItem toExchangeHistoryItem(ExchangeEventRecord record) {
  return ExchangeHistoryItem.fromJson({
    'id': record.id,
    'timestamp': record.createdAt.toIso8601String(),
    'absenceDate': record.absenceDate.toIso8601String(),
    'substitutionDate': record.substitutionDate.toIso8601String(),
    'type': record.type,
    'description': record.description,
    'metadata': record.metadata,
    'notes': record.notes,
    'tags': record.tags,
    'profileId': record.profileId,
    'isReverted': record.isReverted,
    if (record.nodeDatesJson != null)
      'nodeDates': jsonDecode(record.nodeDatesJson!),
    'originalPath': jsonDecode(record.pathJson),
  });
}

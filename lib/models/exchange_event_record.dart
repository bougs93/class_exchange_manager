import 'dart:convert';

/// SQLite `exchange_events` 테이블 한 행 (S5.0)
///
/// [ExchangeHistoryItem]을 SQLite에 그대로 미러링하기 위한 저장 전용
/// 표현이다. 이 클래스 자체는 교체 로직을 전혀 갖지 않는다 — 직렬화·
/// 역직렬화만 담당한다.
///
/// [pathJson]은 `ExchangePath.toJson()` 결과를 그대로 문자열로 담는다.
/// `ExchangeListStorageService`가 JSON 파일에 쓰는 것과 **같은 포맷**을
/// 재사용해야 한다 — 직렬화기를 두 개로 나누면 언젠가 서로 어긋난다(S5
/// 설계 검토 R1).
///
/// S5.0 시점에는 어떤 서비스도 이 클래스를 만들거나 저장소에 쓰지 않는다.
class ExchangeEventRecord {
  final String id;
  final String timetableId;

  /// 적용 순서(단조 증가). 투영(재생) 시 이 순서대로 적용한다(S5.4a 예정).
  final int seq;

  /// `ExchangePathType.name` ('oneToOne'/'circular'/'dual'/'supplement')
  final String type;

  final DateTime absenceDate;
  final DateTime substitutionDate;
  final bool isReverted;

  /// `ExchangePath.toJson()`을 그대로 담은 JSON 문자열
  final String pathJson;

  /// 순환·2중 교체의 노드별 날짜 (OQ-1 채택 — 현재는 항상 null, S5.4에서 사용)
  final String? nodeDatesJson;

  final String description;
  final String? notes;
  final List<String> tags;
  final String? profileId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const ExchangeEventRecord({
    required this.id,
    required this.timetableId,
    required this.seq,
    required this.type,
    required this.absenceDate,
    required this.substitutionDate,
    required this.isReverted,
    required this.pathJson,
    this.nodeDatesJson,
    required this.description,
    this.notes,
    required this.tags,
    this.profileId,
    required this.metadata,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'timetable_id': timetableId,
      'seq': seq,
      'type': type,
      'absence_date': _formatDate(absenceDate),
      'substitution_date': _formatDate(substitutionDate),
      'is_reverted': isReverted ? 1 : 0,
      'path_json': pathJson,
      'node_dates_json': nodeDatesJson,
      'description': description,
      'notes': notes,
      'tags_json': jsonEncode(tags),
      'profile_id': profileId,
      'metadata_json': jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ExchangeEventRecord.fromMap(Map<String, Object?> map) {
    return ExchangeEventRecord(
      id: map['id'] as String,
      timetableId: map['timetable_id'] as String,
      seq: map['seq'] as int,
      type: map['type'] as String,
      absenceDate: DateTime.parse(map['absence_date'] as String),
      substitutionDate: DateTime.parse(map['substitution_date'] as String),
      isReverted: (map['is_reverted'] as int) != 0,
      pathJson: map['path_json'] as String,
      nodeDatesJson: map['node_dates_json'] as String?,
      description: map['description'] as String,
      notes: map['notes'] as String?,
      tags: List<String>.from(jsonDecode(map['tags_json'] as String) as List),
      profileId: map['profile_id'] as String?,
      metadata: Map<String, dynamic>.from(
        jsonDecode(map['metadata_json'] as String) as Map,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  String toString() =>
      'ExchangeEventRecord(id: $id, seq: $seq, type: $type, '
      'absenceDate: $absenceDate, isReverted: $isReverted)';
}

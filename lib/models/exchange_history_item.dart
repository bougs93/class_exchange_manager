import 'exchange_path.dart';
import 'one_to_one_exchange_path.dart';
import 'circular_exchange_path.dart';
import 'dual_exchange_path.dart';
import 'supplement_exchange_path.dart';
import '../utils/exchange_node_slot.dart';
import '../utils/week_date_calculator.dart';

/// 교체 히스토리 항목을 나타내는 클래스
/// 교체 실행의 모든 정보를 담는 데이터 모델
class ExchangeHistoryItem {
  /// 고유 식별자
  final String id;

  /// 실행 시간 (감사 로그용 — "언제 이 조작을 했는가". 교체가 적용되는
  /// 날짜는 [absenceDate]/[substitutionDate]이며 이 값과 다를 수 있다)
  final DateTime timestamp;

  /// 결강일 — 이 교체로 비게 되는 수업의 날짜 (필수)
  ///
  /// §10.6: 문자열이 아닌 DateTime으로 저장한다. 이 값이 이 교체 건의
  /// 소속 주(週)를 결정한다 ([weekMonday]).
  final DateTime absenceDate;

  /// 교체일 — 보강/이동되는 수업의 날짜 (필수)
  final DateTime substitutionDate;

  /// 원본 교체 경로
  final ExchangePath originalPath;

  /// 사용자 친화적 설명
  final String description;

  /// 교체 타입 (1:1, 순환, 2중)
  final ExchangePathType type;

  /// 추가 메타데이터
  final Map<String, dynamic> metadata;

  /// 사용자 메모
  final String? notes;

  /// 태그 목록
  final List<String> tags;

  /// 지정된 인쇄 프로파일(계획서) ID (미지정 시 null → 기본 계획서 사용)
  final String? profileId;

  /// 되돌리기 여부
  bool isReverted;

  /// 순환·2중 교체의 노드(슬롯)별 확정 날짜 (S5.6).
  ///
  /// 키는 [nodeSlotKey]로 만든다('요일|교시', 예: '수|3'). 1:1·보강은 이
  /// 맵을 쓰지도 읽지도 않는다 — 노드가 2개뿐이라 [absenceDate]/
  /// [substitutionDate] 쌍이 이미 완전한 표현이기 때문이다([supportsNodeDates] 참조).
  ///
  /// 비어 있으면(기본값) "확정된 노드 없음" — S5.6 이전과 완전히 동일하게
  /// "결강일이 속한 주"로 추정한다(OQ-1). 이 필드가 기존 동작에 전혀 영향을
  /// 주지 않는다는 것이 S5.6.0~S5.6.4의 회귀-없음 증거다.
  final Map<String, DateTime> nodeDates;

  /// 순환·2중 교체인지 — 노드별 날짜 확정을 지원하는 유형인지 판단할 때 쓴다.
  bool get supportsNodeDates =>
      type == ExchangePathType.circular || type == ExchangePathType.dual;

  /// [dayName]·[period] 슬롯에 확정된 날짜가 있으면 반환한다.
  DateTime? nodeDateFor(String dayName, int period) =>
      nodeDates[nodeSlotKey(dayName, period)];

  /// 이 교체 건이 속한 주의 월요일 ([absenceDate] 기준)
  ///
  /// §10.5: 교체의 "주인"은 결강이므로 주차 칩 건수·주차별 그룹핑은
  /// 모두 이 값을 기준으로 한다. 보강일이 다음 주로 넘어가더라도
  /// (결강 금요일 → 보강 다음 주 월요일) 이 건은 결강일의 주에 속한다.
  DateTime get weekMonday => WeekDateCalculator.getWeekMonday(absenceDate);

  /// 생성자
  ExchangeHistoryItem({
    required this.id,
    required this.timestamp,
    required this.absenceDate,
    required this.substitutionDate,
    required this.originalPath,
    required this.description,
    required this.type,
    required this.metadata,
    this.notes,
    required this.tags,
    this.profileId,
    this.isReverted = false,
    this.nodeDates = const {},
  });

  /// ExchangePath로부터 ExchangeHistoryItem 생성하는 팩토리 생성자
  ///
  /// [absenceDate]/[substitutionDate]는 필수다 — 교체를 실행하는 시점에
  /// 이미 "어느 주를 보고 있는가"가 확정되어 있어야 한다(§10.4 날짜 선행 확정).
  /// 사후에 날짜를 입력받아 채우지 않는다.
  ///
  /// [nodeDates]는 순환·2중 교체 전용(S5.6.7) — 호출부(`ExchangeExecutor`)가
  /// 실행 시점에 이미 알고 있는 각 노드(슬롯)의 실제 날짜를
  /// [seedNodeDatesForWeek]로 계산해 넘긴다. 미지정(null)이면 기존과
  /// 완전히 동일한 빈 맵이다. 1:1·보강에는 절대 저장하지 않는다
  /// ([copyWithNodeDate]와 같은 오염 방지 정책 — 2노드는 이미 결강일/교체일
  /// 쌍만으로 완전히 표현되므로 죽은 데이터가 된다).
  factory ExchangeHistoryItem.fromExchangePath(
    ExchangePath path, {
    required DateTime absenceDate,
    required DateTime substitutionDate,
    String? customId,
    String? customDescription,
    Map<String, dynamic>? additionalMetadata,
    String? notes,
    List<String>? tags,
    int? stepCount, // 순환교체 단계 수 (선택적)
    Map<String, DateTime>? nodeDates,
  }) {
    final pathType = _getPathType(path);
    final generatedId = customId ?? _generateId(pathType, stepCount);
    final supportsNodeDates =
        pathType == ExchangePathType.circular || pathType == ExchangePathType.dual;

    return ExchangeHistoryItem(
      id: generatedId,
      timestamp: DateTime.now(),
      absenceDate: _dateOnly(absenceDate),
      substitutionDate: _dateOnly(substitutionDate),
      originalPath: path,
      description: customDescription ?? path.displayTitle,
      type: pathType,
      metadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'manual',
        'pathId': path.id,
        if (stepCount != null) 'stepCount': stepCount,
        ...?additionalMetadata,
      },
      notes: notes,
      tags: tags ?? [],
      isReverted: false,
      nodeDates:
          supportsNodeDates && nodeDates != null
              ? {for (final entry in nodeDates.entries) entry.key: _dateOnly(entry.value)}
              : const {},
    );
  }

  /// 시각 정보를 제거하고 날짜만 남긴다 (주차 계산·비교의 일관성을 위해)
  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// 고유 ID 생성 (교체 유형 및 단계 정보 포함)
  /// microsecond + 순번으로 동일 시각 연속 교체 시 ID 충돌 방지
  static int _idSequence = 0;

  static String _generateId(ExchangePathType pathType, [int? stepCount]) {
    final now = DateTime.now();
    final sequence = _idSequence++;
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}_'
        '${now.microsecond.toString().padLeft(6, '0')}_$sequence';

    switch (pathType) {
      case ExchangePathType.oneToOne:
        return 'one_to_one_exchange_$timestamp';
      case ExchangePathType.circular:
        if (stepCount != null) {
          return 'circular_exchange_${stepCount}_$timestamp';
        }
        return 'circular_exchange_$timestamp';
      case ExchangePathType.dual:
        return 'dual_exchange_$timestamp';
      case ExchangePathType.supplement:
        return 'supplement_exchange_$timestamp';
    }
  }

  /// ExchangePath의 타입을 ExchangePathType으로 변환
  static ExchangePathType _getPathType(ExchangePath path) {
    if (path.toString().contains('OneToOneExchangePath')) {
      return ExchangePathType.oneToOne;
    } else if (path.toString().contains('CircularExchangePath')) {
      return ExchangePathType.circular;
    } else if (path.toString().contains('DualExchangePath')) {
      return ExchangePathType.dual;
    } else if (path.toString().contains('SupplementExchangePath')) {
      return ExchangePathType.supplement;
    }
    return ExchangePathType.oneToOne; // 기본값
  }

  /// 되돌리기 상태 변경
  ExchangeHistoryItem copyWithReverted(bool reverted) {
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      absenceDate: absenceDate,
      substitutionDate: substitutionDate,
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: metadata,
      notes: notes,
      tags: tags,
      profileId: profileId,
      isReverted: reverted,
      nodeDates: nodeDates,
    );
  }

  /// 메모 업데이트
  ExchangeHistoryItem copyWithNotes(String? newNotes) {
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      absenceDate: absenceDate,
      substitutionDate: substitutionDate,
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: metadata,
      notes: newNotes,
      tags: tags,
      profileId: profileId,
      isReverted: isReverted,
      nodeDates: nodeDates,
    );
  }

  /// 결강일·교체일 수정 (결보강 계획서 화면에서 사용자가 날짜를 보정할 때)
  ///
  /// `savedDates` 제거 이후(§10.10) 이 값이 날짜의 유일한 진실원본이다.
  /// null을 넘긴 필드는 바꾸지 않는다. [weekMonday]가 달라지면(다른 주로
  /// 옮겨가면) 이 교체가 속한 주 자체가 바뀐다 — 호출부가 사전에 사용자
  /// 확인을 받아야 한다(§10.5 A안과 동일 원칙, 문서 §10.10 참조).
  ExchangeHistoryItem copyWithDates({
    DateTime? absenceDate,
    DateTime? substitutionDate,
  }) {
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      absenceDate: absenceDate == null ? this.absenceDate : _dateOnly(absenceDate),
      substitutionDate:
          substitutionDate == null
              ? this.substitutionDate
              : _dateOnly(substitutionDate),
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: metadata,
      notes: notes,
      tags: tags,
      profileId: profileId,
      isReverted: isReverted,
      nodeDates: nodeDates,
    );
  }

  /// 태그 업데이트
  ExchangeHistoryItem copyWithTags(List<String> newTags) {
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      absenceDate: absenceDate,
      substitutionDate: substitutionDate,
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: metadata,
      notes: notes,
      tags: newTags,
      profileId: profileId,
      isReverted: isReverted,
      nodeDates: nodeDates,
    );
  }

  /// 메타데이터 업데이트
  ExchangeHistoryItem copyWithMetadata(Map<String, dynamic> newMetadata) {
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      absenceDate: absenceDate,
      substitutionDate: substitutionDate,
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: {...metadata, ...newMetadata},
      notes: notes,
      tags: tags,
      profileId: profileId,
      isReverted: isReverted,
      nodeDates: nodeDates,
    );
  }

  /// 인쇄 프로파일(계획서) 지정 업데이트
  ExchangeHistoryItem copyWithProfileId(String? newProfileId) {
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      absenceDate: absenceDate,
      substitutionDate: substitutionDate,
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: metadata,
      notes: notes,
      tags: tags,
      profileId: newProfileId,
      isReverted: isReverted,
      nodeDates: nodeDates,
    );
  }

  /// 노드(슬롯)별 확정 날짜 하나를 추가·갱신한다 (S5.6).
  ///
  /// 순환·2중 교체 전용 — [supportsNodeDates]가 false인 1:1·보강 항목에
  /// 호출하면 아무것도 바꾸지 않고 자기 자신을 그대로 반환한다(조용한
  /// 오염 방지). 요일·교시 검증(그 슬롯이 실제로 이 교체 경로에 존재하는지,
  /// 저장하는 날짜의 실제 요일이 [dayName]과 일치하는지)은 호출부
  /// (`ExchangeHistoryService.updateNodeDate`)의 책임이다 — 이 메서드는
  /// 순수하게 맵만 갱신한다.
  ExchangeHistoryItem copyWithNodeDate(String dayName, int period, DateTime date) {
    if (!supportsNodeDates) return this;
    final updated = Map<String, DateTime>.from(nodeDates);
    updated[nodeSlotKey(dayName, period)] = _dateOnly(date);
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      absenceDate: absenceDate,
      substitutionDate: substitutionDate,
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: metadata,
      notes: notes,
      tags: tags,
      profileId: profileId,
      isReverted: isReverted,
      nodeDates: updated,
    );
  }

  /// 실행 시간을 포맷된 문자열로 반환
  String get formattedTimestamp {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// 교체 타입의 한국어 이름 반환
  String get typeDisplayName => type.displayName;

  /// 교체 타입의 아이콘 반환
  String get typeIcon => type.icon;

  /// 참여 교사 목록 반환 (메타데이터에서 추출)
  List<String> get involvedTeachers {
    return metadata['involvedTeachers']?.cast<String>() ?? [];
  }

  /// 참여 학급 목록 반환 (메타데이터에서 추출)
  List<String> get involvedClasses {
    return metadata['involvedClasses']?.cast<String>() ?? [];
  }

  /// 참여 과목 목록 반환 (메타데이터에서 추출)
  List<String> get involvedSubjects {
    return metadata['involvedSubjects']?.cast<String>() ?? [];
  }

  /// 교체 효율성 점수 반환 (메타데이터에서 추출)
  double get efficiencyScore {
    return metadata['efficiencyScore']?.toDouble() ?? 0.0;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExchangeHistoryItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ExchangeHistoryItem(id: $id, timestamp: $timestamp, absenceDate: $absenceDate, '
        'type: $typeDisplayName, description: $description, isReverted: $isReverted)';
  }

  /// JSON 직렬화 (저장용)
  ///
  /// ExchangeHistoryItem을 Map 형태로 변환하여 JSON 파일에 저장할 수 있도록 합니다.
  /// ExchangePath는 타입별로 적절히 직렬화됩니다.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'absenceDate': absenceDate.toIso8601String(),
      'substitutionDate': substitutionDate.toIso8601String(),
      'type': type.name, // enum을 문자열로 저장
      'description': description,
      'metadata': metadata,
      'notes': notes,
      'tags': tags,
      'profileId': profileId,
      'isReverted': isReverted,
      // 비어 있으면 키 자체를 생략한다 — S5.6 이전에 저장된 파일과 바이트
      // 단위로 같은 결과를 내기 위해서다(이 필드를 아직 쓰지 않는 모든
      // 1:1·보강 항목, 그리고 노드 날짜를 한 번도 지정하지 않은 순환·2중
      // 항목 전부 해당).
      if (nodeDates.isNotEmpty)
        'nodeDates': {
          for (final entry in nodeDates.entries)
            entry.key: entry.value.toIso8601String(),
        },
      'originalPath':
          originalPath.toJson(), // ExchangePath는 타입 정보를 포함한 JSON으로 저장
    };
  }

  /// JSON 역직렬화 (로드용)
  ///
  /// JSON 파일에서 읽어온 Map 데이터를 ExchangeHistoryItem 객체로 변환합니다.
  /// ExchangePath는 타입에 따라 적절한 서브클래스로 복원됩니다.
  ///
  /// `absenceDate`/`substitutionDate`가 없는 구 형식 데이터는 지원하지 않는다
  /// (§10.6: 마이그레이션 없음 — 구 파일은 로드 이전에 스키마 버전으로 걸러진다).
  /// 필드가 없으면 예외를 던지며, 호출부(`ExchangeListStorageService`)가
  /// 개별 항목 단위로 이를 잡아 건너뛴다.
  factory ExchangeHistoryItem.fromJson(Map<String, dynamic> json) {
    final pathJson = json['originalPath'] as Map<String, dynamic>;
    final pathType = pathJson['type'] as String;

    // ExchangePath 타입에 따라 적절한 서브클래스로 복원
    final ExchangePath path;
    switch (pathType) {
      case 'oneToOne':
        path = OneToOneExchangePath.fromJson(pathJson);
        break;
      case 'circular':
        path = CircularExchangePath.fromJson(pathJson);
        break;
      case 'dual':
        path = DualExchangePath.fromJson(pathJson);
        break;
      case 'supplement':
        path = SupplementExchangePath.fromJson(pathJson);
        break;
      default:
        throw FormatException('알 수 없는 ExchangePath 타입: $pathType');
    }

    // ExchangePathType enum 변환
    final ExchangePathType type;
    switch (json['type'] as String) {
      case 'oneToOne':
        type = ExchangePathType.oneToOne;
        break;
      case 'circular':
        type = ExchangePathType.circular;
        break;
      case 'dual':
        type = ExchangePathType.dual;
        break;
      case 'supplement':
        type = ExchangePathType.supplement;
        break;
      default:
        type = ExchangePathType.oneToOne;
    }

    return ExchangeHistoryItem(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      absenceDate: DateTime.parse(json['absenceDate'] as String),
      substitutionDate: DateTime.parse(json['substitutionDate'] as String),
      originalPath: path,
      description: json['description'] as String,
      type: type,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      notes: json['notes'] as String?,
      tags: List<String>.from(json['tags'] as List),
      profileId: json['profileId'] as String?,
      isReverted: json['isReverted'] as bool? ?? false,
      nodeDates: (json['nodeDates'] as Map?)?.map(
            (key, value) =>
                MapEntry(key as String, DateTime.parse(value as String)),
          ) ??
          const {},
    );
  }
}

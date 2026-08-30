import 'exchange_path.dart';
import 'one_to_one_exchange_path.dart';
import 'circular_exchange_path.dart';
import 'dual_exchange_path.dart';
import 'supplement_exchange_path.dart';
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
  });

  /// ExchangePath로부터 ExchangeHistoryItem 생성하는 팩토리 생성자
  ///
  /// [absenceDate]/[substitutionDate]는 필수다 — 교체를 실행하는 시점에
  /// 이미 "어느 주를 보고 있는가"가 확정되어 있어야 한다(§10.4 날짜 선행 확정).
  /// 사후에 날짜를 입력받아 채우지 않는다.
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
  }) {
    final pathType = _getPathType(path);
    final generatedId = customId ?? _generateId(pathType, stepCount);

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
    );
  }
}

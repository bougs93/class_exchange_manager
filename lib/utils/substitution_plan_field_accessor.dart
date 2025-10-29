import '../providers/substitution_plan_viewmodel.dart';

/// SubstitutionPlanData 필드 접근 유틸리티
///
/// PDF 서비스와 UI에서 사용하는 서로 다른 필드 키 네이밍을 통합합니다.
/// - PDF: 축약형 키 ('date', 'day', '2subject' 등)
/// - UI: 전체 키 이름 ('absenceDate', 'absenceDay', 'supplementSubject' 등)
class SubstitutionPlanFieldAccessor {
  /// 키 매핑 테이블 (축약형 → 전체 이름)
  ///
  /// PDF 템플릿에서 사용하는 축약형 키를 SubstitutionPlanData의 실제 필드명으로 변환합니다.
  static const Map<String, String> keyMapping = {
    // 결강 정보
    'date': 'absenceDate',
    'day': 'absenceDay',
    'period': 'period',
    'grade': 'grade',
    'class': 'className',
    'subject': 'subject',
    'teacher': 'teacher',

    // 보강/수업변경 정보
    '2subject': 'supplementSubject',
    '2teacher': 'supplementTeacher',

    // 교체 정보
    '3date': 'substitutionDate',
    '3day': 'substitutionDay',
    '3period': 'substitutionPeriod',
    '3subject': 'substitutionSubject',
    '3teacher': 'substitutionTeacher',

    // 비고
    'remarks': 'remarks',

    // 그룹 ID
    'groupId': 'groupId',
  };

  /// 역방향 매핑 (전체 이름 → 축약형)
  ///
  /// UI에서 축약형 키로 변환할 때 사용합니다.
  static final Map<String, String> reverseMapping = {
    for (final entry in keyMapping.entries) entry.value: entry.key,
  };

  /// 통합 필드 접근 (축약형 또는 전체 키 모두 지원)
  ///
  /// [data] SubstitutionPlanData 객체
  /// [key] 필드 키 (축약형 또는 전체 이름)
  ///
  /// Returns: 필드 값
  ///
  /// 예:
  /// ```dart
  /// getValue(data, 'date') // '2024-01-15' (축약형)
  /// getValue(data, 'absenceDate') // '2024-01-15' (전체 이름)
  /// ```
  static String getValue(SubstitutionPlanData data, String key) {
    // 키가 축약형이면 전체 이름으로 변환
    final normalizedKey = keyMapping[key] ?? key;

    // SubstitutionPlanData Extension 메서드 사용
    return switch (normalizedKey) {
      'absenceDate' => data.absenceDate,
      'absenceDay' => data.absenceDay,
      'period' => data.period,
      'grade' => data.grade,
      'className' => data.className,
      'subject' => data.subject,
      'teacher' => data.teacher,
      'supplementSubject' => data.supplementSubject,
      'supplementTeacher' => data.supplementTeacher,
      'substitutionDate' => data.substitutionDate,
      'substitutionDay' => data.substitutionDay,
      'substitutionPeriod' => data.substitutionPeriod,
      'substitutionSubject' => data.substitutionSubject,
      'substitutionTeacher' => data.substitutionTeacher,
      'remarks' => data.remarks,
      'groupId' => data.groupId ?? '',
      _ => '', // 알 수 없는 키는 빈 문자열 반환
    };
  }

  /// 축약형 키로 변환
  ///
  /// [fullKey] 전체 필드 이름
  ///
  /// Returns: 축약형 키 (변환 불가능하면 원본 반환)
  ///
  /// 예:
  /// ```dart
  /// toShortKey('absenceDate') // 'date'
  /// toShortKey('supplementSubject') // '2subject'
  /// ```
  static String toShortKey(String fullKey) {
    return reverseMapping[fullKey] ?? fullKey;
  }

  /// 전체 키로 변환
  ///
  /// [shortKey] 축약형 키
  ///
  /// Returns: 전체 필드 이름 (변환 불가능하면 원본 반환)
  ///
  /// 예:
  /// ```dart
  /// toFullKey('date') // 'absenceDate'
  /// toFullKey('2subject') // 'supplementSubject'
  /// ```
  static String toFullKey(String shortKey) {
    return keyMapping[shortKey] ?? shortKey;
  }

  /// 모든 지원되는 축약형 키 목록
  static List<String> get supportedShortKeys => keyMapping.keys.toList();

  /// 모든 지원되는 전체 키 목록
  static List<String> get supportedFullKeys => keyMapping.values.toList();
}

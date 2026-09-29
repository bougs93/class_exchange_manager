/// 날짜별 수업 배치 1건 (S2 — 아직 화면·저장소에 연결되지 않은 순수 모델)
///
/// 기존 `TimeSlot`(요일 기준)과 달리 실제 캘린더 날짜를 좌표로 갖는다.
/// 셀 문자열(`TimeSlot.displayText`처럼)은 여기서 만들지 않는다 — 화면 표시용
/// 조합은 UI 계층의 책임이고, 이 모델은 구조화된 필드만 담는다(§10.4 원칙).
///
/// 불변 조건(계획서 참고):
/// - [id]는 날짜·교시가 바뀌어도(교체로 이동해도) 유지되는 수업의 고유 식별자다.
/// - [date]는 시각이 없는 날짜 전용 값으로 정규화한다(타임존 변환으로 하루가
///   바뀌지 않도록).
class Lesson {
  final String id;
  final String timetableId;
  final DateTime date;
  final int period;
  final String teacher;
  final String? subject;
  final String? className;
  final bool isExchangeable;
  final String? exchangeReason;

  /// 활성 조회 대상인지 (S3a — 학기 기간 축소로 제외된 날짜는 false).
  ///
  /// 삭제하지 않고 보관한다 — 기간을 다시 확장하면 그대로 재사용한다.
  /// `lesson_snapshots`(원본 스냅샷)에서는 이 값을 실제로 읽지 않는다.
  final bool isActive;

  Lesson({
    required this.id,
    required this.timetableId,
    required DateTime date,
    required this.period,
    required this.teacher,
    this.subject,
    this.className,
    this.isExchangeable = true,
    this.exchangeReason,
    this.isActive = true,
  }) : date = _dateOnly(date);

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// 과목·학급이 모두 없는 빈 수업인지 (TimeSlot.isEmpty와 동일한 규칙)
  bool get isEmpty {
    final hasSubject = subject != null && subject!.trim().isNotEmpty;
    final hasClass = className != null && className!.trim().isNotEmpty;
    return !hasSubject && !hasClass;
  }

  bool get isNotEmpty => !isEmpty;

  bool get canExchange => isExchangeable && isNotEmpty;

  Lesson copyWith({
    DateTime? date,
    int? period,
    String? teacher,
    String? subject,
    String? className,
    bool? isExchangeable,
    String? exchangeReason,
    bool? isActive,
    bool clearSubjectAndClass = false,
  }) {
    return Lesson(
      id: id,
      timetableId: timetableId,
      date: date ?? this.date,
      period: period ?? this.period,
      teacher: teacher ?? this.teacher,
      subject: clearSubjectAndClass ? null : (subject ?? this.subject),
      className: clearSubjectAndClass ? null : (className ?? this.className),
      isExchangeable: isExchangeable ?? this.isExchangeable,
      exchangeReason: exchangeReason ?? this.exchangeReason,
      isActive: isActive ?? this.isActive,
    );
  }

  /// SQLite 행으로 변환 ([TimetableRepository]가 사용)
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'timetable_id': timetableId,
      'date': _formatDate(date),
      'period': period,
      'teacher': teacher,
      'subject': subject,
      'class_name': className,
      'is_exchangeable': isExchangeable ? 1 : 0,
      'exchange_reason': exchangeReason,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Lesson.fromMap(Map<String, Object?> map) {
    return Lesson(
      id: map['id'] as String,
      timetableId: map['timetable_id'] as String,
      date: DateTime.parse(map['date'] as String),
      period: map['period'] as int,
      teacher: map['teacher'] as String,
      subject: map['subject'] as String?,
      className: map['class_name'] as String?,
      isExchangeable: (map['is_exchangeable'] as int? ?? 1) != 0,
      exchangeReason: map['exchange_reason'] as String?,
      isActive: (map['is_active'] as int? ?? 1) != 0,
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// 고유 ID 생성 (동일 시각 연속 생성 충돌 방지를 위해 마이크로초+시퀀스 포함)
  ///
  /// `TimetableRegistryEntry.generateId`와 동일한 방식 — 새 패키지(uuid 등)를
  /// 추가하지 않고 기존 프로젝트 관례를 따른다.
  static int _idSequence = 0;

  static String generateId({DateTime? now}) {
    final t = now ?? DateTime.now();
    final sequence = _idSequence++;
    final stamp =
        '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}'
        '_'
        '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}${t.second.toString().padLeft(2, '0')}'
        '_${t.microsecond.toString().padLeft(6, '0')}_$sequence';
    return 'lsn_$stamp';
  }

  @override
  String toString() =>
      'Lesson(id: $id, date: ${_formatDate(date)}, period: $period, teacher: $teacher, subject: $subject)';
}

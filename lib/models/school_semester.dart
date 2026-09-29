/// 학기 범위 값 객체 (S1 — 날짜 기반 시간표 전환의 첫 단계)
///
/// UI·저장소와 아직 연결되지 않은 순수 모델이다. 학년도·학기·시작일·종료일만
/// 표현하며, 실제 등록된 시간표(`TimetableRegistryEntry.semesterStart/End`)와는
/// 별개다 — 이 모델은 "학기 하나의 날짜 범위"라는 개념 자체를 나타낸다.
///
/// 시작·종료일은 항상 시각이 없는 날짜 전용 값으로 정규화한다(§ 날짜 모델
/// 불변 조건 — 타임존 변환으로 하루가 바뀌지 않아야 한다).
class SchoolSemester {
  /// 학년도 — 2학기는 시작 연도로 표시한다 (예: 2026학년도 2학기는 2026-08 ~ 2027-01).
  final int schoolYear;

  /// 학기 (1 또는 2)
  final int semester;

  /// 학기 시작일 (포함)
  final DateTime startDate;

  /// 학기 종료일 (포함)
  final DateTime endDate;

  SchoolSemester({
    required this.schoolYear,
    required this.semester,
    required DateTime startDate,
    required DateTime endDate,
  }) : assert(semester == 1 || semester == 2, '학기는 1 또는 2만 허용한다'),
       startDate = _dateOnly(startDate),
       endDate = _dateOnly(endDate) {
    assert(
      !this.endDate.isBefore(this.startDate),
      '종료일이 시작일보다 앞설 수 없다',
    );
  }

  /// 확정된 기본값으로 학기 범위를 생성한다.
  ///
  /// - 1학기: 해당 연도 3/1 ~ 7/31
  /// - 2학기: 해당 연도 8/1 ~ 다음 연도 1/31
  factory SchoolSemester.defaultFor({
    required int schoolYear,
    required int semester,
  }) {
    assert(semester == 1 || semester == 2, '학기는 1 또는 2만 허용한다');
    if (semester == 1) {
      return SchoolSemester(
        schoolYear: schoolYear,
        semester: 1,
        startDate: DateTime(schoolYear, 3, 1),
        endDate: DateTime(schoolYear, 7, 31),
      );
    }
    return SchoolSemester(
      schoolYear: schoolYear,
      semester: 2,
      startDate: DateTime(schoolYear, 8, 1),
      endDate: DateTime(schoolYear + 1, 1, 31),
    );
  }

  /// 주어진 날짜가 이 학기 범위 안에 있는지 (시작·종료일 포함)
  bool contains(DateTime date) {
    final d = _dateOnly(date);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  /// 주어진 날짜가 기본 학기 범위([defaultFor]) 중 어디에 속하는지 추정한다 (S3).
  ///
  /// 사용자가 학년도·학기를 직접 고르는 UI가 아직 없는 곳에서, "지금이 대략
  /// 몇 학년도 몇 학기인가"의 기본값을 추측할 때 쓴다 — 정확한 값이 필요하면
  /// (예: 준비 > 기타 설정에서 실제 적용 범위를 확인한 뒤) 사용자가 나중에
  /// 고칠 수 있어야 한다. 이 추정값 자체를 진실 원본으로 취급하지 않는다.
  ///
  /// 2/1~2/28처럼 1학기 시작 전이면서 2학기 기본 범위(~다음 해 1/31)도 지난
  /// 애매한 구간은 해당 연도 1학기로 처리한다(임박한 새 학기로 간주).
  factory SchoolSemester.containing(DateTime date) {
    final d = _dateOnly(date);
    for (final year in [d.year, d.year - 1]) {
      final first = SchoolSemester.defaultFor(schoolYear: year, semester: 1);
      if (first.contains(d)) return first;
      final second = SchoolSemester.defaultFor(schoolYear: year, semester: 2);
      if (second.contains(d)) return second;
    }
    return SchoolSemester.defaultFor(schoolYear: d.year, semester: 1);
  }

  /// 시각을 제거하고 날짜만 남긴다 (로컬 날짜 기준, 시간대 변환 없음)
  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  SchoolSemester copyWith({
    int? schoolYear,
    int? semester,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return SchoolSemester(
      schoolYear: schoolYear ?? this.schoolYear,
      semester: semester ?? this.semester,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  String toString() =>
      'SchoolSemester($schoolYear학년도 $semester학기, $startDate ~ $endDate)';

  @override
  bool operator ==(Object other) =>
      other is SchoolSemester &&
      other.schoolYear == schoolYear &&
      other.semester == semester &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(schoolYear, semester, startDate, endDate);
}

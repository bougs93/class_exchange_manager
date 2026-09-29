import 'school_semester.dart';

/// SQLite에 저장되는 시간표(학기) 1건의 메타데이터 (S2)
///
/// 기존 JSON 기반 `TimetableRegistryEntry`(사용 중, 변경하지 않음)와는 별개의
/// 새 저장소용 모델이다. 학기 범위는 [SchoolSemester]를 그대로 재사용한다.
class DatedTimetable {
  final String id;
  final String name;
  final SchoolSemester semester;
  final String? teacherName;
  final String? schoolName;
  final DateTime registeredAt;
  final int revision;

  DatedTimetable({
    required this.id,
    required this.name,
    required this.semester,
    this.teacherName,
    this.schoolName,
    required this.registeredAt,
    this.revision = 1,
  });

  DatedTimetable copyWith({
    String? name,
    SchoolSemester? semester,
    String? teacherName,
    String? schoolName,
    int? revision,
  }) {
    return DatedTimetable(
      id: id,
      name: name ?? this.name,
      semester: semester ?? this.semester,
      teacherName: teacherName ?? this.teacherName,
      schoolName: schoolName ?? this.schoolName,
      registeredAt: registeredAt,
      revision: revision ?? this.revision,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'school_year': semester.schoolYear,
      'semester': semester.semester,
      'start_date': _formatDate(semester.startDate),
      'end_date': _formatDate(semester.endDate),
      'teacher_name': teacherName,
      'school_name': schoolName,
      'registered_at': registeredAt.toIso8601String(),
      'revision': revision,
    };
  }

  factory DatedTimetable.fromMap(Map<String, Object?> map) {
    return DatedTimetable(
      id: map['id'] as String,
      name: map['name'] as String,
      semester: SchoolSemester(
        schoolYear: map['school_year'] as int,
        semester: map['semester'] as int,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: DateTime.parse(map['end_date'] as String),
      ),
      teacherName: map['teacher_name'] as String?,
      schoolName: map['school_name'] as String?,
      registeredAt: DateTime.parse(map['registered_at'] as String),
      revision: map['revision'] as int? ?? 1,
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  String toString() => 'DatedTimetable(id: $id, name: $name, $semester)';
}

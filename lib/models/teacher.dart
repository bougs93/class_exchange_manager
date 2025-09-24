/// 교사 정보를 나타내는 모델 클래스
class Teacher {
  int? id;           // 교사 ID
  String name;       // 교사명
  String subject;    // 담당 과목
  String? remarks;   // 비고
  
  Teacher({
    this.id,
    required this.name,
    required this.subject,
    this.remarks,
  });
  
  /// 복사본 생성
  Teacher copyWith({
    int? id,
    String? name,
    String? subject,
    String? remarks,
  }) {
    return Teacher(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      remarks: remarks ?? this.remarks,
    );
  }
  
  @override
  String toString() {
    return 'Teacher(id: $id, name: $name, subject: $subject, remarks: $remarks)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Teacher &&
        other.id == id &&
        other.name == name &&
        other.subject == subject &&
        other.remarks == remarks;
  }
  
  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ subject.hashCode ^ remarks.hashCode;
  }
}


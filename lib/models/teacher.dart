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
  
  /// JSON 직렬화 (저장용)
  /// 
  /// Teacher를 Map 형태로 변환하여 JSON 파일에 저장할 수 있도록 합니다.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'remarks': remarks,
    };
  }
  
  /// JSON 역직렬화 (로드용)
  /// 
  /// JSON 파일에서 읽어온 Map 데이터를 Teacher 객체로 변환합니다.
  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as int?,
      name: json['name'] as String,
      subject: json['subject'] as String,
      remarks: json['remarks'] as String?,
    );
  }
}


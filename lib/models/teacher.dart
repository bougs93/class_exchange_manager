/// 교사 정보를 나타내는 모델 클래스
class Teacher {
  int? id;           // 교사 ID
  String name;       // 교사명
  String subject;    // 담당 과목
  String? department; // 부서
  String? phone;     // 연락처
  String? qrCode;    // QR 코드
  bool isActive;     // 활성 상태
  DateTime? createdAt; // 생성일
  
  Teacher({
    this.id,
    required this.name,
    required this.subject,
    this.department,
    this.phone,
    this.qrCode,
    this.isActive = true,
    this.createdAt,
  });
  
  /// 복사본 생성
  Teacher copyWith({
    int? id,
    String? name,
    String? subject,
    String? department,
    String? phone,
    String? qrCode,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Teacher(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      department: department ?? this.department,
      phone: phone ?? this.phone,
      qrCode: qrCode ?? this.qrCode,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  @override
  String toString() {
    return 'Teacher(id: $id, name: $name, subject: $subject, department: $department)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Teacher &&
        other.id == id &&
        other.name == name &&
        other.subject == subject;
  }
  
  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ subject.hashCode;
  }
}


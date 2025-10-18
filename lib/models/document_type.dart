import 'package:flutter/material.dart';

/// 문서 타입 열거형
enum DocumentType {
  /// 결보강 계획서
  substitutionPlan,
  
  /// 학급안내
  classNotice,
  
  /// 교사안내
  teacherNotice,
}

/// DocumentType 확장 메서드들
extension DocumentTypeExtension on DocumentType {
  /// 문서 타입별 표시 이름
  String get displayName {
    switch (this) {
      case DocumentType.substitutionPlan:
        return '결보강 계획서';
      case DocumentType.classNotice:
        return '학급안내';
      case DocumentType.teacherNotice:
        return '교사안내';
    }
  }
  
  /// 문서 타입별 아이콘
  IconData get icon {
    switch (this) {
      case DocumentType.substitutionPlan:
        return Icons.description;
      case DocumentType.classNotice:
        return Icons.class_;
      case DocumentType.teacherNotice:
        return Icons.person;
    }
  }
  
  /// 문서 타입별 색상
  Color get color {
    switch (this) {
      case DocumentType.substitutionPlan:
        return Colors.blue;
      case DocumentType.classNotice:
        return Colors.green;
      case DocumentType.teacherNotice:
        return Colors.orange;
    }
  }
}

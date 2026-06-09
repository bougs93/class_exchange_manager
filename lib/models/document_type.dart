import 'package:flutter/material.dart';

/// 문서 타입 열거형
enum DocumentType {
  /// 결보강 내용 입력
  substitutionPlan,

  /// 결보강 출력(PDF)
  fileExport,
}

/// DocumentType 확장 메서드들
extension DocumentTypeExtension on DocumentType {
  /// 문서 타입별 표시 이름
  String get displayName {
    switch (this) {
      case DocumentType.substitutionPlan:
        return '내용 입력';
      case DocumentType.fileExport:
        return '결보강 출력';
    }
  }

  /// 문서 타입별 아이콘
  IconData get icon {
    switch (this) {
      case DocumentType.substitutionPlan:
        return Icons.description;
      case DocumentType.fileExport:
        return Icons.file_present;
    }
  }

  /// 문서 타입별 색상
  Color get color {
    switch (this) {
      case DocumentType.substitutionPlan:
        return Colors.blue;
      case DocumentType.fileExport:
        return Colors.purple;
    }
  }
}

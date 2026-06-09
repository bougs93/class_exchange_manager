import 'package:flutter/material.dart';

/// 계획서 출력 화면 왼쪽 서브 메뉴
enum PlanOutputMenu {
  /// 날짜 선택 (결강일·교체일·보강 과목 등)
  contentInput,

  /// 결보강 출력 (PDF 저장·인쇄)
  substitutionOutput,
}

/// [PlanOutputMenu] 표시 이름·아이콘·색상
extension PlanOutputMenuExtension on PlanOutputMenu {
  String get displayName {
    switch (this) {
      case PlanOutputMenu.contentInput:
        return '날짜 선택';
      case PlanOutputMenu.substitutionOutput:
        return '결보강 출력';
    }
  }

  IconData get icon {
    switch (this) {
      case PlanOutputMenu.contentInput:
        return Icons.description;
      case PlanOutputMenu.substitutionOutput:
        return Icons.file_present;
    }
  }

  Color get color {
    switch (this) {
      case PlanOutputMenu.contentInput:
        return Colors.blue;
      case PlanOutputMenu.substitutionOutput:
        return Colors.purple;
    }
  }
}

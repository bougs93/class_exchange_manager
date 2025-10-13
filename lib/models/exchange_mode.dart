import 'package:flutter/material.dart';

/// 교체 모드 열거형
/// 각 모드는 상호 배타적으로 동작합니다.
enum ExchangeMode {
  /// 보기 모드 - 일반적인 시간표 조회
  view,
  
  /// 교체불가 편집 모드 - 교체불가 셀 편집
  nonExchangeableEdit,
  
  /// 1:1교체 모드 - 두 교사 간 직접 교체
  oneToOneExchange,
  
  /// 순환교체 모드 - 여러 교사가 순환하며 교체
  circularExchange,
  
  /// 연쇄교체 모드 - 연쇄적으로 교체
  chainExchange,
  
  /// 보강교체 모드 - 보강 수업 추가
  supplementExchange,
}

/// ExchangeMode 확장 메서드들
extension ExchangeModeExtension on ExchangeMode {
  /// 모드의 표시 이름
  String get displayName {
    switch (this) {
      case ExchangeMode.view:
        return '보기';
      case ExchangeMode.nonExchangeableEdit:
        return '교체불가 편집';
      case ExchangeMode.oneToOneExchange:
        return '1:1교체';
      case ExchangeMode.circularExchange:
        return '순환교체';
      case ExchangeMode.chainExchange:
        return '연쇄교체';
      case ExchangeMode.supplementExchange:
        return '보강교체';
    }
  }
  
  /// 모드의 아이콘
  IconData get icon {
    switch (this) {
      case ExchangeMode.view:
        return Icons.visibility;
      case ExchangeMode.nonExchangeableEdit:
        return Icons.block;
      case ExchangeMode.oneToOneExchange:
        return Icons.swap_horiz;
      case ExchangeMode.circularExchange:
        return Icons.refresh;
      case ExchangeMode.chainExchange:
        return Icons.link;
      case ExchangeMode.supplementExchange:
        return Icons.add_circle;
    }
  }
  
  /// 모드의 색상
  Color get color {
    switch (this) {
      case ExchangeMode.view:
        return Colors.grey;
      case ExchangeMode.nonExchangeableEdit:
        return Colors.red;
      case ExchangeMode.oneToOneExchange:
        return Colors.green;
      case ExchangeMode.circularExchange:
        return Colors.indigo;
      case ExchangeMode.chainExchange:
        return Colors.deepOrange;
      case ExchangeMode.supplementExchange:
        return Colors.teal;
    }
  }
  
  /// 모드가 교체 관련 모드인지 확인
  bool get isExchangeMode {
    return this != ExchangeMode.view && this != ExchangeMode.nonExchangeableEdit;
  }
  
  /// 모드가 편집 모드인지 확인
  bool get isEditMode {
    return this == ExchangeMode.nonExchangeableEdit;
  }
}

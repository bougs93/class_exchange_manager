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

  /// 2중교체 모드 - 2중으로 교체
  dualExchange,

  /// 순환교체 모드 - 여러 교사가 순환하며 교체
  circularExchange,

  /// 보강 모드 - 보강 수업 추가
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
        return '교체불가';
      case ExchangeMode.oneToOneExchange:
        return '1:1교체';
      case ExchangeMode.circularExchange:
        return '순환교체';
      case ExchangeMode.dualExchange:
        return '2중교체';
      case ExchangeMode.supplementExchange:
        return '보강';
    }
  }

  /// 툴바용 짧은 라벨 (null이면 아이콘만 표시)
  String? get toolbarLabel {
    switch (this) {
      case ExchangeMode.view:
      case ExchangeMode.nonExchangeableEdit:
        return null;
      case ExchangeMode.oneToOneExchange:
        return '1:1';
      case ExchangeMode.dualExchange:
        return '2중';
      case ExchangeMode.circularExchange:
        return '순환';
      case ExchangeMode.supplementExchange:
        return '보강';
    }
  }

  /// 교체 서브 메뉴 툴팁 설명
  String get tooltipDescription {
    switch (this) {
      case ExchangeMode.view:
        return '교체 작업 없이 시간표만 확인합니다.';
      case ExchangeMode.nonExchangeableEdit:
        return '교체할 수 없는 시간을 선택해 표시하면, 교체 탐색 시 해당 시간이 제외됩니다.';
      case ExchangeMode.oneToOneExchange:
        return '가장 기본적인 교체 방식입니다. 한 교사와 같은 반 수업을 서로 맞바꿉니다.';
      case ExchangeMode.circularExchange:
        return '1:1 교체가 어려울 때, 두 교사의 같은 반 수업을 순환해 맞바꿉니다.';
      case ExchangeMode.dualExchange:
        return '1:1 교체가 어려울 때, 1:1 교체를 두 번 연결해 수업을 맞바꿉니다.';
      case ExchangeMode.supplementExchange:
        return '수업 교체가 불가능할 때, 해당 시간에 수업이 비어 있는 교사가 보강 수업을 진행합니다.';
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
      case ExchangeMode.dualExchange:
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
      case ExchangeMode.dualExchange:
        return Colors.deepOrange;
      case ExchangeMode.supplementExchange:
        return Colors.teal;
    }
  }

  /// 모드가 교체 관련 모드인지 확인
  bool get isExchangeMode {
    return this != ExchangeMode.view &&
        this != ExchangeMode.nonExchangeableEdit;
  }

  /// 모드가 편집 모드인지 확인
  bool get isEditMode {
    return this == ExchangeMode.nonExchangeableEdit;
  }
}

/// [ExchangeMode] ↔ app_settings.json 문자열 변환
String exchangeModeToJson(ExchangeMode mode) => mode.name;

/// JSON 문자열 → [ExchangeMode] (없거나 알 수 없으면 null)
ExchangeMode? exchangeModeFromJson(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  for (final mode in ExchangeMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }
  return null;
}

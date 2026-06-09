import 'package:flutter/material.dart';
import '../../../models/exchange_path.dart';

/// 경로 타입별 색상 시스템
///
/// 각 교체 타입(1:1/순환/2중/보강)의 색상 팔레트와,
/// 노드·경로 아이템의 선택 상태별 색상 계산을 한곳에서 담당한다.
class PathColorScheme {
  final Color primary;              // 메인 색상 (화살표, 강조)
  final Color nodeBackground;       // 노드 배경색 (선택된 상태)
  final Color nodeBackgroundUnselected; // 노드 배경색 (선택되지 않은 상태)
  final Color nodeBorder;           // 노드 테두리색 (선택된 상태)
  final Color nodeBorderUnselected; // 노드 테두리색 (선택되지 않은 상태)
  final Color nodeText;             // 노드 텍스트 색상 (선택된 상태)
  final Color nodeTextUnselected;   // 노드 텍스트 색상 (선택되지 않은 상태)
  final Color shadow;               // 그림자 색상

  const PathColorScheme({
    required this.primary,
    required this.nodeBackground,
    required this.nodeBackgroundUnselected,
    required this.nodeBorder,
    required this.nodeBorderUnselected,
    required this.nodeText,
    required this.nodeTextUnselected,
    required this.shadow,
  });

  /// 1:1교체 색상 스키마 (초록색 계열)
  static const oneToOne = PathColorScheme(
    primary: Color(0xFF4CAF50),                    // 초록색 화살표
    nodeBackground: Color(0xFFE8F5E8),             // 연한 초록색 노드 배경 (선택됨)
    nodeBackgroundUnselected: Color(0xFFF8FFF8),   // 매우 연한 초록색 노드 배경 (선택안됨)
    nodeBorder: Color(0xFF4CAF50),                 // 초록색 노드 테두리 (선택됨)
    nodeBorderUnselected: Color(0xFFC8E6C9),       // 연한 초록색 노드 테두리 (선택안됨)
    nodeText: Color(0xFF2E7D32),                   // 진한 초록색 노드 텍스트 (선택됨)
    nodeTextUnselected: Color(0xFF4CAF50),         // 초록색 노드 텍스트 (선택안됨)
    shadow: Color(0xFFC8E6C9),                     // 초록색 그림자
  );

  /// 순환교체 색상 스키마 (보라색 계열)
  static const circular = PathColorScheme(
    primary: Color(0xFF9C27B0),                    // 보라색 화살표
    nodeBackground: Color(0xFFF3E5F5),             // 연한 보라색 노드 배경 (선택됨)
    nodeBackgroundUnselected: Color(0xFFF8FFF8),   // 매우 연한 보라색 노드 배경 (선택안됨)
    nodeBorder: Color(0xFF9C27B0),                 // 보라색 노드 테두리 (선택됨)
    nodeBorderUnselected: Color(0xFFE1BEE7),       // 연한 보라색 노드 테두리 (선택안됨)
    nodeText: Color(0xFF6A1B9A),                   // 진한 보라색 노드 텍스트 (선택됨)
    nodeTextUnselected: Color(0xFF9C27B0),         // 보라색 노드 텍스트 (선택안됨)
    shadow: Color(0xFFE1BEE7),                     // 보라색 그림자
  );

  /// 2중교체 색상 스키마 (주황색 계열)
  static const chain = PathColorScheme(
    primary: Color(0xFFFF5722),                    // 주황색 화살표
    nodeBackground: Color(0xFFFBE9E7),             // 연한 주황색 노드 배경 (선택됨)
    nodeBackgroundUnselected: Color(0xFFFFF8F8),   // 매우 연한 주황색 노드 배경 (선택안됨)
    nodeBorder: Color(0xFFFF5722),                 // 주황색 노드 테두리 (선택됨)
    nodeBorderUnselected: Color(0xFFFFCCBC),       // 연한 주황색 노드 테두리 (선택안됨)
    nodeText: Color(0xFFD84315),                   // 진한 주황색 노드 텍스트 (선택됨)
    nodeTextUnselected: Color(0xFFFF5722),         // 주황색 노드 텍스트 (선택안됨)
    shadow: Color(0xFFFFCCBC),                     // 주황색 그림자
  );

  /// 보강 색상 스키마 (틸 색상 계열)
  static const supplement = PathColorScheme(
    primary: Color(0xFF20B2AA),                    // 틸 색상 화살표
    nodeBackground: Color(0xFFE0F2F1),             // 연한 틸 색상 노드 배경 (선택됨)
    nodeBackgroundUnselected: Color(0xFFF0FFFF),   // 매우 연한 틸 색상 노드 배경 (선택안됨)
    nodeBorder: Color(0xFF20B2AA),                 // 틸 색상 노드 테두리 (선택됨)
    nodeBorderUnselected: Color(0xFFB2DFDB),       // 연한 틸 색상 노드 테두리 (선택안됨)
    nodeText: Color(0xFF00695C),                   // 진한 틸 색상 노드 텍스트 (선택됨)
    nodeTextUnselected: Color(0xFF20B2AA),         // 틸 색상 노드 텍스트 (선택안됨)
    shadow: Color(0xFFB2DFDB),                     // 틸 색상 그림자
  );

  /// 경로 타입에 따른 색상 스키마 반환
  static PathColorScheme getScheme(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return oneToOne;
      case ExchangePathType.circular:
        return circular;
      case ExchangePathType.chain:
        return chain;
      case ExchangePathType.supplement:
        return supplement;
    }
  }

  // ── 노드 선택 상태별 색상 계산 ──────────────────────────────
  // 노드는 위치(마지막/두번째/일반)와 선택 여부에 따라 색이 달라진다.

  /// 노드 배경색 계산
  Color backgroundFor(bool isSelected, bool isLastNode, bool isSecondNode) {
    if (isLastNode) {
      return isSelected
          ? nodeBackground.withValues(alpha: 0.3)
          : Colors.grey.shade50;
    }
    if (isSecondNode) {
      return isSelected ? _darker(nodeBackground) : Colors.grey.shade300;
    }
    return isSelected ? nodeBackground : Colors.grey.shade100;
  }

  /// 노드 테두리색 계산
  Color borderFor(bool isSelected, bool isLastNode, bool isSecondNode) {
    if (isLastNode) {
      return isSelected
          ? nodeBorder.withValues(alpha: 0.3)
          : Colors.grey.shade300;
    }
    if (isSecondNode) {
      return isSelected ? _darker(nodeBorder) : Colors.grey.shade500;
    }
    return isSelected ? nodeBorder : Colors.grey.shade400;
  }

  /// 노드 텍스트 색상 계산
  Color textFor(bool isSelected, bool isLastNode, bool isSecondNode) {
    if (isLastNode) {
      return isSelected
          ? nodeText.withValues(alpha: 0.4)
          : Colors.grey.shade400;
    }
    if (isSecondNode) {
      return isSelected ? _darker(nodeText) : Colors.grey.shade800;
    }
    return isSelected ? nodeText : Colors.grey.shade600;
  }

  /// 색상을 진하게 만드는 헬퍼 (투명도 변경 없이 명도만 낮춤)
  static Color _darker(Color originalColor) {
    final hsl = HSLColor.fromColor(originalColor);
    return hsl.withLightness((hsl.lightness * 0.85).clamp(0.0, 1.0)).toColor();
  }

  // ── 경로 아이템(카드) 색상 ─────────────────────────────────
  // Material shade 팔레트 기반의 경로 카드 배경/테두리/그림자.

  /// 경로 타입별 카드 배경색
  static Color pathBackground(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return Colors.green.shade50;
      case ExchangePathType.circular:
        return Colors.purple.shade50;
      case ExchangePathType.chain:
        return Colors.deepOrange.shade50;
      case ExchangePathType.supplement:
        return Colors.teal.shade50;
    }
  }

  /// 경로 타입별 카드 테두리색
  static Color pathBorder(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return Colors.green.shade400;
      case ExchangePathType.circular:
        return Colors.purple.shade400;
      case ExchangePathType.chain:
        return Colors.deepOrange.shade400;
      case ExchangePathType.supplement:
        return Colors.teal.shade400;
    }
  }

  /// 경로 타입별 카드 그림자 색상
  static Color pathShadow(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return Colors.green.shade200;
      case ExchangePathType.circular:
        return Colors.purple.shade200;
      case ExchangePathType.chain:
        return Colors.deepOrange.shade200;
      case ExchangePathType.supplement:
        return Colors.teal.shade200;
    }
  }
}

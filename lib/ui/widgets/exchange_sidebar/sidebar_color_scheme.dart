import 'package:flutter/material.dart';

/// 경로 타입별 색상 시스템
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

  /// 연쇄교체 색상 스키마 (주황색 계열)
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

  /// 보강교체 색상 스키마 (틸 색상 계열)
  static const supplement = PathColorScheme(
    primary: Color(0xFF20B2AA),                    // 틸 색상 화살표
    nodeBackground: Color(0xFFE0F2F1),             // 연한 틸 색상 노드 배경 (선택됨)
    nodeBackgroundUnselected: Color(0xFFF0FFFF),   // 매우 연한 틸 색상 노드 배경 (선택안됨)
    nodeBorder: Color(0xFF20B2AA),                 // 틸 색상 노드 테두리 (선택됨)
    nodeBorderUnselected: Color(0xFFB2DFDB),       // 연한 틸 색상 노드 테두리 (선택안됨)
    nodeText: Color(0xFF00796B),                   // 진한 틸 색상 노드 텍스트 (선택됨)
    nodeTextUnselected: Color(0xFF20B2AA),         // 틸 색상 노드 텍스트 (선택안됨)
    shadow: Color(0xFFB2DFDB),                     // 틸 색상 그림자
  );
}

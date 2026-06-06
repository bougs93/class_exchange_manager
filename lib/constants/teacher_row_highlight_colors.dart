import 'package:flutter/material.dart';

/// 교사 행 하이라이트 색상 (교체 화면 범례와 구분)
///
/// 교체 화면에서 사용하는 색상(노랑·빨강·파랑·연파랑·연분홍 등)과
/// 겹치지 않도록 청록·회갈·남보라 계열 팔레트만 제공합니다.
class TeacherRowHighlightColors {
  TeacherRowHighlightColors._();

  /// 기본 하이라이트 — Teal 100 (교체 범례와 구분되는 청록)
  static const Color defaultColor = Color(0xFFB2DFDB);

  /// 홈/설정에서 선택 가능한 프리셋
  static const List<Color> presets = [
    Color(0xFFB2DFDB), // 청록 (Teal 100)
    Color(0xFF80CBC4), // 진청록 (Teal 200)
    Color(0xFFD7CCC8), // Warm grey (Brown 100)
    Color(0xFFBCAAA4), // Taupe (Brown 200)
    Color(0xFFC5CAE9), // 연남보라 (Indigo 100)
    Color(0xFFCFD8DC), // Blue grey 100
  ];

  /// 이전 버전 프리셋 (교체 화면 색상과 유사하여 더 이상 사용하지 않음)
  static const Set<int> _legacyPresetArgb = {
    0xFFE3F2FD, // 연파랑 — 채워진 수업(0xFF90C7F5)과 유사
    0xFFE8F5E9, // 연녹 — 교사명 선택(0xFFC8E6C9)과 유사
    0xFFFFF9C4, // 연노랑 — 선택한 수업(0xFFFFEB3B)과 유사
    0xFFF3E5F5, // 연보라 — 순환교체 경로와 유사
    0xFFE1F5FE, // 연하늘 — 채워진 수업과 유사
    0xFFFFE0B2, // 연주황 — 연쇄교체(0xFFFF8A65)와 유사
    0xFFFFCDD2, // 연분홍 — 교체불가 기본색과 동일
  };

  /// 저장된 ARGB 값을 안전한 하이라이트 색상으로 변환
  static Color resolveSavedColor(int? argb) {
    if (argb == null || _legacyPresetArgb.contains(argb)) {
      return defaultColor;
    }
    return Color(argb);
  }

  static bool isPreset(Color color) {
    return presets.any((preset) => preset.toARGB32() == color.toARGB32());
  }
}

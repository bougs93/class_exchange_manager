import 'package:flutter/material.dart';

/// 교사 행 하이라이트 색상 (교체 화면 범례와 구분)
///
/// 교체 화면에서 사용하는 색상(노랑·빨강·파랑·연파랑·연분홍 등)과
/// 겹치지 않도록 청록·회갈·남보라 계열 팔레트만 제공합니다.
class TeacherRowHighlightColors {
  TeacherRowHighlightColors._();

  /// 기본 하이라이트 — Teal 50 (교체 범례와 구분되는 연한 청록)
  static const Color defaultColor = Color(0xFFE0F2F1);

  /// 홈/설정에서 선택 가능한 프리셋 (연한 파스텔 톤)
  static const List<Color> presets = [
    Color(0xFFE0F2F1), // 연청록 (Teal 50)
    Color(0xFFB2DFDB), // 청록 (Teal 100)
    Color(0xFFEFEBE9), // 연웜그레이 (Brown 50)
    Color(0xFFD7CCC8), // 웜그레이 (Brown 100)
    Color(0xFFE8EAF6), // 연남보라 (Indigo 50)
    Color(0xFFECEFF1), // 연블루그레이 (Blue grey 50)
  ];

  /// 이전 버전 프리셋 (교체 화면 색상·진한 하이라이트 — 기본 연한 색으로 대체)
  static const Set<int> _legacyPresetArgb = {
    0xFF80CBC4, // 구 Teal 200 — 현재 팔레트보다 진함
    0xFFBCAAA4, // 구 Brown 200
    0xFFC5CAE9, // 구 Indigo 100
    0xFFCFD8DC, // 구 Blue grey 100
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

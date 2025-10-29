import 'package:flutter/material.dart';

/// TextField의 InputDecoration을 일관되게 생성하는 헬퍼 클래스
///
/// PDF 필드 입력 등에서 사용되는 공통 스타일을 제공합니다.
class InputDecorationHelper {
  /// 표준 InputDecoration 생성
  ///
  /// [hintText] 힌트 텍스트
  /// [isDense] 컴팩트 모드 여부 (기본: false)
  ///
  /// Returns: 표준 스타일의 InputDecoration
  static InputDecoration buildStandard({
    required String hintText,
    bool isDense = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: isDense
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: isDense,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
    );
  }

  /// 오류 상태 InputDecoration 생성
  ///
  /// [hintText] 힌트 텍스트
  /// [errorText] 오류 메시지
  /// [isDense] 컴팩트 모드 여부
  ///
  /// Returns: 오류 스타일의 InputDecoration
  static InputDecoration buildError({
    required String hintText,
    String? errorText,
    bool isDense = false,
  }) {
    return buildStandard(hintText: hintText, isDense: isDense).copyWith(
      errorText: errorText,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
    );
  }
}

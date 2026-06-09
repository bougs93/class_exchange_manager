import 'package:flutter/material.dart';
import 'exchange_control_panel.dart';

/// 문서 출력 탭 공통 레이아웃 (안내 바 · 툴바 버튼)
class DocumentToolbarLayout {
  DocumentToolbarLayout._();

  /// 안내 바 좌·우·상 여백 (하단은 [hintToToolbarGap]으로 분리)
  static const double hintInset = 5.0;

  /// 안내 바와 버튼 줄 사이 간격
  static const double hintToToolbarGap = 6.0;

  /// 버튼 줄 패딩
  static const double toolbarInset = 5.0;

  /// 툴바 버튼 통일 높이
  static const double buttonHeight = kExchangeUnifiedToolbarHeight - 8;

  /// 툴바 아이콘 크기
  static const double buttonIconSize = kModeButtonIconSize;

  /// 툴바 라벨 글자 크기
  static const double buttonFontSize = kModeButtonFontSize;

  /// 버튼 사이 간격
  static const double buttonGap = 4.0;

  static const EdgeInsets hintPadding =
      EdgeInsets.fromLTRB(hintInset, hintInset, hintInset, 0);

  static const EdgeInsets toolbarPadding = EdgeInsets.all(toolbarInset);

  static const Widget hintToToolbarSpacer =
      SizedBox(height: hintToToolbarGap);

  /// 일반 동작 버튼(새로고침·복사 등) — 선택·눌림 상태처럼 보이지 않는 중립 색
  static Color get neutralButtonBackground => Colors.grey.shade100;
  static Color get neutralButtonForeground => Colors.grey.shade700;
  static Color get neutralButtonBorder => Colors.grey.shade300;
}

import 'package:flutter/material.dart';
import '../screens/document_screen/widgets/substitution_plan_grid_helpers.dart';

/// 선택 가능한 셀의 UI 스타일을 일관되게 생성하는 Builder 클래스
///
/// DateCellRenderer와 SupplementSubjectCellRenderer에서 공통으로 사용하는
/// 스타일 로직을 통합하여 코드 중복을 제거합니다.
class SelectableCellBuilder {
  /// 선택 가능 셀의 배경 색상
  static final Color selectableBackgroundColor = Colors.blue.shade50;

  /// 선택 가능 셀의 테두리 색상
  static final Color selectableBorderColor = Colors.blue.shade200;

  /// 선택 가능 셀의 텍스트 색상
  static final Color selectableTextColor = Colors.blue.shade700;

  /// 일반 셀의 텍스트 색상
  static const Color normalTextColor = Colors.black87;

  /// 선택 가능 셀의 테두리 반경
  static const double borderRadius = 4.0;

  /// 셀 컨테이너 데코레이션 생성
  ///
  /// [isSelectable] 셀이 선택 가능한지 여부
  /// [isEmpty] 셀이 비어있는지 여부
  ///
  /// Returns: BoxDecoration 객체
  static BoxDecoration buildDecoration(bool isSelectable, bool isEmpty) {
    if (!isSelectable || !isEmpty) {
      return const BoxDecoration();
    }

    return BoxDecoration(
      color: selectableBackgroundColor,
      border: Border.all(color: selectableBorderColor),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  /// 셀 텍스트 스타일 생성
  ///
  /// [isSelectable] 셀이 선택 가능한지 여부
  /// [isEmpty] 셀이 비어있는지 여부
  ///
  /// Returns: TextStyle 객체
  static TextStyle buildTextStyle(bool isSelectable, bool isEmpty) {
    return TextStyle(
      fontSize: SubstitutionPlanGridConfig.cellFontSize,
      height: 1.0,
      color: isSelectable && isEmpty ? selectableTextColor : normalTextColor,
      fontWeight: isSelectable && isEmpty ? FontWeight.w500 : FontWeight.normal,
      decoration: TextDecoration.none,
    );
  }

  /// 선택 가능한 셀 위젯 생성
  ///
  /// [isSelectable] 셀이 선택 가능한지 여부
  /// [isEmpty] 셀이 비어있는지 여부
  /// [displayText] 표시할 텍스트
  /// [onTap] 셀 탭 콜백 (선택 가능하고 비어있을 때만 동작)
  ///
  /// Returns: 완성된 셀 위젯
  static Widget build({
    required bool isSelectable,
    required bool isEmpty,
    required String displayText,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: (isSelectable && onTap != null) ? onTap : null,
      child: Container(
        alignment: Alignment.center,
        padding: SubstitutionPlanGridConfig.cellPadding,
        decoration: buildDecoration(isSelectable, isEmpty),
        child: Text(
          displayText,
          style: buildTextStyle(isSelectable, isEmpty),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

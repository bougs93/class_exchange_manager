import 'package:flutter/material.dart';

import '../../../../widgets/content_toolbar_layout.dart';
import '../../../../widgets/timetable_grid/grid_header_widgets.dart';

/// PDF 출력 버튼 — 계획서가 선택된 경우에만 활성
///
/// [SubstitutionOutputWidgetState._buildPdfOutputButton]에서 추출한 순수
/// 렌더링 위젯입니다. 활성 여부는 [onPressed]가 null인지로 판단합니다
/// (계획서를 선택한 뒤에만 출력할 수 있습니다).
class PdfOutputButton extends StatelessWidget {
  const PdfOutputButton({super.key, required this.onPressed});

  /// 누르면 실행되는 콜백. null이면 버튼이 비활성화됩니다.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accentColor = Colors.purple;
    final canPrint = onPressed != null;
    return SizedBox(
      width: double.infinity,
      child: CompactToolbarLabelButton(
        onPressed: onPressed,
        icon: Icons.print,
        label: 'PDF 미리보기, 인쇄',
        tooltip: canPrint ? 'PDF 미리보기, 인쇄' : '계획서를 선택한 뒤에만 출력할 수 있습니다',
        backgroundColor: canPrint ? accentColor.shade50 : Colors.grey.shade200,
        foregroundColor: canPrint ? accentColor.shade600 : Colors.grey.shade500,
        borderColor: canPrint ? accentColor.shade600 : Colors.grey.shade400,
        width: double.infinity,
        height: ContentToolbarLayout.buttonHeight,
        fontSize: ContentToolbarLayout.buttonFontSize,
        iconSize: ContentToolbarLayout.buttonIconSize,
      ),
    );
  }
}

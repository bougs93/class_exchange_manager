import 'package:flutter/material.dart';
import '../../../constants/teacher_row_highlight_colors.dart';
import '../../../theme/design_tokens.dart';

/// 교사 행 하이라이트 색상 선택기 (순수 표현 위젯)
///
/// 현재 색상 미리보기와 프리셋 색상 목록을 표시하고,
/// 선택 시 [onColorSelected] 콜백을 호출한다.
/// 저장 로직과 로딩 상태는 부모가 담당한다.
class HighlightColorPicker extends StatelessWidget {
  final Color currentColor;
  final bool isSaving;
  final ValueChanged<Color> onColorSelected;

  const HighlightColorPicker({
    super.key,
    required this.currentColor,
    required this.isSaving,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '교사 행 하이라이트',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '교체 화면 범례(선택·채움·교체불가 등)와 구분되는 색상입니다.',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),

          // 현재 색상 미리보기
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: currentColor,
              border: Border.all(color: tokens.cardBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: currentColor,
                    border: Border.all(color: Colors.black26, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '현재 색상: RGB(${(currentColor.r * 255.0).round()}, ${(currentColor.g * 255.0).round()}, ${(currentColor.b * 255.0).round()})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 프리셋 색상 목록
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children:
                TeacherRowHighlightColors.presets
                    .map((color) => _buildColorOption(color, tokens))
                    .toList(),
          ),
        ],
      ),
    );
  }

  /// 색상 옵션 버튼
  Widget _buildColorOption(Color color, DesignTokens tokens) {
    final isSelected = currentColor.toARGB32() == color.toARGB32();

    return InkWell(
      onTap: isSaving ? null : () => onColorSelected(color),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isSelected ? tokens.primary : tokens.cardBorder,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

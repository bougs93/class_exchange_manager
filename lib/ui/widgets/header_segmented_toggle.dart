import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'content_toolbar_layout.dart';

/// 두 가지 중 하나를 고르는 헤더용 세그먼트 토글 (`[원본 | 날짜·교체]`).
///
/// 계획서 `[등록순 | 날짜순]`과 픽셀 동일 — 외곽 테두리·radius 4·1px 구분선·
/// 선택됨(`blue.shade600`+흰색 굵게)/미선택(투명+black87) 색을 그대로 쓴다.
/// 양쪽 라벨이 항상 보이므로 단일 토글(색으로만 ON/OFF 구분)보다 상태가
/// 명확하다. 아이콘은 없다(계획서처럼 텍스트만).
class HeaderSegmentedToggle extends StatelessWidget {
  const HeaderSegmentedToggle({
    super.key,
    required this.value,
    required this.offLabel,
    required this.onLabel,
    required this.onChanged,
    required this.height,
    this.tooltip,
  });

  /// true면 [onLabel] 쪽이 선택된 상태다.
  final bool value;
  final String offLabel;
  final String onLabel;
  final ValueChanged<bool> onChanged;
  final double height;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final border = ContentToolbarLayout.neutralButtonBorder(context.tokens);
    final body = Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(offLabel, selected: !value, nextValue: false),
          Container(width: 1, color: border),
          _segment(onLabel, selected: value, nextValue: true),
        ],
      ),
    );
    final tip = tooltip;
    if (tip == null) return body;
    return Tooltip(message: tip, child: body);
  }

  Widget _segment(String label, {required bool selected, required bool nextValue}) {
    return InkWell(
      onTap: selected ? null : () => onChanged(nextValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        color: selected ? Colors.blue.shade600 : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: ContentToolbarLayout.buttonFontSize,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

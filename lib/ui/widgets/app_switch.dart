import 'package:flutter/material.dart';

/// 앱 공용 스위치.
///
/// 색과 모양은 테마의 [Switch]를 그대로 쓴다. 크기는 툴바에 맞게 줄여 두고,
/// 앞으로 스위치가 필요하면 이 위젯을 쓴다.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  /// Material 3 스위치 대비 배율.
  static const double scale = 0.72;

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// shrinkWrap일 때 M3 스위치가 차지하는 크기.
  /// 더 좁게 잡으면 트랙 좌우 여백이 잘려 라벨에 붙는다.
  /// (switchWidth 60 + 좌우 패딩 4×2, 높이 40)
  static const double _layoutWidth = 68;
  static const double _layoutHeight = 40;

  @override
  Widget build(BuildContext context) {
    // scale만 주면 원래 레이아웃 폭이 남아 옆 간격이 벌어진다.
    return SizedBox(
      width: _layoutWidth * scale,
      height: _layoutHeight * scale,
      child: OverflowBox(
        maxWidth: _layoutWidth,
        maxHeight: _layoutHeight,
        alignment: Alignment.center,
        child: Transform.scale(
          scale: scale,
          child: Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

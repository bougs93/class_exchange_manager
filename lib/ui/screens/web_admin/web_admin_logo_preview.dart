import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 접속 설정에서 고른/저장된 학교 로고 미리보기.
///
/// 어떤 바이트를 보여줄지(새로 고른 것 > 저장본 > 없음)는
/// [WebAdminSettingsScreen] 쪽에서 미리 계산해 [logoBytes]로 넘겨준다.
class WebAdminLogoPreview extends StatelessWidget {
  const WebAdminLogoPreview({super.key, required this.logoBytes});

  final Uint8List? logoBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = logoBytes;
    final Widget child =
        bytes != null
            ? Image.memory(bytes, fit: BoxFit.contain)
            : Icon(
              Icons.school_outlined,
              size: 40,
              color: Colors.grey.shade400,
            );
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

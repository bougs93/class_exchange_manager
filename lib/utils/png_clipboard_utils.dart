import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// PNG 클립보드 복사용 이미지 유틸
class PngClipboardUtils {
  PngClipboardUtils._();

  /// 투명 영역을 흰색으로 채워 클립보드 붙여넣기 시 검정 모서리를 방지합니다.
  ///
  /// 둥근 모서리 바깥 픽셀은 PNG에서 투명(alpha=0)인데,
  /// Windows 클립보드 비트맵은 투명을 지원하지 않아 검정으로 보일 수 있습니다.
  static Uint8List flattenOnWhiteBackground(Uint8List pngBytes) {
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      return pngBytes;
    }

    final flattened = img.Image(width: decoded.width, height: decoded.height);
    img.fill(flattened, color: img.ColorRgba8(255, 255, 255, 255));
    img.compositeImage(flattened, decoded);

    return Uint8List.fromList(img.encodePng(flattened));
  }
}

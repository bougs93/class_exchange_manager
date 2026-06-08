import 'dart:typed_data';

import 'package:pasteboard/pasteboard.dart';

import 'png_clipboard_utils.dart';

/// 모든 OS에서 pasteboard 패키지로 클립보드 이미지 복사
///
/// Windows / macOS / Linux / iOS / Android / Web 공통 사용
abstract final class ClipboardImageCopier {
  static Future<bool> copyPng(Uint8List pngBytes) async {
    try {
      final flattened = PngClipboardUtils.flattenOnWhiteBackground(pngBytes);
      await Pasteboard.writeImage(flattened);
      return true;
    } catch (_) {
      return false;
    }
  }
}

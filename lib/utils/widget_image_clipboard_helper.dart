import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'clipboard_image_copier.dart';

/// 위젯을 PNG 이미지로 캡처해 시스템 클립보드에 복사합니다.
class WidgetImageClipboardHelper {
  WidgetImageClipboardHelper._();

  /// [boundaryKey]가 가리키는 [RepaintBoundary]를 PNG 바이트로 캡처합니다.
  static Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = 2.0,
  }) async {
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }

    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// 위젯을 캡처한 뒤 클립보드에 이미지로 저장합니다.
  static Future<bool> copyWidgetToClipboard(
    GlobalKey boundaryKey, {
    double pixelRatio = 2.0,
  }) async {
    final pngBytes = await capturePng(
      boundaryKey,
      pixelRatio: pixelRatio,
    );
    if (pngBytes == null || pngBytes.isEmpty) {
      return false;
    }

    return ClipboardImageCopier.copyPng(pngBytes);
  }
}

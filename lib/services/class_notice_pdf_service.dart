import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/notice_message.dart';
import '../utils/logger.dart';
import 'pdf_font_cache_manager.dart';

/// 학급안내 A4 가로 PDF 생성 (양식 없음)
///
/// 선택 폰트로 줄 폭·블록 높이를 재서 페이지에 들어가는 최대 크기로 채운다.
class ClassNoticePdfService {
  ClassNoticePdfService._();

  /// 프린터 불가 영역(보통 ~10mm)을 고려한 인쇄용 여백.
  /// Syncfusion 단위는 pt(1/72"). 36pt ≈ 12.7mm(0.5").
  static const double _margin = 36;
  static const double _minFontSize = 8;
  static const double _maxFontSize = 120;
  static const double _lineGapFactor = 0.15;

  /// 선택 학급 그룹으로 PDF 바이트 생성
  static Future<Uint8List?> generate({
    required List<NoticeMessageGroup> groups,
    required MessageOption messageOption,
    required String fontType,
  }) async {
    if (groups.isEmpty) return null;

    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.orientation = PdfPageOrientation.landscape;
    document.pageSettings.margins.all = _margin;

    final fontCache = PdfFontCacheManager();

    try {
      var pageCount = 0;
      for (final group in groups) {
        final lines = buildLines(group, messageOption);
        if (lines.isEmpty) continue;

        final page = document.pages.add();
        await _drawFittedLines(
          page: page,
          lines: lines,
          fontType: fontType,
          fontCache: fontCache,
        );
        pageCount++;
      }

      if (pageCount == 0) {
        AppLogger.exchangeDebug('학급안내 PDF: 그릴 줄이 없어 생성 취소');
        return null;
      }

      final bytes = Uint8List.fromList(await document.save());
      AppLogger.exchangeDebug(
        '학급안내 PDF 생성 완료 - 페이지: $pageCount, bytes: ${bytes.length}',
      );
      return bytes;
    } catch (e, st) {
      AppLogger.error('학급안내 PDF 생성 실패', e, st);
      return null;
    } finally {
      fontCache.clear();
      document.dispose();
    }
  }

  /// 저장 다이얼로그용 기본 파일명
  static String buildFileName({DateTime? now}) {
    final stamp = DateFormat('yyyyMMdd_HHmm').format(now ?? DateTime.now());
    return '학급안내_$stamp.pdf';
  }

  /// 메시지 옵션에 맞게 PDF용 줄 목록 생성 (테스트·미리보기용으로 public)
  static List<String> buildLines(
    NoticeMessageGroup group,
    MessageOption messageOption,
  ) {
    final lines = <String>[];
    for (var i = 0; i < group.messages.length; i++) {
      final contentLines = group.messages[i].content.split('\n');
      for (final raw in contentLines) {
        final line = raw.trimRight();
        if (line.trim().isEmpty) continue;
        if (messageOption == MessageOption.option2) {
          lines.addAll(splitExchangeLine(line));
        } else {
          lines.add(line);
        }
      }
      if (i < group.messages.length - 1) {
        lines.add('');
      }
    }
    return lines;
  }

  /// 교체안내 줄: `<->` 우선, 없으면 `->` 앞에서 2줄 분리
  static List<String> splitExchangeLine(String line) {
    final bi = line.indexOf('<->');
    if (bi >= 0) {
      return [
        line.substring(0, bi).trimRight(),
        line.substring(bi).trimLeft(),
      ];
    }
    final uni = line.indexOf('->');
    if (uni >= 0) {
      return [
        line.substring(0, uni).trimRight(),
        line.substring(uni).trimLeft(),
      ];
    }
    return [line];
  }

  static Future<void> _drawFittedLines({
    required PdfPage page,
    required List<String> lines,
    required String fontType,
    required PdfFontCacheManager fontCache,
  }) async {
    final client = page.getClientSize();
    final maxWidth = client.width;
    final maxHeight = client.height;
    if (maxWidth <= 0 || maxHeight <= 0) return;

    final bestSize = await _findMaxFontSize(
      lines: lines,
      fontType: fontType,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      fontCache: fontCache,
    );

    final font = await fontCache.getOrLoad(
      fontSize: bestSize,
      fontType: fontType,
    );
    if (font == null) return;

    final brush = PdfSolidBrush(PdfColor(0, 0, 0));
    // 1줄(학급 제목): 가운데, 이후: 왼쪽
    final centerFormat = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      lineAlignment: PdfVerticalAlignment.middle,
      wordWrap: PdfWordWrapType.none,
    );
    final leftFormat = PdfStringFormat(
      alignment: PdfTextAlignment.left,
      lineAlignment: PdfVerticalAlignment.middle,
      wordWrap: PdfWordWrapType.none,
    );

    final metrics = _measureBlock(font, lines, maxWidth);
    var y = (maxHeight - metrics.totalHeight) / 2;
    if (y < 0) y = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final h = metrics.lineHeights[i];
      if (line.isNotEmpty) {
        page.graphics.drawString(
          line,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(0, y, maxWidth, h),
          format: i == 0 ? centerFormat : leftFormat,
        );
      }
      y += h;
      if (i < lines.length - 1) {
        y += metrics.gap;
      }
    }
  }

  static Future<double> _findMaxFontSize({
    required List<String> lines,
    required String fontType,
    required double maxWidth,
    required double maxHeight,
    required PdfFontCacheManager fontCache,
  }) async {
    var lo = _minFontSize.round();
    var hi = _maxFontSize.round();
    var best = lo;

    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final font = await fontCache.getOrLoad(
        fontSize: mid.toDouble(),
        fontType: fontType,
      );
      if (font == null) {
        hi = mid - 1;
        continue;
      }

      if (_fits(font, lines, maxWidth, maxHeight)) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    return best.toDouble();
  }

  static bool _fits(
    PdfFont font,
    List<String> lines,
    double maxWidth,
    double maxHeight,
  ) {
    final metrics = _measureBlock(font, lines, maxWidth);
    if (metrics.totalHeight > maxHeight + 0.01) return false;
    for (final w in metrics.lineWidths) {
      if (w > maxWidth + 0.01) return false;
    }
    return true;
  }

  static _BlockMetrics _measureBlock(
    PdfFont font,
    List<String> lines,
    double maxWidth,
  ) {
    final lineHeights = <double>[];
    final lineWidths = <double>[];
    final gap = font.height * _lineGapFactor;
    var totalHeight = 0.0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        final h = font.height * 0.5;
        lineHeights.add(h);
        lineWidths.add(0);
        totalHeight += h;
      } else {
        final size = font.measureString(
          line,
          layoutArea: Size(maxWidth * 2, font.height * 2),
        );
        final h = size.height > 0 ? size.height : font.height;
        lineHeights.add(h);
        lineWidths.add(size.width);
        totalHeight += h;
      }
      if (i < lines.length - 1) {
        totalHeight += gap;
      }
    }

    return _BlockMetrics(
      lineHeights: lineHeights,
      lineWidths: lineWidths,
      gap: gap,
      totalHeight: totalHeight,
    );
  }
}

class _BlockMetrics {
  final List<double> lineHeights;
  final List<double> lineWidths;
  final double gap;
  final double totalHeight;

  const _BlockMetrics({
    required this.lineHeights,
    required this.lineWidths,
    required this.gap,
    required this.totalHeight,
  });
}

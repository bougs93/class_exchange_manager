import 'dart:developer' as developer;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'pdf_export_service.dart';

/// PDF 폰트 캐시 매니저
///
/// PdfExportService에서 반복적으로 사용되는 폰트 캐시 로직을 통합 관리합니다.
/// 동일한 폰트를 여러 번 로드하지 않도록 캐싱하여 성능을 최적화합니다.
class PdfFontCacheManager {
  /// 폰트 캐시 (키: "폰트타입_폰트사이즈", 값: PdfFont 객체)
  final Map<String, PdfFont> _cache = {};

  /// 폰트 가져오기 또는 로드 (캐싱 자동 처리)
  ///
  /// [fontSize] 폰트 크기 (pt 단위)
  /// [fontType] 폰트 종류 (null이면 자동 선택)
  ///
  /// Returns: PdfFont 객체 (로드 실패 시 null)
  Future<PdfFont?> getOrLoad({
    required double fontSize,
    String? fontType,
  }) async {
    final key = _generateCacheKey(fontType, fontSize);

    // 캐시에서 먼저 확인
    if (_cache.containsKey(key)) {
      developer.log('폰트 캐시에서 재사용: $key');
      return _cache[key];
    }

    // 캐시에 없으면 로드
    developer.log('폰트 로드 시작: $key');
    final font = await PdfExportService.loadKoreanFont(
      fontSize: fontSize,
      fontType: fontType,
    );

    if (font != null) {
      _cache[key] = font;
      developer.log('폰트 캐시에 저장: $key');
    } else {
      developer.log('폰트 로드 실패: $key');
    }

    return font;
  }

  /// 캐시 키 생성
  ///
  /// [fontType] 폰트 종류 (null이면 "default" 사용)
  /// [fontSize] 폰트 크기
  ///
  /// Returns: 캐시 키 문자열 (예: "malgun.ttf_10.0")
  String _generateCacheKey(String? fontType, double fontSize) {
    return '${fontType ?? "default"}_$fontSize';
  }

  /// 캐시 클리어
  ///
  /// 메모리 절약이 필요한 경우 호출하여 모든 캐시를 삭제합니다.
  void clear() {
    _cache.clear();
    developer.log('폰트 캐시 클리어 완료');
  }

  /// 캐시 크기 확인
  ///
  /// Returns: 현재 캐시된 폰트 개수
  int get cacheSize => _cache.length;

  /// 특정 폰트가 캐시되어 있는지 확인
  ///
  /// [fontSize] 폰트 크기
  /// [fontType] 폰트 종류
  ///
  /// Returns: 캐시 여부
  bool isCached({required double fontSize, String? fontType}) {
    final key = _generateCacheKey(fontType, fontSize);
    return _cache.containsKey(key);
  }
}

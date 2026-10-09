import 'dart:convert';
import 'dart:typed_data';

/// 웹 접속(로그인) 화면 학교 브랜딩 정보.
///
/// Firestore `config/public`에 저장한다.
/// 로고는 Storage에도 올리지만, 웹에서 URL 이미지가 자주 막혀
/// 작은 로고는 `schoolLogoBase64`로 문서에 같이 둔다.
class WebLoginBranding {
  /// 제목 (예: 월계중학교 2026년 2학기 시간표)
  final String title;

  /// 제목 아래 안내 본문 (HTML 서식 가능)
  final String notice;

  /// 학교 홈페이지 URL (로고 탭 시 이동)
  final String homeUrl;

  /// 사용법 버튼에 보일 이름 (비우면 기본값 `사용법 보기`)
  final String guideButtonLabel;

  /// 사용법 버튼 링크 (비우면 버튼 숨김, 새 탭으로 연다)
  final String guideButtonUrl;

  /// 학교 로고 다운로드 URL (비어 있으면 로고 미표시)
  final String logoUrl;

  /// 로고 이미지 base64 (웹 표시용, 비어 있을 수 있음)
  final String logoBase64;

  /// 로고 갱신 시각(ms). 이미지 캐시 무효화용.
  final int logoUpdatedAt;

  /// 사용법 버튼 기본 이름.
  static const String defaultGuideButtonLabel = '사용법 보기';

  const WebLoginBranding({
    this.title = '',
    this.notice = '',
    this.homeUrl = '',
    this.guideButtonLabel = '',
    this.guideButtonUrl = '',
    this.logoUrl = '',
    this.logoBase64 = '',
    this.logoUpdatedAt = 0,
  });

  /// Firestore/메모리에서 바로 쓸 로고 바이트.
  Uint8List? get logoBytes {
    if (logoBase64.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Decode(logoBase64));
    } catch (_) {
      return null;
    }
  }

  bool get hasLogo => logoBase64.isNotEmpty || logoUrl.trim().isNotEmpty;

  /// 링크가 있을 때만 사용법 버튼을 보여 준다.
  bool get hasGuideButton => guideButtonUrl.trim().isNotEmpty;

  /// 화면에 그릴 버튼 이름 (비어 있으면 기본값).
  String get displayGuideButtonLabel {
    final label = guideButtonLabel.trim();
    return label.isEmpty ? defaultGuideButtonLabel : label;
  }

  /// 접속 화면에 그릴 제목 HTML (일반 텍스트 저장분은 자동 변환).
  String get displayTitleHtml => BrandingHtml.toHtml(title);

  /// 접속 화면에 그릴 안내 HTML (일반 텍스트 저장분은 자동 변환).
  String get displayNoticeHtml => BrandingHtml.toHtml(notice);

  factory WebLoginBranding.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const WebLoginBranding();
    final title = (data['loginMessage'] ?? data['LoginMessage']) as String?;
    return WebLoginBranding(
      title: title?.trim() ?? '',
      notice: (data['loginNotice'] as String?)?.trim() ?? '',
      homeUrl: (data['schoolHomeUrl'] as String?)?.trim() ?? '',
      guideButtonLabel: (data['guideButtonLabel'] as String?)?.trim() ?? '',
      guideButtonUrl: (data['guideButtonUrl'] as String?)?.trim() ?? '',
      logoUrl: (data['schoolLogoUrl'] as String?)?.trim() ?? '',
      logoBase64: (data['schoolLogoBase64'] as String?)?.trim() ?? '',
      logoUpdatedAt: (data['schoolLogoUpdatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toPublicFields() => {
    'loginMessage': title,
    'loginNotice': notice,
    'schoolHomeUrl': homeUrl,
    'guideButtonLabel': guideButtonLabel,
    'guideButtonUrl': guideButtonUrl,
    'schoolLogoUrl': logoUrl,
    'schoolLogoBase64': logoBase64,
    'schoolLogoUpdatedAt': logoUpdatedAt,
  };

  WebLoginBranding copyWith({
    String? title,
    String? notice,
    String? homeUrl,
    String? guideButtonLabel,
    String? guideButtonUrl,
    String? logoUrl,
    String? logoBase64,
    int? logoUpdatedAt,
  }) {
    return WebLoginBranding(
      title: title ?? this.title,
      notice: notice ?? this.notice,
      homeUrl: homeUrl ?? this.homeUrl,
      guideButtonLabel: guideButtonLabel ?? this.guideButtonLabel,
      guideButtonUrl: guideButtonUrl ?? this.guideButtonUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      logoBase64: logoBase64 ?? this.logoBase64,
      logoUpdatedAt: logoUpdatedAt ?? this.logoUpdatedAt,
    );
  }
}

/// 제목·안내 문구의 HTML 저장/표시 헬퍼.
///
/// Firestore 키(`loginMessage`/`loginNotice`)는 그대로 두고 값만 HTML로
/// 저장한다. 서식 도입 전 일반 텍스트로 저장된 값은 표시 시점에 이스케이프
/// 후 줄바꿈→`<br>`로 바꿔 그대로 보여 준다.
class BrandingHtml {
  static final RegExp _tagPattern = RegExp(r'<[a-zA-Z/!][^<>]*>');

  /// HTML 태그가 하나라도 있으면 HTML로 본다.
  static bool looksLikeHtml(String raw) => _tagPattern.hasMatch(raw);

  /// 표시용 HTML. 일반 텍스트면 이스케이프 + 줄바꿈을 `<br>`로 바꾼다.
  static String toHtml(String raw) {
    if (raw.trim().isEmpty) return '';
    if (looksLikeHtml(raw)) return raw;
    final escaped = raw
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return escaped.replaceAll('\r\n', '\n').replaceAll('\n', '<br>');
  }

  /// HTML에서 태그를 걷어 낸 일반 텍스트 (글자 수 확인·폴백용).
  static String stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</(p|div|li|h[1-6]|tr)>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^<>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

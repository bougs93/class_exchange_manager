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

  /// 제목 아래 안내 박스 본문
  final String notice;

  /// 학교 홈페이지 URL (로고 탭 시 이동)
  final String homeUrl;

  /// 학교 로고 다운로드 URL (비어 있으면 로고 미표시)
  final String logoUrl;

  /// 로고 이미지 base64 (웹 표시용, 비어 있을 수 있음)
  final String logoBase64;

  /// 로고 갱신 시각(ms). 이미지 캐시 무효화용.
  final int logoUpdatedAt;

  const WebLoginBranding({
    this.title = '',
    this.notice = '',
    this.homeUrl = '',
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

  bool get hasLogo =>
      logoBase64.isNotEmpty || logoUrl.trim().isNotEmpty;

  factory WebLoginBranding.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const WebLoginBranding();
    final title = (data['loginMessage'] ?? data['LoginMessage']) as String?;
    return WebLoginBranding(
      title: title?.trim() ?? '',
      notice: (data['loginNotice'] as String?)?.trim() ?? '',
      homeUrl: (data['schoolHomeUrl'] as String?)?.trim() ?? '',
      logoUrl: (data['schoolLogoUrl'] as String?)?.trim() ?? '',
      logoBase64: (data['schoolLogoBase64'] as String?)?.trim() ?? '',
      logoUpdatedAt: (data['schoolLogoUpdatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toPublicFields() => {
    'loginMessage': title,
    'loginNotice': notice,
    'schoolHomeUrl': homeUrl,
    'schoolLogoUrl': logoUrl,
    'schoolLogoBase64': logoBase64,
    'schoolLogoUpdatedAt': logoUpdatedAt,
  };

  WebLoginBranding copyWith({
    String? title,
    String? notice,
    String? homeUrl,
    String? logoUrl,
    String? logoBase64,
    int? logoUpdatedAt,
  }) {
    return WebLoginBranding(
      title: title ?? this.title,
      notice: notice ?? this.notice,
      homeUrl: homeUrl ?? this.homeUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      logoBase64: logoBase64 ?? this.logoBase64,
      logoUpdatedAt: logoUpdatedAt ?? this.logoUpdatedAt,
    );
  }
}

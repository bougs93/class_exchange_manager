import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/web_login_branding.dart';
import '../../utils/url_launcher_helper.dart';

/// 접속 화면용 학교 브랜딩 블록.
///
/// 버전 정보 아래에 배치한다.
/// 학교 로고 → 제목 → 안내 박스 순서.
///
/// 안내 박스 폭은 부모가 주는 폭을 그대로 쓴다.
/// (접속 화면에서만 부모를 폼보다 넓게 잡는다.)
class WebLoginBrandingBlock extends StatelessWidget {
  const WebLoginBrandingBlock({
    super.key,
    required this.branding,
    this.localLogoBytes,
    this.compact = false,
  });

  final WebLoginBranding branding;

  /// 관리자 미리보기용 — 아직 업로드 전인 로고 바이트.
  final Uint8List? localLogoBytes;

  /// 미리보기 다이얼로그에서는 여백을 조금 줄인다.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 12.0 : 16.0;
    final logoBytes = localLogoBytes ?? branding.logoBytes;
    final hasLogo = logoBytes != null || branding.hasLogo;
    final hasTitle = branding.title.isNotEmpty;
    final hasNotice = branding.notice.isNotEmpty;

    if (!hasLogo && !hasTitle && !hasNotice) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasLogo) ...[
          Center(child: _buildLogo(context)),
          SizedBox(height: gap),
        ],
        if (hasTitle)
          Text(
            branding.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        if (hasTitle && hasNotice) SizedBox(height: compact ? 10 : 12),
        if (hasNotice)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              branding.notice,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLogo(BuildContext context) {
    final image = _logoImage();
    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: compact ? 88 : 112,
        height: compact ? 88 : 112,
        child: image,
      ),
    );

    final url = branding.homeUrl.trim();
    if (url.isEmpty) return framed;

    return Tooltip(
      message: '학교 홈페이지 열기',
      child: InkWell(
        onTap: () => UrlLauncherHelper.launchURL(url, context: context),
        borderRadius: BorderRadius.circular(12),
        child: framed,
      ),
    );
  }

  Widget _logoImage() {
    final bytes = localLogoBytes ?? branding.logoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes, fit: BoxFit.contain);
    }
    // URL만 있고 바이트가 아직 없을 때 자리 표시.
    return ColoredBox(
      color: Colors.grey.shade100,
      child: Icon(
        Icons.school_outlined,
        size: 48,
        color: Colors.grey.shade400,
      ),
    );
  }
}

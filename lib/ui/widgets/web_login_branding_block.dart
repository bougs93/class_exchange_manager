import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../constants/app_assets.dart';
import '../../constants/app_info.dart';
import '../../models/web_login_branding.dart';
import '../../utils/url_launcher_helper.dart';

/// 프로그램 로고(+학교 로고) · 프로그램명 · 버전.
///
/// 학교 로고가 있으면 프로그램 로고 오른쪽에 나란히 둔다.
class WebLoginIdentityHeader extends StatelessWidget {
  const WebLoginIdentityHeader({
    super.key,
    required this.branding,
    this.localLogoBytes,
    this.compact = false,
  });

  final WebLoginBranding branding;
  final Uint8List? localLogoBytes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 80.0 : 96.0;
    final gap = compact ? 16.0 : 20.0;
    final hasSchoolLogo = localLogoBytes != null || branding.hasLogo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ProgramLogo(size: logoSize),
            if (hasSchoolLogo) ...[
              SizedBox(width: compact ? 16 : 20),
              WebLoginSchoolLogo(
                branding: branding,
                localLogoBytes: localLogoBytes,
                size: logoSize,
              ),
            ],
          ],
        ),
        SizedBox(height: gap),
        Text(
          AppInfo.programName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version : ${AppInfo.versionLabel}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _ProgramLogo extends StatelessWidget {
  const _ProgramLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: Image.asset(
        AppAssets.appIcon,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder:
            (_, _, _) => Icon(
              Icons.swap_horiz_rounded,
              size: size * 0.75,
              color: Colors.teal,
            ),
      ),
    );
  }
}

/// 학교 로고 (홈페이지 URL이 있으면 탭으로 연다).
class WebLoginSchoolLogo extends StatelessWidget {
  const WebLoginSchoolLogo({
    super.key,
    required this.branding,
    this.localLogoBytes,
    this.size = 96,
  });

  final WebLoginBranding branding;
  final Uint8List? localLogoBytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: size, height: size, child: _logoImage()),
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
    return ColoredBox(
      color: Colors.grey.shade100,
      child: Icon(
        Icons.school_outlined,
        size: size * 0.45,
        color: Colors.grey.shade400,
      ),
    );
  }
}

/// 접속 화면용 학교 브랜딩 블록 (제목 · 안내).
///
/// 로고는 [WebLoginIdentityHeader]에서 프로그램 로고 옆에 둔다.
/// [showLogo]가 true이면 예전처럼 이 블록 안에 학교 로고도 그린다.
class WebLoginBrandingBlock extends StatelessWidget {
  const WebLoginBrandingBlock({
    super.key,
    required this.branding,
    this.localLogoBytes,
    this.compact = false,
    this.showLogo = false,
  });

  final WebLoginBranding branding;

  /// 관리자 미리보기용 — 아직 업로드 전인 로고 바이트.
  final Uint8List? localLogoBytes;

  /// 미리보기 다이얼로그에서는 여백을 조금 줄인다.
  final bool compact;

  /// true면 제목 위에 학교 로고를 따로 그린다(헤더에 이미 있으면 false).
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 12.0 : 16.0;
    final hasLogo = showLogo && (localLogoBytes != null || branding.hasLogo);
    final hasTitle = branding.title.isNotEmpty;
    final hasGuideButton = branding.hasGuideButton;
    final hasNotice = branding.notice.isNotEmpty;

    if (!hasLogo && !hasTitle && !hasGuideButton && !hasNotice) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasLogo) ...[
          Center(
            child: WebLoginSchoolLogo(
              branding: branding,
              localLogoBytes: localLogoBytes,
              size: compact ? 88 : 112,
            ),
          ),
          SizedBox(height: gap),
        ],
        if (hasTitle)
          BrandingHtmlView(
            html: branding.displayTitleHtml,
            textAlign: TextAlign.center,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        // 제목 바로 아래 — 관리자가 설정한 사용법 링크(새 탭)
        if (hasGuideButton) ...[
          if (hasTitle) SizedBox(height: compact ? 8 : 10),
          Center(
            child: OutlinedButton.icon(
              onPressed:
                  () => UrlLauncherHelper.launchURL(
                    branding.guideButtonUrl.trim(),
                    context: context,
                  ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(branding.displayGuideButtonLabel),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
        if ((hasTitle || hasGuideButton) && hasNotice)
          SizedBox(height: compact ? 10 : 12),
        // 박스 장식 없이 서식 그대로 보여 준다 (2026-10-09 요청).
        if (hasNotice)
          BrandingHtmlView(
            html: branding.displayNoticeHtml,
            textAlign: TextAlign.left,
            fontSize: 13,
            lineHeight: 1.45,
          ),
      ],
    );
  }
}

/// 제목·안내 문구용 HTML 표시 위젯.
///
/// 저장값이 서식 도입 전 일반 텍스트면 [WebLoginBranding]이 표시용 HTML로
/// 바꿔 준다. 링크는 새 탭(외부 브라우저)으로 연다.
class BrandingHtmlView extends StatelessWidget {
  const BrandingHtmlView({
    super.key,
    required this.html,
    this.textAlign = TextAlign.left,
    this.fontSize = 13,
    this.fontWeight,
    this.lineHeight,
  });

  final String html;
  final TextAlign textAlign;
  final double fontSize;
  final FontWeight? fontWeight;
  final double? lineHeight;

  @override
  Widget build(BuildContext context) {
    // 제목은 기본 가운데 정렬 — div로 감싸면 안쪽 명시 정렬이 우선한다.
    final data =
        textAlign == TextAlign.center && html.trim().isNotEmpty
            ? '<div style="text-align: center;">$html</div>'
            : html;
    return HtmlWidget(
      data,
      textStyle: TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        color: Colors.grey.shade800,
        fontWeight: fontWeight,
      ),
      customStylesBuilder:
          (element) => switch (element.localName) {
            'a' => {'color': '#00796B'},
            'p' => {'margin': '0'},
            _ => null,
          },
      onTapUrl: (url) {
        UrlLauncherHelper.launchURL(url.trim(), context: context);
        return true;
      },
    );
  }
}

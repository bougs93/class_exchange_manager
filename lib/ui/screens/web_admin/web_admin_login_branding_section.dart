import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'web_admin_logo_preview.dart';

/// 접속 화면(학교 로고·안내) 브랜딩 섹션.
///
/// `WebAdminSettingsScreen`의 build()에서 분리된 순수 위젯이다. 로고 선택/
/// 제거, 기본 안내 적용, 미리보기, 저장은 모두 콜백으로 부모에게 넘기고
/// 내부에서는 `setState`를 호출하지 않는다.
class WebAdminLoginBrandingSection extends StatelessWidget {
  const WebAdminLoginBrandingSection({
    super.key,
    required this.saving,
    required this.displayLogoBytes,
    required this.showRemoveLogoButton,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.schoolHomeUrlController,
    required this.loginMessageController,
    required this.loginNoticeController,
    required this.onApplyDefaultNotice,
    required this.onShowPreview,
    required this.onSaveBranding,
    this.showSaveButton = true,
  });

  final bool saving;

  /// 미리보기에 쓸 로고 바이트 (새 선택 > 저장본).
  final Uint8List? displayLogoBytes;

  /// `_displayLogoBytes != null || (!_removeLogo && _branding.logoUrl.isNotEmpty)`.
  final bool showRemoveLogoButton;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;

  final TextEditingController schoolHomeUrlController;
  final TextEditingController loginMessageController;
  final TextEditingController loginNoticeController;

  final VoidCallback onApplyDefaultNotice;
  final VoidCallback onShowPreview;
  final VoidCallback onSaveBranding;

  /// 저장 버튼 표시 여부 (기본 true).
  ///
  /// 접속 설정 꾸미기 탭은 학교명·사용법 버튼까지 한 번에 저장하는
  /// 통합 버튼을 탭 하단에 두므로, 섹션별 버튼은 false로 숨긴다.
  final bool showSaveButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '접속 화면 (학교 로고·안내)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          '프로그램 로고 옆에 학교 로고가, 아래에 제목·안내 박스가 보입니다. '
          '로고를 누르면 홈페이지로 이동합니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        Center(child: WebAdminLogoPreview(logoBytes: displayLogoBytes)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: saving ? null : onPickLogo,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('로고 선택'),
            ),
            if (showRemoveLogoButton)
              TextButton(
                onPressed: saving ? null : onRemoveLogo,
                child: const Text('로고 제거'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: schoolHomeUrlController,
          decoration: const InputDecoration(
            labelText: '학교 홈페이지 주소',
            hintText: 'https://example.sen.ms.kr',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: loginMessageController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: '제목 (예: 월계중학교 2026년 2학기 시간표)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: loginNoticeController,
          // 내용에 따라 늘어나고, 안에서 스크롤되지 않는다 (바깥 ListView가
          // 스크롤한다). maxLines 고정은 긴 안내가 안에서 잘리게 만든다.
          minLines: 4,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: '안내 문구 (사각형 박스)',
            hintText: '선생님 전용입니다. 비밀번호를 입력해 주세요.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: saving ? null : onApplyDefaultNotice,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('기본값'),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: onShowPreview,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('미리보기'),
            ),
            if (showSaveButton) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: saving ? null : onSaveBranding,
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('접속 화면 저장'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

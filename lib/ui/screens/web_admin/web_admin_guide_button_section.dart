import 'package:flutter/material.dart';

/// 로그인 화면 사용법 버튼 설정 섹션.
///
/// `WebAdminSettingsScreen`의 build()에서 분리된 순수 위젯이다.
/// 저장은 콜백으로 부모에게 넘기고 내부에서는 `setState`를 호출하지 않는다.
class WebAdminGuideButtonSection extends StatelessWidget {
  const WebAdminGuideButtonSection({
    super.key,
    required this.saving,
    required this.labelController,
    required this.urlController,
    required this.onSave,
    this.showSaveButton = true,
  });

  final bool saving;
  final TextEditingController labelController;
  final TextEditingController urlController;
  final VoidCallback onSave;

  /// 저장 버튼 표시 여부 (기본 true) — 꾸미기 탭은 통합 버튼을 쓰므로
  /// false로 숨긴다.
  final bool showSaveButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '사용법 버튼',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          '접속 화면 제목 바로 아래에 버튼을 두고, 누르면 새 탭으로 엽니다. '
          '주소를 비우면 버튼이 숨겨지고, 이름만 비우면 '
          '「사용법 보기」로 표시됩니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: labelController,
          decoration: const InputDecoration(
            labelText: '버튼 이름',
            hintText: '사용법 보기',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: '링크 주소',
            hintText: 'https://example.com/guide',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 6),
        if (showSaveButton)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('사용법 버튼 저장'),
            ),
          ),
      ],
    );
  }
}

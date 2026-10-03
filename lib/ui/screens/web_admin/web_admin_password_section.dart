import 'package:flutter/material.dart';

import 'web_admin_password_field.dart';

/// 접속자·관리자 비밀번호 변경 섹션.
///
/// `WebAdminSettingsScreen`의 build()에서 분리된 순수 위젯이다. 내부에
/// `setState`를 두지 않고, 보기/숨기기 토글과 저장 동작을 모두 콜백으로
/// 부모에게 넘긴다.
class WebAdminPasswordSection extends StatelessWidget {
  const WebAdminPasswordSection({
    super.key,
    required this.saving,
    required this.viewerPasswordController,
    required this.viewerPasswordConfirmController,
    required this.viewerVisible,
    required this.onToggleViewerVisible,
    required this.onSaveViewerPassword,
    required this.adminPasswordController,
    required this.adminPasswordConfirmController,
    required this.adminVisible,
    required this.onToggleAdminVisible,
    required this.onSaveAdminPassword,
  });

  final bool saving;

  final TextEditingController viewerPasswordController;
  final TextEditingController viewerPasswordConfirmController;
  final bool viewerVisible;
  final VoidCallback onToggleViewerVisible;
  final VoidCallback onSaveViewerPassword;

  final TextEditingController adminPasswordController;
  final TextEditingController adminPasswordConfirmController;
  final bool adminVisible;
  final VoidCallback onToggleAdminVisible;
  final VoidCallback onSaveAdminPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '접속자 비밀번호 변경',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        WebAdminPasswordField(
          controller: viewerPasswordController,
          label: '새 접속자 비밀번호 (4자 이상)',
          visible: viewerVisible,
          onToggle: onToggleViewerVisible,
        ),
        const SizedBox(height: 8),
        WebAdminPasswordField(
          controller: viewerPasswordConfirmController,
          label: '새 접속자 비밀번호 확인',
          visible: viewerVisible,
          onToggle: onToggleViewerVisible,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: saving ? null : onSaveViewerPassword,
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('접속자 비밀번호 저장'),
          ),
        ),
        const Divider(height: 24),
        const Text(
          '관리자 비밀번호 변경',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        WebAdminPasswordField(
          controller: adminPasswordController,
          label: '새 관리자 비밀번호 (4자 이상)',
          visible: adminVisible,
          onToggle: onToggleAdminVisible,
        ),
        const SizedBox(height: 8),
        WebAdminPasswordField(
          controller: adminPasswordConfirmController,
          label: '새 관리자 비밀번호 확인',
          visible: adminVisible,
          onToggle: onToggleAdminVisible,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: saving ? null : onSaveAdminPassword,
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('관리자 비밀번호 저장'),
          ),
        ),
      ],
    );
  }
}

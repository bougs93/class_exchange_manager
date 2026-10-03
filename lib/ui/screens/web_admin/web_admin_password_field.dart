import 'package:flutter/material.dart';

/// 보기/숨기기 토글이 달린 비밀번호 입력란.
///
/// [WebAdminSettingsScreen]의 접속자/관리자 비밀번호 입력란에서 공용으로
/// 쓰인다. 내부 상태가 없어 `visible`·`onToggle`을 외부(부모의 `setState`)에서
/// 그대로 전달받는다.
class WebAdminPasswordField extends StatelessWidget {
  const WebAdminPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          tooltip: visible ? '숨기기' : '보기',
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 기본 학교명 설정 섹션.
///
/// `WebAdminSettingsScreen`의 build()에서 분리된 순수 위젯이다. 저장 동작은
/// 콜백으로 부모에게 넘기고 내부에서는 `setState`를 호출하지 않는다.
class WebAdminDefaultSchoolNameSection extends StatelessWidget {
  const WebAdminDefaultSchoolNameSection({
    super.key,
    required this.saving,
    required this.controller,
    required this.onSave,
  });

  final bool saving;
  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '기본 학교명 설정',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '예: 월계중학교',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('기본 학교명 저장'),
          ),
        ),
      ],
    );
  }
}

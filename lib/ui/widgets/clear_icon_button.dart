import 'package:flutter/material.dart';

/// TextField의 지우기 아이콘 버튼
///
/// TextEditingController의 텍스트가 비어있지 않을 때만 표시됩니다.
class ClearIconButton extends StatelessWidget {
  final TextEditingController controller;

  const ClearIconButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // 텍스트가 비어있으면 아무것도 표시하지 않음
    if (controller.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: Icon(Icons.clear, size: 16, color: Colors.grey.shade600),
      onPressed: controller.clear,
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      visualDensity: VisualDensity.compact,
      iconSize: 16,
    );
  }
}

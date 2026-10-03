import 'package:flutter/material.dart';

/// 언어 설정 섹션 (현재 한국어만 지원)
///
/// [StartSettingsCard]의 `_buildLanguageSection`을 그대로 옮긴 순수 표현
/// 위젯이다. 로딩 상태·현재 값·변경 콜백을 매개변수로 받는다.
class LanguageSection extends StatelessWidget {
  const LanguageSection({
    super.key,
    required this.isLoading,
    required this.selectedLanguage,
    required this.onChanged,
  });

  final bool isLoading;
  final String selectedLanguage;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(4.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '언어 설정',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        DropdownButton<String>(
          value: selectedLanguage,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(
              value: 'ko',
              child: Text('한국어', style: TextStyle(fontSize: 12)),
            ),
          ],
          onChanged:
              (newValue) =>
                  newValue != null && newValue != selectedLanguage
                      ? onChanged(newValue)
                      : null,
        ),
      ],
    );
  }
}

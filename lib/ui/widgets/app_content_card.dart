import 'package:flutter/material.dart';

/// 홈·도움말·정보 등에서 공통으로 사용하는 콘텐츠 카드
///
/// Material [Card] 기반으로 동일한 elevation·모서리·패딩을 제공합니다.
class AppContentCard extends StatelessWidget {
  const AppContentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: margin ?? EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

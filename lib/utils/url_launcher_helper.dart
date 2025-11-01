import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// URL 실행 유틸리티
///
/// 외부 링크를 브라우저나 앱에서 여는 공통 함수를 제공합니다.
class UrlLauncherHelper {
  /// URL을 외부 앱이나 브라우저에서 엽니다.
  ///
  /// [url]: 열려는 URL 문자열
  /// [context]: (선택) 에러 메시지 표시를 위한 BuildContext
  ///
  /// 반환값: URL 실행 성공 여부
  static Future<bool> launchURL(String url, {BuildContext? context}) async {
    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        debugPrint('URL 실행 불가: $url');
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('링크를 열 수 없습니다: $url'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('URL 실행 오류: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('링크를 여는 중 오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
  }
}

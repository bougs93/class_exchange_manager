import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../constants/app_assets.dart';
import '../../constants/app_info.dart';
import '../../models/web_login_branding.dart';
import 'web_login_branding_block.dart';

/// 관리자용 로그인(접속) 화면 전체 미리보기.
///
/// 실제 입력·로그인은 하지 않고, 선생님 접속 화면 레이아웃만 보여 준다.
class WebLoginScreenPreview extends StatelessWidget {
  const WebLoginScreenPreview({
    super.key,
    required this.branding,
    this.localLogoBytes,
  });

  final WebLoginBranding branding;
  final Uint8List? localLogoBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              AppAssets.appIcon,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, _, _) => const Icon(
                    Icons.swap_horiz_rounded,
                    size: 72,
                    color: Colors.teal,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            AppInfo.programName,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Version : ${AppInfo.versionLabel}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 20),
        WebLoginBrandingBlock(
          branding: branding,
          localLogoBytes: localLogoBytes,
          compact: true,
        ),
        const SizedBox(height: 20),
        const TextField(
          enabled: false,
          obscureText: true,
          decoration: InputDecoration(
            labelText: '선생님 접속 비밀번호',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: null,
          child: const Text('선생님 들어가기'),
        ),
        const SizedBox(height: 8),
        const TextButton(
          onPressed: null,
          child: Text('관리자 로그인'),
        ),
      ],
    );
  }
}

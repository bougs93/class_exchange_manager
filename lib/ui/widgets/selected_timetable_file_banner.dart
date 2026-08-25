import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// 선택된 시간표(엑셀) 파일 정보 배너
///
/// 교체 화면에서 사용하던 파란색 파일 표시 스타일을 홈 등에서 공통으로 사용합니다.
/// [selectedFile] 또는 [displayFileName] 중 하나라도 있으면 파일이 로드된 것으로 표시합니다.
class SelectedTimetableFileBanner extends StatelessWidget {
  final File? selectedFile;

  /// JSON 캐시 로드 시 metadata.fileName (로컬 xlsm 경로 없을 때)
  final String? displayFileName;

  const SelectedTimetableFileBanner({
    super.key,
    required this.selectedFile,
    this.displayFileName,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (selectedFile != null) {
      return _buildFileBanner(
        tokens,
        selectedFile!.path.split(Platform.pathSeparator).last,
        subtitle: null,
      );
    }

    final name = displayFileName?.trim();
    if (name != null && name.isNotEmpty) {
      return _buildFileBanner(tokens, name, subtitle: '저장된 시간표 데이터에서 불러옴');
    }

    return _buildNoFileBanner(tokens);
  }

  /// 파일 미선택 안내 (회색 배너)
  Widget _buildNoFileBanner(DesignTokens tokens) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Text(
        '시간표가 포함된 엑셀 파일(.xlsx, .xls, .xlsm)을 선택하세요.',
        style: TextStyle(fontSize: 14, color: tokens.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 선택된 파일명 표시 (파란색 배너)
  Widget _buildFileBanner(
    DesignTokens tokens,
    String fileName, {
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.description, color: tokens.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '파일: $fileName',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tokens.primary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: tokens.primary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

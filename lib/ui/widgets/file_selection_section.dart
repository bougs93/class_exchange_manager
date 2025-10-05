import 'dart:io';
import 'package:flutter/material.dart';

/// 파일 선택 섹션 위젯
/// 엑셀 파일 선택과 관련된 UI를 담당
class FileSelectionSection extends StatelessWidget {
  final File? selectedFile;
  final bool isLoading;
  final bool isExchangeModeEnabled;
  final bool isCircularExchangeModeEnabled;
  final bool isChainExchangeModeEnabled;
  final bool isNonExchangeableEditMode;
  final VoidCallback onToggleExchangeMode;
  final VoidCallback onToggleCircularExchangeMode;
  final VoidCallback onToggleChainExchangeMode;
  final VoidCallback onToggleNonExchangeableEditMode;

  const FileSelectionSection({
    super.key,
    required this.selectedFile,
    required this.isLoading,
    required this.isExchangeModeEnabled,
    required this.isCircularExchangeModeEnabled,
    required this.isChainExchangeModeEnabled,
    required this.isNonExchangeableEditMode,
    required this.onToggleExchangeMode,
    required this.onToggleCircularExchangeMode,
    required this.onToggleChainExchangeMode,
    required this.onToggleNonExchangeableEditMode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 파일 선택 상태에 따른 UI
            if (selectedFile == null) 
              _buildNoFileSelectedUI()
            else 
              _buildFileSelectedUI(),
          ],
        ),
      ),
    );
  }

  /// 파일이 선택되지 않았을 때의 UI
  Widget _buildNoFileSelectedUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        '시간표가 포함된 엑셀 파일(.xlsx, .xls)을 선택하세요.',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 파일이 선택되었을 때의 UI
  Widget _buildFileSelectedUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 선택된 파일 정보 표시
        _buildSelectedFileInfo(),
        
        const SizedBox(height: 12),
        
        // 버튼들
        _buildActionButtons(),
      ],
    );
  }

  /// 선택된 파일 정보 표시
  Widget _buildSelectedFileInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description,
            color: Colors.green.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '선택된 파일: ${selectedFile!.path.split('\\').last}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 액션 버튼들 구성
  Widget _buildActionButtons() {
    return Row(
      children: [
        // 교체불가 편집 모드 버튼
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onToggleNonExchangeableEditMode,
            icon: Icon(isNonExchangeableEditMode ? Icons.block : Icons.block_outlined),
            label: Text(isNonExchangeableEditMode ? '편집완료' : '교체불가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isNonExchangeableEditMode ? Colors.red.shade600 : Colors.red.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 1:1교체 버튼
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onToggleExchangeMode,
            icon: Icon(isExchangeModeEnabled ? Icons.swap_horiz : Icons.swap_horiz_outlined),
            label: Text(isExchangeModeEnabled ? '교체 모드 종료' : '1:1교체'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isExchangeModeEnabled ? Colors.orange.shade600 : Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 순환교체 버튼
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onToggleCircularExchangeMode,
            icon: Icon(isCircularExchangeModeEnabled ? Icons.refresh : Icons.refresh_outlined),
            label: Text(isCircularExchangeModeEnabled ? '순환교체 종료' : '순환교체'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCircularExchangeModeEnabled ? Colors.purple.shade600 : Colors.indigo.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // 연쇄교체 버튼
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onToggleChainExchangeMode,
            icon: Icon(isChainExchangeModeEnabled ? Icons.link : Icons.link_off_outlined),
            label: Text(isChainExchangeModeEnabled ? '연쇄교체 종료' : '연쇄교체'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isChainExchangeModeEnabled ? Colors.deepOrange.shade700 : Colors.deepOrange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

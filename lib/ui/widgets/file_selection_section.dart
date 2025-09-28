import 'dart:io';
import 'package:flutter/material.dart';

/// 파일 선택 섹션 위젯
/// 엑셀 파일 선택과 관련된 UI를 담당
class FileSelectionSection extends StatelessWidget {
  final File? selectedFile;
  final bool isLoading;
  final bool isExchangeModeEnabled;
  final bool isCircularExchangeModeEnabled;
  final VoidCallback onSelectExcelFile;
  final VoidCallback onToggleExchangeMode;
  final VoidCallback onToggleCircularExchangeMode;
  final VoidCallback onClearSelection;

  const FileSelectionSection({
    super.key,
    required this.selectedFile,
    required this.isLoading,
    required this.isExchangeModeEnabled,
    required this.isCircularExchangeModeEnabled,
    required this.onSelectExcelFile,
    required this.onToggleExchangeMode,
    required this.onToggleCircularExchangeMode,
    required this.onClearSelection,
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
            // 헤더
            _buildHeader(),
            
            const SizedBox(height: 12),
            
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

  /// 헤더 구성
  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.upload_file,
          color: Colors.blue.shade600,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          '엑셀 파일 선택',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade600,
          ),
        ),
      ],
    );
  }

  /// 파일이 선택되지 않았을 때의 UI
  Widget _buildNoFileSelectedUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시간표가 포함된 엑셀 파일(.xlsx, .xls)을 선택하세요.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onSelectExcelFile,
            icon: isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: Text(isLoading ? '처리 중...' : '엑셀 파일 선택'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
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
        // 다른 파일 선택 버튼
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onSelectExcelFile,
            icon: isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(isLoading ? '처리 중...' : '다른 파일 선택'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
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
        
        // 선택 해제 버튼
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onClearSelection,
            icon: const Icon(Icons.clear),
            label: const Text('선택 해제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

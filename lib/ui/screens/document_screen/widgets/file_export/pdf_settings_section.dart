import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../../constants/korean_fonts.dart';
import '../../../../../utils/pdf_field_config.dart';

/// PDF 설정 섹션 위젯
///
/// 템플릿 선택, 폰트 설정, 비고 출력 여부 등을 관리하는 위젯입니다.
class PdfSettingsSection extends StatelessWidget {
  final int selectedTemplateIndex;
  final String? selectedTemplateFilePath;
  final double fontSize;
  final double remarksFontSize;
  final String selectedFont;
  final bool includeRemarks;
  final List<double> fontSizeOptions;
  final List<double> remarksFontSizeOptions;
  final ValueChanged<int> onTemplateIndexChanged;
  final ValueChanged<String?> onTemplateFilePathChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onRemarksFontSizeChanged;
  final ValueChanged<String> onFontChanged;
  final ValueChanged<bool> onIncludeRemarksChanged;

  const PdfSettingsSection({
    super.key,
    required this.selectedTemplateIndex,
    required this.selectedTemplateFilePath,
    required this.fontSize,
    required this.remarksFontSize,
    required this.selectedFont,
    required this.includeRemarks,
    required this.fontSizeOptions,
    required this.remarksFontSizeOptions,
    required this.onTemplateIndexChanged,
    required this.onTemplateFilePathChanged,
    required this.onFontSizeChanged,
    required this.onRemarksFontSizeChanged,
    required this.onFontChanged,
    required this.onIncludeRemarksChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PDF 양식 선택
        _buildTemplateSelector(context),
        const SizedBox(height: 15),
        // 폰트 설정
        _buildFontSettings(),
      ],
    );
  }

  /// PDF 양식 파일 선택
  Widget _buildTemplateSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '양식 PDF 선택',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                height: 37,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.centerLeft,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _getCurrentSelectedIndex(),
                  underline: const SizedBox.shrink(),
                  iconSize: 24,
                  isDense: false,
                  style: const TextStyle(color: Colors.black, fontSize: 13),
                  items: _buildDropdownItems(),
                  onChanged: (int? newIndex) {
                    if (newIndex == null) return;
                    if (newIndex < kPdfTemplates.length) {
                      onTemplateIndexChanged(newIndex);
                      onTemplateFilePathChanged(null);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _pickPdfTemplate(context),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('내 컴퓨터에서 PDF 선택', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        if (selectedTemplateFilePath != null) ...[
          const SizedBox(height: 2),
          Text(selectedTemplateFilePath!, style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
          const SizedBox(height: 2),
          Text('사용자 선택 파일이 우선 적용됩니다.', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
        ],
      ],
    );
  }

  /// 폰트 설정 섹션
  Widget _buildFontSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.font_download, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text('폰트 설정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 16),
          _buildFontTypeSelector(),
          const SizedBox(height: 16),
          _buildFontSizeRow(),
        ],
      ),
    );
  }

  /// 폰트 종류 선택
  Widget _buildFontTypeSelector() {
    return Row(
      children: [
        Expanded(child: Text('폰트 종류', style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: selectedFont,
              underline: const SizedBox.shrink(),
              isExpanded: true,
              isDense: true,
              style: const TextStyle(color: Colors.black, fontSize: 13),
              items: KoreanFontConstants.fontListWithNames.map((font) {
                return DropdownMenuItem(
                  value: font['file']!,
                  child: Text(font['name']!, style: const TextStyle(color: Colors.black)),
                );
              }).toList(),
              onChanged: (String? newFont) {
                if (newFont != null) onFontChanged(newFont);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 폰트 사이즈 행 (일반 + 비고)
  Widget _buildFontSizeRow() {
    return Row(
      children: [
        Expanded(child: _buildFontSizeDropdown('일 반', fontSize, fontSizeOptions, onFontSizeChanged)),
        Container(
          width: 1,
          height: 25,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(0.5)),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildFontSizeDropdown('비 고', remarksFontSize, remarksFontSizeOptions, onRemarksFontSizeChanged)),
              const SizedBox(width: 16),
              Row(
                children: [
                  Checkbox(
                    value: includeRemarks,
                    onChanged: (bool? value) {
                      if (value != null) onIncludeRemarksChanged(value);
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text('비고 출력', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 폰트 사이즈 드롭다운
  Widget _buildFontSizeDropdown(String label, double value, List<double> options, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<double>(
            value: value,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: const TextStyle(color: Colors.black, fontSize: 13),
            items: options.map((size) {
              return DropdownMenuItem(
                value: size,
                child: Text('${size.toInt()}pt', style: const TextStyle(color: Colors.black)),
              );
            }).toList(),
            onChanged: (double? newSize) {
              if (newSize != null) onChanged(newSize);
            },
          ),
        ),
      ],
    );
  }

  /// 드롭다운 항목 생성
  List<DropdownMenuItem<int>> _buildDropdownItems() {
    final items = <DropdownMenuItem<int>>[];
    for (int i = 0; i < kPdfTemplates.length; i++) {
      items.add(DropdownMenuItem<int>(
        value: i,
        child: Text(kPdfTemplates[i].name, style: const TextStyle(color: Colors.black, fontSize: 13)),
      ));
    }
    if (selectedTemplateFilePath != null) {
      final fileName = selectedTemplateFilePath!.split(Platform.pathSeparator).last;
      items.add(DropdownMenuItem<int>(
        value: kPdfTemplates.length,
        child: Text(fileName, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500)),
      ));
    }
    return items;
  }

  /// 현재 선택된 인덱스
  int _getCurrentSelectedIndex() {
    return selectedTemplateFilePath != null ? kPdfTemplates.length : selectedTemplateIndex;
  }

  /// PDF 템플릿 파일 선택
  Future<void> _pickPdfTemplate(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: false,
      dialogTitle: 'PDF 양식 파일 선택',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path != null) {
      onTemplateFilePathChanged(path);
    }
  }
}

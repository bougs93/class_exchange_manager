import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../utils/pdf_field_config.dart';
import '../../../../services/pdf_export_service.dart';

/// 파일 출력 위젯
/// 
/// 결보강 계획서를 PDF 형식으로 내보낼 수 있는 위젯입니다.
class FileExportWidget extends ConsumerStatefulWidget {
  const FileExportWidget({super.key});

  @override
  ConsumerState<FileExportWidget> createState() => _FileExportWidgetState();
}

class _FileExportWidgetState extends ConsumerState<FileExportWidget> {
  // 현재 선택된 PDF 템플릿 인덱스 (기본: 첫 번째)
  int _selectedTemplateIndex = 0;
  // 사용자가 직접 선택한 PDF 템플릿 파일 경로(있으면 이것을 우선 사용)
  String? _selectedTemplateFilePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          
          // 안내 문구
          _buildInfoSection(),
          
          const SizedBox(height: 15),
          
          // PDF 양식 파일 선택
          _buildTemplateSelector(),

          const SizedBox(height: 8),
          _buildTemplateFilePicker(),
          
          const SizedBox(height: 15),
          
          // 내보내기 버튼
          _buildExportButton(),
          
          const SizedBox(height: 15),
          
          // 주의사항
          _buildNoticeSection(),
        ],
      ),
    );
  }

  /// 안내 섹션
  Widget _buildInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                '안내',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '결보강 계획서를 PDF 파일로 내보낼 수 있습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// PDF 양식 파일 선택 드롭다운
  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PDF양식 파일 선택',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            isExpanded: true,
            value: _selectedTemplateIndex,
            underline: const SizedBox.shrink(),
            items: [
              for (int i = 0; i < kPdfTemplates.length; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text(kPdfTemplates[i].name),
                ),
            ],
            onChanged: (int? newIndex) {
              if (newIndex == null) return;
              setState(() {
                _selectedTemplateIndex = newIndex;
              });
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          kPdfTemplates[_selectedTemplateIndex].assetPath,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        if (_selectedTemplateFilePath != null) ...[
          const SizedBox(height: 4),
          Text(
            '사용자 선택 파일이 우선 적용됩니다.',
            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
          ),
        ],
      ],
    );
  }

  /// 로컬 PDF 양식 파일 선택 (file_picker)
  Widget _buildTemplateFilePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickPdfTemplate,
              icon: const Icon(Icons.upload_file),
              label: const Text('내 컴퓨터에서 PDF 선택'),
            ),
            const SizedBox(width: 12),
            if (_selectedTemplateFilePath != null)
              Expanded(
                child: Text(
                  _selectedTemplateFilePath!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
          ],
        ),
        if (_selectedTemplateFilePath == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '선택된 파일 없음 (미선택 시 내장 템플릿 사용)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Future<void> _pickPdfTemplate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: false,
      dialogTitle: 'PDF 양식 파일 선택',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    if (!mounted) return;
    setState(() {
      _selectedTemplateFilePath = path;
    });
  }

  /// 내보내기 버튼
  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleExport(),
        icon: const Icon(Icons.picture_as_pdf, size: 24),
        label: const Text(
          'PDF 파일 내보내기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  /// 주의사항 섹션
  Widget _buildNoticeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                '주의사항',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...[
            '파일을 저장할 위치를 미리 확인하세요',
            '파일 내보내기 중에는 프로그램을 종료하지 마세요',
          ].map((notice) {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      notice,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }


  /// 파일 내보내기 처리
  Future<void> _handleExport() async {
    if (!mounted) return;

    try {
      // 1) 데이터 수집
      final planData = ref.read(substitutionPlanViewModelProvider).planData;
      if (planData.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('내보낼 데이터가 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 2) 출력 경로 생성 (Downloads/문서 폴더)
      final outputPath = await _buildOutputPath();

      // 3) 중복 파일 체크
      final finalOutputPath = _getUniqueFilePath(outputPath);

      // 4) PDF 내보내기 실행
      final String templatePath = _selectedTemplateFilePath ?? kPdfTemplates[_selectedTemplateIndex].assetPath;
      final success = await PdfExportService.exportSubstitutionPlan(
        planData: planData,
        outputPath: finalOutputPath,
        templatePath: templatePath,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'PDF 내보내기 완료: $finalOutputPath' : 'PDF 내보내기 실패'),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 기본 출력 경로 생성 (Downloads 우선, 없으면 Documents)
  Future<String> _buildOutputPath() async {
    final now = DateTime.now();
    final baseName = '${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} 결보강계획서.pdf';

    Directory? downloads;
    try {
      downloads = await getDownloadsDirectory();
    } catch (_) {
      downloads = null;
    }
    Directory targetDir;
    if (downloads != null) {
      targetDir = downloads;
    } else {
      targetDir = await getApplicationDocumentsDirectory();
    }
    return '${targetDir.path}${Platform.pathSeparator}$baseName';
  }

  /// 동일 파일명이 있으면 (1), (2) 를 붙여 유니크한 경로 생성
  String _getUniqueFilePath(String basePath) {
    if (!File(basePath).existsSync()) return basePath;
    final dir = File(basePath).parent.path;
    final fileName = basePath.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    final name = dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
    final ext = dotIndex == -1 ? '' : fileName.substring(dotIndex);
    int counter = 1;
    while (true) {
      final candidate = '$dir${Platform.pathSeparator}$name($counter)$ext';
      if (!File(candidate).existsSync()) return candidate;
      counter++;
    }
  }
}


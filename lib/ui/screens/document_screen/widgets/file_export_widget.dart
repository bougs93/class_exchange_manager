import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/excel_export_service.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';

/// 파일 출력 위젯
/// 
/// 교체 기록을 다양한 형식으로 내보낼 수 있는 위젯입니다.
class FileExportWidget extends ConsumerStatefulWidget {
  const FileExportWidget({super.key});

  @override
  ConsumerState<FileExportWidget> createState() => _FileExportWidgetState();
}

class _FileExportWidgetState extends ConsumerState<FileExportWidget> {

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
            '결보강 계획서, 학급안내, 교사안내를 엑셀 파일로 내보낼 수 있습니다.',
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

  /// 내보내기 버튼
  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleExport(),
        icon: const Icon(Icons.table_chart, size: 24),
        label: const Text(
          'Excel 파일 내보내기',
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
      // 1) 템플릿 파일 경로 확인
      const templatePath = 'lib/결보강계획서_양식.xlsx';
      final templateFile = File(templatePath);
      
      if (!templateFile.existsSync()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('템플릿 파일을 찾을 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2) 데이터 수집
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

      // 3) 파일명 생성 (MM.dd 결보강계획서.xlsx)
      final now = DateTime.now();
      final fileName =
          '${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} 결보강계획서.xlsx';
      final outputPath = '${Directory.current.path}/$fileName';

      // 4) 중복 파일 체크
      final finalOutputPath = _getUniqueFilePath(outputPath);

      // 5) 내보내기 실행
      final success = await ExcelExportService.exportSubstitutionPlan(
        templatePath: templatePath,
        planData: planData,
        outputPath: finalOutputPath,
        context: context,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 완료: $finalOutputPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('파일 내보내기에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  /// 고유한 파일 경로 생성
  String _getUniqueFilePath(String originalPath) {
    final file = File(originalPath);
    if (!file.existsSync()) {
      return originalPath;
    }

    final path = file.path;
    final lastDot = path.lastIndexOf('.');
    final fileNameWithoutExt =
        lastDot == -1 ? path : path.substring(0, lastDot);
    final extension = lastDot == -1 ? '' : path.substring(lastDot);

    int counter = 1;
    while (true) {
      final newPath = '$fileNameWithoutExt ($counter)$extension';
      if (!File(newPath).existsSync()) {
        return newPath;
      }
      counter++;
    }
  }
}

/// 내보내기 파일 형식 열거형
enum ExportFormat {
  /// Excel 파일
  excel,
}

/// ExportFormat 확장 메서드들
extension ExportFormatExtension on ExportFormat {
  /// 형식별 표시 이름
  String get displayName {
    switch (this) {
      case ExportFormat.excel:
        return 'Excel 파일 (.xlsx)';
    }
  }
  
  /// 형식별 설명
  String get description {
    switch (this) {
      case ExportFormat.excel:
        return '엑셀로 열 수 있는 표 형식 파일';
    }
  }
  
  /// 형식별 아이콘
  IconData get icon {
    switch (this) {
      case ExportFormat.excel:
        return Icons.table_chart;
    }
  }
}


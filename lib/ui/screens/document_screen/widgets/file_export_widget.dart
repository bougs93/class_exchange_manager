import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../utils/pdf_field_config.dart';

/// 파일 출력 위젯
/// 
/// 결보강 계획서를 PDF 형식으로 내보낼 수 있는 위젯입니다.
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

      // 2) 파일명 생성 (MM.dd 결보강계획서.pdf)
      // final now = DateTime.now();
      // final fileName =
      //     '${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} 결보강계획서.pdf';
      // final outputPath = '${Directory.current.path}/$fileName';

      // 3) 중복 파일 체크
      // final finalOutputPath = _getUniqueFilePath(outputPath);

      // 4) PDF 내보내기 실행 (필드명 유틸 사용 예시)
      // TODO: PDF 생성 서비스 구현 필요
      // final success = await PdfExportService.exportSubstitutionPlan(
      //   planData: planData,
      //   outputPath: finalOutputPath,
      //   context: context,
      // );

      // 예: 1행의 'grade' 컬럼에 해당하는 PDF 필드명 계산 (경고 제거용 샘플)
      // 실제 내보내기 구현 시 삭제/대체하세요.
      if (planData.isNotEmpty) {
        final sampleField = pdfCellFieldName(1, 'grade');
        debugPrint('sample pdf field: $sampleField');
      }

      if (!mounted) return;

      // 임시 메시지 (PDF 서비스 구현 후 제거)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF 내보내기 기능은 준비 중입니다.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
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
}


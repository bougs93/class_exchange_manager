import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../../utils/pdf_field_config.dart';
import '../../../../../services/pdf_export_service.dart';
import '../../../../../constants/korean_fonts.dart';
import 'pdf_settings_section.dart';
import 'pdf_field_inputs_section.dart';
import '../../pdf_preview_screen.dart';

/// 파일 출력 위젯 (리팩토링된 버전)
///
/// 결보강 계획서를 PDF 형식으로 미리보고 저장할 수 있는 위젯입니다.
/// 설정 및 입력 섹션은 별도 위젯으로 분리되어 있습니다.
class FileExportWidget extends ConsumerStatefulWidget {
  const FileExportWidget({super.key});

  @override
  ConsumerState<FileExportWidget> createState() => _FileExportWidgetState();
}

class _FileExportWidgetState extends ConsumerState<FileExportWidget> {
  // PDF 템플릿 설정
  int _selectedTemplateIndex = 0;
  String? _selectedTemplateFilePath;

  // 폰트 설정
  double _fontSize = 10.0;
  double _remarksFontSize = 7.0;
  String _selectedFont = KoreanFontConstants.defaultFont;
  bool _includeRemarks = true;

  // 폰트 사이즈 옵션
  final List<double> _fontSizeOptions = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0];
  final List<double> _remarksFontSizeOptions = [6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0];

  // PDF 추가 필드 컨트롤러
  final TextEditingController _teacherNameController = TextEditingController();
  final TextEditingController _absencePeriodController = TextEditingController();
  final TextEditingController _workStatusController = TextEditingController();
  final TextEditingController _reasonForAbsenceController = TextEditingController();
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController(
    text: '''< 유 의 사 항 >
☆ 결강교사, 과목, 기간은 해당 교사의 내용으로 기록합니다.
☆ 결강발생 시 결강 교사 본인이 교체한 후 사전에 결재를 득하여 제출합니다.(부득이한 경우 수업계 협조)
☆ 근무상황은 연가, 병가, 출장, 조퇴 등을 기록합니다.
☆ 결강사유는 결강내용을 기록하여 주시고 출장, 연수 등에는 장소도 함께 기록하여 주십시오.
☆ 결강일 작성은 해당일 여러 과목 결강 발생 시 최초 윗줄만 기록하여 주십시오.
☆ 교체를 원칙으로 하나 수업교체가 어려운 경우는 동교과 보강 또는 수업변경으로 처리할 수 있습니다.
☆ 원어민(영어, 중국어) 수업의 경우 겸임 날짜가 지정되어 있으므로 수업 교체시 유의해 주십시오.''',
  );

  @override
  void dispose() {
    _teacherNameController.dispose();
    _absencePeriodController.dispose();
    _workStatusController.dispose();
    _reasonForAbsenceController.dispose();
    _notesController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PDF 설정 섹션 (템플릿, 폰트)
          PdfSettingsSection(
            selectedTemplateIndex: _selectedTemplateIndex,
            selectedTemplateFilePath: _selectedTemplateFilePath,
            fontSize: _fontSize,
            remarksFontSize: _remarksFontSize,
            selectedFont: _selectedFont,
            includeRemarks: _includeRemarks,
            fontSizeOptions: _fontSizeOptions,
            remarksFontSizeOptions: _remarksFontSizeOptions,
            onTemplateIndexChanged: (index) => setState(() => _selectedTemplateIndex = index),
            onTemplateFilePathChanged: (path) => setState(() => _selectedTemplateFilePath = path),
            onFontSizeChanged: (size) => setState(() => _fontSize = size),
            onRemarksFontSizeChanged: (size) => setState(() => _remarksFontSize = size),
            onFontChanged: (font) => setState(() => _selectedFont = font),
            onIncludeRemarksChanged: (include) => setState(() => _includeRemarks = include),
          ),

          const SizedBox(height: 15),

          // PDF 추가 필드 입력 섹션
          PdfFieldInputsSection(
            teacherNameController: _teacherNameController,
            absencePeriodController: _absencePeriodController,
            workStatusController: _workStatusController,
            reasonForAbsenceController: _reasonForAbsenceController,
            notesController: _notesController,
            schoolNameController: _schoolNameController,
          ),

          const SizedBox(height: 15),

          // 문서 출력 버튼
          _buildDocumentOutputButton(),
        ],
      ),
    );
  }

  /// 문서 출력 버튼
  Widget _buildDocumentOutputButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handlePreview,
        icon: const Icon(Icons.description, size: 20),
        label: const Text(
          '문서 출력',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.purple.shade600,
          side: BorderSide(color: Colors.purple.shade600),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  /// 출력 미리 보기 처리
  Future<void> _handlePreview() async {
    if (!mounted) return;

    try {
      // 1. 데이터 수집
      final planData = ref.read(substitutionPlanViewModelProvider).planData;
      if (planData.isEmpty) {
        if (!mounted) return;
        _showSnackBar('미리볼 데이터가 없습니다.', Colors.orange);
        return;
      }

      // 2. 임시 파일 경로 생성
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}${Platform.pathSeparator}preview_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // 3. PDF 생성
      final String templatePath = _selectedTemplateFilePath ?? kPdfTemplates[_selectedTemplateIndex].assetPath;
      final success = await PdfExportService.exportSubstitutionPlan(
        planData: planData,
        outputPath: tempPath,
        templatePath: templatePath,
        fontSize: _fontSize,
        remarksFontSize: _remarksFontSize,
        fontType: _selectedFont,
        includeRemarks: _includeRemarks,
        additionalFields: {
          'teacherName': _teacherNameController.text,
          'absencePeriod': _absencePeriodController.text,
          'workStatus': _workStatusController.text,
          'reasonForAbsence': _reasonForAbsenceController.text,
          'notes': _notesController.text,
          'schoolName': _schoolNameController.text,
        },
      );

      if (!mounted) return;

      if (!success) {
        _showSnackBar('출력 미리 보기 생성 실패', Colors.red);
        return;
      }

      // 4. 미리보기 화면으로 이동
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(pdfPath: tempPath),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('오류: $e', Colors.red);
      }
    }
  }

  /// 스낵바 표시
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

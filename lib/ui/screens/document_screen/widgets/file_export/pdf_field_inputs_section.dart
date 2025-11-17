import 'package:flutter/material.dart';
import '../../../../widgets/input_decoration_helper.dart';

/// PDF 추가 필드 입력 섹션
///
/// 결강교사, 결강기간, 근무상황, 결강사유, 학교명, 주의사항 등을 입력하는 위젯입니다.
class PdfFieldInputsSection extends StatefulWidget {
  final TextEditingController teacherNameController;
  final TextEditingController absencePeriodController;
  final TextEditingController workStatusController;
  final TextEditingController reasonForAbsenceController;
  final TextEditingController notesController;
  final TextEditingController schoolNameController;

  const PdfFieldInputsSection({
    super.key,
    required this.teacherNameController,
    required this.absencePeriodController,
    required this.workStatusController,
    required this.reasonForAbsenceController,
    required this.notesController,
    required this.schoolNameController,
  });

  @override
  State<PdfFieldInputsSection> createState() => _PdfFieldInputsSectionState();
}

class _PdfFieldInputsSectionState extends State<PdfFieldInputsSection> {
  @override
  void initState() {
    super.initState();
    // 모든 컨트롤러에 리스너 추가하여 텍스트 변경 시 UI 업데이트
    _addListeners();
  }

  @override
  void didUpdateWidget(PdfFieldInputsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 위젯이 업데이트될 때 Controller가 변경된 경우에만 리스너 재등록
    if (oldWidget.teacherNameController != widget.teacherNameController ||
        oldWidget.workStatusController != widget.workStatusController ||
        oldWidget.reasonForAbsenceController != widget.reasonForAbsenceController ||
        oldWidget.schoolNameController != widget.schoolNameController ||
        oldWidget.notesController != widget.notesController ||
        oldWidget.absencePeriodController != widget.absencePeriodController) {
      // Controller가 변경된 경우 리스너 재등록
      _removeListeners();
      _addListeners();
      // UI 강제 업데이트 (새 Controller로 변경되었으므로 필요)
      setState(() {});
    }
    // Controller가 동일한 경우 리스너가 자동으로 변경을 감지하므로 setState() 불필요
  }

  @override
  void dispose() {
    // 리스너 제거
    _removeListeners();
    super.dispose();
  }

  /// 모든 컨트롤러에 리스너 추가
  void _addListeners() {
    widget.teacherNameController.addListener(_onTextChanged);
    widget.absencePeriodController.addListener(_onTextChanged);
    widget.workStatusController.addListener(_onTextChanged);
    widget.reasonForAbsenceController.addListener(_onTextChanged);
    widget.schoolNameController.addListener(_onTextChanged);
    widget.notesController.addListener(_onTextChanged);
  }

  /// 모든 컨트롤러에서 리스너 제거
  void _removeListeners() {
    widget.teacherNameController.removeListener(_onTextChanged);
    widget.absencePeriodController.removeListener(_onTextChanged);
    widget.workStatusController.removeListener(_onTextChanged);
    widget.reasonForAbsenceController.removeListener(_onTextChanged);
    widget.schoolNameController.removeListener(_onTextChanged);
    widget.notesController.removeListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {}); // 텍스트 변경 시 UI 업데이트
  }

  @override
  Widget build(BuildContext context) {
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
          // 섹션 제목
          Row(
            children: [
              Icon(Icons.edit_note, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                '추가 필드 입력',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. 결강교사
          _buildTextField(
            controller: widget.teacherNameController,
            label: '결강교사',
            hint: '결강한 교사 이름을 입력하세요',
          ),
          const SizedBox(height: 12),

          // 2. 결강기간
          _buildTextField(
            controller: widget.absencePeriodController,
            label: '결강기간',
            hint: '예: 2024.01.15 ~ 2024.01.19',
          ),
          const SizedBox(height: 12),

          // 3. 근무상황
          _buildTextField(
            controller: widget.workStatusController,
            label: '근무상황',
            hint: '예: 출장, 연가, 병가 등',
          ),
          const SizedBox(height: 12),

          // 4. 결강사유
          _buildTextField(
            controller: widget.reasonForAbsenceController,
            label: '결강사유',
            hint: '결강 사유를 입력하세요',
          ),
          const SizedBox(height: 12),

          // 5. 학교명
          _buildTextField(
            controller: widget.schoolNameController,
            label: '학교명',
            hint: '학교명을 입력하세요',
          ),
          const SizedBox(height: 12),

          // 6. 설명 (여러 줄)
          _buildTextField(
            controller: widget.notesController,
            label: '설명',
            hint: '설명를 입력하세요 (여러 줄 가능)',
            maxLines: 6,
          ),
        ],
      ),
    );
  }

  /// 텍스트 필드 생성 헬퍼 메서드
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    // 지우기 아이콘 (텍스트가 있을 때만 표시)
    Widget? buildClearIcon() {
      return controller.text.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.clear, size: 16, color: Colors.grey.shade600),
              onPressed: () {
                controller.clear();
              },
              // padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              visualDensity: VisualDensity.compact,
              iconSize: 16,
            )
          : null;
    }

    // 여러 줄 입력인 경우 세로로 배치
    if (maxLines > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecorationHelper.buildStandard(
              hintText: hint,
            ).copyWith(
              suffixIcon: buildClearIcon(),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
            ),
          ),
        ],
      );
    }

    // 1줄 입력인 경우 가로로 배치
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecorationHelper.buildStandard(
              hintText: hint,
              isDense: true,
            ).copyWith(
              suffixIcon: buildClearIcon(),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

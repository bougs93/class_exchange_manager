import 'package:flutter/material.dart';

/// PDF 추가 필드 입력 섹션
///
/// 결강교사, 결강기간, 근무상황, 결강사유, 학교명, 주의사항 등을 입력하는 위젯입니다.
class PdfFieldInputsSection extends StatelessWidget {
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
            controller: teacherNameController,
            label: '결강교사',
            hint: '결강한 교사 이름을 입력하세요',
          ),
          const SizedBox(height: 12),

          // 2. 결강기간
          _buildTextField(
            controller: absencePeriodController,
            label: '결강기간',
            hint: '예: 2024.01.15 ~ 2024.01.19',
          ),
          const SizedBox(height: 12),

          // 3. 근무상황
          _buildTextField(
            controller: workStatusController,
            label: '근무상황',
            hint: '예: 출장, 연가, 병가 등',
          ),
          const SizedBox(height: 12),

          // 4. 결강사유
          _buildTextField(
            controller: reasonForAbsenceController,
            label: '결강사유',
            hint: '결강 사유를 입력하세요',
          ),
          const SizedBox(height: 12),

          // 5. 학교명
          _buildTextField(
            controller: schoolNameController,
            label: '학교명',
            hint: '학교명을 입력하세요',
          ),
          const SizedBox(height: 12),

          // 6. 주의사항 (여러 줄)
          _buildTextField(
            controller: notesController,
            label: '주의사항',
            hint: '주의사항을 입력하세요 (여러 줄 가능)',
            maxLines: 4,
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
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
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
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

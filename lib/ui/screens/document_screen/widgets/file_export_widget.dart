import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'substitution_plan_grid_helpers.dart';

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
          
          const SizedBox(height: 32),
          
          // 내보내기 형식 표시
          _buildFormatInfo(),
          
          const SizedBox(height: 32),
          
          // 내보내기 버튼
          _buildExportButton(),
          
          const SizedBox(height: 24),
          
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
            '교체 기록을 선택한 형식으로 내보낼 수 있습니다.\n내보내기 전에 교체 기록이 정확히 입력되어 있는지 확인하세요.\n출력할 파일은 "결보강계획서_양식.xlsx" 파일이 필요합니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          
          // 테이블 미리보기
          Text(
            '출력될 파일 형식:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 8),
          _buildTablePreview(),
        ],
      ),
    );
  }

  /// 테이블 미리보기 위젯
  /// 
  /// 결보강계획서 테이블의 헤더 구조를 미리보기로 보여줍니다.
  /// SubstitutionPlanGridConfig를 사용하여 공통 구조를 재사용합니다.
  Widget _buildTablePreview() {
    // SubstitutionPlanGridConfig에서 헤더 정보 가져오기
    final columns = SubstitutionPlanGridConfig.getColumns();
    final stackedHeaders = SubstitutionPlanGridConfig.getStackedHeaders();
    
    // 스택 헤더 정보 추출
    if (stackedHeaders.isEmpty) return const SizedBox.shrink();
    final firstStackedHeader = stackedHeaders[0];
    final stackedCells = firstStackedHeader.cells;
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 첫 번째 행: 큰 헤더 (결강, 보강/수업변경, 수업 교체, 비고)
            _buildStackedHeaderRow(stackedCells),
            
            // 두 번째 행: 세부 헤더
            _buildDetailHeaderRow(columns),
            
            // 예시 데이터 행 (이미지와 같은 형식으로)
            _buildExampleDataRow(),
          ],
        ),
      ),
    );
  }
  
  /// 스택 헤더 행 생성 (상단 큰 헤더)
  Widget _buildStackedHeaderRow(List<StackedHeaderCell> stackedCells) {
    return Row(
      children: stackedCells.map((cell) {
        // 각 스택 셀의 columnNames 개수에 따라 너비 계산
        final colSpan = cell.columnNames.length;
        final cellWidth = 60.0 * colSpan; // 각 셀 너비는 약 60
        
        // 텍스트 추출
        String text = _extractTextFromWidget(cell.child);
        
        return Container(
          width: cellWidth,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  /// 세부 헤더 행 생성 (하단 상세 헤더)
  Widget _buildDetailHeaderRow(List<GridColumn> columns) {
    return Row(
      children: columns.map((column) {
        // GridColumn의 label에서 텍스트 추출
        final columnLabel = column.label;
        final label = _extractTextFromWidget(columnLabel);
        
        return Container(
          width: 60, // 각 셀 너비를 60으로 고정
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  /// 예시 데이터 행 생성 (이미지 형식 참고)
  Widget _buildExampleDataRow() {
    return Row(
      children: [
        // 결강일 영역 (7개 컬럼)
        _buildExampleCell('월', isButton: true),
        _buildExampleCell('월'),
        _buildExampleCell('4'),
        _buildExampleCell('2'),
        _buildExampleCell('5'),
        _buildExampleCell('국어'),
        _buildExampleCell('정수정'),
        // 보강/수업변경 영역 (2개 컬럼)
        _buildExampleCell(''),
        _buildExampleCell(''),
        // 수업 교체 영역 (5개 컬럼)
        _buildExampleCell('수', isButton: true),
        _buildExampleCell('수'),
        _buildExampleCell('4'),
        _buildExampleCell('역사'),
        _buildExampleCell('유인성'),
        // 비고 영역 (1개 컬럼)
        _buildExampleCell(''),
      ],
    );
  }
  
  /// 예시 셀 생성
  Widget _buildExampleCell(String text, {bool isButton = false}) {
    return Container(
      width: 60,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: isButton
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  text.isEmpty ? '선택' : text,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                ),
              ),
      ),
    );
  }
  
  /// 위젯에서 텍스트 추출 (간단한 경우만)
  String _extractTextFromWidget(Widget widget) {
    if (widget is Text) {
      return widget.data ?? '';
    } else if (widget is Container) {
      final child = widget.child;
      if (child != null) {
        if (child is Text) {
          return child.data ?? '';
        } else if (child is Center || child is Align) {
          // Center나 Align 내부의 child를 확인
          final dynamic childWidget = (child as dynamic).child;
          if (childWidget is Text) {
            return childWidget.data ?? '';
          }
        }
      }
    }
    return '';
  }

  /// 내보내기 형식 정보 표시
  Widget _buildFormatInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.table_chart,
            color: Colors.purple.shade600,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Excel 파일 (.xlsx)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '엑셀로 열 수 있는 표 형식 파일',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.purple.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: Colors.purple.shade600,
            size: 28,
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
        icon: const Icon(Icons.download, size: 24),
        label: const Text(
          '파일 내보내기',
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
            '내보낸 파일은 다른 이름으로 변경하여 저장할 수 있습니다',
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
    // TODO: 실제 파일 내보내기 로직 구현
    if (!mounted) return;

    // 임시 구현: 알림만 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Excel 형식으로 파일을 내보내는 기능은 아직 구현되지 않았습니다.',
        ),
        backgroundColor: Colors.purple,
        duration: Duration(seconds: 2),
      ),
    );
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


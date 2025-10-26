import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../mixins/scroll_management_mixin.dart';
import 'substitution_plan_grid_helpers.dart';

/// 파일 출력 위젯
/// 
/// 교체 기록을 다양한 형식으로 내보낼 수 있는 위젯입니다.
class FileExportWidget extends ConsumerStatefulWidget {
  const FileExportWidget({super.key});

  @override
  ConsumerState<FileExportWidget> createState() => _FileExportWidgetState();
}

/// 파일 출력 위젯의 테이블 미리보기 설정 상수
class FileExportTableConfig {
  /// 각 글자에 할당할 픽셀 (한글 기준)
  static const double characterWidth = 8.5;
  
  /// 최소 셀 폭
  static const double minCellWidth = 40.0;
  
  /// 최대 셀 폭
  static const double maxCellWidth = 120.0;
  
  /// 큰 헤더(스택 헤더) 셀 높이
  static const double stackedHeaderHeight = 35.0;
  
  /// 세부 헤더 셀 높이
  static const double detailHeaderHeight = 30.0;
  
  /// 데이터 셀 높이
  static const double dataCellHeight = 40.0;
  
  /// 셀 내부 패딩 (상하)
  static const double cellPaddingVertical = 8.0;
  
  /// 셀 내부 패딩 (좌우)
  static const double cellPaddingHorizontal = 0.0;
  
  /// 헤더 셀 내부 패딩 (상하)
  static const double headerPaddingVertical = 6.0;
  
  /// 셀 테두리 두께
  static const double borderWidth = 0.5;
  
  /// 각 컬럼의 개별 폭 설정 (선택사항)
  /// 
  /// 컬럼명을 키로 하여 원하는 폭을 지정할 수 있습니다.
  /// 지정하지 않은 컬럼은 자동으로 텍스트 길이에 따라 계산됩니다.
  static const Map<String, double> customColumnWidths = {
    // 결강 관련 컬럼
    'absenceDate': 80.0,    // 결강일
    'absenceDay': 70.0,     // 요일
    'period': 40.0,         // 교시
    'grade': 40.0,          // 학년
    'className': 65.0,      // 반
    'subject': 50.0,        // 과목
    'teacher': 55.0,        // 교사
    
    // 보강/수업변경 관련 컬럼
    'supplementSubject': 110.0,   // 과목
    'supplementTeacher': 110.0,   // 성명
    
    // 수업 교체 관련 컬럼
    'substitutionDate': 100.0,    // 교체일
    'substitutionDay': 100.0,      // 요일
    'substitutionPeriod': 110.0,   // 교시
    'substitutionSubject': 110.0, // 과목
    'substitutionTeacher': 110.0, // 교사
    
    // 비고
    'remarks': 60.0,       // 비고
  };
}

class _FileExportWidgetState extends ConsumerState<FileExportWidget>
    with ScrollManagementMixin {
  @override
  void initState() {
    super.initState();
    // 공통 스크롤 관리 믹신 초기화
    initializeScrollControllers();
  }

  @override
  void dispose() {
    // 공통 스크롤 관리 믹신 해제
    disposeScrollControllers();
    super.dispose();
  }

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
            '결보강 계획서, 학급안내, 교사안내를 엑셀 파일로 내보낼 수 있습니다.\n'
            '양식 파일로 "결보강계획서_양식.xlsx"이 필요합니다.\n'
            '양식 파일에서 테이블 테그를 찾아 해당 컬럼에 내용이 기록됩니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          
          // 테이블 미리보기 헤더 (제목과 복사 버튼)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '엑셀 테이블 테그:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
              TextButton.icon(
                onPressed: () => _copyTableToClipboard(context),
                icon: const Icon(Icons.copy, size: 12),
                label: const Text(
                  '테이블테그 복사',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ),
            ],
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
    // 예시 데이터 생성
    final exampleData = _createExamplePlanData();
    
    // SubstitutionPlanGridConfig에서 헤더 정보 가져오기
    final columns = _getCustomColumns();
    final stackedHeaders = SubstitutionPlanGridConfig.getStackedHeaders();
    
    // 데이터 소스 생성
    final dataSource = _ExampleDataSource(exampleData);
    
    // 데이터 행 수에 맞는 높이 계산
    // 큰 헤더(35) + 작은 헤더(30) + 데이터 행 수 × 행 높이(40)
    final rowCount = exampleData.length;
    final calculatedHeight = FileExportTableConfig.stackedHeaderHeight + 
                            FileExportTableConfig.detailHeaderHeight + 
                            (rowCount * FileExportTableConfig.dataCellHeight)+25;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 테이블
        SizedBox(
          height: calculatedHeight,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: wrapWithDragScroll(
              SfDataGrid(
                source: dataSource,
                columns: columns,
                stackedHeaderRows: stackedHeaders,
                allowColumnsResizing: false,
                gridLinesVisibility: GridLinesVisibility.both,
                headerGridLinesVisibility: GridLinesVisibility.both,
                selectionMode: SelectionMode.none,
                headerRowHeight: FileExportTableConfig.stackedHeaderHeight,
                rowHeight: FileExportTableConfig.dataCellHeight,
                allowEditing: false,
                horizontalScrollController: horizontalScrollController,
                verticalScrollController: verticalScrollController,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// 테이블 내용을 클립보드에 복사
  Future<void> _copyTableToClipboard(BuildContext context) async {
    final exampleData = _createExamplePlanData();
    
    // 테이블 내용을 텍스트로 변환
    final tableText = _generateTableText(exampleData);
    
    await Clipboard.setData(ClipboardData(text: tableText));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('테이블 내용이 클립보드에 복사되었습니다.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  /// 테이블 내용을 텍스트 형식으로 변환
  /// 
  /// 탭(\t)으로 구분하여 엑셀에서 붙여넣기 시 각 셀에 데이터가 자동으로 분리됩니다.
  String _generateTableText(List<SubstitutionPlanData> data) {
    final buffer = StringBuffer();
    
    // 헤더 행 (탭으로 구분)
    final headers = [
      '결강일',
      '요일',
      '교시',
      '학년',
      '반',
      '과목',
      '교사',
      '보강/수업변경 과목',
      '보강/수업변경 성명',
      '교체일',
      '교체요일',
      '교체교시',
      '교체과목',
      '교체교사',
      '비고',
    ];
    buffer.writeln(headers.join('\t'));
    
    // 데이터 행
    for (final row in data) {
      final cells = [
        row.absenceDate.isEmpty ? '' : row.absenceDate,
        row.absenceDay,
        row.period,
        row.grade,
        row.className,
        row.subject,
        row.teacher,
        row.supplementSubject,
        row.supplementTeacher,
        row.substitutionDate,
        row.substitutionDay,
        row.substitutionPeriod,
        row.substitutionSubject,
        row.substitutionTeacher,
        row.remarks,
      ];
      buffer.writeln(cells.join('\t'));
    }
    
    return buffer.toString();
  }
  
  /// 컬럼 폭을 적용한 GridColumn 리스트 생성
  List<GridColumn> _getCustomColumns() {
    final baseColumns = SubstitutionPlanGridConfig.getColumns();
    
    return baseColumns.map((column) {
      final columnName = column.columnName;
      double? customWidth;
      
      // customColumnWidths에서 지정된 폭 확인
      if (FileExportTableConfig.customColumnWidths.containsKey(columnName)) {
        customWidth = FileExportTableConfig.customColumnWidths[columnName];
      }
      
      // 폭이 지정되어 있으면 새로운 GridColumn 생성
      if (customWidth != null) {
        return GridColumn(
          columnName: column.columnName,
          width: customWidth,
          label: column.label,
        );
      }
      
      // 지정되지 않았으면 원본 컬럼 유지
      return column;
    }).toList();
  }
  
  /// 예시 데이터 생성
  List<SubstitutionPlanData> _createExamplePlanData() {
    return [
      SubstitutionPlanData(
        exchangeId: 'example_1',
        absenceDate: 'absenceDate',      // 결강일
        absenceDay: 'absenceDay',         // 요일
        period: 'period',             // 교시
        grade: 'grade',              // 학년
        className: 'className',           // 반
        subject: 'subject',          // 과목
        teacher: 'teacher',        // 교사
        supplementSubject: 'supplementSubject',    // 보강 과목
        supplementTeacher: 'supplementTeacher',   // 보강 교사
        substitutionDate: 'substitutionDate',   // 교체일
        substitutionDay: 'substitutionDay',    // 요일
        substitutionPeriod: 'substitutionPeriod',  // 교시
        substitutionSubject: 'substitutionSubject',  // 과목
        substitutionTeacher: 'substitutionTeacher', // 교사
        remarks: 'remarks',             // 비고
      ),
    ];
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

/// 예시 데이터 소스
/// 
/// 파일 출력 위젯의 테이블 미리보기용 간단한 데이터 소스입니다.
class _ExampleDataSource extends DataGridSource {
  final List<SubstitutionPlanData> planData;

  _ExampleDataSource(this.planData);

  @override
  List<DataGridRow> get rows => planData.map<DataGridRow>((data) {
    return DataGridRow(cells: [
      DataGridCell<String>(columnName: 'absenceDate', value: data.absenceDate),
      DataGridCell<String>(columnName: 'absenceDay', value: data.absenceDay),
      DataGridCell<String>(columnName: 'period', value: data.period),
      DataGridCell<String>(columnName: 'grade', value: data.grade),
      DataGridCell<String>(columnName: 'className', value: data.className),
      DataGridCell<String>(columnName: 'subject', value: data.subject),
      DataGridCell<String>(columnName: 'teacher', value: data.teacher),
      DataGridCell<String>(columnName: 'supplementSubject', value: data.supplementSubject),
      DataGridCell<String>(columnName: 'supplementTeacher', value: data.supplementTeacher),
      DataGridCell<String>(columnName: 'substitutionDate', value: data.substitutionDate),
      DataGridCell<String>(columnName: 'substitutionDay', value: data.substitutionDay),
      DataGridCell<String>(columnName: 'substitutionPeriod', value: data.substitutionPeriod),
      DataGridCell<String>(columnName: 'substitutionSubject', value: data.substitutionSubject),
      DataGridCell<String>(columnName: 'substitutionTeacher', value: data.substitutionTeacher),
      DataGridCell<String>(columnName: 'remarks', value: data.remarks),
    ]);
  }).toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final value = cell.value?.toString() ?? '';
        final isEmpty = value.isEmpty;
        
        return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(FileExportTableConfig.cellPaddingHorizontal),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isEmpty ? Colors.transparent : Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }
}


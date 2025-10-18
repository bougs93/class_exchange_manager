import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../../providers/services_provider.dart';
import '../../../../models/exchange_history_item.dart';

/// 여백 및 스타일 상수
class _Spacing {
  // 패딩 - 최소화
  static const EdgeInsets headerPadding = EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0);
  static const EdgeInsets cellPadding = EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0);
  
  // 간격 - 최소화
  static const double smallSpacing = 4.0;
  static const double mediumSpacing = 8.0; // 16.0에서 8.0으로 줄임
  
  // 폰트 크기
  static const double headerFontSize = 12.0; // 14.0에서 12.0으로 줄임
  static const double cellFontSize = 11.0; // 12.0에서 11.0으로 줄임
}

/// 보강계획서 데이터 모델
class SubstitutionPlanData {
  final String absenceDate;      // 결강일
  final String absenceDay;       // 결강 요일
  final String period;           // 교시
  final String grade;           // 학년
  final String className;       // 반
  final String subject;         // 과목
  final String teacher;         // 교사
  final String supplementSubject; // 보강/수업변경 과목
  final String supplementTeacher; // 보강/수업변경 교사 성명
  final String substitutionDate; // 교체일
  final String substitutionDay;  // 교체 요일
  final String substitutionPeriod; // 교체 교시
  final String substitutionSubject; // 교체 과목
  final String substitutionTeacher; // 교체 교사 성명
  final String remarks;         // 비고

  SubstitutionPlanData({
    required this.absenceDate,
    required this.absenceDay,
    required this.period,
    required this.grade,
    required this.className,
    required this.subject,
    required this.teacher,
    required this.supplementSubject,
    required this.supplementTeacher,
    required this.substitutionDate,
    required this.substitutionDay,
    required this.substitutionPeriod,
    required this.substitutionSubject,
    required this.substitutionTeacher,
    required this.remarks,
  });
}

/// 보강계획서 데이터 소스
class SubstitutionPlanDataSource extends DataGridSource {
  final List<SubstitutionPlanData> _data;
  final Function(DataGridCell, DataGridRow)? onDateCellTap;

  SubstitutionPlanDataSource(this._data, {this.onDateCellTap});

  @override
  List<DataGridRow> get rows => _data.map<DataGridRow>((data) {
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
      cells: row.getCells().map<Widget>((dataGridCell) {
        
        // 다른 컬럼들은 기본 텍스트 표시
        return Container(
          alignment: Alignment.center,
          padding: _Spacing.cellPadding, // 최소화된 패딩 사용
          child: Text(
            dataGridCell.value?.toString() ?? '',
            style: const TextStyle(
              fontSize: _Spacing.cellFontSize,
              height: 1.0, // 줄 간격 최소화
            ),
            textAlign: TextAlign.center,
          ),
        );
      }).toList(),
    );
  }
}

/// 보강계획서 그리드 위젯
class SubstitutionPlanGrid extends ConsumerStatefulWidget {
  const SubstitutionPlanGrid({super.key});

  @override
  ConsumerState<SubstitutionPlanGrid> createState() => _SubstitutionPlanGridState();
}

class _SubstitutionPlanGridState extends ConsumerState<SubstitutionPlanGrid> {
  late SubstitutionPlanDataSource _dataSource;
  List<SubstitutionPlanData> _planData = [];
  
  // 요일 제한 설정 (true인 요일만 선택 가능)
  final Map<int, bool> _allowedWeekdays = {
    1: true,  // 월요일
    2: true,  // 화요일
    3: true,  // 수요일
    4: true,  // 목요일
    5: true,  // 금요일
    6: false, // 토요일
    7: false, // 일요일
  };

  @override
  void initState() {
    super.initState();
    _loadPlanData();
  }

  /// 교체 히스토리에서 보강계획서 데이터 로드
  void _loadPlanData() {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final exchangeList = historyService.getExchangeList();
    
    // 실제 교체 히스토리 데이터만 로드 (빈 행 제거)
    _planData = exchangeList.map((item) {
      return SubstitutionPlanData(
        absenceDate: _formatDate(item.timestamp),
        absenceDay: _extractDay(item),
        period: _extractPeriod(item),
        grade: _extractGrade(item),
        className: _extractClassName(item),
        subject: _extractSubject(item),
         teacher: _extractTeacherName(item), // 결강 교사
         supplementSubject: _extractSubject(item), // 보강 과목은 동일
         supplementTeacher: _extractSubstitutionTeacher(item), // 보강 교사 성명
        substitutionDate: _formatDate(item.timestamp),
        substitutionDay: _extractDay(item),
        substitutionPeriod: _extractPeriod(item),
        substitutionSubject: _extractSubject(item),
        substitutionTeacher: _extractSubstitutionTeacher(item),
        remarks: item.notes ?? '',
      );
    }).toList();

    // 데이터 소스는 항상 초기화 (빈 데이터여도 안정적으로 작동)
    _dataSource = SubstitutionPlanDataSource(_planData, onDateCellTap: _showDatePicker);
  }

  /// 날짜 포맷팅 (월.일 형태)
  String _formatDate(DateTime date) {
    return '${date.month}.${date.day}';
  }

  /// 요일 추출
  String _extractDay(ExchangeHistoryItem item) {
    final nodes = item.originalPath.nodes;
    if (nodes.isNotEmpty) {
      return nodes.first.day;
    }
    return '';
  }

  /// 교시 추출
  String _extractPeriod(ExchangeHistoryItem item) {
    // ExchangeHistoryItem에서 교시 정보 추출
    final nodes = item.originalPath.nodes;
    if (nodes.isNotEmpty) {
      return nodes.first.period.toString();
    }
    return '';
  }

  /// 학년 추출
  String _extractGrade(ExchangeHistoryItem item) {
    // ExchangeHistoryItem에서 학년 정보 추출
    final nodes = item.originalPath.nodes;
    if (nodes.isNotEmpty) {
      // 학급명에서 학년 추출 (예: "1학년 3반" -> "1")
      final className = nodes.first.className;
      final gradeMatch = RegExp(r'(\d+)학년').firstMatch(className);
      return gradeMatch?.group(1) ?? '';
    }
    return '';
  }

  /// 반 추출
  String _extractClassName(ExchangeHistoryItem item) {
    final nodes = item.originalPath.nodes;
    if (nodes.isNotEmpty) {
      return nodes.first.className;
    }
    return '';
  }

  /// 과목 추출
  String _extractSubject(ExchangeHistoryItem item) {
    final nodes = item.originalPath.nodes;
    if (nodes.isNotEmpty) {
      return nodes.first.subjectName;
    }
    return '';
  }

  /// 교사명 추출
  String _extractTeacherName(ExchangeHistoryItem item) {
    final nodes = item.originalPath.nodes;
    if (nodes.isNotEmpty) {
      return nodes.first.teacherName;
    }
    return '';
  }

  /// 교체 교사명 추출
  String _extractSubstitutionTeacher(ExchangeHistoryItem item) {
    final nodes = item.originalPath.nodes;
    if (nodes.length > 1) {
      return nodes[1].teacherName;
    }
    return '';
  }

  /// 날짜 선택기 표시 (calendar_date_picker2 사용)
  Future<void> _showDatePicker(DataGridCell dataGridCell, DataGridRow row) async {
    // 선택 가능한 날짜를 찾아서 initialDate로 설정
    DateTime initialDate = DateTime.now();
    
    // 현재 날짜가 선택 가능하지 않다면, 다음 선택 가능한 날짜를 찾음
    if (!(_allowedWeekdays[initialDate.weekday] ?? false)) {
      for (int i = 1; i <= 7; i++) {
        final testDate = initialDate.add(Duration(days: i));
        if (_allowedWeekdays[testDate.weekday] ?? false) {
          initialDate = testDate;
          break;
        }
      }
    }
    
    // calendar_date_picker2를 사용한 날짜 선택기
    final List<DateTime?>? selectedDates = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.single,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        weekdayLabels: ['일', '월', '화', '수', '목', '금', '토'], // 한글 요일
        weekdayLabelTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: _Spacing.headerFontSize,
        ),
        selectedDayTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16, // 선택된 날짜 숫자 크기
        ),
        selectedDayHighlightColor: Colors.blue.shade600,
        todayTextStyle: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 16, // 오늘 날짜 숫자 크기
        ),
        dayTextStyle: const TextStyle(
          fontSize: _Spacing.headerFontSize, // 일반 날짜 숫자 크기
          color: Colors.black87,
        ),
        selectableDayPredicate: (DateTime date) {
          // 설정된 요일만 선택 가능
          return _allowedWeekdays[date.weekday] ?? false;
        },
        cancelButtonTextStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 16,
        ),
        okButtonTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        okButton: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('확인'),
        ),
        cancelButton: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('취소', style: TextStyle(color: Colors.grey.shade600)),
        ),
      ),
      dialogSize: const Size(350, 360),
      borderRadius: BorderRadius.circular(5),
      value: [initialDate],
    );
    
    final DateTime? selectedDate = selectedDates?.isNotEmpty == true ? selectedDates!.first : null;

    if (selectedDate != null) {
      // 선택된 날짜를 포맷팅
      final formattedDate = _formatDate(selectedDate);
      
      // 데이터 업데이트
      final rowIndex = _dataSource.rows.indexOf(row);
      if (rowIndex >= 0 && rowIndex < _planData.length) {
        setState(() {
          // 어떤 날짜 컬럼인지에 따라 업데이트
          if (dataGridCell.columnName == 'absenceDate') {
            _planData[rowIndex] = SubstitutionPlanData(
              absenceDate: formattedDate,
              absenceDay: _planData[rowIndex].absenceDay,
              period: _planData[rowIndex].period,
              grade: _planData[rowIndex].grade,
              className: _planData[rowIndex].className,
              subject: _planData[rowIndex].subject,
              teacher: _planData[rowIndex].teacher,
              supplementSubject: _planData[rowIndex].supplementSubject,
              supplementTeacher: _planData[rowIndex].supplementTeacher,
              substitutionDate: _planData[rowIndex].substitutionDate,
              substitutionDay: _planData[rowIndex].substitutionDay,
              substitutionPeriod: _planData[rowIndex].substitutionPeriod,
              substitutionSubject: _planData[rowIndex].substitutionSubject,
              substitutionTeacher: _planData[rowIndex].substitutionTeacher,
              remarks: _planData[rowIndex].remarks,
            );
          } else if (dataGridCell.columnName == 'substitutionDate') {
            _planData[rowIndex] = SubstitutionPlanData(
              absenceDate: _planData[rowIndex].absenceDate,
              absenceDay: _planData[rowIndex].absenceDay,
              period: _planData[rowIndex].period,
              grade: _planData[rowIndex].grade,
              className: _planData[rowIndex].className,
              subject: _planData[rowIndex].subject,
              teacher: _planData[rowIndex].teacher,
              supplementSubject: _planData[rowIndex].supplementSubject,
              supplementTeacher: _planData[rowIndex].supplementTeacher,
              substitutionDate: formattedDate,
              substitutionDay: _planData[rowIndex].substitutionDay,
              substitutionPeriod: _planData[rowIndex].substitutionPeriod,
              substitutionSubject: _planData[rowIndex].substitutionSubject,
              substitutionTeacher: _planData[rowIndex].substitutionTeacher,
              remarks: _planData[rowIndex].remarks,
            );
          }
        });
        
        // 데이터 소스 새로고침
        _dataSource = SubstitutionPlanDataSource(_planData, onDateCellTap: _showDatePicker);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 버튼들을 SingleChildScrollView로 감싸서 가로 스크롤 가능하게 함
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadPlanData,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('새로고침'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: _Spacing.smallSpacing),
                  ElevatedButton.icon(
                    onPressed: _exportToPDF,
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF 출력'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: _Spacing.smallSpacing),
                  ElevatedButton.icon(
                    onPressed: _showWeekdaySettings,
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('요일 설정'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _Spacing.mediumSpacing),
            // 고정 높이로 설정하여 TabBarView 내에서 크기 문제 해결
            SizedBox(
              height: 500, // 고정 높이로 설정
              child: Stack(
                children: [
                  // 헤더와 데이터 그리드는 항상 표시
                  SfDataGrid(
                    source: _dataSource, // 항상 동일한 데이터 소스 사용
                    columns: _buildColumns(),
                    stackedHeaderRows: _buildStackedHeaders(),
                    allowColumnsResizing: true,
                    columnResizeMode: ColumnResizeMode.onResize,
                    gridLinesVisibility: GridLinesVisibility.both,
                    headerGridLinesVisibility: GridLinesVisibility.both,
                    selectionMode: SelectionMode.single,
                    headerRowHeight: 35, // 50에서 35로 줄임
                    rowHeight: 28, // 40에서 28로 줄임
                  ),
                  // 데이터가 없을 때만 안내 메시지 오버레이 표시
                  if (_planData.isEmpty)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.5),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '교체 기록이 없습니다',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '교체를 실행하면 여기에 기록이 표시됩니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 컬럼 정의
  List<GridColumn> _buildColumns() {
    return [
      // 결강 섹션 (7개 컬럼) - 너비 최소화
      GridColumn(
        columnName: 'absenceDate',
        label: const Text(''), // 스택 헤더 사용 시 빈 텍스트
        width: 70, // 80에서 70으로 줄임
      ),
      GridColumn(
        columnName: 'absenceDay',
        label: const Text(''),
        width: 45, // 50에서 45로 줄임
      ),
      GridColumn(
        columnName: 'period',
        label: const Text(''),
        width: 45, // 50에서 45로 줄임
      ),
      GridColumn(
        columnName: 'grade',
        label: const Text(''),
        width: 45, // 50에서 45로 줄임
      ),
      GridColumn(
        columnName: 'className',
        label: const Text(''),
        width: 55, // 60에서 55로 줄임
      ),
      GridColumn(
        columnName: 'subject',
        label: const Text(''),
        width: 70, // 80에서 70으로 줄임
      ),
      GridColumn(
        columnName: 'teacher',
        label: const Text(''),
        width: 70, // 80에서 70으로 줄임
      ),
      // 보강/수업변경 섹션 (2개 컬럼) - 너비 최소화
      GridColumn(
        columnName: 'supplementSubject',
        label: const Text(''),
        width: 70, // 80에서 70으로 줄임
      ),
      GridColumn(
        columnName: 'supplementTeacher',
        label: const Text(''),
        width: 90, // 100에서 90으로 줄임
      ),
      // 수업 교체 섹션 (5개 컬럼) - 너비 최소화
      GridColumn(
        columnName: 'substitutionDate',
        label: const Text(''),
        width: 70, // 80에서 70으로 줄임
      ),
      GridColumn(
        columnName: 'substitutionDay',
        label: const Text(''),
        width: 45, // 50에서 45로 줄임
      ),
      GridColumn(
        columnName: 'substitutionPeriod',
        label: const Text(''),
        width: 45, // 50에서 45로 줄임
      ),
      GridColumn(
        columnName: 'substitutionSubject',
        label: const Text(''),
        width: 70, // 80에서 70으로 줄임
      ),
      GridColumn(
        columnName: 'substitutionTeacher',
        label: const Text(''),
        width: 90, // 100에서 90으로 줄임
      ),
      // 비고 섹션 (1개 컬럼) - 너비 최소화
      GridColumn(
        columnName: 'remarks',
        label: const Text(''),
        width: 100, // 120에서 100으로 줄임
      ),
    ];
  }

  /// 스택 헤더 정의
  List<StackedHeaderRow> _buildStackedHeaders() {
    return [
      // 첫 번째 헤더 행 (주요 카테고리)
      StackedHeaderRow(
        cells: [
          // 결강 섹션 (7개 컬럼)
          StackedHeaderCell(
            columnNames: ['absenceDate', 'absenceDay', 'period', 'grade', 'className', 'subject', 'teacher'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '결강',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _Spacing.headerFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          // 보강/수업변경 섹션 (2개 컬럼)
          StackedHeaderCell(
            columnNames: ['supplementSubject', 'supplementTeacher'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '보강/수업변경',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _Spacing.headerFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          // 수업 교체 섹션 (5개 컬럼)
          StackedHeaderCell(
            columnNames: ['substitutionDate', 'substitutionDay', 'substitutionPeriod', 'substitutionSubject', 'substitutionTeacher'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '수업 교체',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _Spacing.headerFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          // 비고 섹션 (2행 병합)
          StackedHeaderCell(
            columnNames: ['remarks'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '비고',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _Spacing.headerFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
        ],
      ),
      // 두 번째 헤더 행 (세부 항목)
      StackedHeaderRow(
        cells: [
          // 결강 섹션 세부 항목들
          StackedHeaderCell(
            columnNames: ['absenceDate'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '결강일',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['absenceDay'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '요일',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['period'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '교시',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['grade'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '학년',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['className'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '반',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['subject'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '과목',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['teacher'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '교사',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          // 보강/수업변경 섹션 세부 항목들
          StackedHeaderCell(
            columnNames: ['supplementSubject'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '과목',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['supplementTeacher'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '성명',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          // 수업 교체 섹션 세부 항목들
          StackedHeaderCell(
            columnNames: ['substitutionDate'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '교체일',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['substitutionDay'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '요일',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['substitutionPeriod'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '교시',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['substitutionSubject'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '과목',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['substitutionTeacher'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '교사',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          // 비고 섹션 (2행 병합이므로 두 번째 행에서는 빈 공간)
          StackedHeaderCell(
            columnNames: ['remarks'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '(참고사항)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  /// 요일 설정 다이얼로그 표시
  void _showWeekdaySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('선택 가능한 요일 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('날짜 선택 시 선택 가능한 요일을 설정하세요:'),
            const SizedBox(height: _Spacing.mediumSpacing),
            ..._allowedWeekdays.entries.map((entry) {
              final weekdayNames = ['', '월', '화', '수', '목', '금', '토', '일'];
              return CheckboxListTile(
                title: Text('${weekdayNames[entry.key]}요일'),
                value: entry.value,
                onChanged: (bool? value) {
                  setState(() {
                    _allowedWeekdays[entry.key] = value ?? false;
                  });
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// PDF 출력 기능
  void _exportToPDF() {
    // TODO: PDF 출력 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF 출력 기능은 추후 구현 예정입니다.'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../../providers/services_provider.dart';
import '../../../../models/exchange_history_item.dart';

/// 보강계획서 데이터 모델
class SubstitutionPlanData {
  final String absenceDate;      // 결강일
  final String absenceDay;       // 결강 요일
  final String period;           // 교시
  final String grade;           // 학년
  final String className;       // 반
  final String subject;         // 과목
  final String supplementSubject; // 보강/수업변경 과목
  final String teacherName;     // 교사 성명
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
    required this.supplementSubject,
    required this.teacherName,
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
      DataGridCell<String>(columnName: 'supplementSubject', value: data.supplementSubject),
      DataGridCell<String>(columnName: 'teacherName', value: data.teacherName),
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
        // 날짜 컬럼인 경우 날짜 선택기 위젯 사용 (아이콘 없이 셀 전체 클릭 가능)
        if (dataGridCell.columnName == 'absenceDate' || dataGridCell.columnName == 'substitutionDate') {
          return GestureDetector(
            onTap: () => onDateCellTap?.call(dataGridCell, row),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey.shade50, // 클릭 가능함을 시각적으로 표시
              ),
              child: Text(
                dataGridCell.value?.toString() ?? '날짜 선택',
                style: TextStyle(
                  fontSize: 12,
                  color: (dataGridCell.value?.toString().isEmpty == true || 
                          dataGridCell.value?.toString() == '날짜 선택')
                      ? Colors.grey.shade500 
                      : Colors.black,
                  fontWeight: FontWeight.w500, // 클릭 가능한 텍스트임을 강조
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        
        // 다른 컬럼들은 기본 텍스트 표시
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            dataGridCell.value?.toString() ?? '',
            style: const TextStyle(fontSize: 12),
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
    
    // 먼저 빈 행 추가 (입력용 공간)
    _planData = [
      SubstitutionPlanData(
        absenceDate: '날짜 선택',
        absenceDay: '',
        period: '',
        grade: '',
        className: '',
        subject: '',
        supplementSubject: '',
        teacherName: '',
        substitutionDate: '날짜 선택',
        substitutionDay: '',
        substitutionPeriod: '',
        substitutionSubject: '',
        substitutionTeacher: '',
        remarks: '',
      ),
    ];
    
    // 실제 교체 히스토리 데이터 추가
    final actualData = exchangeList.map((item) {
      return SubstitutionPlanData(
        absenceDate: _formatDate(item.timestamp),
        absenceDay: _extractDay(item),
        period: _extractPeriod(item),
        grade: _extractGrade(item),
        className: _extractClassName(item),
        subject: _extractSubject(item),
        supplementSubject: _extractSubject(item), // 보강 과목은 동일
        teacherName: _extractTeacherName(item),
        substitutionDate: _formatDate(item.timestamp),
        substitutionDay: _extractDay(item),
        substitutionPeriod: _extractPeriod(item),
        substitutionSubject: _extractSubject(item),
        substitutionTeacher: _extractSubstitutionTeacher(item),
        remarks: item.notes ?? '',
      );
    }).toList();
    
    _planData.addAll(actualData);
    
    // 테스트용 더미 데이터 추가 (실제 데이터가 없을 때)
    if (actualData.isEmpty) {
      _planData.add(
        SubstitutionPlanData(
          absenceDate: _formatDate(DateTime.now()),
          absenceDay: '월',
          period: '1',
          grade: '1',
          className: '1학년 1반',
          subject: '국어',
          supplementSubject: '국어',
          teacherName: '김교사',
          substitutionDate: _formatDate(DateTime.now().add(Duration(days: 1))),
          substitutionDay: '화',
          substitutionPeriod: '1',
          substitutionSubject: '국어',
          substitutionTeacher: '이교사',
          remarks: '테스트 데이터',
        ),
      );
    }

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
          fontSize: 14,
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
          fontSize: 14, // 일반 날짜 숫자 크기
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
              supplementSubject: _planData[rowIndex].supplementSubject,
              teacherName: _planData[rowIndex].teacherName,
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
              supplementSubject: _planData[rowIndex].supplementSubject,
              teacherName: _planData[rowIndex].teacherName,
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
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _exportToPDF,
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF 출력'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
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
            const SizedBox(height: 16),
            // 고정 높이로 데이터 그리드 설정 (최소 높이 보장)
            SizedBox(
              height: 400, // 고정 높이로 설정하여 오버플로우 방지
              child: SfDataGrid(
                source: _dataSource,
                columns: _buildColumns(),
                stackedHeaderRows: _buildStackedHeaders(),
                allowColumnsResizing: true,
                columnResizeMode: ColumnResizeMode.onResize,
                gridLinesVisibility: GridLinesVisibility.both,
                headerGridLinesVisibility: GridLinesVisibility.both,
                selectionMode: SelectionMode.single,
                headerRowHeight: 50,
                rowHeight: 40,
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
      GridColumn(
        columnName: 'absenceDate',
        label: const Text(''), // 스택 헤더 사용 시 빈 텍스트
        width: 80,
      ),
      GridColumn(
        columnName: 'absenceDay',
        label: const Text(''),
        width: 50,
      ),
      GridColumn(
        columnName: 'period',
        label: const Text(''),
        width: 50,
      ),
      GridColumn(
        columnName: 'grade',
        label: const Text(''),
        width: 50,
      ),
      GridColumn(
        columnName: 'className',
        label: const Text(''),
        width: 60,
      ),
      GridColumn(
        columnName: 'subject',
        label: const Text(''),
        width: 80,
      ),
      GridColumn(
        columnName: 'supplementSubject',
        label: const Text(''),
        width: 80,
      ),
      GridColumn(
        columnName: 'teacherName',
        label: const Text(''),
        width: 100,
      ),
      GridColumn(
        columnName: 'substitutionDate',
        label: const Text(''),
        width: 80,
      ),
      GridColumn(
        columnName: 'substitutionDay',
        label: const Text(''),
        width: 50,
      ),
      GridColumn(
        columnName: 'substitutionPeriod',
        label: const Text(''),
        width: 50,
      ),
      GridColumn(
        columnName: 'substitutionSubject',
        label: const Text(''),
        width: 80,
      ),
      GridColumn(
        columnName: 'substitutionTeacher',
        label: const Text(''),
        width: 100,
      ),
      GridColumn(
        columnName: 'remarks',
        label: const Text(''),
        width: 120,
      ),
    ];
  }

  /// 스택 헤더 정의
  List<StackedHeaderRow> _buildStackedHeaders() {
    return [
      // 첫 번째 헤더 행 (주요 카테고리)
      StackedHeaderRow(
        cells: [
          StackedHeaderCell(
            columnNames: ['absenceDate', 'absenceDay', 'period', 'grade', 'className', 'subject'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '결강',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['supplementSubject', 'teacherName'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '보강/수업변경',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['substitutionDate', 'substitutionDay', 'substitutionPeriod', 'substitutionSubject', 'substitutionTeacher'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '수업 교체',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['remarks'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '비고',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      // 두 번째 헤더 행 (세부 항목)
      StackedHeaderRow(
        cells: [
          StackedHeaderCell(
            columnNames: ['absenceDate'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '결강일',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['absenceDay'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '요일',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['period'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '교시',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['grade'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '학년',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['className'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '반',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['subject'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '과목',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['supplementSubject'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '과목',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['teacherName'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '교사 성명',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['substitutionDate'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '교체일',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['substitutionDay'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '요일',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['substitutionPeriod'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '교시',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['substitutionSubject'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '과목',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['substitutionTeacher'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '교사 성명',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StackedHeaderCell(
            columnNames: ['remarks'],
            child: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                '(참고사항)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
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
            const SizedBox(height: 16),
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

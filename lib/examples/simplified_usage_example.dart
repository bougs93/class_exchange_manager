import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../utils/simplified_timetable_data_source.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../utils/logger.dart';

/// 단순화된 시간표 사용 예시
class SimplifiedTimetableExample extends StatefulWidget {
  const SimplifiedTimetableExample({super.key});

  @override
  State<SimplifiedTimetableExample> createState() => _SimplifiedTimetableExampleState();
}

class _SimplifiedTimetableExampleState extends State<SimplifiedTimetableExample> {
  SimplifiedTimetableDataSource? _dataSource;
  List<GridColumn> _columns = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // 샘플 데이터 생성
    List<Teacher> teachers = [
      Teacher(name: 'A교사', subject: '수학'),
      Teacher(name: 'B교사', subject: '국어'),
      Teacher(name: 'C교사', subject: '영어'),
    ];

    List<TimeSlot> timeSlots = [
      TimeSlot(teacher: 'A교사', dayOfWeek: 1, period: 1, className: '1-1', subject: '수학'),
      TimeSlot(teacher: 'B교사', dayOfWeek: 1, period: 2, className: '1-2', subject: '국어'),
      TimeSlot(teacher: 'C교사', dayOfWeek: 2, period: 1, className: '1-1', subject: '영어'),
    ];

    // 데이터 소스 생성
    _dataSource = SimplifiedTimetableDataSource(
      timeSlots: timeSlots,
      teachers: teachers,
    );

    // 컬럼 생성 (완전한 예시)
    _columns = [
      GridColumn(
        columnName: 'teacher',
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: const Text('교사'),
        ),
      ),
      GridColumn(
        columnName: '월_1',
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: const Text('월 1교시'),
        ),
      ),
      GridColumn(
        columnName: '월_2',
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: const Text('월 2교시'),
        ),
      ),
      GridColumn(
        columnName: '화_1',
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: const Text('화 1교시'),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_dataSource == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('단순화된 시간표')),
      body: Column(
        children: [
          // 컨트롤 버튼들
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () => _selectCell('A교사', '월', 1),
                  child: const Text('A교사 월1교시 선택'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _clearSelection(),
                  child: const Text('선택 해제'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _setExchangeableTeachers(),
                  child: const Text('교체 가능한 교사 설정'),
                ),
              ],
            ),
          ),
          // 시간표 그리드
          Expanded(
            child: SfDataGrid(
              source: _dataSource!,
              columns: _columns,
              gridLinesVisibility: GridLinesVisibility.both,
              headerGridLinesVisibility: GridLinesVisibility.both,
              onCellTap: _onCellTap,
            ),
          ),
        ],
      ),
    );
  }

  void _selectCell(String teacher, String day, int period) {
    AppLogger.exchangeInfo('선택 시도: 교사=$teacher, 요일=$day, 교시=$period');
    setState(() {
      _dataSource?.updateSelection(teacher, day, period);
    });
    AppLogger.exchangeDebug('선택 완료');
  }

  void _clearSelection() {
    setState(() {
      _dataSource?.updateSelection(null, null, null);
    });
  }

  void _setExchangeableTeachers() {
    setState(() {
      _dataSource?.updateExchangeableTeachers([
        {'teacherName': 'B교사', 'day': '월', 'period': 1},
        {'teacherName': 'C교사', 'day': '화', 'period': 2},
      ]);
    });
  }

  void _onCellTap(DataGridCellTapDetails details) {
    // 셀 탭 이벤트 처리
    AppLogger.exchangeDebug('셀 탭: ${details.column.columnName}');
  }
}

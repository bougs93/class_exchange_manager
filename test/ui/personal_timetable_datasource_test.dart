import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/ui/screens/personal_schedule_screen/personal_timetable_datasource.dart';
import 'package:class_exchange_manager/ui/widgets/simplified_timetable_cell.dart';
import 'package:class_exchange_manager/utils/personal_exchange_info_extractor.dart';

/// 2026-09-30 버그 재현: 2중교체에서 같은 칸(같은 날짜·교시)이 한 단계에서는
/// 결강(X)이면서 다른 단계에서는 도착(O)인 경우, 첫 매칭 후 break하던 기존
/// 코드는 둘 중 하나만 반영했다. 이제 둘 다 반영돼야 한다.
void main() {
  test('같은 칸에 결강(X)·도착(O) 정보가 모두 있으면 둘 다 표시하고 도착 과목을 보여준다', () {
    // 월4교시: 이숙희 본인 수업(사회, 1-2)이 빠지는 자리(중간 단계)이면서,
    // 동시에 다른 교사(수학, 1-4)가 도착하는 자리(최종 단계)다.
    final exchangeInfoList = [
      ExchangeCellInfo(
        teacherName: '이숙희',
        date: '2026.09.28',
        day: '월',
        period: 4,
        isAbsence: true,
        subject: '사회',
        className: '1-2',
      ),
      ExchangeCellInfo(
        teacherName: '이숙희',
        date: '2026.09.28',
        day: '월',
        period: 4,
        isAbsence: false,
        subject: '수학',
        className: '1-4',
      ),
    ];

    final baseSlot = TimeSlot(
      teacher: '이숙희',
      subject: '사회',
      className: '1-2',
      dayOfWeek: 1,
      period: 4,
    );
    final row = DataGridRow(
      cells: [
        const DataGridCell(columnName: 'period', value: '4'),
        DataGridCell(columnName: '월_4_2026.09.28', value: baseSlot),
      ],
    );

    final dataSource = PersonalTimetableDataSource(
      rows: [row],
      exchangeInfoList: exchangeInfoList,
      isExchangeViewEnabled: true,
    );

    final adapter = dataSource.buildRow(row)!;
    final cell = adapter.cells[1] as SimplifiedTimetableCell;

    expect(cell.isExchangedSourceCell, isTrue);
    expect(cell.isExchangedDestinationCell, isTrue);
    expect(cell.content, contains('수학'));
    expect(cell.content, contains('1-4'));
  });

  test('결강 정보만 있으면 기존과 동일하게 X만 표시하고 내용을 비운다', () {
    final exchangeInfoList = [
      ExchangeCellInfo(
        teacherName: '정원길',
        date: '2026.09.28',
        day: '월',
        period: 1,
        isAbsence: true,
        subject: '기술가정',
        className: '3-8',
      ),
    ];

    final baseSlot = TimeSlot(
      teacher: '정원길',
      subject: '기술가정',
      className: '3-8',
      dayOfWeek: 1,
      period: 1,
    );
    final row = DataGridRow(
      cells: [
        const DataGridCell(columnName: 'period', value: '1'),
        DataGridCell(columnName: '월_1_2026.09.28', value: baseSlot),
      ],
    );

    final dataSource = PersonalTimetableDataSource(
      rows: [row],
      exchangeInfoList: exchangeInfoList,
      isExchangeViewEnabled: true,
    );

    final adapter = dataSource.buildRow(row)!;
    final cell = adapter.cells[1] as SimplifiedTimetableCell;

    expect(cell.isExchangedSourceCell, isTrue);
    expect(cell.isExchangedDestinationCell, isFalse);
    expect(cell.content, isEmpty);
  });
}

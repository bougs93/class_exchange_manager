import 'package:class_exchange_manager/models/teacher.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/ui/widgets/simplified_timetable_cell.dart';
import 'package:class_exchange_manager/utils/timetable_data_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class RecordingSource extends TimetableDataSource {
  RecordingSource({
    required super.timeSlots,
    required super.teachers,
    required super.ref,
  });
  final updates = <(int, int)?>[];

  @override
  void notifyDataSourceListeners({RowColumnIndex? rowColumnIndex}) {
    updates.add(
      rowColumnIndex == null
          ? null
          : (rowColumnIndex.rowIndex, rowColumnIndex.columnIndex),
    );
    super.notifyDataSourceListeners(rowColumnIndex: rowColumnIndex);
  }
}

void main() {
  testWidgets(
    'selection and data changes refresh affected cells, retaining rows',
    (tester) async {
      late RecordingSource source;
      final teachers = [
        Teacher(name: 'A', subject: '수학'),
        Teacher(name: 'B', subject: '영어'),
      ];
      final slots = [
        for (final name in ['A', 'B'])
          for (var period = 1; period <= 2; period++)
            TimeSlot(
              teacher: name,
              subject: '과목',
              className: '$name-$period',
              dayOfWeek: 1,
              period: period,
            ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                source = RecordingSource(
                  timeSlots: slots,
                  teachers: teachers,
                  ref: ref,
                );
                return Scaffold(
                  body: SfDataGrid(
                    source: source,
                    selectionMode: SelectionMode.none,
                    columns: [
                      for (final name in ['teacher', '월_1', '월_2'])
                        GridColumn(
                          columnName: name,
                          width: 140,
                          label: Text(name),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rows = List<DataGridRow>.of(source.rows);
      source.updates.clear();

      source.updateSelection('A', '월', 1);
      source.notifyDataChanged(); // header refresh in the same input event
      await tester.pumpAndSettle();
      expect(source.updates, unorderedEquals([(0, 0), (0, 1)]));
      expect(
        tester
            .widgetList<SimplifiedTimetableCell>(
              find.byType(SimplifiedTimetableCell),
            )
            .where((cell) => cell.isSelected)
            .map((cell) => cell.content),
        contains('A-1\n과목'),
      );

      source.updates.clear();
      source.updateSelection('B', '월', 2);
      await tester.pumpAndSettle();
      expect(source.updates, unorderedEquals([(0, 0), (0, 1), (1, 0), (1, 2)]));
      final selected =
          tester
              .widgetList<SimplifiedTimetableCell>(
                find.byType(SimplifiedTimetableCell),
              )
              .where((cell) => cell.isSelected)
              .map((cell) => cell.content)
              .toList();
      expect(selected, contains('B-2\n과목'));
      expect(selected, isNot(contains('A-1\n과목')));

      source.updates.clear();
      final changed = slots.map((s) => TimeSlot.fromJson(s.toJson())).toList();
      changed.first.subject = '변경과목';
      source.updateData(changed, teachers);
      await tester.pumpAndSettle();
      expect(source.updates, [(0, 1)]);
      expect(identical(source.rows[0], rows[0]), isTrue);
      expect(identical(source.rows[1], rows[1]), isTrue);
      expect(
        tester
            .widgetList<SimplifiedTimetableCell>(
              find.byType(SimplifiedTimetableCell),
            )
            .map((cell) => cell.content),
        contains('A-1\n변경과목'),
      );

      source.updates.clear();
      source.setNonExchangeableEditMode(false);
      source.notifyDataChanged();
      await tester.pumpAndSettle();
      expect(source.updates, isEmpty);

      source.updates.clear();
      source.updateData([
        ...changed,
        TimeSlot(teacher: 'A', dayOfWeek: 2, period: 1),
      ], teachers);
      // Only inspect the source: the owning screen updates the columns with a
      // structural change, unlike the fixed columns in this fixture.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(source.updates, [null]);
      source.dispose();
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/dated_timetable.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/school_semester.dart';
import 'package:class_exchange_manager/providers/services_provider.dart';
import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/providers/timetable_repository_provider.dart';
import 'package:class_exchange_manager/utils/date_format_utils.dart';
import 'package:class_exchange_manager/utils/substitution_plan_field_accessor.dart';

/// S7.1 회귀: 계획서 화면에서 노드 날짜를 수정하면 PDF 출력이 실제로 그
/// 값을 반영하는지 끝까지 추적한다.
///
/// `PdfExportService._getFieldValue`는 private static이라 직접 호출할 수
/// 없지만, 그 구현은 정확히 `SubstitutionPlanFieldAccessor.getValue` +
/// (날짜 필드면) `DateFormatUtils.toMonthDay`이다(pdf_export_service.dart
/// 참고) — 이 테스트는 그 두 함수를 같은 순서로 직접 호출해 PDF가 실제로
/// 찍을 문자열을 재현하고, `SubstitutionPlanViewModel.loadPlanData()`가
/// 만든 `planData`(계획서 화면·PDF·엑셀·문자 전부가 공유하는 단일 출처)에서
/// 노드 날짜 수정이 그대로 반영되는지 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CircularExchangePath circularPath() {
    final a = ExchangeNode(
      teacherName: 'A',
      day: '월',
      period: 1,
      className: '1-1',
      subjectName: '수학',
    );
    final b = ExchangeNode(
      teacherName: 'B',
      day: '화',
      period: 2,
      className: '1-1',
      subjectName: '영어',
    );
    final c = ExchangeNode(
      teacherName: 'C',
      day: '수',
      period: 3,
      className: '1-1',
      subjectName: '과학',
    );
    return CircularExchangePath.fromNodes([a, b, c, a]);
  }

  String pdfFieldValue(SubstitutionPlanData data, String columnKey) {
    final value = SubstitutionPlanFieldAccessor.getValue(data, columnKey);
    if (value.isEmpty) return '';
    if (columnKey == 'date' || columnKey == '3date') {
      return DateFormatUtils.toMonthDay(value);
    }
    return value;
  }

  test(
    '계획서에서 노드 날짜를 다른 주로 수정하면 PDF가 찍을 날짜 문자열도 그대로 바뀐다',
    () async {
      const timetableId = 'tt_pdf_field_mapping';
      final container = ProviderContainer(
        overrides: [
          timetableDatabaseProvider.overrideWith(
            (ref) => TimetableDatabase.open(path: inMemoryDatabasePath),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo = await container.read(timetableRepositoryProvider.future);
      await repo.insertTimetable(
        DatedTimetable(
          id: timetableId,
          name: '테스트',
          semester: SchoolSemester.defaultFor(schoolYear: 2026, semester: 2),
          registeredAt: DateTime(2026, 8, 1),
        ),
      );

      final history = container.read(exchangeHistoryServiceProvider);
      history.timetableId = timetableId;
      addTearDown(() async {
        await history.clearStoredDataForTimetable(timetableId);
        history.resetForTesting();
      });

      history.addExchange(
        circularPath(),
        absenceDate: DateTime(2026, 8, 24), // 월
        substitutionDate: DateTime(2026, 8, 25),
      );
      final id = history.getExchangeList().single.id;

      // B(화,2)를 결강일과 다른 주(9월 2주 화요일)로 확정 — 계획서 날짜
      // 선택기가 실제로 호출하는 것과 같은 저장 메서드.
      history.updateNodeDate(id, dayName: '화', period: 2, date: DateTime(2026, 9, 8));
      await history.flushPendingWrites();

      final state = container.read(substitutionPlanViewModelProvider);
      final row = state.planData.firstWhere(
        (r) => r.remarks == '순환교체1', // B(화,2) → A(월,1)
      );

      expect(row.absenceDate, '2026.09.08'); // 화, 확정된 다른 주
      expect(pdfFieldValue(row, 'date'), '09.08'); // PDF는 연도 없이 월.일만
      expect(pdfFieldValue(row, '3date'), DateFormatUtils.toMonthDay(row.substitutionDate));
    },
  );
}

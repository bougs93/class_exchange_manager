// ExchangeService의 현재 동작을 캡처하는 특성화 테스트 (characterization test)
//
// 이 파일은 리팩토링(파일 분리) 이전의 동작을 문서화하기 위해 작성되었다.
// 분리 작업 전후로 테스트 결과가 동일하게 유지되어야 한다.
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/teacher.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/services/exchange_service.dart';
import 'package:class_exchange_manager/utils/timetable_data_source.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// 수업이 있는 TimeSlot 생성 헬퍼
TimeSlot lesson({
  required String teacher,
  required int dayOfWeek,
  required int period,
  required String className,
  String subject = '과목',
  bool isExchangeable = true,
  String? exchangeReason,
}) => TimeSlot(
  teacher: teacher,
  subject: subject,
  className: className,
  dayOfWeek: dayOfWeek,
  period: period,
  isExchangeable: isExchangeable,
  exchangeReason: exchangeReason,
);

/// 빈 TimeSlot 생성 헬퍼 (교사/요일/교시만 있고 수업 내용은 없음)
TimeSlot emptySlot({
  required String teacher,
  required int dayOfWeek,
  required int period,
  bool isExchangeable = true,
  String? exchangeReason,
}) => TimeSlot(
  teacher: teacher,
  dayOfWeek: dayOfWeek,
  period: period,
  isExchangeable: isExchangeable,
  exchangeReason: exchangeReason,
);

/// ProviderScope 안에서 실제 WidgetRef를 얻어 TimetableDataSource를 생성한다.
/// (TimetableDataSource 생성자는 WidgetRef를 필수로 요구하므로 위젯 트리가 필요함)
Future<TimetableDataSource> buildDataSource(
  WidgetTester tester, {
  required List<TimeSlot> timeSlots,
  required List<Teacher> teachers,
}) async {
  TimetableDataSource? source;
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          source ??= TimetableDataSource(
            timeSlots: timeSlots,
            teachers: teachers,
            ref: ref,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return source!;
}

void main() {
  // ExchangeService는 싱글톤이므로 테스트 간 상태가 공유된다.
  // 각 테스트 시작 시 선택 상태를 명시적으로 초기화한다.
  late ExchangeService service;

  setUp(() {
    service = ExchangeService();
    service.clearAllSelections();
  });

  group('startOneToOneExchange', () {
    testWidgets('교사명 컬럼을 클릭하면 noAction을 반환한다', (tester) async {
      final dataSource = await buildDataSource(
        tester,
        timeSlots: const [],
        teachers: [Teacher(name: '김영희', subject: '수학')],
      );
      final details = DataGridCellTapDetails(
        globalPosition: Offset.zero,
        localPosition: Offset.zero,
        kind: PointerDeviceKind.touch,
        rowColumnIndex: RowColumnIndex(2, 0),
        column: GridColumn(columnName: 'teacher', label: const SizedBox()),
      );

      final result = service.startOneToOneExchange(details, dataSource);

      expect(result.isNoAction, isTrue);
      expect(result.isSelected, isFalse);
      expect(result.isDeselected, isFalse);
    });

    testWidgets('컬럼명이 요일_교시 형식이 아니면 noAction을 반환한다', (tester) async {
      final dataSource = await buildDataSource(
        tester,
        timeSlots: const [],
        teachers: [Teacher(name: '김영희', subject: '수학')],
      );
      final details = DataGridCellTapDetails(
        globalPosition: Offset.zero,
        localPosition: Offset.zero,
        kind: PointerDeviceKind.touch,
        rowColumnIndex: RowColumnIndex(2, 1),
        column: GridColumn(
          columnName: 'invalidColumn',
          label: const SizedBox(),
        ),
      );

      final result = service.startOneToOneExchange(details, dataSource);

      expect(result.isNoAction, isTrue);
    });

    testWidgets('새 셀을 클릭하면 선택되고 selectCell이 호출된다', (tester) async {
      final dataSource = await buildDataSource(
        tester,
        timeSlots: [
          lesson(teacher: '김영희', dayOfWeek: 1, period: 1, className: '1-1'),
        ],
        teachers: [Teacher(name: '김영희', subject: '수학')],
      );
      final details = DataGridCellTapDetails(
        globalPosition: Offset.zero,
        localPosition: Offset.zero,
        kind: PointerDeviceKind.touch,
        rowColumnIndex: RowColumnIndex(2, 1),
        column: GridColumn(columnName: '월_1', label: const SizedBox()),
      );

      final result = service.startOneToOneExchange(details, dataSource);

      expect(result.isSelected, isTrue);
      expect(result.teacherName, '김영희');
      expect(result.day, '월');
      expect(result.period, 1);
      expect(service.selectedTeacher, '김영희');
      expect(service.hasSelectedCell(), isTrue);
    });

    testWidgets('동일한 셀을 다시 클릭하면 선택이 해제된다', (tester) async {
      final dataSource = await buildDataSource(
        tester,
        timeSlots: [
          lesson(teacher: '김영희', dayOfWeek: 1, period: 1, className: '1-1'),
        ],
        teachers: [Teacher(name: '김영희', subject: '수학')],
      );
      final details = DataGridCellTapDetails(
        globalPosition: Offset.zero,
        localPosition: Offset.zero,
        kind: PointerDeviceKind.touch,
        rowColumnIndex: RowColumnIndex(2, 1),
        column: GridColumn(columnName: '월_1', label: const SizedBox()),
      );

      // 먼저 선택
      service.startOneToOneExchange(details, dataSource);
      // 동일 셀 재클릭
      final result = service.startOneToOneExchange(details, dataSource);

      expect(result.isDeselected, isTrue);
      expect(service.hasSelectedCell(), isFalse);
    });
  });

  group('performOneToOneExchange', () {
    test('같은 학급을 가르치는 두 교사의 교체는 성공한다', () {
      final slots = [
        lesson(teacher: '문유란', dayOfWeek: 1, period: 1, className: '1-1'),
        lesson(teacher: '이숙기', dayOfWeek: 2, period: 2, className: '1-1'),
        // 교체 목적지 TimeSlot(같은 교사·다른 시간대)도 실제 시간표처럼 미리 존재해야 한다
        emptySlot(teacher: '이숙기', dayOfWeek: 1, period: 1),
        emptySlot(teacher: '문유란', dayOfWeek: 2, period: 2),
      ];

      final result = service.performOneToOneExchange(
        slots,
        '문유란',
        '월',
        1,
        '이숙기',
        '화',
        2,
      );

      expect(result, isTrue);
      // 교체 후: 문유란은 화2교시로, 이숙기는 월1교시로 이동 → 원래 자리는 비워짐
      expect(slots[0].isEmpty, isTrue);
      expect(slots[1].isEmpty, isTrue);
      // 목적지 자리에 서로의 수업 내용이 채워진다
      expect(slots[2].className, '1-1'); // 이숙기 월1교시
      expect(slots[3].className, '1-1'); // 문유란 화2교시
    });

    test('다른 학급을 가르치는 교사끼리는 교체할 수 없다', () {
      final slots = [
        lesson(teacher: '문유란', dayOfWeek: 1, period: 1, className: '1-1'),
        lesson(teacher: '이숙기', dayOfWeek: 2, period: 2, className: '2-2'),
      ];

      final result = service.performOneToOneExchange(
        slots,
        '문유란',
        '월',
        1,
        '이숙기',
        '화',
        2,
      );

      expect(result, isFalse);
    });

    test('교체 불가로 설정된 수업은 교체할 수 없다', () {
      final slots = [
        lesson(
          teacher: '문유란',
          dayOfWeek: 1,
          period: 1,
          className: '1-1',
          isExchangeable: false,
          exchangeReason: '교체불가',
        ),
        lesson(teacher: '이숙기', dayOfWeek: 2, period: 2, className: '1-1'),
      ];

      final result = service.performOneToOneExchange(
        slots,
        '문유란',
        '월',
        1,
        '이숙기',
        '화',
        2,
      );

      expect(result, isFalse);
    });

    test('존재하지 않는 TimeSlot에 대한 교체는 실패한다', () {
      final slots = [
        lesson(teacher: '문유란', dayOfWeek: 1, period: 1, className: '1-1'),
      ];

      final result = service.performOneToOneExchange(
        slots,
        '문유란',
        '월',
        1,
        '존재하지않는교사',
        '화',
        2,
      );

      expect(result, isFalse);
    });

    test('빈 셀끼리는 교체할 수 없다 (수업이 없음)', () {
      final slots = [
        emptySlot(teacher: '문유란', dayOfWeek: 1, period: 1),
        emptySlot(teacher: '이숙기', dayOfWeek: 2, period: 2),
      ];

      final result = service.performOneToOneExchange(
        slots,
        '문유란',
        '월',
        1,
        '이숙기',
        '화',
        2,
      );

      expect(result, isFalse);
    });
  });

  group('performSupplementExchange / undoSupplementExchange', () {
    test('빈 셀에 보강을 채우면 성공하고 내용이 복사된다', () {
      final slots = [
        lesson(teacher: '문유란', dayOfWeek: 1, period: 2, className: '1-3'),
        emptySlot(teacher: '김연주', dayOfWeek: 1, period: 2),
      ];

      final result = service.performSupplementExchange(
        slots,
        '문유란',
        '월',
        2,
        '김연주',
        '월',
        2,
      );

      expect(result, isTrue);
      expect(slots[1].className, '1-3');
      expect(slots[1].subject, '과목');
      // 소스는 비워진다
      expect(slots[0].isEmpty, isTrue);
    });

    test('타겟 셀이 비어있지 않으면 보강에 실패한다', () {
      final slots = [
        lesson(teacher: '문유란', dayOfWeek: 1, period: 2, className: '1-3'),
        lesson(teacher: '김연주', dayOfWeek: 1, period: 2, className: '2-1'),
      ];

      final result = service.performSupplementExchange(
        slots,
        '문유란',
        '월',
        2,
        '김연주',
        '월',
        2,
      );

      expect(result, isFalse);
    });

    test('소스 셀이 비어있으면 보강에 실패한다', () {
      final slots = [
        emptySlot(teacher: '문유란', dayOfWeek: 1, period: 2),
        emptySlot(teacher: '김연주', dayOfWeek: 1, period: 2),
      ];

      final result = service.performSupplementExchange(
        slots,
        '문유란',
        '월',
        2,
        '김연주',
        '월',
        2,
      );

      expect(result, isFalse);
    });

    test('보강 후 되돌리면 타겟 셀이 다시 빈 상태가 된다', () {
      final slots = [
        lesson(teacher: '문유란', dayOfWeek: 1, period: 2, className: '1-3'),
        emptySlot(teacher: '김연주', dayOfWeek: 1, period: 2),
      ];

      service.performSupplementExchange(slots, '문유란', '월', 2, '김연주', '월', 2);
      final undoResult = service.undoSupplementExchange(slots, '김연주', '월', 2);

      expect(undoResult, isTrue);
      expect(slots[1].isEmpty, isTrue);
    });

    test('존재하지 않는 TimeSlot을 되돌리면 실패한다', () {
      final slots = [
        lesson(teacher: '문유란', dayOfWeek: 1, period: 2, className: '1-3'),
      ];

      final undoResult = service.undoSupplementExchange(
        slots,
        '존재하지않는교사',
        '월',
        2,
      );

      expect(undoResult, isFalse);
    });
  });

  group('performCircularExchange', () {
    test('3개 노드로 구성된 순환 교체는 성공한다', () {
      // 순환 교체는 각 교사가 다음 노드의 "자기 자신" 자리로 이동하므로
      // A가 월2교시로 이동하려면 A의 월2교시 TimeSlot이 미리 존재해야 한다.
      // 실제 시간표에서는 모든 교사가 모든 교시에 TimeSlot을 갖고 있으므로
      // (수업이 없으면 빈 TimeSlot) 아래처럼 3x3 매트릭스를 모두 채워준다.
      final slots = [
        lesson(teacher: 'A', dayOfWeek: 1, period: 1, className: '1-1'),
        emptySlot(teacher: 'A', dayOfWeek: 1, period: 2),
        emptySlot(teacher: 'A', dayOfWeek: 1, period: 3),
        emptySlot(teacher: 'B', dayOfWeek: 1, period: 1),
        lesson(teacher: 'B', dayOfWeek: 1, period: 2, className: '1-1'),
        emptySlot(teacher: 'B', dayOfWeek: 1, period: 3),
        emptySlot(teacher: 'C', dayOfWeek: 1, period: 1),
        emptySlot(teacher: 'C', dayOfWeek: 1, period: 2),
        lesson(teacher: 'C', dayOfWeek: 1, period: 3, className: '1-1'),
      ];

      final nodes = [
        ExchangeNode(teacherName: 'A', day: '월', period: 1, className: '1-1'),
        ExchangeNode(teacherName: 'B', day: '월', period: 2, className: '1-1'),
        ExchangeNode(teacherName: 'C', day: '월', period: 3, className: '1-1'),
        // 순환 경로는 마지막에 시작 노드로 닫힌다
        ExchangeNode(teacherName: 'A', day: '월', period: 1, className: '1-1'),
      ];

      final result = service.performCircularExchange(slots, nodes);

      expect(result, isTrue);
    });

    test('노드가 3개 미만이면 순환 교체가 실패한다', () {
      final slots = [
        lesson(teacher: 'A', dayOfWeek: 1, period: 1, className: '1-1'),
        lesson(teacher: 'B', dayOfWeek: 1, period: 2, className: '1-1'),
      ];

      final nodes = [
        ExchangeNode(teacherName: 'A', day: '월', period: 1, className: '1-1'),
        ExchangeNode(teacherName: 'B', day: '월', period: 2, className: '1-1'),
      ];

      final result = service.performCircularExchange(slots, nodes);

      expect(result, isFalse);
    });

    test('노드에 해당하는 TimeSlot이 없으면 순환 교체가 실패한다', () {
      final slots = [
        lesson(teacher: 'A', dayOfWeek: 1, period: 1, className: '1-1'),
      ];

      final nodes = [
        ExchangeNode(teacherName: 'A', day: '월', period: 1, className: '1-1'),
        ExchangeNode(
          teacherName: '존재하지않음',
          day: '월',
          period: 2,
          className: '1-1',
        ),
        ExchangeNode(teacherName: 'C', day: '월', period: 3, className: '1-1'),
      ];

      final result = service.performCircularExchange(slots, nodes);

      expect(result, isFalse);
    });
  });

  group('teacherTeachesSubject', () {
    test('교사가 해당 과목을 가르치면 true를 반환한다', () {
      final slots = [
        lesson(
          teacher: '문유란',
          dayOfWeek: 1,
          period: 1,
          className: '1-1',
          subject: '수학',
        ),
      ];

      expect(service.teacherTeachesSubject('문유란', '수학', slots), isTrue);
    });

    test('교사가 해당 과목을 가르치지 않으면 false를 반환한다', () {
      final slots = [
        lesson(
          teacher: '문유란',
          dayOfWeek: 1,
          period: 1,
          className: '1-1',
          subject: '수학',
        ),
      ];

      expect(service.teacherTeachesSubject('문유란', '국어', slots), isFalse);
    });

    test('빈 문자열 과목명을 전달하면 false를 반환한다', () {
      final slots = [
        lesson(
          teacher: '문유란',
          dayOfWeek: 1,
          period: 1,
          className: '1-1',
          subject: '수학',
        ),
      ];

      expect(service.teacherTeachesSubject('문유란', '  ', slots), isFalse);
    });
  });

  group('타겟 셀 및 선택 상태 관리', () {
    test('setTargetCell로 설정한 값을 getter로 조회할 수 있다', () {
      service.setTargetCell('김연주', '월', 3);

      expect(service.targetTeacher, '김연주');
      expect(service.targetDay, '월');
      expect(service.targetPeriod, 3);
      expect(service.hasTargetCell(), isTrue);
    });

    test('updateTargetCellState로 null을 설정하면 hasTargetCell이 false가 된다', () {
      service.setTargetCell('김연주', '월', 3);
      service.updateTargetCellState(null, null, null);

      expect(service.hasTargetCell(), isFalse);
    });

    test('clearAllSelections 호출 시 선택 셀과 타겟 셀이 모두 초기화된다', () {
      service.selectCell('문유란', '월', 1);
      service.setTargetCell('김연주', '월', 3);

      service.clearAllSelections();

      expect(service.hasSelectedCell(), isFalse);
      expect(service.hasTargetCell(), isFalse);
      expect(service.exchangeOptions, isEmpty);
    });

    test('setTargetCell 호출 전에는 hasTargetCell이 false다', () {
      expect(service.hasTargetCell(), isFalse);
    });
  });
}

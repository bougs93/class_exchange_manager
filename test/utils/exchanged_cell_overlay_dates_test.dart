import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/dual_exchange_path.dart';
import 'package:class_exchange_manager/models/exchange_history_item.dart';
import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/supplement_exchange_path.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/utils/exchanged_cell_overlay_dates.dart';

ExchangeNode _node(String teacher, String day, int period) {
  return ExchangeNode(
    teacherName: teacher,
    day: day,
    period: period,
    className: '1-1',
    subjectName: '수학',
  );
}

OneToOneExchangePath _oneToOnePath({
  required String sourceTeacher,
  required String sourceDay,
  required int sourcePeriod,
  required String targetTeacher,
  required String targetDay,
  required int targetPeriod,
}) {
  final targetSlot = TimeSlot(
    teacher: targetTeacher,
    subject: '기술가정',
    className: '3-8',
    dayOfWeek: 1,
    period: targetPeriod,
  );
  return OneToOneExchangePath(
    sourceNode: ExchangeNode(
      teacherName: sourceTeacher,
      day: sourceDay,
      period: sourcePeriod,
      className: '3-8',
      subjectName: '기술가정',
    ),
    targetNode: ExchangeNode(
      teacherName: targetTeacher,
      day: targetDay,
      period: targetPeriod,
      className: '3-8',
      subjectName: '기술가정',
    ),
    option: ExchangeOption(
      timeSlot: targetSlot,
      teacherName: targetTeacher,
      type: ExchangeType.sameClass,
      priority: 1,
      reason: 'test',
    ),
  );
}

void main() {
  group('ExchangedCellOverlayDates.build — 1:1 교체', () {
    test('결강일·교체일이 각 노드의 요일에 맞게 4개 칸 모두에 매핑된다 (사용자 보고 사례 재현)', () {
      // 계획서 화면 사례: 정원길 결강일 10.07(수) 1교시, 박은선 교체일 10.05(월) 1교시
      final path = _oneToOnePath(
        sourceTeacher: '정원길',
        sourceDay: '수',
        sourcePeriod: 1,
        targetTeacher: '박은선',
        targetDay: '월',
        targetPeriod: 1,
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 10, 7),
        substitutionDate: DateTime(2026, 10, 5),
      );

      final dates = ExchangedCellOverlayDates.build([item]);

      // 결강일(수)에 속하는 두 칸 — 정원길 본인 자리, 박은선이 대신 들어간 자리
      expect(dates['정원길_수_1'], DateTime(2026, 10, 7));
      expect(dates['박은선_수_1'], DateTime(2026, 10, 7));
      // 교체일(월)에 속하는 두 칸 — 박은선 본인 자리, 정원길이 대신 들어간 자리
      expect(dates['박은선_월_1'], DateTime(2026, 10, 5));
      expect(dates['정원길_월_1'], DateTime(2026, 10, 5));
    });

    test('현재 보고 있는 주가 달라도 실제 저장된 날짜를 그대로 반환한다', () {
      // 회귀 방지: "선택 주 월요일 + 요일 오프셋"으로 계산하던 이전 버그를 재현하지 않는지 확인.
      // 이 함수는 selectedWeekProvider를 전혀 참조하지 않으므로 애초에 이 문제가 발생할 수 없다.
      final path = _oneToOnePath(
        sourceTeacher: 'A',
        sourceDay: '월',
        sourcePeriod: 3,
        targetTeacher: 'B',
        targetDay: '금',
        targetPeriod: 5,
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 1, 5),
        substitutionDate: DateTime(2026, 1, 9),
      );

      final dates = ExchangedCellOverlayDates.build([item]);

      expect(dates['A_월_3'], DateTime(2026, 1, 5));
      expect(dates['B_금_5'], DateTime(2026, 1, 9));
    });

    test('되돌린(isReverted) 항목은 build에 넘기지 않으면 매핑되지 않는다', () {
      final path = _oneToOnePath(
        sourceTeacher: 'A',
        sourceDay: '월',
        sourcePeriod: 1,
        targetTeacher: 'B',
        targetDay: '화',
        targetPeriod: 1,
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 1, 5),
        substitutionDate: DateTime(2026, 1, 6),
      );

      // getActiveExchangeList()가 이미 isReverted를 걸러내므로, build()는 걸러진
      // 리스트만 받는다는 계약을 확인한다 (빈 리스트를 넘기면 매핑도 비어있음).
      final dates = ExchangedCellOverlayDates.build([]);

      expect(dates, isEmpty);
      // (참고) item 자체는 여전히 유효한 값이다 — 걸러내는 책임은 서비스 계층에 있다.
      expect(item.absenceDate, DateTime(2026, 1, 5));
    });
  });

  group('ExchangedCellOverlayDates.build — 보강(단방향)', () {
    test('소스는 결강일, 타겟은 교체일로 매핑된다', () {
      final path = SupplementExchangePath.simple(
        id: 'test-supplement',
        sourceTeacher: '정원길',
        sourceDay: '수',
        sourcePeriod: 1,
        targetTeacher: '박은선',
        targetDay: '월',
        targetPeriod: 2,
        className: '3-8',
        subject: '기술가정',
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 10, 7),
        substitutionDate: DateTime(2026, 10, 5),
      );

      final dates = ExchangedCellOverlayDates.build([item]);

      expect(dates['정원길_수_1'], DateTime(2026, 10, 7));
      expect(dates['박은선_월_2'], DateTime(2026, 10, 5));
    });
  });

  group('ExchangedCellOverlayDates.build — 순환·2중 교체는 추정 날짜를 보여준다', () {
    test('순환 교체 — 결강일이 속한 주의 요일로 추정한 날짜가 각 칸에 채워진다', () {
      final a = _node('A', '월', 1);
      final b = _node('B', '화', 2);
      final c = _node('C', '수', 3);
      final path = CircularExchangePath.fromNodes([a, b, c, a]);
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 8, 24), // 월요일(8월4주)
        substitutionDate: DateTime(2026, 8, 25),
      );

      final dates = ExchangedCellOverlayDates.build([item]);

      expect(dates['A_월_1'], DateTime(2026, 8, 24));
      expect(dates['A_화_2'], DateTime(2026, 8, 25));
      expect(dates['B_화_2'], DateTime(2026, 8, 25));
      expect(dates['B_수_3'], DateTime(2026, 8, 26));
    });

    test('2중 교체 — 4개 노드 모두 결강일이 속한 주의 요일로 추정한 날짜가 채워진다', () {
      final nodeA = _node('박지혜', '월', 1);
      final nodeB = _node('이숙희', '화', 4);
      final node1 = _node('이숙희', '월', 4);
      final node2 = _node('손혜옥', '화', 5);
      final path = DualExchangePath.build(
        nodeA: nodeA,
        nodeB: nodeB,
        node1: node1,
        node2: node2,
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 8, 24), // 월요일
        substitutionDate: DateTime(2026, 8, 25),
      );

      final dates = ExchangedCellOverlayDates.build([item]);

      expect(dates['박지혜_월_1'], DateTime(2026, 8, 24));
      expect(dates['박지혜_화_4'], DateTime(2026, 8, 25));
      expect(dates['이숙희_월_4'], DateTime(2026, 8, 24));
      expect(dates['손혜옥_화_5'], DateTime(2026, 8, 25));
    });

    test('노드에 확정 날짜(S5.6)가 있으면 추정이 아니라 그 확정 날짜를 보여준다', () {
      final a = _node('A', '월', 1);
      final b = _node('B', '화', 2);
      final c = _node('C', '수', 3);
      final path = CircularExchangePath.fromNodes([a, b, c, a]);
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 8, 24), // 월요일(8월4주)
        substitutionDate: DateTime(2026, 8, 25),
      ).copyWithNodeDate('화', 2, DateTime(2026, 9, 8)); // B만 9월2주 화요일로 확정

      final dates = ExchangedCellOverlayDates.build([item]);

      // A·C는 여전히 추정(8월4주)이지만, B는 확정 날짜(9월2주)를 그대로 보여준다.
      expect(dates['A_월_1'], DateTime(2026, 8, 24));
      expect(dates['B_화_2'], DateTime(2026, 9, 8));
      expect(dates['B_수_3'], DateTime(2026, 8, 26)); // C 자리로 이동한 B — 그 슬롯은 C의 것
    });
  });

  group('ExchangedCellOverlayDates.build — 1:1 요일 불일치는 여전히 생략한다', () {
    test('결강일의 실제 요일이 노드의 요일과 다르면 추정하지 않고 생략한다', () {
      // sourceDay는 '수'인데 absenceDate 실제 요일은 월요일 — 불일치.
      // 순환·2중과 달리 이 경우는 "사용자가 이상한 값을 넣은" 상황이므로
      // 노드 요일로 억지로 되짚어 추정하면 틀린 날짜를 보여줄 수 있다.
      final path = _oneToOnePath(
        sourceTeacher: '정원길',
        sourceDay: '수',
        sourcePeriod: 1,
        targetTeacher: '박은선',
        targetDay: '월',
        targetPeriod: 1,
      );
      final item = ExchangeHistoryItem.fromExchangePath(
        path,
        absenceDate: DateTime(2026, 10, 12), // 월요일 — sourceDay('수')와 불일치
        substitutionDate: DateTime(2026, 10, 14),
      );

      final dates = ExchangedCellOverlayDates.build([item]);

      expect(dates, isEmpty);
    });
  });
}

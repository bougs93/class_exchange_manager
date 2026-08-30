import '../models/exchange_history_item.dart';
import '../models/exchange_node.dart';
import '../models/exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../models/time_slot.dart';
import '../ui/screens/personal_schedule_screen/exchange_week_collector.dart';
import 'day_utils.dart';

/// 교체 경로가 실제로 수행하는 셀 이동 1건
///
/// §10.4: 모든 교체 유형은 "누군가의 한 셀 내용을 다른 셀로 옮기고, 원래 셀은
/// 비운다"는 원시 연산의 조합으로 분해된다. `fromTeacher == toTeacher`면
/// 한 교사가 자기 시간표 안에서 셀을 옮기는 것(1:1·순환 교체), 다르면
/// 다른 교사의 셀로 옮기는 것(보강)이다.
///
/// `exchange_service.dart`의 실제 스왑 코드(`performOneToOneExchange`:373-381,
/// `performSupplementExchange`:490)를 근거로 도출했다 — 추측이 아니다.
class CellMove {
  final String fromTeacher;
  final int fromDay; // 1=월 ~ 5=금
  final int fromPeriod;
  final String toTeacher;
  final int toDay;
  final int toPeriod;

  const CellMove({
    required this.fromTeacher,
    required this.fromDay,
    required this.fromPeriod,
    required this.toTeacher,
    required this.toDay,
    required this.toPeriod,
  });
}

/// [ExchangePath]를 [CellMove] 목록으로 분해한다.
///
/// **구현 범위 (3단계)**: `OneToOneExchangePath`, `SupplementExchangePath`만
/// 지원한다. 두 타입 모두 `exchange_service.dart`의 실제 실행 코드를 직접
/// 대조해 검증했다.
///
/// **미구현 (4단계 예정)**: `CircularExchangePath`, `DualExchangePath`.
/// 이 둘은 노드가 3개 이상이며, 실제 노드 체인이 어떻게 구성되는지
/// (`circular_exchange_service.dart`/`dual_exchange_service.dart`의 경로 탐색
/// 코드)까지 함께 검증해야 안전하게 일반화할 수 있다 — 스왑 실행 코드만
/// 보고 추정하면 노드 순서를 잘못 해석할 위험이 있다. 4단계에서 두 서비스의
/// 경로 생성 코드를 검토한 뒤 이 함수에 케이스를 추가한다.
List<CellMove> exchangePathMoves(ExchangePath path) {
  if (path is OneToOneExchangePath) {
    return _twoWaySwap(path.sourceNode, path.targetNode);
  }
  if (path is SupplementExchangePath) {
    return _oneWayMove(path.sourceNode, path.targetNode);
  }
  throw UnimplementedError(
    '${path.runtimeType}의 셀 이동 분해는 아직 구현되지 않았습니다 '
    '(§10.8 4단계에서 CircularExchangePath/DualExchangePath 지원 예정)',
  );
}

/// 1:1 교체: 두 교사가 각자 자기 셀을 상대의 시간으로 옮긴다 (자기 행 안에서의 이동 2건)
List<CellMove> _twoWaySwap(ExchangeNode a, ExchangeNode b) {
  return [
    CellMove(
      fromTeacher: a.teacherName,
      fromDay: DayUtils.getDayNumber(a.day),
      fromPeriod: a.period,
      toTeacher: a.teacherName,
      toDay: DayUtils.getDayNumber(b.day),
      toPeriod: b.period,
    ),
    CellMove(
      fromTeacher: b.teacherName,
      fromDay: DayUtils.getDayNumber(b.day),
      fromPeriod: b.period,
      toTeacher: b.teacherName,
      toDay: DayUtils.getDayNumber(a.day),
      toPeriod: a.period,
    ),
  ];
}

/// 보강: source 교사의 셀 내용이 target 교사의 셀로 옮겨간다 (교사 간 이동 1건)
List<CellMove> _oneWayMove(ExchangeNode source, ExchangeNode target) {
  return [
    CellMove(
      fromTeacher: source.teacherName,
      fromDay: DayUtils.getDayNumber(source.day),
      fromPeriod: source.period,
      toTeacher: target.teacherName,
      toDay: DayUtils.getDayNumber(target.day),
      toPeriod: target.period,
    ),
  ];
}

/// 특정 주(週)에 대해 [원본 시간표 + 그 주에 속한 교체 이벤트]를 합성한 결과.
///
/// §10.4 B안의 핵심 구현체:
/// - 원본(`base`)은 절대 변경하지 않는다 (모든 셀을 [TimeSlot.copy]로 복제)
/// - `weekMonday`가 다르면 완전히 다른 결과를 낸다 — 다른 주의 이벤트는
///   전혀 관여하지 않는다(P1·P3 해소의 근거)
/// - 계산은 그때그때 하며 아무것도 저장하지 않는다 — 순수 함수
class ResolvedWeek {
  final Map<String, TimeSlot> _cells;
  final DateTime weekMonday;

  ResolvedWeek._(this._cells, this.weekMonday);

  static String _key(String teacher, int day, int period) =>
      '$teacher|$day|$period';

  /// 특정 교사·요일·교시의 합성된 셀 (원본에 없으면 null)
  TimeSlot? cellFor(String teacherName, int dayOfWeek, int period) {
    return _cells[_key(teacherName, dayOfWeek, period)];
  }

  /// [base](원본 시간표) 위에 [events] 중 [weekMonday]가 속한 주에 해당하는
  /// 활성(되돌리지 않은) 이벤트만 순서대로 적용해 합성한다.
  ///
  /// [events]는 실행 순서(예: timestamp 오름차순)로 넘겨야 한다 — 같은 주 안에서
  /// 같은 셀을 두 번 이상 건드리는 이벤트가 있다면 나중 이벤트가 우선한다.
  /// (정상적으로는 검증 단계에서 이런 충돌을 막아야 하며, 이 함수는 그 검증을
  /// 하지 않는다 — 검증은 4단계에서 이 결과 위에 얹는다.)
  static ResolvedWeek of({
    required List<TimeSlot> base,
    required List<ExchangeHistoryItem> events,
    required DateTime weekMonday,
  }) {
    final cells = <String, TimeSlot>{};
    for (final slot in base) {
      final teacher = slot.teacher;
      final day = slot.dayOfWeek;
      final period = slot.period;
      if (teacher == null || day == null || period == null) continue;
      // 원본을 절대 변경하지 않는다 — 복제본만 저장
      cells[_key(teacher, day, period)] = slot.copy();
    }

    final weekEvents = events.where(
      (e) => !e.isReverted && ExchangeWeekCollector.isSameWeek(
        e.weekMonday,
        weekMonday,
      ),
    );

    for (final event in weekEvents) {
      for (final move in exchangePathMoves(event.originalPath)) {
        _applyMove(cells, move);
      }
    }

    return ResolvedWeek._(cells, weekMonday);
  }

  static void _applyMove(Map<String, TimeSlot> cells, CellMove move) {
    final sourceKey = _key(move.fromTeacher, move.fromDay, move.fromPeriod);
    final targetKey = _key(move.toTeacher, move.toDay, move.toPeriod);

    final sourceCell =
        cells[sourceKey] ??
        TimeSlot(
          teacher: move.fromTeacher,
          dayOfWeek: move.fromDay,
          period: move.fromPeriod,
        );

    // 대상 셀: source의 내용(과목·학급·교체가능여부)을 그대로 가져온다.
    // TimeSlot.copyFromWithNewTime과 동일한 규칙.
    cells[targetKey] = TimeSlot(
      teacher: move.toTeacher,
      subject: sourceCell.subject,
      className: sourceCell.className,
      dayOfWeek: move.toDay,
      period: move.toPeriod,
      isExchangeable: sourceCell.isExchangeable,
      exchangeReason: sourceCell.exchangeReason,
    );

    // 원본 셀: 내용만 비운다. isExchangeable/exchangeReason은 유지한다.
    // TimeSlot.clear()와 동일한 규칙.
    cells[sourceKey] = TimeSlot(
      teacher: move.fromTeacher,
      dayOfWeek: move.fromDay,
      period: move.fromPeriod,
      isExchangeable: sourceCell.isExchangeable,
      exchangeReason: sourceCell.exchangeReason,
    );
  }
}

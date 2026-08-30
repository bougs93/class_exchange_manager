import '../models/circular_exchange_path.dart';
import '../models/dual_exchange_path.dart';
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
/// 네 가지 교체 유형 모두 지원하며, 각각 실제 실행 코드를 직접 대조해 검증했다:
///
/// | 유형 | 근거 코드 | 분해 결과 |
/// |---|---|---|
/// | 1:1 | `exchange_service.dart:373-381` | 자기-이동 2건 |
/// | 보강 | `exchange_service.dart:490` | 교사 간 이동 1건 |
/// | 순환 | `exchange_service.dart:782-823` | 자기-이동 (N-1)건 |
/// | 2중 | `exchange_view_provider.dart:658-686` | 1:1 스왑 2회(순서 있음) |
///
/// 반환 순서가 곧 적용 순서다 — 2중 교체는 1단계가 자리를 비운 뒤에야
/// 2단계가 성립하므로 순서를 바꾸면 결과가 달라진다.
List<CellMove> exchangePathMoves(ExchangePath path) {
  if (path is OneToOneExchangePath) {
    return _twoWaySwap(path.sourceNode, path.targetNode);
  }
  if (path is SupplementExchangePath) {
    return _oneWayMove(path.sourceNode, path.targetNode);
  }
  if (path is CircularExchangePath) {
    return _circularMoves(path.nodes);
  }
  if (path is DualExchangePath) {
    // exchange_view_provider._executeDualExchange와 동일한 순서:
    // 1단계 node1↔node2로 node2 자리를 비운 뒤, 2단계 nodeA↔nodeB.
    return [
      ..._twoWaySwap(path.node1, path.node2),
      ..._twoWaySwap(path.nodeA, path.nodeB),
    ];
  }
  throw UnimplementedError('${path.runtimeType}의 셀 이동 분해는 구현되지 않았습니다');
}

/// 순환 교체: 각 노드의 교사가 **자기 행 안에서** 다음 노드의 시간으로 이동한다.
///
/// `performCircularExchange`(`exchange_service.dart:782-823`)와 동일하게
/// 마지막 노드는 순회에서 제외한다 — `nodes.first == nodes.last`인 순환
/// 표현에서 마지막은 "시작점 복귀" 표시일 뿐 별도의 이동이 아니다.
/// 조회·이동 모두 `currentNode.teacherName`을 쓴다는 점이 핵심이다
/// (다음 노드의 교사가 아니다).
List<CellMove> _circularMoves(List<ExchangeNode> nodes) {
  if (nodes.length < 2) return const [];

  final moves = <CellMove>[];
  for (int i = 0; i < nodes.length - 1; i++) {
    final current = nodes[i];
    final next = nodes[i + 1];
    moves.add(
      CellMove(
        fromTeacher: current.teacherName,
        fromDay: DayUtils.getDayNumber(current.day),
        fromPeriod: current.period,
        toTeacher: current.teacherName,
        toDay: DayUtils.getDayNumber(next.day),
        toPeriod: next.period,
      ),
    );
  }
  return moves;
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

  /// 합성 결과를 [base]와 **같은 순서**의 새 리스트로 반환한다.
  ///
  /// `TimetableDataSource.updateData()`에 넘기기 위한 어댑터다. 그리드는 리스트
  /// 순서에 의존하므로 순서를 그대로 유지하며, [base]의 원소는 하나도 변경하지
  /// 않는다(항상 새 객체를 만든다).
  List<TimeSlot> toTimeSlots(List<TimeSlot> base) {
    return base.map((slot) {
      final teacher = slot.teacher;
      final day = slot.dayOfWeek;
      final period = slot.period;
      if (teacher == null || day == null || period == null) {
        return slot.copy();
      }
      return _cells[_key(teacher, day, period)] ?? slot.copy();
    }).toList();
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

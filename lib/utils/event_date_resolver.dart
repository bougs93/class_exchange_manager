import '../models/exchange_history_item.dart';
import 'day_utils.dart';
import 'exchange_cell_dates.dart';
import 'resolved_week.dart' show CellMove;
import 'week_date_calculator.dart';

/// 한 칸의 날짜가 어디서 왔는지 (S5.6).
enum CellDateSource {
  /// 1:1·보강 — 확정된 결강일/교체일 쌍에서 직접 유도됨.
  confirmedPair,

  /// 순환·2중 — 계획서에서 그 노드(슬롯)에 개별적으로 지정한 확정 날짜.
  confirmedNode,

  /// 순환·2중 중 아직 확정되지 않은 노드 — "결강일이 속한 주"로 추정한 값(OQ-1).
  estimated,
}

/// [EventDateResolution.forSlot]의 결과 한 칸.
class ResolvedCellDate {
  final DateTime date;
  final CellDateSource source;

  const ResolvedCellDate(this.date, this.source);

  /// 추정이 아니라 실제로 확정된 값인지.
  bool get isConfirmed => source != CellDateSource.estimated;
}

/// [resolveEventDates]가 돌려주는, 한 이벤트에 대한 날짜 조회기.
///
/// ⚠ 1:1·보강의 날짜를 **요일만으로 찾으면 안 된다.** 결강일과 교체일은 다른
/// 주의 같은 요일일 수 있다(예: 10.07(수) 4교시 ↔ 10.14(수) 6교시). 예전에는
/// 요일 → 날짜 맵을 써서 한쪽 날짜가 다른 쪽을 덮어썼고, 그 결과 날짜 반영
/// 화면에서 결강일 주의 교체가 통째로 사라졌다(2026-10-05 수정).
/// 그래서 확정 날짜는 **칸 좌표(쪽·교사·요일·교시)** 로만 찾는다.
class EventDateResolution {
  final ExchangeHistoryItem _item;

  /// 1:1·보강의 확정 날짜 — [_cellKey] → 날짜. supported일 때만 non-null.
  final Map<String, DateTime>? _confirmedCells;

  /// 1:1·보강의 확정 날짜 — [_slotKey] → 날짜. 같은 요일·교시가 서로 다른
  /// 날짜에 걸치는(구분 불가) 슬롯은 넣지 않는다. supported일 때만 non-null.
  final Map<String, DateTime>? _confirmedSlots;

  const EventDateResolution._(
    this._item,
    this._confirmedCells,
    this._confirmedSlots,
  );

  static String _cellKey(bool isVacateSide, String teacher, int day, int period) =>
      '${isVacateSide ? 'V' : 'F'}|$teacher|$day|$period';

  static String _slotKey(int day, int period) => '$day|$period';

  /// 셀 이동 하나의 "빠지는 쪽"·"채워지는 쪽" 날짜를 조회한다.
  ///
  /// **셀 이동([CellMove])에 날짜를 붙이는 곳은 반드시 이 함수를 쓴다.**
  /// 1:1·보강은 이동의 양 끝 칸 좌표로 확정 날짜를 정확히 찾으므로, 결강일과
  /// 교체일이 같은 요일(심지어 같은 교시)이어도 섞이지 않는다.
  /// 순환·2중은 [forSlot](노드 확정 날짜 → 추정)과 같다.
  ({ResolvedCellDate? from, ResolvedCellDate? to}) forMove(CellMove move) {
    final cells = _confirmedCells;
    if (cells != null) {
      final from =
          cells[_cellKey(true, move.fromTeacher, move.fromDay, move.fromPeriod)];
      final to =
          cells[_cellKey(false, move.toTeacher, move.toDay, move.toPeriod)];
      if (from != null && to != null) {
        return (
          from: ResolvedCellDate(from, CellDateSource.confirmedPair),
          to: ResolvedCellDate(to, CellDateSource.confirmedPair),
        );
      }
    }
    return (
      from: forSlot(move.fromDay, move.fromPeriod),
      to: forSlot(move.toDay, move.toPeriod),
    );
  }

  /// [dayNumber](1~5)·[period] 슬롯의 날짜를 조회한다.
  ///
  /// 순환·2중 노드 날짜 조회용이다. 1:1·보강에서 같은 요일·교시가 두 날짜에
  /// 걸치면(다른 주의 같은 칸끼리 교체) 슬롯만으로는 어느 날짜인지 알 수 없으므로
  /// null을 돌려준다 — 셀 이동에 날짜를 붙일 때는 [forMove]를 쓸 것.
  ///
  /// `dayNumber`가 1~5 밖이면 null이다 — 기존 소비자들의 "이론상 발생하지
  /// 않지만 방어적으로 폴백" 분기를 그대로 살리기 위함이다.
  ResolvedCellDate? forSlot(int dayNumber, int period) {
    final confirmedSlots = _confirmedSlots;
    if (confirmedSlots != null) {
      final date = confirmedSlots[_slotKey(dayNumber, period)];
      if (date != null) return ResolvedCellDate(date, CellDateSource.confirmedPair);
      // 이 이벤트가 건드리는 슬롯인데 맵에 없다 = 두 날짜에 걸쳐 구분 불가
      if (_confirmedCells!.keys.any((k) => k.endsWith('|$dayNumber|$period'))) {
        return null;
      }
    }

    if (_item.supportsNodeDates && dayNumber >= 1 && dayNumber <= 5) {
      final dayName = DayUtils.getDayName(dayNumber);
      final nodeDate = _item.nodeDateFor(dayName, period);
      if (nodeDate != null) {
        return ResolvedCellDate(nodeDate, CellDateSource.confirmedNode);
      }
    }

    if (dayNumber < 1 || dayNumber > 5) return null;

    final weekMonday = WeekDateCalculator.getWeekMonday(_item.absenceDate);
    return ResolvedCellDate(
      weekMonday.add(Duration(days: dayNumber - 1)),
      CellDateSource.estimated,
    );
  }
}

/// [item] 하나에 대한 날짜 판단기를 만든다 (S5.6).
///
/// 이 함수 하나가 "확정 쌍(1:1·보강) / 확정 노드(순환·2중) / 추정(OQ-1)"을
/// 판단하는 유일한 장소다 — `lesson_projection.dart`와 `resolved_week.dart`의
/// `ResolvedWeek.dateAware`가 이 함수를 공유한다(둘 다 [EventDateResolution.forMove]
/// 사용). 두 곳이 각자 다시 추측하지 않는다는 것이 `project() ≡ dateAware`
/// 등식이 계속 성립하는 근거다.
///
/// 1:1·보강의 확정 날짜는 [ExchangeCellDates.forItem]의 칸별 날짜를 그대로 쓴다
/// — X/○ 표시([ExchangeCellDates.forWeek])와 같은 출처라 표시와 내용이 어긋나지 않는다.
EventDateResolution resolveEventDates(ExchangeHistoryItem item) {
  final cellDates = ExchangeCellDates.forItem(item);
  if (!cellDates.supported) return EventDateResolution._(item, null, null);

  final cells = <String, DateTime>{};
  final slots = <String, DateTime>{};
  final ambiguousSlots = <String>{};
  for (final cell in cellDates.cells) {
    final day = DayUtils.getDayNumber(cell.dayName);
    cells[EventDateResolution._cellKey(
      cell.isVacateSide,
      cell.teacher,
      day,
      cell.period,
    )] = cell.date;

    final slotKey = EventDateResolution._slotKey(day, cell.period);
    final existing = slots[slotKey];
    if (existing != null && existing != cell.date) ambiguousSlots.add(slotKey);
    slots[slotKey] = cell.date;
  }
  slots.removeWhere((key, _) => ambiguousSlots.contains(key));

  return EventDateResolution._(item, cells, slots);
}

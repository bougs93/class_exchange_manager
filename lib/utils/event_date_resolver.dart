import '../models/exchange_history_item.dart';
import 'day_utils.dart';
import 'exchange_cell_dates.dart';
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

/// [resolveEventDates]가 돌려주는, 한 이벤트에 대한 슬롯별 날짜 조회기.
class EventDateResolution {
  final ExchangeHistoryItem _item;
  final Map<int, DateTime>? _confirmedPairByDay; // supported일 때만 non-null

  const EventDateResolution._(this._item, this._confirmedPairByDay);

  /// [dayNumber](1~5)·[period] 슬롯의 날짜를 조회한다.
  ///
  /// `dayNumber`가 1~5 밖이면 null이다 — 기존 소비자들의 "이론상 발생하지
  /// 않지만 방어적으로 폴백" 분기를 그대로 살리기 위함이다.
  ResolvedCellDate? forSlot(int dayNumber, int period) {
    final confirmedPair = _confirmedPairByDay;
    if (confirmedPair != null) {
      // 1:1·보강: period는 일부러 무시한다 — 기존 `_resolveDateByDay`/
      // `dateAware`가 정확히 이렇게 동작했으므로, 여기서 슬롯 정밀도를
      // "개선"하면 1:1이 기존과 바이트 동일하지 않게 된다.
      final date = confirmedPair[dayNumber];
      if (date != null) return ResolvedCellDate(date, CellDateSource.confirmedPair);
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

/// [item] 하나에 대한 슬롯별 날짜 판단기를 만든다 (S5.6).
///
/// 이 함수 하나가 "확정 쌍(1:1·보강) / 확정 노드(순환·2중) / 추정(OQ-1)"을
/// 판단하는 유일한 장소다 — `lesson_projection.dart`(`_resolveDateByDay`가
/// 있던 자리)와 `resolved_week.dart`의 `ResolvedWeek.dateAware`가 이 함수를
/// 공유한다. 두 곳이 각자 다시 추측하지 않는다는 것이 S5.3/S5.4a에서 증명한
/// `project() ≡ dateAware` 등식이 S5.6 이후에도 계속 성립하는 근거다.
///
/// **불변 조건**: [item.nodeDates]가 비어 있으면(S5.6 이전 상태, 그리고
/// 노드 날짜를 한 번도 지정하지 않은 모든 순환·2중 항목) 이 함수의 출력은
/// 모든 입력에 대해 기존 `ExchangeCellDates.forItem(...).dateByDayNumber` /
/// 기존 `_resolveDateByDay(...)`와 동일하다.
EventDateResolution resolveEventDates(ExchangeHistoryItem item) {
  final cellDates = ExchangeCellDates.forItem(item);
  return EventDateResolution._(
    item,
    cellDates.supported ? cellDates.dateByDayNumber : null,
  );
}

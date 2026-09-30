import '../models/exchange_history_item.dart';
import '../models/lesson.dart';
import 'event_date_resolver.dart';
import 'resolved_week.dart';

/// 교체 이벤트 저널을 날짜별 수업 배치(`Lesson`)에 재생(replay)하는 순수
/// 함수 (S5.3).
///
/// **SQLite에 아무것도 쓰지 않는다** — 계산만 한다. `exchangePathMoves`
/// (`resolved_week.dart`)와 `ExchangeCellDates.forItem`을 화면 합성 로직
/// (`ResolvedWeek.dateAware`)과 그대로 공유하므로, 이 함수의 결과가 특정
/// 주로 필터됐을 때 화면에 실제로 보이는 결과와 어긋나지 않는다는 것을
/// 등식으로 증명할 수 있다(`test/utils/lesson_projection_test.dart` 참조).
/// 이 등식이 성립함을 확인하는 것이 S5.3의 목적이며, 실제 `lessons` 테이블에
/// 쓰는 것은 S5.4a에서 이 함수를 재사용해 진행한다.
///
/// 순환·2중 교체([ExchangeCellDates.forItem]이 `unsupported`를 반환하는
/// 경우 — 참여 노드가 3개 이상인데 저장된 날짜는 2개뿐이라 정확한 날짜를
/// 알 수 없음)는 "모든 참여 칸이 결강일과 같은 주에 있다"고 가정해 채운다
/// (S5 설계 검토 OQ-1 채택안 — 노드별로 다른 주를 지정하는 기능은 범위 밖).
/// 요일과 실제 날짜가 어긋나는 이벤트도 같은 방식으로 폴백한다
/// (`ResolvedWeek.dateAware`와 동일한 안전장치).
List<Lesson> project({
  required List<Lesson> snapshot,
  required List<ExchangeHistoryItem> activeEvents,
  required String timetableId,
}) {
  final cells = <String, Lesson>{
    for (final lesson in snapshot) _key(lesson.teacher, lesson.date, lesson.period): lesson,
  };

  for (final event in activeEvents) {
    final resolution = resolveEventDates(event);
    for (final move in exchangePathMoves(event.originalPath)) {
      final fromDate = resolution.forSlot(move.fromDay, move.fromPeriod)?.date;
      final toDate = resolution.forSlot(move.toDay, move.toPeriod)?.date;
      if (fromDate == null || toDate == null) continue;
      _applyMove(cells, move, fromDate, toDate, timetableId);
    }
  }

  return cells.values.toList();
}

/// [event] 하나가 실제로 건드리는 칸의 좌표(교사·날짜·교시) 목록 (S5.4a 성능
/// 수정에서 사용).
///
/// `replayInto`가 이 이벤트 때문에 "리셋·재계산해야 할 범위"를 정할 때 쓴다.
/// [project]와 정확히 같은 날짜 해석 규칙([resolveEventDates])을 쓰므로, 이
/// 함수가 돌려주는 좌표 집합은 항상 [project]가 실제로 건드리는 좌표와 일치한다.
List<TouchedCell> touchedCellsFor(ExchangeHistoryItem event) {
  final resolution = resolveEventDates(event);
  final cells = <TouchedCell>[];
  for (final move in exchangePathMoves(event.originalPath)) {
    final fromDate = resolution.forSlot(move.fromDay, move.fromPeriod)?.date;
    final toDate = resolution.forSlot(move.toDay, move.toPeriod)?.date;
    if (fromDate == null || toDate == null) continue;
    cells.add(TouchedCell(teacher: move.fromTeacher, date: fromDate, period: move.fromPeriod));
    cells.add(TouchedCell(teacher: move.toTeacher, date: toDate, period: move.toPeriod));
  }
  return cells;
}

/// [touchedCellsFor]가 돌려주는 좌표 한 개.
class TouchedCell {
  final String teacher;
  final DateTime date;
  final int period;

  const TouchedCell({
    required this.teacher,
    required this.date,
    required this.period,
  });
}

void _applyMove(
  Map<String, Lesson> cells,
  CellMove move,
  DateTime fromDate,
  DateTime toDate,
  String timetableId,
) {
  final fromKey = _key(move.fromTeacher, fromDate, move.fromPeriod);
  final toKey = _key(move.toTeacher, toDate, move.toPeriod);

  final sourceLesson =
      cells[fromKey] ??
      Lesson(
        id: _deterministicId(timetableId, move.fromTeacher, fromDate, move.fromPeriod),
        timetableId: timetableId,
        date: fromDate,
        period: move.fromPeriod,
        teacher: move.fromTeacher,
      );

  // 대상 칸: source의 내용을 그대로 가져온다 (ResolvedWeek._applyMove와 동일 규칙).
  // 이미 그 칸에 Lesson이 있었으면 id를 유지한다. 처음 생기는 칸이면 좌표 기반
  // 결정적 ID를 쓴다 — `replayInto`(S5.4a)가 매번 재생될 때마다 같은 칸에
  // 다른 ID를 새로 만들어 행이 중복 쌓이는 것을 막는다(S5 설계 검토 OQ-6).
  cells[toKey] = Lesson(
    id: cells[toKey]?.id ?? _deterministicId(timetableId, move.toTeacher, toDate, move.toPeriod),
    timetableId: timetableId,
    date: toDate,
    period: move.toPeriod,
    teacher: move.toTeacher,
    subject: sourceLesson.subject,
    className: sourceLesson.className,
    isExchangeable: sourceLesson.isExchangeable,
    exchangeReason: sourceLesson.exchangeReason,
  );

  // 원본 칸: 내용만 비운다. isExchangeable/exchangeReason은 유지한다.
  cells[fromKey] = Lesson(
    id: sourceLesson.id,
    timetableId: timetableId,
    date: fromDate,
    period: move.fromPeriod,
    teacher: move.fromTeacher,
    isExchangeable: sourceLesson.isExchangeable,
    exchangeReason: sourceLesson.exchangeReason,
  );
}

String _key(String teacher, DateTime date, int period) =>
    '$teacher|${date.year}-${date.month}-${date.day}|$period';

/// 새로 생기는 칸(원래 스냅샷에 없던 좌표)에 쓰는 결정적 ID.
///
/// 이벤트 ID가 아니라 **좌표**(시간표·교사·날짜·교시) 기준이다 — 여러 이벤트가
/// 재생 순서상 같은 칸을 거쳐 가도, 그 칸의 정체성은 "언제 누가 만들었나"가
/// 아니라 "지금 이 시간표의 이 날짜·교시가 누구 것인가"이기 때문이다.
String _deterministicId(
  String timetableId,
  String teacher,
  DateTime date,
  int period,
) => 'proj_${timetableId}_${teacher}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_$period';

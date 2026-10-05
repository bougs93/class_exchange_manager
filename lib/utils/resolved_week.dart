import '../models/circular_exchange_path.dart';
import '../models/dual_exchange_path.dart';
import '../models/exchange_history_item.dart';
import '../models/exchange_node.dart';
import '../models/exchange_path.dart';
import '../models/lesson.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../models/time_slot.dart';
import '../ui/screens/personal_schedule_screen/exchange_week_collector.dart';
import 'day_utils.dart';
import 'event_date_resolver.dart';
import 'week_date_calculator.dart';

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
  ///
  /// 현재 앱 코드에서는 쓰지 않는다(OFF는 [allWeeks], ON은 [dateAware]) — 테스트용 기준 구현.
  static ResolvedWeek of({
    required List<TimeSlot> base,
    required List<ExchangeHistoryItem> events,
    required DateTime weekMonday,
  }) {
    return _compose(
      base,
      events.where(
        (e) => !e.isReverted && ExchangeWeekCollector.isSameWeek(
          e.weekMonday,
          weekMonday,
        ),
      ),
      weekMonday,
    );
  }

  /// 날짜 반영 OFF 전용 — 주와 관계없이 모든 활성 교체를 한 주에 모아 합성한다.
  ///
  /// OFF에서는 빠진·맡은 수업 표시가 모든 주의 교체에 붙는다. 내용도 같은 기준으로
  /// 합성해야 표시가 붙은 칸이 실제로 바뀌어 보인다. 교체 이력·원본은 바꾸지 않는다
  /// (화면용 합성일 뿐 — 날짜는 교체 이력에 그대로 남아 계획서·PDF·ON 화면이 쓴다).
  ///
  /// 호출부는 두 곳이며 **항상 같이 바꿔야 한다**: `exchange_view_provider.dart`
  /// (화면), `resolved_timetable_provider.dart`(교체 탐색·검증).
  ///
  /// 알려진 제한 (서로 다른 주의 교체가 같은 칸을 건드린 경우):
  /// - 실행 순서상 나중 교체가 보인다. 앞 교체가 이미 비운 칸을 옮기면 빈 내용이
  ///   옮겨져 수업이 빈칸으로 보일 수 있다 → ON으로 보면 주별로 정상 표시된다
  /// - 이동한 수업은 `isExchangeable`도 함께 옮겨지므로, 합성 결과로 교체불가 셀을
  ///   저장하면(`TimetableDataSource._saveNonExchangeableCells`) 옮겨간 칸까지
  ///   교체불가로 저장될 수 있다 (`of`/ON에서도 같은 구조, OFF에서 범위만 넓다)
  static ResolvedWeek allWeeks({
    required List<TimeSlot> base,
    required List<ExchangeHistoryItem> events,
    required DateTime weekMonday,
  }) {
    return _compose(base, events.where((e) => !e.isReverted), weekMonday);
  }

  static ResolvedWeek _compose(
    List<TimeSlot> base,
    Iterable<ExchangeHistoryItem> events,
    DateTime weekMonday,
  ) {
    final cells = <String, TimeSlot>{};
    for (final slot in base) {
      final teacher = slot.teacher;
      final day = slot.dayOfWeek;
      final period = slot.period;
      if (teacher == null || day == null || period == null) continue;
      // 원본을 절대 변경하지 않는다 — 복제본만 저장
      cells[_key(teacher, day, period)] = slot.copy();
    }

    for (final event in events) {
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

  /// [base] 위에 [events] 중 **실제 참여 칸의 캘린더 날짜**가 [weekMonday]가 속한
  /// 주에 걸리는 쪽만 적용해 합성한다 (S1.7 — 날짜표시 스위치 ON 전용).
  ///
  /// [of]와의 차이: [of]는 이벤트 전체를 "결강일이 속한 주"로만 판단하고 그
  /// 안에서 이동의 양쪽을 항상 함께 적용한다. 이 함수는 이동 하나를 "빠지는
  /// 쪽"과 "채워지는 쪽"으로 나눠, 각 쪽이 실제로 속한 주에서만 독립적으로
  /// 적용한다 — 결강일 쪽 주에서는 빠지는 쪽만, 교체일 쪽 주에서는 채워지는
  /// 쪽만 보이는 식으로, 다른 주로 넘어가는 교체를 올바르게 표현한다.
  ///
  /// 같은 주 안에서 끝나는 이벤트(양쪽 날짜가 모두 [weekMonday]가 속한 주)는
  /// [of]와 **완전히 같은 결과**를 낸다 — `exchange_cell_dates_test.dart`와
  /// `resolved_week_test.dart`의 기존 동일 주 픽스처로 이 성질을 검증한다.
  ///
  /// 순환·2중 교체는 [resolveEventDates]가 노드별 확정 날짜(S5.6, 계획서에서
  /// 지정)를 갖고 있으면 그 슬롯만 정확히 배치하고, 없으면 [of]와 동일하게
  /// "결강일이 속한 주"로 추정한 값을 쓴다(틀린 주에 억지로 나눠 표시하지
  /// 않는다 — 추정값은 항상 그 이벤트의 전 슬롯이 같은 주이므로 아래 통합
  /// 분기가 자동으로 `of`와 같은 결과를 낸다).
  static ResolvedWeek dateAware({
    required List<TimeSlot> base,
    required List<ExchangeHistoryItem> events,
    required DateTime weekMonday,
  }) {
    final cells = <String, TimeSlot>{};
    final baseIndex = <String, TimeSlot>{};
    for (final slot in base) {
      final teacher = slot.teacher;
      final day = slot.dayOfWeek;
      final period = slot.period;
      if (teacher == null || day == null || period == null) continue;
      // 원본을 절대 변경하지 않는다 — 복제본만 저장
      cells[_key(teacher, day, period)] = slot.copy();
      // 채워지는 쪽이 다른 주라 현재 cells 맵에 아직 소스가 없을 때, 원본
      // 스냅샷에서 내용을 가져오기 위한 색인(§2.2 applyFillOnly 참고)
      baseIndex[_key(teacher, day, period)] = slot;
    }

    final viewedMonday = WeekDateCalculator.getWeekMonday(weekMonday);
    bool inViewedWeek(DateTime date) =>
        WeekDateCalculator.getWeekMonday(date) == viewedMonday;

    final activeEvents = events.where((e) => !e.isReverted);

    for (final event in activeEvents) {
      final resolution = resolveEventDates(event);

      for (final move in exchangePathMoves(event.originalPath)) {
        final dates = resolution.forMove(move);
        final fromDate = dates.from?.date;
        final toDate = dates.to?.date;
        if (fromDate == null || toDate == null) {
          // 이론상 발생하지 않아야 하지만, 방어적으로 기존 방식으로 폴백
          if (inViewedWeek(event.absenceDate)) _applyMove(cells, move);
          continue;
        }

        final fromHere = inViewedWeek(fromDate);
        final toHere = inViewedWeek(toDate);

        if (fromHere && toHere) {
          _applyMove(cells, move);
        } else if (fromHere) {
          _applyVacateOnly(cells, move);
        } else if (toHere) {
          _applyFillOnly(cells, move, baseIndex);
        }
        // 둘 다 아니면 이 주에서는 이 이동이 보이지 않는다
      }
    }

    return ResolvedWeek._(cells, viewedMonday);
  }

  /// [move]의 "빠지는 쪽"만 적용한다 — 원본 셀 내용을 비운다.
  static void _applyVacateOnly(Map<String, TimeSlot> cells, CellMove move) {
    final sourceKey = _key(move.fromTeacher, move.fromDay, move.fromPeriod);
    final sourceCell =
        cells[sourceKey] ??
        TimeSlot(
          teacher: move.fromTeacher,
          dayOfWeek: move.fromDay,
          period: move.fromPeriod,
        );

    cells[sourceKey] = TimeSlot(
      teacher: move.fromTeacher,
      dayOfWeek: move.fromDay,
      period: move.fromPeriod,
      isExchangeable: sourceCell.isExchangeable,
      exchangeReason: sourceCell.exchangeReason,
    );
  }

  /// [base](원본 시간표) 위에, SQLite `lessons`에서 조회한 [touchedLessons]만
  /// 덮어써 합성한다 (S5.5.1 — 조회 전환용 오버레이 어댑터).
  ///
  /// [of]/[dateAware]와 달리 이벤트 목록을 직접 재생하지 않는다 — 이미
  /// `lesson_projection.dart`의 [project]가 재생을 끝내고 `TimetableRepository`에
  /// 저장해 둔 결과([touchedLessons], 보통 `getTouchedLessonsForWeek`의 반환값)를
  /// "덮어쓰기"만 한다는 점이 이 함수의 전략(오버레이) 전체를 요약한다.
  ///
  /// [touchedLessons]에 없는 칸은 [base] 그대로 남는다 — 건드린 적 없는 칸까지
  /// 전부 가져올 필요가 없다는 것이 이 오버레이 전략의 핵심이다(S5.5 설계 검토
  /// Decision A). 덮어쓰는 내용은 **`subject`/`className`뿐**이다 —
  /// `isExchangeable`/`exchangeReason`(교체 가능 여부·사유)은 [base]의 값을 그대로
  /// 유지한다(S5.5 설계 검토 Decision B, R8 — 이 값은 원본 시간표 속성이지
  /// 교체로 바뀌는 값이 아니므로 SQLite 쪽 값을 신뢰하지 않는다).
  ///
  /// [weekMonday]는 결과에 실릴 값일 뿐 필터링에 쓰이지 않는다 — 호출자가 이미
  /// 그 주에 해당하는 [touchedLessons]만 건네준다고 가정한다(`getTouchedLessonsForWeek`
  /// 계약). 이 함수 자체는 [Lesson.date]의 요일(`DateTime.weekday`, 1=월~5=금 —
  /// [CellMove]가 쓰는 것과 같은 체계)만으로 어느 칸을 덮어쓸지 정한다.
  static ResolvedWeek fromLessons({
    required List<TimeSlot> base,
    required List<Lesson> touchedLessons,
    required DateTime weekMonday,
  }) {
    final cells = <String, TimeSlot>{};
    for (final slot in base) {
      final teacher = slot.teacher;
      final day = slot.dayOfWeek;
      final period = slot.period;
      if (teacher == null || day == null || period == null) continue;
      cells[_key(teacher, day, period)] = slot.copy();
    }

    for (final lesson in touchedLessons) {
      final key = _key(lesson.teacher, lesson.date.weekday, lesson.period);
      final baseSlot = cells[key];
      cells[key] = TimeSlot(
        teacher: lesson.teacher,
        subject: lesson.subject,
        className: lesson.className,
        dayOfWeek: lesson.date.weekday,
        period: lesson.period,
        isExchangeable: baseSlot?.isExchangeable ?? true,
        exchangeReason: baseSlot?.exchangeReason,
      );
    }

    return ResolvedWeek._(cells, weekMonday);
  }

  /// [move]의 "채워지는 쪽"만 적용한다 — 소스 내용은 **원본 스냅샷**([baseIndex])
  /// 에서 가져온다. 소스가 다른 주에 있어 현재 [cells] 맵에 없을 수 있기 때문이다.
  ///
  /// 알려진 근사: 소스 셀이 자기 주 안에서 또 다른 교체로 이미 바뀐 상태라면,
  /// 여기서는 그 변경을 반영하지 못하고 원본 내용을 그대로 가져온다(연쇄 재교체
  /// 재귀 해석은 순환 위험이 있어 이번 단계 범위 밖 — S5에서 재검토).
  static void _applyFillOnly(
    Map<String, TimeSlot> cells,
    CellMove move,
    Map<String, TimeSlot> baseIndex,
  ) {
    final targetKey = _key(move.toTeacher, move.toDay, move.toPeriod);
    final sourceBaseKey = _key(move.fromTeacher, move.fromDay, move.fromPeriod);
    final src = baseIndex[sourceBaseKey];

    cells[targetKey] = TimeSlot(
      teacher: move.toTeacher,
      subject: src?.subject,
      className: src?.className,
      dayOfWeek: move.toDay,
      period: move.toPeriod,
      isExchangeable: src?.isExchangeable ?? true,
      exchangeReason: src?.exchangeReason,
    );
  }
}

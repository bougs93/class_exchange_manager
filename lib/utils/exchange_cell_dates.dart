import '../models/circular_exchange_path.dart';
import '../models/dual_exchange_path.dart';
import '../models/exchange_history_item.dart';
import '../models/exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import 'day_utils.dart';
import 'event_date_resolver.dart';
import 'week_date_calculator.dart';

/// 교체 이벤트 한 건이 건드리는 칸 하나 — 교사·요일·교시 좌표 + 실제 날짜.
///
/// [isVacateSide]가 true면 X(빠진 수업), false면 ○(맡은 수업)에 해당한다.
class DatedCell {
  final String teacher;
  final String dayName; // '월'~'금' (ExchangeNode.day 형식)
  final int period;
  final DateTime date; // 실제 캘린더 날짜
  final bool isVacateSide;

  const DatedCell({
    required this.teacher,
    required this.dayName,
    required this.period,
    required this.date,
    required this.isVacateSide,
  });

  String get coordinateKey => '${teacher}_${dayName}_$period';
}

/// 교체 이벤트 한 건의 참여 칸별 실제 날짜 매핑 결과.
///
/// [supported]가 false면(순환·2중 교체, 또는 요일·실제 날짜 불일치) 참여 칸별
/// 정확한 날짜를 알 수 없다는 뜻이다 — 이 경우 [cells]는 비어 있고, 호출부는
/// 날짜 미확정으로 안전하게 폴백해야 한다(틀린 날짜를 보여주지 않는다).
class EventCellDates {
  final bool supported;
  final List<DatedCell> cells;

  const EventCellDates({required this.supported, required this.cells});

  static const EventCellDates unsupported = EventCellDates(
    supported: false,
    cells: [],
  );

  /// dayNumber(1~5) → 그 요일에 해당하는 실제 날짜.
  ///
  /// 같은 이벤트 안에서 결강일 쪽 요일과 교체일 쪽 요일이 같을 수는 없으므로
  /// (다르니까 두 날짜가 필요한 것) 충돌 없이 1:1로 채워진다.
  Map<int, DateTime> get dateByDayNumber => {
    for (final cell in cells) DayUtils.getDayNumber(cell.dayName): cell.date,
  };
}

/// 특정 주(週)에 대해 실제 날짜 기준으로 스코프된 X/○ 셀 키 집합.
///
/// [undatedKeys]는 순환·2중 교체 등 날짜 미확정 칸의 키(소스+목적지 합산)다 —
/// 호출부가 "?" 표시를 붙일 때 사용한다.
class WeekScopedExchangeCells {
  final Set<String> sourceKeys;
  final Set<String> destinationKeys;
  final Set<String> undatedKeys;

  const WeekScopedExchangeCells({
    required this.sourceKeys,
    required this.destinationKeys,
    required this.undatedKeys,
  });
}

/// 교체 이벤트의 참여 칸별 실제 날짜를 계산하는 순수 유틸 (S1.6).
///
/// `ExchangedCellOverlayDates`(1:1·보강 전용, 날짜 꼬리표용)의 매핑 로직을
/// 일반화한 것이다 — 같은 규칙을 여기 한 곳에 모아 두고, 날짜 꼬리표 표시
/// (`ExchangedCellOverlayDates`)와 X/○ 하이라이트 주별 스코프(S1.9)가 모두
/// 이 유틸에 의존하게 해서 두 곳의 판단 기준이 어긋나지 않게 한다.
class ExchangeCellDates {
  const ExchangeCellDates._();

  /// 이벤트 하나의 참여 칸별 실제 날짜를 계산한다.
  ///
  /// 규칙: 어떤 칸의 실제 날짜는 그 칸이 차지한 노드(요일·교시)의 실제 날짜와
  /// 같다 — 그 칸을 누가 쓰든(원래 주인이든 대신 들어온 사람이든) 상관없다.
  ///
  /// 안전장치: 결강일·교체일의 실제 요일(`DateTime.weekday`)이 해당 노드의
  /// 요일(`ExchangeNode.day`)과 다르면(계획서에서 요일과 안 맞는 날짜로 직접
  /// 고친 경우) `unsupported`를 반환한다 — 칸을 억지로 다른 열로 옮기지 않는다.
  static EventCellDates forItem(ExchangeHistoryItem item) {
    final path = item.originalPath;

    if (path is OneToOneExchangePath) {
      final s = path.sourceNode;
      final t = path.targetNode;
      if (!_weekdayMatches(item.absenceDate, s.day) ||
          !_weekdayMatches(item.substitutionDate, t.day)) {
        return EventCellDates.unsupported;
      }
      return EventCellDates(
        supported: true,
        cells: [
          DatedCell(
            teacher: s.teacherName,
            dayName: s.day,
            period: s.period,
            date: item.absenceDate,
            isVacateSide: true,
          ),
          DatedCell(
            teacher: t.teacherName,
            dayName: s.day,
            period: s.period,
            date: item.absenceDate,
            isVacateSide: false,
          ),
          DatedCell(
            teacher: t.teacherName,
            dayName: t.day,
            period: t.period,
            date: item.substitutionDate,
            isVacateSide: true,
          ),
          DatedCell(
            teacher: s.teacherName,
            dayName: t.day,
            period: t.period,
            date: item.substitutionDate,
            isVacateSide: false,
          ),
        ],
      );
    }

    if (path is SupplementExchangePath) {
      if (!_weekdayMatches(item.absenceDate, path.sourceDay) ||
          !_weekdayMatches(item.substitutionDate, path.targetDay)) {
        return EventCellDates.unsupported;
      }
      return EventCellDates(
        supported: true,
        cells: [
          DatedCell(
            teacher: path.sourceTeacher,
            dayName: path.sourceDay,
            period: path.sourcePeriod,
            date: item.absenceDate,
            isVacateSide: true,
          ),
          DatedCell(
            teacher: path.targetTeacher,
            dayName: path.targetDay,
            period: path.targetPeriod,
            date: item.substitutionDate,
            isVacateSide: false,
          ),
        ],
      );
    }

    // CircularExchangePath / DualExchangePath: 참여 노드가 3개 이상인데
    // 저장된 날짜는 2개(absenceDate/substitutionDate)뿐이라 노드별 정확한
    // 날짜를 알 수 없다. 억지로 추정하지 않는다(2026-09-29 사용자 확정).
    return EventCellDates.unsupported;
  }

  static bool _weekdayMatches(DateTime date, String dayName) {
    return date.weekday == DayUtils.getDayNumber(dayName);
  }

  /// 여러 이벤트의 참여 칸 날짜를 한 번에 계산한다 (이벤트 id → 결과).
  static Map<String, EventCellDates> forItems(List<ExchangeHistoryItem> items) {
    return {for (final item in items) item.id: forItem(item)};
  }

  /// 특정 주(週)에 대해 실제 날짜 기준으로 X/○ 셀 키를 스코프한다 (S1.9).
  ///
  /// [items]는 이미 되돌리지 않은(활성) 이벤트만 담겨 있어야 한다.
  /// 날짜 미확정 이벤트(순환·2중, 또는 요일 불일치)는 기존 방식대로
  /// 어느 주를 보든 항상 표시한다(회귀 없음) — 대신 `undatedKeys`에 표시해
  /// 호출부가 "?" 꼬리표를 붙일 수 있게 한다.
  static WeekScopedExchangeCells forWeek(
    List<ExchangeHistoryItem> items,
    DateTime viewedWeekMonday,
  ) {
    final sourceKeys = <String>{};
    final destinationKeys = <String>{};
    final undatedKeys = <String>{};

    final viewedMonday = WeekDateCalculator.getWeekMonday(viewedWeekMonday);
    bool inViewedWeek(DateTime date) =>
        WeekDateCalculator.getWeekMonday(date) == viewedMonday;

    for (final item in items) {
      final cd = forItem(item);

      if (!cd.supported) {
        // 순환·2중은 노드(슬롯) 단위로 세분화한다 — 계획서에서 확정한 노드가
        // 있으면(S5.6) 그 칸만 실제 주에 스코프해서 보여주고 "?"에서 뺀다.
        // 확정 안 된 슬롯(순환·2중 전체 미확정, 또는 1:1·보강의 요일 불일치)은
        // `resolveEventDates`가 항상 `estimated`를 반환하므로 기존과 똑같이
        // "어느 주를 보든 항상 표시 + undatedKeys" 경로를 그대로 탄다.
        final resolution = resolveEventDates(item);
        for (final slotted in _legacySlottedKeys(item.originalPath)) {
          final targetKeys = slotted.isVacateSide ? sourceKeys : destinationKeys;
          final resolved = resolution.forSlot(
            DayUtils.getDayNumber(slotted.dayName),
            slotted.period,
          );
          if (resolved != null && resolved.isConfirmed) {
            if (inViewedWeek(resolved.date)) targetKeys.add(slotted.key);
            // 확정됐지만 다른 주 → 이 주에는 보이지 않는다(undatedKeys에도 안 넣는다).
          } else {
            targetKeys.add(slotted.key);
            undatedKeys.add(slotted.key);
          }
        }
        continue;
      }

      for (final cell in cd.cells) {
        if (!inViewedWeek(cell.date)) continue;
        (cell.isVacateSide ? sourceKeys : destinationKeys).add(
          cell.coordinateKey,
        );
      }
    }

    return WeekScopedExchangeCells(
      sourceKeys: sourceKeys,
      destinationKeys: destinationKeys,
      undatedKeys: undatedKeys,
    );
  }

  /// [legacySourceKeys]∪[legacyDestinationKeys]와 정확히 같은 키 집합을 내되,
  /// 각 키가 어느 슬롯(요일·교시)에 해당하는지 함께 돌려준다 (S5.6).
  ///
  /// `legacySourceKeys`/`legacyDestinationKeys` 자체는 건드리지 않는다(OFF
  /// 모드가 직접 쓰는 함수들이라 중복을 감수하고 별도로 유지한다) —
  /// 두 함수가 같은 키 집합을 낸다는 것은 `exchange_cell_dates_test.dart`의
  /// 등식 테스트로 고정한다.
  static List<_SlottedKey> _legacySlottedKeys(ExchangePath path) {
    if (path is OneToOneExchangePath) {
      final s = path.sourceNode;
      final t = path.targetNode;
      return [
        _SlottedKey('${s.teacherName}_${s.day}_${s.period}', s.day, s.period, true),
        _SlottedKey('${t.teacherName}_${t.day}_${t.period}', t.day, t.period, true),
        _SlottedKey('${t.teacherName}_${s.day}_${s.period}', s.day, s.period, false),
        _SlottedKey('${s.teacherName}_${t.day}_${t.period}', t.day, t.period, false),
      ];
    } else if (path is CircularExchangePath) {
      final keys = <_SlottedKey>[];
      for (var i = 0; i < path.nodes.length - 1; i++) {
        final cur = path.nodes[i];
        keys.add(_SlottedKey('${cur.teacherName}_${cur.day}_${cur.period}', cur.day, cur.period, true));
      }
      for (var i = 0; i < path.nodes.length - 1; i++) {
        final cur = path.nodes[i];
        final next = path.nodes[i + 1];
        keys.add(
          _SlottedKey('${cur.teacherName}_${next.day}_${next.period}', next.day, next.period, false),
        );
      }
      return keys;
    } else if (path is DualExchangePath) {
      return [
        for (final n in [path.nodeA, path.nodeB, path.node1, path.node2])
          _SlottedKey('${n.teacherName}_${n.day}_${n.period}', n.day, n.period, true),
        _SlottedKey(
          '${path.node1.teacherName}_${path.node2.day}_${path.node2.period}',
          path.node2.day,
          path.node2.period,
          false,
        ),
        _SlottedKey(
          '${path.node2.teacherName}_${path.node1.day}_${path.node1.period}',
          path.node1.day,
          path.node1.period,
          false,
        ),
        _SlottedKey(
          '${path.nodeA.teacherName}_${path.nodeB.day}_${path.nodeB.period}',
          path.nodeB.day,
          path.nodeB.period,
          false,
        ),
        _SlottedKey(
          '${path.nodeB.teacherName}_${path.nodeA.day}_${path.nodeA.period}',
          path.nodeA.day,
          path.nodeA.period,
          false,
        ),
      ];
    } else if (path is SupplementExchangePath) {
      return [
        _SlottedKey(
          '${path.sourceTeacher}_${path.sourceDay}_${path.sourcePeriod}',
          path.sourceDay,
          path.sourcePeriod,
          true,
        ),
        _SlottedKey(
          '${path.targetTeacher}_${path.targetDay}_${path.targetPeriod}',
          path.targetDay,
          path.targetPeriod,
          false,
        ),
      ];
    }
    return const [];
  }

  // ==================== 기존(날짜 미인식) 키 생성 — 그대로 이동 ====================
  //
  // `exchange_executor.dart`의 `_getCellKeysFromPathStatic`/
  // `_getDestinationCellsFromPathStatic`을 동작 변경 없이 그대로 옮긴 것이다.
  // 날짜표시 OFF일 때, 그리고 순환·2중 교체의 날짜 미확정 폴백에 계속 쓰인다.

  /// 교체 경로에서 소스 셀(빠진 수업) 키 목록 추출 — 요일·교시 기준, 날짜 무관.
  static List<String> legacySourceKeys(ExchangePath path) {
    if (path is OneToOneExchangePath) {
      return [
        '${path.sourceNode.teacherName}_${path.sourceNode.day}_${path.sourceNode.period}',
        '${path.targetNode.teacherName}_${path.targetNode.day}_${path.targetNode.period}',
      ];
    } else if (path is CircularExchangePath) {
      // 순환 교체: 마지막 노드를 제외한 모든 노드가 소스 셀
      return path.nodes
          .take(path.nodes.length - 1)
          .map((node) => '${node.teacherName}_${node.day}_${node.period}')
          .toList();
    } else if (path is DualExchangePath) {
      return [
        '${path.nodeA.teacherName}_${path.nodeA.day}_${path.nodeA.period}',
        '${path.nodeB.teacherName}_${path.nodeB.day}_${path.nodeB.period}',
        '${path.node1.teacherName}_${path.node1.day}_${path.node1.period}',
        '${path.node2.teacherName}_${path.node2.day}_${path.node2.period}',
      ];
    } else if (path is SupplementExchangePath) {
      // 보강: 소스 셀만 교체된 소스 셀로 표시
      return ['${path.sourceTeacher}_${path.sourceDay}_${path.sourcePeriod}'];
    }
    return [];
  }

  /// 교체 경로에서 목적지 셀(맡은 수업) 키 목록 추출 — 요일·교시 기준, 날짜 무관.
  static List<String> legacyDestinationKeys(ExchangePath path) {
    final cellKeys = <String>[];

    if (path is OneToOneExchangePath) {
      cellKeys.addAll([
        '${path.targetNode.teacherName}_${path.sourceNode.day}_${path.sourceNode.period}',
        '${path.sourceNode.teacherName}_${path.targetNode.day}_${path.targetNode.period}',
      ]);
    } else if (path is CircularExchangePath) {
      final destinationKeys = <String>[];
      for (int i = 0; i < path.nodes.length - 1; i++) {
        final currentNode = path.nodes[i];
        final nextNode = path.nodes[i + 1];
        final destinationKey =
            '${currentNode.teacherName}_${nextNode.day}_${nextNode.period}';
        destinationKeys.add(destinationKey);
      }
      cellKeys.addAll(destinationKeys);
    } else if (path is DualExchangePath) {
      cellKeys.add(
        '${path.node1.teacherName}_${path.node2.day}_${path.node2.period}',
      );
      cellKeys.add(
        '${path.node2.teacherName}_${path.node1.day}_${path.node1.period}',
      );
      cellKeys.add(
        '${path.nodeA.teacherName}_${path.nodeB.day}_${path.nodeB.period}',
      );
      cellKeys.add(
        '${path.nodeB.teacherName}_${path.nodeA.day}_${path.nodeA.period}',
      );
    } else if (path is SupplementExchangePath) {
      cellKeys.add(
        '${path.targetTeacher}_${path.targetDay}_${path.targetPeriod}',
      );
    }

    return cellKeys;
  }
}

/// [ExchangeCellDates._legacySlottedKeys]가 돌려주는 키 한 개 (S5.6).
class _SlottedKey {
  final String key;
  final String dayName;
  final int period;
  final bool isVacateSide;

  const _SlottedKey(this.key, this.dayName, this.period, this.isVacateSide);
}

import 'package:sqflite_common/sqlite_api.dart';

import '../../models/exchange_event_record.dart';
import '../../models/lesson.dart';
import '../../models/timetable_repository_models.dart';
import '../../services/exchange_event_mirror.dart';
import '../../utils/lesson_projection.dart';
import 'timetable_date_format.dart';

/// `lessons` 좌표 한 칸(교사·날짜·교시) — [TimetableReplayRepository.replayInto]가
/// "건드린 범위"를 계산할 때 쓰는 내부 레코드 타입.
typedef _CellCoord = ({String teacher, String date, int period});

/// 투영 재생(S5.4a) 전용 저장소 — `exchange_events` 저널을 재생해 `lessons`를
/// 다시 계산하는 책임만 모았다.
///
/// 원래 `TimetableRepository`의 일부였던 `replayInto`/`getProjectionStatus`/
/// `getTouchedLessonsForWeek`와 그 템플릿 캐시를 그대로 옮겼다 — 동작은 완전히
/// 동일하다. `TimetableRepository`는 CRUD로 시간표/수업이 바뀔 때마다
/// [invalidateTemplateCache]를 호출해 이 캐시를 무효화한다.
class TimetableReplayRepository {
  final Database db;

  TimetableReplayRepository(this.db);

  /// `replayInto`가 매번 `lesson_snapshots`를 통째로 다시 읽지 않도록 하는
  /// 인스턴스 단위 캐시 (S5.4a 성능 수정, 2026-09-29).
  ///
  /// 스냅샷은 시간표 등록 시점에 한 번만 만들어지고 이후 바뀌지 않으므로
  /// (계획서 §10.4), 같은 `TimetableRepository` 인스턴스가 살아있는 동안은
  /// 한 번만 읽어도 된다. 앱에서는 Provider가 인스턴스를 하나만 유지하므로
  /// 앱 실행 중 한 번만 채워진다. 테스트마다 새 인스턴스를 만들므로
  /// (인스턴스 필드라 static이 아님) 테스트 간 오염도 없다.
  final Map<String, Map<String, Lesson>> _templateCacheByTimetable = {};

  /// [timetableId]의 템플릿 캐시를 무효화한다 — `TimetableRepository`가 시간표
  /// 등록/삭제/수업 교체 등으로 스냅샷이 바뀔 때마다 호출한다.
  void invalidateTemplateCache(String timetableId) {
    _templateCacheByTimetable.remove(timetableId);
  }

  /// 이 시간표의 `exchange_events`를 재생(replay)해 `lessons`를 다시 계산한다.
  ///
  /// `lessons`는 저널의 **파생 뷰**다 — 이 함수 밖에서 `lessons`의 교사·과목을
  /// 직접 고치는 코드 경로를 두지 않는다(S5 설계 검토 R1).
  ///
  /// **범위를 "건드린 좌표"로 좁힌다**(2026-09-29 성능 수정 — 처음 구현은 매번
  /// 학기 전체 `lessons`(수만 행)를 통째로 다시 읽어, 사용자가 "교체 실행 시
  /// 스낵바가 뜨는 동안 화면이 멈춘다"고 보고할 정도로 느렸다). 실제 교체가
  /// 건드리는 칸은 보통 학기 전체의 극히 일부일 뿐이므로:
  /// ① 이 시간표의 **모든** 이벤트(활성+되돌림 — 되돌린 이벤트가 예전에 건드린
  ///    칸도 다시 템플릿으로 되돌려야 한다)가 건드리는 좌표를 계산하고,
  ///    지금까지 누적된 `dirty_lesson_keys`(한 번이라도 건드린 적 있는 좌표 —
  ///    삭제된 이벤트의 흔적도 여기 남아 있다)와 합쳐 "이번에 계산할 범위"를
  ///    정한다.
  /// ② 그 범위에 해당하는 `lessons` 행만 조회해 템플릿으로 리셋한다.
  /// ③ 활성 이벤트를 `seq` 순으로 [project]에 재생시켜 최종 내용을 계산한다.
  /// ④ 리셋 상태와 달라진 행만 갱신하고(불필요한 쓰기 방지) 새 칸만 삽입,
  ///    `dirty_lesson_keys`(누적)와 `timetables.projected_seq`를 갱신한다.
  ///
  /// 어떤 화면도 아직 이 결과를 읽지 않는다(조회 전환은 S5.5) — 이 함수는
  /// `lessons`를 미리 최신 상태로 맞춰 두는 역할만 한다. 날짜·교시·활성 여부는
  /// 절대 건드리지 않는다 — 학기 기간 관리(`TimetableRepository.applyPeriodChange`)의
  /// 책임이다.
  Future<void> replayInto(String timetableId) async {
    final templateByKey = await _templateForTimetable(timetableId);

    await db.transaction((txn) async {
      final allEventRows = await txn.query(
        'exchange_events',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
        orderBy: 'seq ASC',
      );
      final allEvents = allEventRows.map(ExchangeEventRecord.fromMap).toList();

      // ① 지금 이벤트들이 건드리는 좌표 + 예전에 건드렸던 좌표(dirty_lesson_keys)
      final newTouched = <_CellCoord>{};
      for (final record in allEvents) {
        for (final cell in touchedCellsFor(toExchangeHistoryItem(record))) {
          newTouched.add((
            teacher: cell.teacher,
            date: formatTimetableDate(cell.date),
            period: cell.period,
          ));
        }
      }

      final dirtyRows = await txn.query(
        'dirty_lesson_keys',
        where: 'timetable_id = ?',
        whereArgs: [timetableId],
      );
      final workingSet = <_CellCoord>{
        for (final row in dirtyRows)
          (
            teacher: row['teacher'] as String,
            date: row['date'] as String,
            period: row['period'] as int,
          ),
        ...newTouched,
      };

      if (workingSet.isEmpty) {
        // 이 시간표에 교체가 한 번도 없었다(또는 전부 지워졌고 흔적도 없다) —
        // 재계산할 것이 없다.
        await txn.update(
          'timetables',
          {'projected_seq': -1},
          where: 'id = ?',
          whereArgs: [timetableId],
        );
        return;
      }

      // dirty_lesson_keys는 계속 쌓기만 한다(grow-only) — 나중에 이 좌표를
      // 건드리던 교체가 지워져도, 다음 재생 때 이 표 덕분에 여전히 리셋 대상에
      // 포함된다.
      final dirtyBatch = txn.batch();
      for (final coord in workingSet) {
        dirtyBatch.insert('dirty_lesson_keys', {
          'timetable_id': timetableId,
          'teacher': coord.teacher,
          'date': coord.date,
          'period': coord.period,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await dirtyBatch.commit(noResult: true);

      // ② 건드릴 교사·날짜로만 좁혀 조회 — 학기 전체를 훑지 않는다.
      final touchedTeachers = workingSet.map((c) => c.teacher).toSet().toList();
      final touchedDates = workingSet.map((c) => c.date).toSet().toList();
      final teacherPlaceholders = List.filled(
        touchedTeachers.length,
        '?',
      ).join(',');
      final datePlaceholders = List.filled(touchedDates.length, '?').join(',');
      final currentRows = await txn.rawQuery(
        'SELECT * FROM lessons WHERE timetable_id = ? '
        'AND teacher IN ($teacherPlaceholders) AND date IN ($datePlaceholders)',
        [timetableId, ...touchedTeachers, ...touchedDates],
      );
      final currentByCoord = <_CellCoord, Lesson>{
        for (final row in currentRows.map(Lesson.fromMap))
          (
            teacher: row.teacher,
            date: formatTimetableDate(row.date),
            period: row.period,
          ): row,
      };

      // 리셋 — id·date·period·teacher·isActive는 유지(있으면), 내용만 원복.
      // 해당 좌표에 실제 lessons 행이 아직 없으면(이론상 드묾 — 등록 시 모든
      // 요일·교시 조합이 이미 채워진다) 결정적 id로 새로 만든다.
      final resetLessons =
          workingSet.map((coord) {
            final existing = currentByCoord[coord];
            final date = existing?.date ?? DateTime.parse(coord.date);
            final template =
                templateByKey['${coord.teacher}_${date.weekday}_${coord.period}'];
            return Lesson(
              id:
                  existing?.id ??
                  'proj_${timetableId}_${coord.teacher}_'
                      '${coord.date.replaceAll('-', '')}_${coord.period}',
              timetableId: timetableId,
              date: date,
              period: coord.period,
              teacher: coord.teacher,
              subject: template?.subject,
              className: template?.className,
              isExchangeable: template?.isExchangeable ?? true,
              exchangeReason: template?.exchangeReason,
              isActive: existing?.isActive ?? true,
            );
          }).toList();

      // ③ 활성 이벤트를 seq 순으로 재생
      final activeEvents =
          allEvents
              .where((record) => !record.isReverted)
              .map(toExchangeHistoryItem)
              .toList();

      final projected = project(
        snapshot: resetLessons,
        activeEvents: activeEvents,
        timetableId: timetableId,
      );

      // ④ **실제 DB에 지금 저장된 내용** 대비 달라진 행만 갱신, 새 칸만 삽입.
      //
      // 반드시 `currentByCoord`(DB에서 방금 읽어온 실제 값)와 비교해야 한다 —
      // `resetLessons`는 이번 호출에서만 쓰는 메모리상의 중간 값이라 DB에
      // 한 번도 쓰인 적이 없다. 만약 이 값과 비교하면(과거 버전의 버그),
      // 활성 이벤트가 하나도 이 칸을 건드리지 않는 한 `projected`가
      // `resetLessons`와 항상 같아 보여 "변경 없음"으로 오판하고, 실제로는
      // DB에 남아 있는 옛 스왑 내용을 절대 지우지 못한다(교체를 완전히
      // 삭제해도 그 흔적이 영원히 남는 버그로 재현됨).
      final batch = txn.batch();
      for (final lesson in projected) {
        final coord = (
          teacher: lesson.teacher,
          date: formatTimetableDate(lesson.date),
          period: lesson.period,
        );
        final before = currentByCoord[coord];
        if (before == null) {
          batch.insert('lessons', lesson.toMap());
        } else if (before.subject != lesson.subject ||
            before.className != lesson.className ||
            before.isExchangeable != lesson.isExchangeable ||
            before.exchangeReason != lesson.exchangeReason) {
          batch.update(
            'lessons',
            lesson.toMap(),
            where: 'id = ?',
            whereArgs: [lesson.id],
          );
        }
      }

      final activeSeqs = allEventRows
          .where((row) => (row['is_reverted'] as int) == 0)
          .map((row) => row['seq'] as int);
      final maxSeq =
          activeSeqs.isEmpty ? -1 : activeSeqs.reduce((a, b) => a > b ? a : b);
      batch.update(
        'timetables',
        {'projected_seq': maxSeq},
        where: 'id = ?',
        whereArgs: [timetableId],
      );

      await batch.commit(noResult: true);
    });
  }

  /// [ProjectionStatus] 조회 (S5.5.0 — 조회 전환 준비, 집계만 사용).
  ///
  /// `getLessonStats`와 같은 방식으로 `COUNT(*)`/`MAX(seq)` 집계만 실행하고
  /// 행 전체를 읽지 않는다. 이 값 자체는 아직 어떤 화면에도 연결되지 않는다.
  Future<ProjectionStatus> getProjectionStatus(String timetableId) async {
    final timetableRows = await db.query(
      'timetables',
      columns: ['projected_seq'],
      where: 'id = ?',
      whereArgs: [timetableId],
      limit: 1,
    );
    final hasTimetableRow = timetableRows.isNotEmpty;
    final projectedSeq =
        hasTimetableRow
            ? (timetableRows.first['projected_seq'] as int? ?? -1)
            : -1;

    final maxSeqRows = await db.rawQuery(
      'SELECT MAX(seq) AS m FROM exchange_events '
      'WHERE timetable_id = ? AND is_reverted = 0',
      [timetableId],
    );
    final maxActiveSeq = (maxSeqRows.first['m'] as int?) ?? -1;

    final lessonCountRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM lessons WHERE timetable_id = ?',
      [timetableId],
    );
    final lessonRowCount = (lessonCountRows.first['c'] as int?) ?? 0;

    return ProjectionStatus(
      projectedSeq: projectedSeq,
      maxActiveSeq: maxActiveSeq,
      lessonRowCount: lessonRowCount,
      hasTimetableRow: hasTimetableRow,
    );
  }

  /// [weekMonday]가 속한 주(월~금)에서, 지금까지 한 번이라도 교체가 건드린
  /// 적 있는 칸(`dirty_lesson_keys`에 기록된 좌표)만 `lessons`와 조인해
  /// 조회한다 (S5.5.0 — 조회 전환 준비).
  ///
  /// "건드린 적 있는 칸만" 좁히는 이유는 S5.5 설계의 오버레이 전략 때문이다 —
  /// 화면은 기존 `TimeSlot` 위에 이 칸들만 덮어쓸 예정이라, 건드리지 않은
  /// 칸까지 가져올 필요가 없다. 아직 어떤 화면도 이 값을 읽지 않는다.
  /// 기본은 활성(`is_active = 1`) 수업만 반환한다 — 학기 기간 축소로 보관된
  /// 칸은 제외한다.
  Future<List<Lesson>> getTouchedLessonsForWeek(
    String timetableId,
    DateTime weekMonday,
  ) async {
    final friday = weekMonday.add(const Duration(days: 4));
    final rows = await db.rawQuery(
      'SELECT lessons.* FROM lessons '
      'INNER JOIN dirty_lesson_keys '
      'ON lessons.timetable_id = dirty_lesson_keys.timetable_id '
      'AND lessons.teacher = dirty_lesson_keys.teacher '
      'AND lessons.date = dirty_lesson_keys.date '
      'AND lessons.period = dirty_lesson_keys.period '
      'WHERE lessons.timetable_id = ? '
      'AND lessons.date >= ? AND lessons.date <= ? '
      'AND lessons.is_active = 1',
      [
        timetableId,
        formatTimetableDate(weekMonday),
        formatTimetableDate(friday),
      ],
    );
    return rows.map(Lesson.fromMap).toList();
  }

  /// (교사, 요일, 교시) → 대표 스냅샷 한 건. 인스턴스 캐시에 없으면 한 번만
  /// `lesson_snapshots`를 읽어 채운다 — 자세한 이유는 [_templateCacheByTimetable] 참고.
  Future<Map<String, Lesson>> _templateForTimetable(String timetableId) async {
    final cached = _templateCacheByTimetable[timetableId];
    if (cached != null) return cached;

    final snapshotRows = await db.query(
      'lesson_snapshots',
      where: 'timetable_id = ?',
      whereArgs: [timetableId],
    );
    final templateByKey = <String, Lesson>{};
    for (final snapshot in snapshotRows.map(Lesson.fromMap)) {
      final key =
          '${snapshot.teacher}_${snapshot.date.weekday}_${snapshot.period}';
      templateByKey.putIfAbsent(key, () => snapshot);
    }
    // 스냅샷이 아직 없으면(예: 등록 직후 타이밍) 캐시하지 않는다 — 다음 호출이
    // 다시 시도해 실제 데이터가 생긴 뒤에는 정상적으로 캐시되도록 한다.
    if (templateByKey.isNotEmpty) {
      _templateCacheByTimetable[timetableId] = templateByKey;
    }
    return templateByKey;
  }
}

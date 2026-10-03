/// `TimetableRepository`가 쓰는 결과·예외 값 객체들.
///
/// 원래 `lib/repositories/timetable_repository.dart`에 함께 있던 네 클래스를
/// 분리했다 — 저장소 클래스 자체는 로직, 이 파일은 순수 데이터/예외 타입이다.
library;

/// 이 시간표의 `lessons`가 `exchange_events` 저널을 얼마나 최신으로
/// 반영하고 있는지 요약 (S5.5.0 — 조회 전환 준비).
///
/// `replayInto`가 매번 정확히 호출된다면 [isStale]은 항상 false여야 한다.
/// 다만 로드 경로(`ExchangeHistoryService.loadFromLocalStorage`가 SQLite를
/// 바로 쓸 때)는 `mirrorSink`를 거치지 않으므로 재생이 밀릴 수 있다 — S5.5
/// 설계 검토에서 발견한 실제 간극이다. 화면이 SQLite를 읽기 전에 반드시
/// 이 값을 확인해야 한다.
class ProjectionStatus {
  /// `timetables.projected_seq` — 마지막으로 반영이 끝난 시점의 최대 seq(-1=없음)
  final int projectedSeq;

  /// 현재 활성(`is_reverted=0`) 이벤트 중 최대 seq(-1=활성 이벤트 없음)
  final int maxActiveSeq;

  /// 이 시간표의 `lessons` 총 행 수
  final int lessonRowCount;

  /// `timetables`에 이 id로 등록된 행이 있는지 (S3 이전 등록 시간표는 없을 수 있음)
  final bool hasTimetableRow;

  const ProjectionStatus({
    required this.projectedSeq,
    required this.maxActiveSeq,
    required this.lessonRowCount,
    required this.hasTimetableRow,
  });

  /// 재생이 밀려 있는지 — 화면이 SQLite를 읽기 전 반드시 확인해야 하는 값.
  bool get isStale => projectedSeq != maxActiveSeq;
}

/// 학기 기간 반영이 활성 교체 이벤트와 충돌할 때 던진다 (S5.4a — D5/OQ-7).
///
/// 기간을 줄이면 그 활성 교체의 결강일·교체일 중 하나가 새 범위 밖으로
/// 나가버리는 경우다 — 이 경우만 **유일하게 차단**한다(다른 모든 안내는
/// 비차단이지만, 여기서는 사용자 데이터가 조용히 유실될 수 있어 예외다).
class PeriodChangeConflictException implements Exception {
  final List<String> conflictingDescriptions;

  const PeriodChangeConflictException(this.conflictingDescriptions);

  @override
  String toString() {
    return '학기 기간을 줄이면 활성 교체 ${conflictingDescriptions.length}건과 충돌합니다: '
        '${conflictingDescriptions.join(', ')}';
  }
}

/// 학기 기간 반영(`TimetableRepository.applyPeriodChange`) 결과 요약 (S3a).
///
/// "준비 > 기타 설정"의 반영 다이얼로그·완료 메시지에서 추가·보관 건수를
/// 보여주기 위한 값이다.
class PeriodChangeResult {
  /// 새로 생성된 날짜 수 (기간 확장)
  final int addedCount;

  /// 기간 밖으로 나가 비활성 처리된 날짜 수 (기간 축소, 삭제 아님 — 보관)
  final int deactivatedCount;

  /// 기간 안으로 다시 들어와 재활성화된 날짜 수 (축소 후 재확장)
  final int reactivatedCount;

  const PeriodChangeResult({
    required this.addedCount,
    required this.deactivatedCount,
    required this.reactivatedCount,
  });
}

/// 시간표 한 건의 SQLite 저장 현황 요약 (S4.0 — 읽기 전용 확인 패널).
///
/// S2·S3·S3a가 실제로 무엇을 저장했는지 사람이 직접 확인할 수 있게 하기 위한
/// 값이다. 집계 쿼리(`COUNT`/`MIN`/`MAX`)로만 구하며 행 전체를 메모리에
/// 올리지 않는다.
class LessonStats {
  final int totalCount;
  final int activeCount;
  final int inactiveCount;
  final int snapshotCount;
  final DateTime? earliestDate;
  final DateTime? latestDate;

  const LessonStats({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
    required this.snapshotCount,
    required this.earliestDate,
    required this.latestDate,
  });
}

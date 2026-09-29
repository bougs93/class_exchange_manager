import '../models/circular_exchange_path.dart';
import '../models/dual_exchange_path.dart';
import '../models/exchange_history_item.dart';
import 'day_utils.dart';
import 'exchange_cell_dates.dart';
import 'lesson_projection.dart' show touchedCellsFor;

/// 교체된 칸(`교사_요일_교시`)이 실제로 어느 날짜에 일어난 교체인지 매핑한다 (S1.5)
///
/// `isCellExchangedSource`/`isCellExchangedDestination`는 히스토리 전체를
/// `교사_요일_교시` 키로만 판정하므로 날짜 정보가 없다. 날짜표시 OFF 모드의
/// 날짜 꼬리표는 "현재 보고 있는 주의 날짜"가 아니라 실제 [ExchangeHistoryItem]의
/// `absenceDate`/`substitutionDate`를 그대로 보여줘야 계획서 화면과 값이 일치한다.
///
/// 정확한 매핑 규칙은 [ExchangeCellDates.forItem]에 있다 (S1.6에서 일반화·이동).
/// 1:1·보강은 이 정확한 값을 그대로 쓴다.
///
/// 순환·2중 교체(참여 노드가 3개 이상인데 저장된 날짜는 2개뿐이라 정확한 날짜를
/// 알 수 없는 경우)는 "결강일이 속한 주"라는 가정으로 날짜를 **추정**해 채운다
/// (S5 설계 검토 OQ-1 채택안, 2026-09-29 — 아무 표시도 없던 것보다 낫다는 사용자
/// 요청). [touchedCellsFor](`lesson_projection.dart`)가 이 추정 규칙을 이미
/// 갖고 있으므로 그대로 재사용한다 — 규칙이 한 곳에서만 정의되게 유지한다.
///
/// **1:1·보강의 요일 불일치 폴백은 추정하지 않는다** — 이 경우는 사용자가
/// 계획서에서 실제로 요일과 다른 날짜를 지정한 상황이라(S1.6), 노드의 요일로
/// 억지로 되짚어 날짜를 추정하면 사용자가 지정한 값과 다른 **틀린** 날짜를
/// 보여줄 수 있다. 그래서 이 경우만 여전히 생략한다(순환·2중과 달리 "노드
/// 자체에 진짜 날짜가 없어서" 추정하는 게 아니라 "사용자가 이상한 값을
/// 넣어서" 못 믿는 경우이기 때문 — 성격이 다르다).
///
/// **주의**: 이 맵은 OFF 모드 꼬리표 전용이다. X/○ 하이라이트 범위
/// ([ExchangeCellDates.forWeek])나 다른 주 교체 반영([ResolvedWeek.dateAware])은
/// 여전히 [ExchangeCellDates.forItem]의 `supported` 여부만 보고 판단하며 이
/// 추정값을 쓰지 않는다 — ON 모드에서 순환·2중 교체가 여전히 "?"로 표시되는 것도
/// 그 때문이다(추정값일 뿐 확정 값이 아님을 계속 구분한다).
class ExchangedCellOverlayDates {
  const ExchangedCellOverlayDates._();

  static Map<String, DateTime> build(List<ExchangeHistoryItem> items) {
    final map = <String, DateTime>{};

    for (final item in items) {
      final cellDates = ExchangeCellDates.forItem(item);
      if (cellDates.supported) {
        for (final cell in cellDates.cells) {
          map[cell.coordinateKey] = cell.date;
        }
        continue;
      }

      final path = item.originalPath;
      if (path is! CircularExchangePath && path is! DualExchangePath) {
        continue; // 1:1·보강의 요일 불일치 — 추정하지 않고 생략
      }

      for (final cell in touchedCellsFor(item)) {
        final dayName = DayUtils.getDayName(cell.date.weekday);
        map['${cell.teacher}_${dayName}_${cell.period}'] = cell.date;
      }
    }

    return map;
  }
}

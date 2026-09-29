import '../models/exchange_history_item.dart';
import 'exchange_cell_dates.dart';

/// 교체된 칸(`교사_요일_교시`)이 실제로 어느 날짜에 일어난 교체인지 매핑한다 (S1.5)
///
/// `isCellExchangedSource`/`isCellExchangedDestination`는 히스토리 전체를
/// `교사_요일_교시` 키로만 판정하므로 날짜 정보가 없다. 날짜표시 OFF 모드의
/// 날짜 꼬리표는 "현재 보고 있는 주의 날짜"가 아니라 실제 [ExchangeHistoryItem]의
/// `absenceDate`/`substitutionDate`를 그대로 보여줘야 계획서 화면과 값이 일치한다.
///
/// 실제 매핑 규칙은 [ExchangeCellDates.forItem]에 있다 (S1.6에서 일반화·이동).
/// 1:1·보강만 지원하고, 순환·2중 교체나 요일·날짜가 어긋나는 경우는 매핑하지
/// 않는다 — 틀린 날짜를 보여주는 것보다 생략하는 것이 안전하다.
class ExchangedCellOverlayDates {
  const ExchangedCellOverlayDates._();

  static Map<String, DateTime> build(List<ExchangeHistoryItem> items) {
    final map = <String, DateTime>{};

    for (final item in items) {
      final cellDates = ExchangeCellDates.forItem(item);
      if (!cellDates.supported) continue;
      for (final cell in cellDates.cells) {
        map[cell.coordinateKey] = cell.date;
      }
    }

    return map;
  }
}

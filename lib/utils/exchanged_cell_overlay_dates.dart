import '../models/exchange_history_item.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/supplement_exchange_path.dart';

/// 교체된 칸(`교사_요일_교시`)이 실제로 어느 날짜에 일어난 교체인지 매핑한다 (S1.5)
///
/// `isCellExchangedSource`/`isCellExchangedDestination`는 히스토리 전체를
/// `교사_요일_교시` 키로만 판정하므로 날짜 정보가 없다. 날짜표시 OFF 모드의
/// 날짜 꼬리표는 "현재 보고 있는 주의 날짜"가 아니라 실제 [ExchangeHistoryItem]의
/// `absenceDate`/`substitutionDate`를 그대로 보여줘야 계획서 화면과 값이 일치한다.
///
/// 1:1 교체는 두 날짜(결강일·교체일)가 각각 어느 셀에 해당하는지 노드의 요일로
/// 구분해 4개 키를 모두 채운다. 보강(단방향)은 소스=결강일, 타겟=교체일로 채운다.
/// 순환·2중 교체는 참여 노드 수가 저장된 날짜(2개)보다 많아 노드별 정확한 날짜를
/// 알 수 없으므로 매핑하지 않는다 — 이 경우 날짜 꼬리표를 생략하는 것이
/// 틀린 날짜를 보여주는 것보다 안전하다 (S5에서 노드별 날짜 저장으로 재설계 필요).
class ExchangedCellOverlayDates {
  const ExchangedCellOverlayDates._();

  static Map<String, DateTime> build(List<ExchangeHistoryItem> items) {
    final map = <String, DateTime>{};

    for (final item in items) {
      final path = item.originalPath;

      if (path is OneToOneExchangePath) {
        final s = path.sourceNode;
        final t = path.targetNode;
        // 결강일(s의 요일)에 속하는 두 칸 — s 본인 자리(빠진 수업), t가 대신 들어간 자리(맡은 수업)
        map['${s.teacherName}_${s.day}_${s.period}'] = item.absenceDate;
        map['${t.teacherName}_${s.day}_${s.period}'] = item.absenceDate;
        // 교체일(t의 요일)에 속하는 두 칸
        map['${t.teacherName}_${t.day}_${t.period}'] = item.substitutionDate;
        map['${s.teacherName}_${t.day}_${t.period}'] = item.substitutionDate;
      } else if (path is SupplementExchangePath) {
        map['${path.sourceTeacher}_${path.sourceDay}_${path.sourcePeriod}'] =
            item.absenceDate;
        map['${path.targetTeacher}_${path.targetDay}_${path.targetPeriod}'] =
            item.substitutionDate;
      }
      // CircularExchangePath / DualExchangePath는 의도적으로 매핑하지 않는다 (위 설명 참고).
    }

    return map;
  }
}

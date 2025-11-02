import '../models/exchange_history_item.dart';
import '../providers/substitution_plan_provider.dart';
import '../services/exchange_history_service.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';

/// 개인 시간표용 교체 필터링 유틸리티
/// 
/// 교사 안내 페이지의 필터링 방식을 참조하여
/// 특정 교사명과 날짜에 해당하는 교체만 필터링합니다.
class PersonalExchangeFilter {
  /// 개인 시간표용 교체 리스트 필터링
  /// 
  /// 매개변수:
  /// - `String` teacherName: 필터링할 교사명
  /// - `List<DateTime>` weekDates: 현재 주의 날짜 리스트 [월, 화, 수, 목, 금]
  /// - `SubstitutionPlanProvider` substitutionPlanProvider: 결보강 계획서 Provider (날짜 정보 조회용)
  /// - `ExchangeHistoryService` historyService: 교체 히스토리 서비스
  /// 
  /// 반환값: 필터링된 교체 리스트
  static List<ExchangeHistoryItem> filterExchangesForPersonalSchedule({
    required String teacherName,
    required List<DateTime> weekDates,
    required SubstitutionPlanState substitutionPlanState,
    required ExchangeHistoryService historyService,
  }) {
    // 전체 교체 리스트 가져오기
    final allExchanges = historyService.getExchangeList();
    
    if (allExchanges.isEmpty) {
      AppLogger.exchangeDebug('[PersonalExchangeFilter] 교체 리스트가 비어있습니다');
      return [];
    }

    AppLogger.exchangeDebug('[PersonalExchangeFilter] 전체 교체 리스트: ${allExchanges.length}개');

    // 필터링된 교체 리스트
    final filteredExchanges = <ExchangeHistoryItem>[];

    for (final exchange in allExchanges) {
      // 1. 교사명 필터링
      if (!_matchesTeacher(exchange, teacherName)) {
        continue;
      }

      // 2. 날짜 필터링
      if (!_matchesWeekDates(exchange, weekDates, substitutionPlanState)) {
        continue;
      }

      filteredExchanges.add(exchange);
    }

    AppLogger.exchangeDebug('[PersonalExchangeFilter] 필터링 완료: ${filteredExchanges.length}개');
    return filteredExchanges;
  }

  /// 교체가 해당 교사명과 매칭되는지 확인
  /// 
  /// 교사 안내 페이지 방식: 원래 교사, 교체 교사, 보강 교사 모두 확인
  static bool _matchesTeacher(ExchangeHistoryItem exchange, String teacherName) {
    final path = exchange.originalPath;
    final nodes = path.nodes;

    // 모든 노드에서 교사명 확인
    for (final node in nodes) {
      if (node.teacherName == teacherName) {
        return true;
      }
    }

    return false;
  }

  /// 교체가 현재 주의 날짜와 매칭되는지 확인
  /// 
  /// 결보강 계획서에서 날짜가 지정된 경우만 필터링
  /// 날짜가 없으면 전체 적용 (모든 날짜에 해당 교체 표시)
  static bool _matchesWeekDates(
    ExchangeHistoryItem exchange,
    List<DateTime> weekDates,
    SubstitutionPlanState substitutionPlanState,
  ) {
    final exchangeId = exchange.id;

    // 결보강 계획서에서 날짜 정보 조회
    final absenceDateStr = substitutionPlanState.savedDates['${exchangeId}_absenceDate'] ?? '';
    final substitutionDateStr = substitutionPlanState.savedDates['${exchangeId}_substitutionDate'] ?? '';

    // 날짜가 하나도 지정되지 않은 경우: 전체 적용 (true 반환)
    if (absenceDateStr.isEmpty && substitutionDateStr.isEmpty) {
      AppLogger.exchangeDebug('[PersonalExchangeFilter] 교체 $exchangeId: 날짜 미지정 → 전체 적용');
      return true;
    }

    // 주의 날짜를 "년.월.일" 형식으로 변환하여 비교
    final weekDateStrings = weekDates.map((date) {
      return DateFormatUtils.toYearMonthDay(date);
    }).toSet();

    // 결강일이 현재 주에 포함되는지 확인
    if (absenceDateStr.isNotEmpty) {
      if (weekDateStrings.contains(absenceDateStr)) {
        AppLogger.exchangeDebug('[PersonalExchangeFilter] 교체 $exchangeId: 결강일($absenceDateStr) 매칭');
        return true;
      }
    }

    // 교체일이 현재 주에 포함되는지 확인
    if (substitutionDateStr.isNotEmpty) {
      if (weekDateStrings.contains(substitutionDateStr)) {
        AppLogger.exchangeDebug('[PersonalExchangeFilter] 교체 $exchangeId: 교체일($substitutionDateStr) 매칭');
        return true;
      }
    }

    AppLogger.exchangeDebug('[PersonalExchangeFilter] 교체 $exchangeId: 날짜 불일치 → 제외');
    return false;
  }
}


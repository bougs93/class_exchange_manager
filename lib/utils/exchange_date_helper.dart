import '../models/exchange_node.dart';
import '../providers/personal_schedule_provider.dart';
import '../providers/substitution_plan_provider.dart';

/// 교체 날짜 헬퍼
///
/// 교체 정보에서 날짜를 추출하고 포맷팅하는 유틸리티 클래스입니다.
/// personal_exchange_info_extractor와 personal_schedule_debug_helper에서 공통으로 사용됩니다.
class ExchangeDateHelper {
  /// 날짜 포맷 함수: YYYY.MM.DD 형식 유지
  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    return dateStr;
  }

  /// 요일을 날짜로 변환하는 함수 (YYYY.MM.DD 형식)
  ///
  /// 디버그용 fallback으로 사용됩니다.
  static String dayToDate(String day, PersonalScheduleState scheduleState) {
    final weekDates = scheduleState.weekDates;

    // 요일 인덱스 매핑
    final dayIndex = {
      '월': 0, '화': 1, '수': 2, '목': 3, '금': 4,
    };

    final index = dayIndex[day];
    if (index != null && index < weekDates.length) {
      final date = weekDates[index];
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }
    return '';
  }

  /// 저장된 날짜 가져오는 헬퍼 함수 (교사명, 요일, 교시, 과목으로 찾기)
  ///
  /// 매개변수:
  /// - `useFallback`: true인 경우 날짜가 없으면 dayToDate로 fallback (디버그용)
  ///
  /// 날짜가 저장되지 않은 경우:
  /// - useFallback=false: 빈 문자열 반환 (기본값, 운영용)
  /// - useFallback=true: dayToDate로 fallback (디버그용)
  static String getSavedDateByNode({
    required String teacherName,
    required String day,
    required int period,
    required String subject,
    required String dateType,
    required SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState? scheduleState,
    bool useFallback = false,
  }) {
    final key = '${teacherName}_$day${period}_${subject}_$dateType';
    final rawDate = substitutionPlanState.savedDates[key];
    final savedDate = formatDate(rawDate);

    if (savedDate.isNotEmpty) {
      return savedDate;
    }

    // fallback 옵션이 활성화되고 scheduleState가 제공된 경우
    if (useFallback && scheduleState != null) {
      return dayToDate(day, scheduleState);
    }

    return '';
  }

  /// 노드 날짜 가져오기
  ///
  /// 매개변수:
  /// - `useFallback`: true인 경우 날짜가 없으면 dayToDate로 fallback (디버그용)
  ///
  /// 날짜가 저장되지 않은 경우:
  /// - useFallback=false: 빈 문자열 반환 (기본값, 운영용)
  /// - useFallback=true: dayToDate로 fallback (디버그용)
  static String getNodeDate({
    required ExchangeNode node,
    required String dateType,
    required SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState? scheduleState,
    bool useFallback = false,
  }) {
    // savedDates에서 날짜 찾기
    for (final key in substitutionPlanState.savedDates.keys) {
      if (key.startsWith(
            '${node.teacherName}_${node.day}${node.period}_${node.subjectName}_',
          ) &&
          key.endsWith(dateType)) {
        return formatDate(substitutionPlanState.savedDates[key]);
      }
    }

    // node.date에서 날짜 찾기
    final nodeDate = formatDate(node.date);
    if (nodeDate.isNotEmpty) {
      return nodeDate;
    }

    // fallback 옵션이 활성화되고 scheduleState가 제공된 경우
    if (useFallback && scheduleState != null) {
      return dayToDate(node.day, scheduleState);
    }

    return '';
  }

  /// 연쇄교체 날짜 가져오기
  ///
  /// 매개변수:
  /// - `useFallback`: true인 경우 날짜가 없으면 dayToDate로 fallback (디버그용)
  ///
  /// 날짜가 저장되지 않은 경우:
  /// - useFallback=false: 빈 문자열 반환 (기본값, 운영용)
  /// - useFallback=true: dayToDate로 fallback (디버그용)
  static String getChainDate({
    required String teacherName,
    required String day,
    required int period,
    required String dateType,
    required String stepInfo,
    required SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState? scheduleState,
    bool useFallback = false,
  }) {
    for (final key in substitutionPlanState.savedDates.keys) {
      if (key.contains(teacherName) &&
          key.contains('$day$period') &&
          key.contains(stepInfo) &&
          key.endsWith(dateType)) {
        return formatDate(substitutionPlanState.savedDates[key]);
      }
    }

    // fallback 옵션이 활성화되고 scheduleState가 제공된 경우
    if (useFallback && scheduleState != null) {
      return dayToDate(day, scheduleState);
    }

    return '';
  }

  /// 보강 날짜 가져오기
  ///
  /// 매개변수:
  /// - `useFallback`: true인 경우 날짜가 없으면 dayToDate로 fallback (디버그용)
  ///
  /// 날짜가 저장되지 않은 경우:
  /// - useFallback=false: 빈 문자열 반환 (기본값, 운영용)
  /// - useFallback=true: dayToDate로 fallback (디버그용)
  static String getSupplementDate({
    required ExchangeNode sourceNode,
    required SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState? scheduleState,
    bool useFallback = false,
  }) {
    for (final key in substitutionPlanState.savedDates.keys) {
      if (key.startsWith(
            '${sourceNode.teacherName}_${sourceNode.day}${sourceNode.period}_${sourceNode.subjectName}_보강_',
          ) &&
          key.endsWith('absenceDate')) {
        return formatDate(substitutionPlanState.savedDates[key]);
      }
    }

    // fallback 옵션이 활성화되고 scheduleState가 제공된 경우
    if (useFallback && scheduleState != null) {
      return dayToDate(sourceNode.day, scheduleState);
    }

    return '';
  }

  /// 저장된 보강 과목 가져오기
  static String getSupplementSubject({
    required ExchangeNode sourceNode,
    required ExchangeNode targetNode,
    required SubstitutionPlanState substitutionPlanState,
  }) {
    final searchKey =
        '${sourceNode.teacherName}_${sourceNode.day}${sourceNode.period}_${sourceNode.subjectName}_보강';

    final savedSubject = substitutionPlanState.savedSupplementSubjects[searchKey];
    if (savedSubject != null && savedSubject.isNotEmpty) {
      return savedSubject;
    }

    return targetNode.subjectName.isNotEmpty
        ? targetNode.subjectName
        : sourceNode.subjectName;
  }
}

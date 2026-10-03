import '../../models/notice_message.dart';
import '../../providers/substitution_plan_viewmodel.dart';
import '../notice_message_helpers.dart';

/// 교체 유형/카테고리 판별 공통 로직
///
/// 학급 안내(ClassNoticeBuilder)와 교사 안내(TeacherNoticeBuilder) 양쪽에서
/// 공통으로 사용하는 교체 유형 구분 로직을 모아둔다.
class NoticeExchangeCategorizer {
  /// 교체 유형 구분 헬퍼 메서드 (그룹ID 기반)
  static ExchangeCategory getExchangeCategory(SubstitutionPlanData data) {
    // 보강 확인
    if (isSupplement(data)) {
      return ExchangeCategory.supplement;
    }

    // 순환교체 4단계 이상 확인
    if (GroupIdParser.isCircular4Plus(data.groupId)) {
      return ExchangeCategory.circularFourPlus;
    }

    // 기본 교체 유형 (1:1교체, 순환교체 3단계, 2중교체)
    return ExchangeCategory.basic;
  }

  /// 보강 여부 확인 (공통 로직)
  static bool isSupplement(SubstitutionPlanData data) {
    return data.supplementTeacher.isNotEmpty ||
        GroupIdParser.isSupplement(data.groupId);
  }

  /// 교체 유형 결정 헬퍼 메서드 (그룹ID 기반)
  static ExchangeTypeCombination determineExchangeTypeCombination(
    List<SubstitutionPlanData> dataList,
  ) {
    final List<ExchangeType> types = [];

    for (final data in dataList) {
      final type = getExchangeTypeForData(data);

      if (!types.contains(type)) {
        types.add(type);
      }
    }

    return ExchangeTypeCombination(types);
  }

  /// 개별 데이터의 교체 유형 결정
  static ExchangeType getExchangeTypeForData(SubstitutionPlanData data) {
    if (isSupplement(data)) {
      return ExchangeType.supplement;
    }

    final step = GroupIdParser.extractCircularStep(data.groupId);
    if (step != null && step >= 4) {
      return ExchangeType.circular;
    }

    return ExchangeType.substitution;
  }

  /// 리스트의 교체 유형 결정 (우선순위: 보강 > 순환 > 수업교체)
  static ExchangeType determineExchangeType(
    List<SubstitutionPlanData> dataList,
  ) {
    // 보강가 하나라도 있으면 보강으로 분류
    if (dataList.any(isSupplement)) {
      return ExchangeType.supplement;
    }

    // 순환교체 4단계 이상이 있으면 순환교체로 분류
    for (final data in dataList) {
      final step = GroupIdParser.extractCircularStep(data.groupId);
      if (step != null && step >= 4) {
        return ExchangeType.circular;
      }
    }

    // 그 외에는 수업교체
    return ExchangeType.substitution;
  }
}

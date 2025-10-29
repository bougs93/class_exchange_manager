import '../models/notice_message.dart';
import '../providers/substitution_plan_viewmodel.dart';

/// 교체 그룹 ID 파싱 헬퍼 클래스
class GroupIdParser {
  // 교체 유형 접두사 상수
  static const String circularPrefix = 'circular_exchange_';
  static const String supplementPrefix = 'supplement_exchange_';
  static const String oneToOnePrefix = 'one_to_one_exchange_';
  static const String chainPrefix = 'chain_exchange_';

  /// 순환교체 단계 수 추출
  static int? extractCircularStep(String? groupId) {
    if (groupId == null || !groupId.startsWith(circularPrefix)) return null;
    final match = RegExp(r'circular_exchange_(\d+)_').firstMatch(groupId);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// 순환교체 4단계 이상 여부 확인
  static bool isCircular4Plus(String? groupId) {
    final step = extractCircularStep(groupId);
    return step != null && step >= 4;
  }

  /// 보강 교체 여부 확인
  static bool isSupplement(String? groupId) {
    return groupId != null && groupId.startsWith(supplementPrefix);
  }

  /// 1:1 교체 여부 확인
  static bool isOneToOne(String? groupId) {
    return groupId != null && groupId.startsWith(oneToOnePrefix);
  }

  /// 연쇄 교체 여부 확인
  static bool isChain(String? groupId) {
    return groupId != null && groupId.startsWith(chainPrefix);
  }
}

/// 날짜 및 교시 정렬 헬퍼 클래스
class DataSorter {
  /// 결강일 및 교시 기준으로 정렬
  static List<SubstitutionPlanData> sortByDateAndPeriod(
    List<SubstitutionPlanData> dataList,
  ) {
    final sorted = List<SubstitutionPlanData>.from(dataList);
    sorted.sort((a, b) {
      // 결강일 기준으로 정렬
      final aDate = a.absenceDate;
      final bDate = b.absenceDate;

      if (aDate != bDate) {
        return aDate.compareTo(bDate);
      }

      // 같은 날이면 교시 순으로
      final aPeriod = int.tryParse(a.period) ?? 0;
      final bPeriod = int.tryParse(b.period) ?? 0;
      return aPeriod.compareTo(bPeriod);
    });
    return sorted;
  }
}

/// 메시지 포맷터 (간소화된 버전)
///
/// 기존의 4개 Strategy 클래스를 단일 static 메서드로 통합하여 간소화했습니다.
class MessageFormatter {
  /// 교체 메시지 포맷팅
  ///
  /// [data] 교체 데이터
  /// [className] 학급명
  /// [category] 교체 카테고리 (기본, 순환4+, 보강)
  /// [option] 메시지 옵션 (옵션1, 옵션2)
  ///
  /// Returns: 포맷팅된 메시지 (보강일 경우 null)
  static String? format({
    required SubstitutionPlanData data,
    required String className,
    required ExchangeCategory category,
    required MessageOption option,
  }) {
    // 보강은 별도 처리
    if (category == ExchangeCategory.supplement) {
      return null;
    }

    if (option == MessageOption.option1) {
      // 옵션1: 화살표 형태
      final arrow = category == ExchangeCategory.circularFourPlus ? '->' : '<->';
      return "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' $arrow '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}'";
    } else {
      // 옵션2: 수업 형태
      if (category == ExchangeCategory.circularFourPlus) {
        return "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 수업입니다.";
      } else {
        return "'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 수업입니다.";
      }
    }
  }
}

/// 교체 유형 카테고리 (메시지 처리 방식 구분)
enum ExchangeCategory {
  basic,           // 1:1교체, 순환교체 3단계, 연쇄교체 (동일한 방식)
  supplement,      // 보강교체 (별도 방식)
  circularFourPlus, // 순환교체 4단계 이상 (별도 방식)
}

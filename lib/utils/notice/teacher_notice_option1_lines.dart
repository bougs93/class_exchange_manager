import '../../providers/substitution_plan_viewmodel.dart';
import '../notice_message_helpers.dart';
import 'notice_exchange_category.dart';

/// 교사 메시지 옵션1(교체 안내 형태) 라인 생성 로직
class TeacherNoticeOption1Lines {
  /// 교사 메시지 옵션1 라인 생성
  static List<String> generateTeacherOption1Lines(
    List<SubstitutionPlanData> sortedDataList,
    String teacherName,
  ) {
    final List<String> exchangeLines = [];
    final Set<String> processedCircularGroups = {};

    for (final data in sortedDataList) {
      final category = NoticeExchangeCategorizer.getExchangeCategory(data);

      switch (category) {
        case ExchangeCategory.basic:
          exchangeLines.add(_formatBasicExchangeOption1(data));
          break;
        case ExchangeCategory.circularFourPlus:
          _addCircularExchangeOption1(
            data,
            sortedDataList,
            teacherName,
            exchangeLines,
            processedCircularGroups,
          );
          break;
        case ExchangeCategory.supplement:
          _addSupplementExchangeOption1(data, teacherName, exchangeLines);
          break;
      }
    }

    return exchangeLines;
  }

  /// 기본 교체 옵션1 포맷팅
  static String _formatBasicExchangeOption1(SubstitutionPlanData data) {
    final className = data.fullClassName;
    return "${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher} <-> ${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher} 수업 교체되었습니다.";
  }

  /// 순환교체 4단계+ 옵션1 추가
  static void _addCircularExchangeOption1(
    SubstitutionPlanData data,
    List<SubstitutionPlanData> sortedDataList,
    String teacherName,
    List<String> exchangeLines,
    Set<String> processedCircularGroups,
  ) {
    if (data.groupId == null ||
        processedCircularGroups.contains(data.groupId)) {
      return;
    }

    processedCircularGroups.add(data.groupId!);

    // 같은 그룹의 모든 PlanData 찾기
    final groupData =
        sortedDataList.where((d) => d.groupId == data.groupId).toList();

    // 현재 교사의 출발지와 도착지 찾기
    final route = _findCircularRoute(groupData, teacherName);

    if (route != null) {
      exchangeLines.add(
        "${route['departure']} -> ${route['arrival']} ${route['subject']} ${route['className']} 이동 되었습니다.",
      );
    }
  }

  /// 순환교체 경로 찾기 (출발지 → 도착지)
  static Map<String, String>? _findCircularRoute(
    List<SubstitutionPlanData> groupData,
    String teacherName,
  ) {
    String? departureInfo;
    String? arrivalInfo;
    String? teacherSubject;
    String? teacherClassName;

    // 1. 출발지 찾기: teacher == teacherName인 PlanData의 absenceDate
    for (final d in groupData) {
      if (d.teacher == teacherName) {
        departureInfo =
            "${d.formattedAbsenceDate} ${d.absenceDay} ${d.period}교시";
        teacherSubject = d.subject;
        teacherClassName = d.fullClassName;
        break;
      }
    }

    // 2. 도착지 찾기: substitutionTeacher == teacherName인 PlanData의 absenceDate
    for (final d in groupData) {
      if (d.substitutionTeacher == teacherName &&
          d.substitutionSubject == teacherSubject) {
        arrivalInfo = "${d.formattedAbsenceDate} ${d.absenceDay} ${d.period}교시";
        break;
      }
    }

    // 3. 메시지 생성 (출발지와 도착지가 모두 있을 때만)
    if (departureInfo != null &&
        arrivalInfo != null &&
        teacherSubject != null &&
        teacherClassName != null) {
      return {
        'departure': departureInfo,
        'arrival': arrivalInfo,
        'subject': teacherSubject,
        'className': teacherClassName,
      };
    }

    return null;
  }

  /// 보강 옵션1 추가
  static void _addSupplementExchangeOption1(
    SubstitutionPlanData data,
    String teacherName,
    List<String> exchangeLines,
  ) {
    final className = data.fullClassName;

    if (teacherName == data.teacher) {
      exchangeLines.add(
        "${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} 결강 되었습니다.",
      );
    } else if (teacherName == data.supplementTeacher) {
      exchangeLines.add(
        "${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} 보강 수업입니다.",
      );
    }
  }
}

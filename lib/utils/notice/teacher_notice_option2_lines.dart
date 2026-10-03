import '../../providers/substitution_plan_viewmodel.dart';
import '../date_format_utils.dart';
import '../notice_message_helpers.dart';
import 'notice_exchange_category.dart';
import 'teacher_notice_dual_lines.dart';
import 'teacher_notice_line.dart';

/// 교사 메시지 옵션(수업 안내 형태) 라인 생성 로직
///
/// 결강 줄과 수업 줄을 교체 건(행) 단위로 묶어서 순서대로 내보내지 않고,
/// 모든 줄을 각자의 실제 날짜·교시로 한 번에 정렬한다 — 한 교사가 여러
/// 건의 교체에 걸쳐 있을 때 수업 날짜가 결강 날짜보다 빠른 경우가 있어
/// 행 단위 정렬만으로는 줄 순서가 뒤섞였다(2026-09-30 수정).
class TeacherNoticeOption2Lines {
  /// 교사 메시지 옵션2 라인 생성
  static List<String> generateTeacherOption2Lines(
    List<SubstitutionPlanData> sortedDataList,
    String teacherName,
  ) {
    final List<TeacherNoticeLine> lines = [];

    // 2중교체와 일반 교체 분리
    final dualGroups = <String?, List<SubstitutionPlanData>>{};
    final nonDualData = <SubstitutionPlanData>[];

    for (final data in sortedDataList) {
      final isDualExchange =
          (data.groupId != null && GroupIdParser.isDual(data.groupId!)) ||
          data.remarks.contains('2중교체');

      if (isDualExchange) {
        dualGroups.putIfAbsent(data.groupId, () => []).add(data);
      } else {
        nonDualData.add(data);
      }
    }

    // 2중교체 그룹별로 최종 결과 계산하여 메시지 생성
    for (final groupDataList in dualGroups.values) {
      lines.addAll(
        TeacherNoticeDualLines.generateDualExchangeOption2Lines(
          groupDataList,
          teacherName,
        ),
      );
    }

    // 일반 교체 메시지 생성
    lines.addAll(_generateNonDualTeacherLines(nonDualData, teacherName));

    lines.sort((a, b) {
      final aDate = a.date;
      final bDate = b.date;
      if (aDate != null && bDate != null) {
        final dateCompare = aDate.compareTo(bDate);
        if (dateCompare != 0) return dateCompare;
      } else if (aDate != null) {
        return -1;
      } else if (bDate != null) {
        return 1;
      }
      return a.period.compareTo(b.period);
    });

    return lines.map((line) => line.text).toList();
  }

  /// 일반 교체 교사 메시지 라인 생성
  static List<TeacherNoticeLine> _generateNonDualTeacherLines(
    List<SubstitutionPlanData> dataList,
    String teacherName,
  ) {
    final List<TeacherNoticeLine> classLines = [];

    // 순환교체 그룹별로 처리된 항목 추적 (중복 방지)
    final Set<String> processedCircularGroups = {};

    for (final data in dataList) {
      final category = NoticeExchangeCategorizer.getExchangeCategory(data);

      switch (category) {
        case ExchangeCategory.basic:
          classLines.addAll(
            _generateBasicExchangeTeacherLines(data, teacherName),
          );
          break;
        case ExchangeCategory.circularFourPlus:
          // 순환교체 4단계 이상: 그룹별로 한 번만 처리
          if (data.groupId != null &&
              !processedCircularGroups.contains(data.groupId)) {
            processedCircularGroups.add(data.groupId!);

            // 같은 그룹의 모든 PlanData 찾기
            final groupData =
                dataList.where((d) => d.groupId == data.groupId).toList();

            // 그룹 전체를 전달하여 처리
            classLines.addAll(
              _generateCircularFourPlusTeacherLines(groupData, teacherName),
            );
          }
          break;
        case ExchangeCategory.supplement:
          classLines.addAll(_generateSupplementTeacherLines(data, teacherName));
          break;
      }
    }

    return classLines;
  }

  /// 기본 교체 교사 메시지 라인 생성
  ///
  /// "수업입니다" 줄은 그 시간에 실제로 수업을 하는 사람(=이 교사 자신)의
  /// 과목을 써야 한다 — 원래 그 시간대에 있던 상대방 과목이 아니다. 교사는
  /// 자리를 옮겨도 자기 과목을 그대로 가르치기 때문이다(2026-09-30, 과목
  /// 뒤바뀜 버그 수정: 기존엔 상대방 과목(substitutionSubject/subject)을
  /// 반대로 썼었다).
  static List<TeacherNoticeLine> _generateBasicExchangeTeacherLines(
    SubstitutionPlanData data,
    String teacherName,
  ) {
    final List<TeacherNoticeLine> lines = [];

    if (teacherName == data.teacher) {
      lines.add(
        TeacherNoticeLine(
          date: DateFormatUtils.parseYearMonthDay(data.absenceDate),
          period: int.tryParse(data.period) ?? 0,
          text:
              "${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.subject} ${data.fullClassName} 결강입니다.",
        ),
      );
      lines.add(
        TeacherNoticeLine(
          date: DateFormatUtils.parseYearMonthDay(data.substitutionDate),
          period: int.tryParse(data.substitutionPeriod) ?? 0,
          text:
              "${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.subject} ${data.fullClassName} 수업입니다.",
        ),
      );
    } else if (teacherName == data.substitutionTeacher) {
      lines.add(
        TeacherNoticeLine(
          date: DateFormatUtils.parseYearMonthDay(data.substitutionDate),
          period: int.tryParse(data.substitutionPeriod) ?? 0,
          text:
              "${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.substitutionSubject} ${data.fullClassName} 결강입니다.",
        ),
      );
      lines.add(
        TeacherNoticeLine(
          date: DateFormatUtils.parseYearMonthDay(data.absenceDate),
          period: int.tryParse(data.period) ?? 0,
          text:
              "${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.substitutionSubject} ${data.fullClassName} 수업입니다.",
        ),
      );
    }

    return lines;
  }

  /// 순환교체 4단계 이상 교사 메시지 라인 생성 (옵션2)
  static List<TeacherNoticeLine> _generateCircularFourPlusTeacherLines(
    List<SubstitutionPlanData> groupData,
    String teacherName,
  ) {
    final List<TeacherNoticeLine> lines = [];

    // 현재 교사의 출발지와 도착지 찾기
    String? departureInfo; // 출발: 날짜 요일 교시
    String? arrivalInfo; // 도착: 날짜 요일 교시
    String? teacherSubject; // 과목
    String? teacherClassName; // 학급
    DateTime? departureDate;
    int departurePeriod = 0;

    // 순환교체: 각 교사는 자신의 과목을 들고 출발지 → 도착지로 이동
    // 1. 출발지 찾기: teacher == teacherName인 PlanData의 absenceDate
    for (final d in groupData) {
      if (d.teacher == teacherName) {
        // 출발지: absenceDate (결강일) - 교사가 자신의 과목을 들고 출발하는 곳
        departureInfo =
            "${d.formattedAbsenceDate} ${d.absenceDay} ${d.period}교시";
        // 과목과 학급은 출발지에서 가져옴
        teacherSubject = d.subject;
        teacherClassName = d.fullClassName;
        departureDate = DateFormatUtils.parseYearMonthDay(d.absenceDate);
        departurePeriod = int.tryParse(d.period) ?? 0;
        break;
      }
    }

    // 2. 도착지 찾기: substitutionTeacher == teacherName인 PlanData의 absenceDate
    // 순환교체에서 교사는 다른 교사의 원래 시간대로 이동하므로,
    // substitutionTeacher가 자신인 PlanData의 absenceDate가 최종 도착지
    for (final d in groupData) {
      if (d.substitutionTeacher == teacherName &&
          d.substitutionSubject == teacherSubject) {
        // 도착지: absenceDate (결강일) - 교사가 자신의 과목을 들고 도착하는 곳
        arrivalInfo = "${d.formattedAbsenceDate} ${d.absenceDay} ${d.period}교시";
        break;
      }
    }

    // 3. 메시지 생성 (출발지와 도착지가 모두 있을 때만)
    if (departureInfo != null &&
        arrivalInfo != null &&
        teacherSubject != null &&
        teacherClassName != null) {
      lines.add(
        TeacherNoticeLine(
          date: departureDate,
          period: departurePeriod,
          text:
              "$departureInfo -> $arrivalInfo $teacherSubject $teacherClassName 이동 되었습니다.",
        ),
      );
    }

    return lines;
  }

  /// 보강 교사 메시지 라인 생성
  static List<TeacherNoticeLine> _generateSupplementTeacherLines(
    SubstitutionPlanData data,
    String teacherName,
  ) {
    final List<TeacherNoticeLine> lines = [];
    final date = DateFormatUtils.parseYearMonthDay(data.absenceDate);
    final period = int.tryParse(data.period) ?? 0;

    if (teacherName == data.teacher) {
      lines.add(
        TeacherNoticeLine(
          date: date,
          period: period,
          text:
              "${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.fullClassName} ${data.subject} 결강 되었습니다.",
        ),
      );
    } else if (teacherName == data.supplementTeacher) {
      lines.add(
        TeacherNoticeLine(
          date: date,
          period: period,
          text:
              "${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.fullClassName} ${data.supplementSubject} 보강 수업입니다.",
        ),
      );
    }

    return lines;
  }
}
